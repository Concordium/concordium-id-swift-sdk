//
//  ConcordiumIDAppSDK.swift
//  ConcordiumIDApp
//
//  Created by Lov Niveriya on 02/11/2025.
//

import Foundation
import MnemonicSwift
import CryptoKit
import ConcordiumWalletCrypto
import Concordium
import GRPC

// MARK: - Configuration

public struct ConcordiumConfiguration {
    public let enableDebugging: Bool
    public let network: Network
    public let transactionExpiryMinutes: Int

    public static let test = ConcordiumConfiguration(
        enableDebugging: true,
        network: .testnet,
        transactionExpiryMinutes: 16
    )

    public static let production = ConcordiumConfiguration(
        enableDebugging: false,
        network: .mainnet,
        transactionExpiryMinutes: 16
    )
}

// MARK: - SDK Error Definitions

extension ConcordiumIDAppSDK {
    enum SDKError: LocalizedError {
        case notInitialized
        case invalidTransactionData
        case identityProviderNotFound
        case networkFailure(String)
        case serializationFailure(String)

        var errorDescription: String? {
            switch self {
            case .notInitialized:
                return "Concordium SDK not initialized. Please call initialize() first."
            case .invalidTransactionData:
                return "Transaction data is invalid or improperly formatted."
            case .identityProviderNotFound:
                return "Specified Identity Provider not found."
            case .networkFailure(let reason):
                return "Network operation failed: \(reason)"
            case .serializationFailure(let details):
                return "Failed to serialize/deserialize data: \(details)"
            }
        }
    }
}

// MARK: - SDK Core

public final class ConcordiumIDAppSDK {

    // MARK: - Properties

    private static var configuration: ConcordiumConfiguration?

    // MARK: - Initialization

    private init() {}

    public static func initialize(with configuration: ConcordiumConfiguration = .production) {
        self.configuration = configuration
        if configuration.enableDebugging {
            print("[ConcordiumSDK] Initialized with configuration: \(configuration.network)")
        }
    }

    private static func ensureInitialized() throws {
        guard configuration != nil else { throw SDKError.notInitialized }
    }

    // MARK: - Public APIs

    /// Creates and submits a credential deployment transaction.
    public static func signAndSubmit(
        seedPhrase: String,
        transactionInput: String,
        client: NodeClient,
        identityProviderID: IdentityProviderID
    ) async throws {
        try ensureInitialized()
        guard let config = configuration else { return }

        log("Starting credential deployment process...")

        // Parse transaction input JSON
        let transactionData = try parseTransactionInput(transactionInput)
        log("Parsed transaction data: expiry=\(transactionData.expiry)")

        // Create WalletSeed from mnemonic
        let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
        let seed = try WalletSeed(seedHex: seedHex, network: config.network)

        // Fetch cryptographic parameters from chain
        log("Fetching cryptographic parameters...")
        let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)

        // Recover identity using Identity Provider
        //TODO: How we will get the URL for this
        let walletProxy = WalletProxy(baseURL: URL(string: "https://testnet-wallet-proxy.concordium.com")!)
        //MARK: This will give the ipCdiVerifyKey automatically ->>>>>>>>>>>>>>>
        guard let providerJSON = try await findIdentityProvider(
            walletProxy: walletProxy,
            id: identityProviderID
        )
        else {
            throw SDKError.identityProviderNotFound
        }

        let identityProvider = try providerJSON.toSDKType()

        //MARK: This have signature  ->>>>>>>>>>>>>>>
        let recoveryRequest = try makeIdentityRecoveryRequest(
            seed: seed,
            cryptoParams: cryptoParams,
            identityProvider: identityProvider,
            identityIndex: 0
        )

        log("Recovering identity from provider...")
        let recoveryResponse = try await recoveryRequest.send(session: .shared)
        let identity = try recoveryResponse.result.get()

        // Derive account credentials and sign transaction
        log("Deriving account and signing transaction...")
        let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)

        let seedIndexes = AccountCredentialSeedIndexes(
            identity: IdentitySeedIndexes(providerID: 0, index: 0),
            counter: 0
        )

        let credential = try accountDerivation.deriveCredential(
            seedIndexes: seedIndexes,
            identity: identity.value,
            provider: identityProvider,
            threshold: 1
        )

        let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])
        let expiry = UInt64(Date().timeIntervalSince1970 + Double(config.transactionExpiryMinutes * 60))
        let signedTransaction = try account.keys.sign(deployment: credential.credential, expiry: expiry)

        // Serialize and submit transaction
        let serializedTransaction = try signedTransaction.serialize()
        log("Submitting credential deployment transaction...")

        let txResponse = try await client.send(deployment: serializedTransaction)
        let (blockHash, summary) = try await txResponse.waitUntilFinalized(timeoutSeconds: 10)

        log("Transaction finalized in block \(blockHash): \(summary)")
    }

    // MARK: - Identity Provider Helpers

    static func findIdentityProvider(walletProxy: WalletProxy, id: IdentityProviderID) async throws -> IdentityProviderJSON? {
        let providers = try await walletProxy.getIdentityProviders.send(session: .shared)
        return providers.first { $0.ipInfo.ipIdentity == id }
    }

    static func makeIdentityRecoveryRequest(
        seed: WalletSeed,
        cryptoParams: CryptographicParameters,
        identityProvider: IdentityProvider,
        identityIndex: IdentityIndex
    ) throws -> IdentityRecoveryRequest {
        let builder = SeedBasedIdentityRequestBuilder(seed: seed, cryptoParams: cryptoParams)
        let requestJSON = try builder.recoveryRequestJSON(
            provider: identityProvider.info,
            index: identityIndex,
            time: Date()
        )

        let urlBuilder = IdentityRequestURLBuilder(callbackURL: nil)
        return try urlBuilder.recoveryRequest(
            baseURL: identityProvider.metadata.recoveryStart,
            requestJSON: requestJSON
        )
    }

    // MARK: - Transaction Input Parser

    private static func parseTransactionInput(_ input: String) throws -> (unsignedCdi: String, expiry: Int64) {
        guard let data = input.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let unsignedCdi = json["unsignedCdiStr"] as? String,
              let expiry = json["expiry"] as? Int64 else {
            throw SDKError.invalidTransactionData
        }
        return (unsignedCdi, expiry)
    }

    // MARK: - GRPC Client Wrapper

    struct GRPCOptions: Encodable {
        var host: String = "grpc.testnet.concordium.com"
        var port: Int = 20000
        var insecure: Bool = false
    }

    func withGRPCClient<T>(_ execute: (GRPCNodeClient) async throws -> T) async throws -> T {
        let opts = GRPCOptions()
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

        let connectionBuilder = opts.insecure
            ? ClientConnection.insecure(group: group)
            : ClientConnection.usingPlatformAppropriateTLS(for: group)

        let connection = connectionBuilder.connect(host: opts.host, port: opts.port)
        let client = GRPCNodeClient(channel: connection)

        do {
            let result = try await execute(client)
            try await connection.close().get()
            try await group.shutdownGracefully()
            return result
        } catch {
            try? await connection.close().get()
            try? await group.shutdownGracefully()
            throw SDKError.networkFailure(error.localizedDescription)
        }
    }

    // MARK: - Utilities

    private static func log(_ message: String) {
        guard configuration?.enableDebugging == true else { return }
        print("[ConcordiumSDK] \(message)")
    }
}

// MARK: - Account Key Generation Utility

extension ConcordiumIDAppSDK {
    public static func generateAccountKeyPair(
        from seedPhrase: String,
        network: Network,
        accountIndex: Int = 0
    ) async throws -> CCDAccountKeyPair {
        let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
        let seed = try WalletSeed(seedHex: seedHex, network: network)

        let indexes = AccountCredentialSeedIndexes(
            identity: IdentitySeedIndexes(providerID: 0, index: IdentityIndex(accountIndex)),
            counter: 0
        )

        let privateKey = try seed.signingKey(accountCredentialIndexes: indexes)
        let publicKey = privateKey.publicKey

        return CCDAccountKeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}

// MARK: - Model: CCDAccountKeyPair

public struct CCDAccountKeyPair {
    public let privateKey: Curve25519.Signing.PrivateKey
    public let publicKey: Curve25519.Signing.PublicKey
}

/*

 func generateAccountWithSeedPhrase(seed: seedPhrase,
     network: network,
     accountIndex: accountIndex){
 let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
 let seed = try WalletSeed(seedHex: seedHex, network: 'Testnet')
 let idxs = AccountCredentialSeedIndexes(identity: IdentitySeedIndexes(providerID: 0, index: 0),counter: 0)

 let privateKey: Data = try seed.signingKey(
             accountCredentialIndexes: idxs
     )
 let publicKey = try seed.publicKey(
     accountCredentialIndexes: idxs
     )

 func signAndSubmit(seedPhrase, serializedCredentialDeploymentTransaction) -> blockHash{

 //////  ---- Parse the input ---
 /// deserialise unsignedCdiStr
 let unsignedCdi = JSONbig.parse(
     serializedCredentialDeploymentTransaction.unsignedCdiStr,
     );

 let expiry = serializedCredentialDeploymentTransaction.expiry

 /// no use...
 // let randomness = serializedCredentialDeploymentTransaction.randomness
 //////  ---- Parse the input ---

 // reference: https://github.com/Concordium/concordium-swift-sdk/blob/16598566a721eccdb1d94e0aace15481df41b10f/examples/CLI/Sources/ConcordiumExampleClient/commands.swift#L807

 let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
 let seed = try WalletSeed(seedHex: seedHex, network: 'Testnet')
 let idxs = AccountCredentialSeedIndexes(identity: IdentitySeedIndexes(providerID: 0, index: 0),counter: 0)

 // let privateKey: Data = try seed.signingKey(
 //             accountCredentialIndexes: idxs
 //     )
 // let publicKey = try seed.publicKey(
 //     accountCredentialIndexes: idxs
 //     )


 // todo 1: find out how to form client object
 let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
 let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)

 // todo 2: Find out type of credentials in deriveAccount function
 let account = try accountDerivation.deriveAccount(credentials: [idxs])
 let signedTx = try account.keys.sign(deployment: unsignedCdi, expiry: expiry)

 // let signature = try Curve25519.Signing.PrivateKey(
 //             rawRepresentation: privateKey
 //         ).signature(for: message)

 print("Serializing credential deployment.")
 let serializedTx = try signedTx.serialize()

 // send
 try await withGRPCClient() { client in
 let tx = try await client.send(deployment: serializedTx)
     print("Transaction with hash '\(tx.hash)' successfully submitted. Waiting for finalization.")
     let (blockHash, summary) = try await tx.waitUntilFinalized(timeoutSeconds: 10)
     print("Transaction finalized in block \(blockHash): \(summary)")
 }
 }

 ///

 /// Input from idApp
 let serializedCredentialDeploymentTransaction = {
     "expiry": 1761728783,
     "randomness": {
         "attributesRand": {
             "countryOfResidence": "1f10fdfa86932309dee12843d0a5b0718cb681ae37dc9965cda2bddf256198ed",
             "dob": "15df7849a1efd608b3ec10f2f0d95cbe08afa03e2aa7c3e2eeac47084939ccad",
             "firstName": "641e3ec128611bd0ac4068db8359402ea39f2bc9375dc34ba0854dae8faecea0",
             "idDocExpiresAt": "3a241a1c27352a1969e34b9bab6e810564f34b4d0fb5faa08e825e70c8eb3bac",
             "idDocIssuedAt": "1b0a2abe70ac9b060171af2335fe0ed872ce8dca75141894d4d72d01950e1eb7",
             "idDocIssuer": "3417e7380709e5c34d5193b554726b6226734bc59f8e7b8c0f695657d7fe5bb3",
             "idDocNo": "360db545f71d65bf807322e72b8339db0c32415737a7a3279eabd4d846aadc64",
             "idDocType": "0f36083df36c95a445d329a1d640533237e43ca6163fd9836d2fb303bd388d1c",
             "lastName": "1d9e41694f797b816501dba0132cb98ae5bb52dffb33fa0a261717846cebc457",
             "nationalIdNo": "246a80388e95b3a48dbdea0c4a7e1e6c28feb550a83ec4cc193a47d819fa3ad7",
             "nationality": "5c5abac7ffdb3c89c229abce3a57efdc2c30ad8319b22fe75c513cbaea247e80",
             "sex": "334d94bc04f3852df2932225f1a8a6bf37bd23ce9d6352f235894686cec0d595",
             "taxIdNo": "6bfe25b426bbb66a18cfd741b2cd23747e08122703be7a67978c62f4e46de121"
         },
         "credCounterRand": "1cdbc18e0dc3bbcd7d7e57da796cbc5431f125d5ec5630723de041ff3ccceb93",
         "idCredSecRand": "65767545bee5ad170d19638ec824c0300a94ec6e49c3da58d474d8db10aba657",
         "maxAccountsRand": "391b372ea8ca218a2ae52e5301e09c58dfad7bd00b9f33bc85b3bf1f9993f056",
         "prfRand": "719c924dac2d08286c6c2c927e28ba129ca1129516fef2e00bc5548dc6335c22"
     },
     "unsignedCdiStr": "{\"arData\":{\"1\":{\"encIdCredPubShare\":\"94dabaef0aee815d8eee92fa93743f70ae40f3fefed20f9d6dec9f09226df10e15d47d49731c145c33d54d36137d526c86d786f54821b69d776e1269e1b9e435e408fd2c3bc26d6b68e71e89e28e1edf22ea9f2459a6a1964700cd636d0e464b\"},\"2\":{\"encIdCredPubShare\":\"aa51b298a445911c241ceba22eadab69fcfb4c30e624148e839fb3f5e1bf1f75e0f3aa592ff24832bc38c10eba2d8467891e6938240866677c4897474cad8c1bc9bbf00e61962a204b7f76d77903c50045202edaaa85b8078dd2e08db5c25c7c\"},\"3\":{\"encIdCredPubShare\":\"8bf0e3d115afe112d81ef3510568b814167280e846edc0ff7bd6b53ec64e692a22b4051b427e3ddfa0617681d648f05c8a22a66838ff6f097c0094c133e133efd39d7f150663ad19c644b1e333d7bd95bd17a28b495c8a3a2bb25e5189e982d8\"}},\"credId\":\"a9a817aed3ac63f384ca2acee366cc78b1ffe571edc356140778921889268b500e6a180a70d99b2a841e874d1e145886\",\"credentialPublicKeys\":{\"keys\":{\"0\":{\"schemeId\":\"Ed25519\",\"verifyKey\":\"51d0621532c01d4c00d6d411ad97047cceac743c5cb3b19526221e9b6f503d10\"}},\"threshold\":1},\"ipIdentity\":0,\"policy\":{\"createdAt\":\"202509\",\"revealedAttributes\":{},\"validTo\":\"202609\"},\"proofs\":{\"challenge\":\"fcb1077fc7748cbacb560b88db40a697fd3b272f4b5a3aeaeeb6acda3ebb7cb4\",\"commitments\":\"a59750d8c43a9f9660a5958883be7308119a168e9cca5764750c4084d3b6694423d5e43002b704cafce187819de27ddf8e9f422f6e208e5cae196e88c23a56f86ee99f160072bc02814792b865340716c9933ee182a24e9f83a99c8114728bfda2f3f28d9fad42adcb5016306842c3220b36b6add29f627e6a014851c6646ab3e8e2fac40ae2a9e5cad2325d73b992eb000d00b13d280eebb818101e221be76ced1819b84b6d163f97e7e11301449e3b66bee977ed938f6346be385577b430f9faf8ed01a3baca8bababe41fcfbaa07b37b64f31a490a7d86e8b94724cd550acd651c11274110d6f8c95891bed1bfb97b97ce13b0295f49a153abfd3dcc20d99b9bb860c2641c596d5177acfc724d6e3345b79b1af76f98ebdde820311038019ca045eb258039243ef4af203197a9cc21725b5e496bbf98385d990d1dd42ea073c23e54a17622ef726ef655c0e1de187f2bd3e668fc804a1ea0c625c804d23eca85e95c929388ea2d6591da551d72017fb3ae6bbc196a1f48c00d106f549f877e391b0ec17c64a0594469d8d1c62c574f03c326d9d5e2b3f7dae5551b04d5becae7ad5fef2229d02ae9d89ada39a0bf01ef69b0e44ba265706b8e6a7e49f61818ebdd3051f3f5b921cef8dcf6db89556df8b6e29f7d192c130bdcef27efdc5c0b0494a324f84840f1507972f031394d19878958bbd628db816a51e5358dde62672cbfed6a1bbab45446d354b6f6cecc36e4955a45b3b814efaa90894adf2e83fd8870f548d0f1b3953473b632feecaea089aee787fdb613d084460e74f976bfae21d1fbd9d8135e311f336099139a4b5e71fbeaa77f223ec42262e50b53d17c495f65f274ed66638a4b843c5b6ce07f140053d01ce8afdb3313dfdff0a81750f761b59e37d736cd728fcd239543f8781ff597400f819466e6c9be38b379621191297a7e90d54648ca6243a9f650bb8a50b908ed8aa312545b85a24342ba39fa71a9fa0cfbf001f11e3b96bad908af3ccc0794abafe02fb2b9517783a70590c8606e3e6e2c3d7e2d6b9f31d51f08143d8b401a5e5da6b1ca21dc66a5f037cf00ee2c9d4e1624300a765bb6f634690410000000000000002b39cf01daeafdb53c464dce4422d2f84c5d95a4d56c28b64635ab889beef5b3e2a42c3872ed14cbc03075b8c09b94285996b2bfef1f3fe466f03f71dcedcae610821c63d1e8f9b3a3b98ed6218568cd86fa8b5b027fc938f914ebd511196a76f\",\"credCounterLessThanMaxAccounts\":\"a7f7c42d77a226eeaf33f65166321e9db9ae2fa537d36f0f7d6d965fb6933345e45f5c70db2d31376fbcebb59f6c1c90b73bf2307d4e42b1635b84a3417887b1238b24c27bbca1d251d240165bf3e6b119e62f29cd2bafb9502e4c1010d22c319959224247bc6f25617cf15ca7d454c1dde8a1ef6d85568533b65abb85faa6551245e143ab7c0965f0645c22d1704d05824e526daf9e97ba4373f0a3cacfd34bdfd100f24631e9b82ec7e17bff6fc56ce81d20d83caae078626ad693942ef2ed02c67fac31c0a9bb458851d3601b120d2843808a839541dea5fdba1ef9b1c4b141765445bb631bc62855d4dd89edf718779320bf07caf68690f48e56caa39647253e7d4e162662d077017da303c86966636090a9c8be5ff553491ee8e7e2e33a000000048b196b032344226aa54c91447661b9921d07f1df93ff02ac8c5ca19fbb8b8d30825125a60160d30980b75a166617351da3361d69c1b7ffd631d5ac080b12587d595734788c1f0b251161717a1c84fad3cca0d096c81c2f9d626d4297f8dcd67cb8cb4258c7540f9fa00e9f0903dd21eb8fbe925aa912d8272a1d7881ce3f0947fc5a2071731e6c7fbd74632b7b845dc487b451c3a4bfe5858329e851d45899f8093872076f59801adcb210fb6ffcb93ff8444cd0f9362ce3c9ff897c83c33a86ae8022dc78113d064800ebf0c7b4276c94631300ccff49cad8f530cae80875318ddd84be6fbc315a822ae3b872058714811158dbc844de883bf682bec91e82520de14ad18a1759f5323fe9be27ff244ba8407730a9df74931d76d4fc1c80e777a37d5a5fe9c7754c7357ed3aa5fa95989e222738e25a89417f63698242df5ec5162f50a5c29f38741809631d11d4662189833d2e82a9f2c1906e043704995749ba94315d7f983eeb51330c4f2fd3609b7eaaabb2691209c5ea5e9ea8a2a8fca55bbbb68e2c364a029fc5b9dd1e0a087a86027017a81c6e2731515cf9a16cb215291aeec11f11bbfe157b5e2d8de7004bdbd5d5dab8222ec69811698a723fbf9f\",\"proofIdCredPub\":{\"1\":\"06d39c1874e9ad6a86666c372746c651d396f4097631517e5627f37a14bede1a14827a6876ce6d6aa5bfb9a0497fc47939ecd024e73fb29f45e62399aabc4d2d3408f02a9067c026852b63aa76ede83446ce7c3e5e7d902c9d0370622f459152\",\"2\":\"5eb88d38ba6e3ff77039158192932c259d35966fe909af63e922b867381486a7564e9e6a3499e0a87fa3aca5d2e8d2be843e51b5e79c770458e3eafac0a510c63fa1b1a311a892c23f9accb2943a460c1cdb3cd72f4af3210fd9f3d7a9b35a96\",\"3\":\"2afed6d02324fd2f219de6f8a081839fe5dd96a8070e37d35bc905dddbac91a52dbaa633586d2c4f01cb8eb42f0d723299ba088258fcc5855b0436a070b77ad12de9faa08d0cfddbdf5694835d139152533174c8b537d5881d60651357286dfc\"},\"proofIpSig\":\"0fe17d167b862dd6daad79901dc5e80fd25f6bf7bdca6b5903caddfb1cb4cf9500000013472c38b25c35de7a8eb9a5cfe3ad0cd75179b9fdb466c2ef95f886616a399fdf7198ddb67caf95e4de48b14284510b7321eb9bd9477884b0a7e406b2258f8b491291459c10bfe10e3c844bae6bbe977ee848b05ebc1cf667d2e9f3332ea31834493dfc6b42094412f22b5550866be51674f897262acc6c36a3b19296f0d570156703c5e01047936fbb0a65c5c57ffecdcaf0952804ff542281da77ea3fe169232957de2943182efa4ed0abae8f371b7984a80c540c8649c15e5f8cca393a8f717366a9eef1bd93a6e7a77fe3d10ac757e6357f6209e64707a0c92d5c1319bcfb531e0d14c9619587f33682628619d20b410ebbc8b45d77f9f143214717c1a74306aa79d44b0b3f7df30b0345cb2dbd252be6ed415ef0aa9bded7b6eda884c27416b146c3dc97a3085d31855166cefff3cd1fc50d3ec3d852c04f0b502e433b6654a3c3333b20e32582ef8635548d07933f64a28c1bbdefc6ade8bc5467db455411bc25236a8d8b294285d4bfcdbf2825dd7608eb5842d28e0bf8643625999cc751e86e70f5a51768b9172375644ccf3086f6dee00c320a6dc62c67390afeff1a73e85540afaca4e94d1c9a378daad79a6f2df08ab562c21bfcde1e9d335ba59161aaa88284866dc7e1ba1bee64d3acf404eb1cd3b22ed6960eeec899274aaabd1b44e3f7db5c08cf4da65c21d114e4676ee203996b6c5df8625c07d257c926b147e3339322cbf6cf2c1048bc2584e3451e0a2c1c62d756e00ff37cc5f337e36901afc8ffb14ab8e2c28b5a744230abdd25b94f23f1b466662bc7b8a9416d025562bf544e7c84e61da6aa141fc9ea2a4cc5d7f45829945aaa66e9cd9395adee211c51122be03e39f856ddda81860957386cb19fe46c8cad8e62e966a32501f8f933efcd9fb1458cda6ca237159b96c0ce01c49c2697622b6dc3bb8e84640a07712468aa03f95b6acd4dbf4c661b9424fe0e970e8635dddac890f13b85b7f73ce61c5c5d70bbf7012d67b6de90c5d8eb0a2003b40c3d900c3e1710cf91e1f7ded332e84275217096881a6966138cb8db302015d096237c72108f79b6658cae421a156b68edc7fdb9735addad6064c3eae31f04321817179aa527b9975b9334e5366379a302a555ae3d3d04d4914ded73459bc69e021ccee19b47a8f5dab1507f0563e5a129f5db44b66ccb7aafd734ca57effa005fd38bd44fa86b836e0d08ad0942d0b7b8071a2e5108737d2d2eed3dde998d0bcca33099bc575414edc15a89b40a17242a8d72089de861855df0dc3065017e1c631659e1718fc4dfc5d3342382123b2c8c27b559c7041eaa9db1d1dd1ad18434c72a02dbf6e3d0d2dad948f593340b865265f636ad3193792fdb50c951f8ec585014107441edfc51a826137f2e0ae1d7b702f40e56894671dcdbff0cb045af0139fcc5878cc77f7d66b0c54d4237fe637e7c883921f73f08cf67f0c40c7431c83911e8c825a8adfab321f0adc438555e801966437ddcdabcf0d8ec7efca46f951f4f6b671210294b11bc256cbf144d4d3fa5327ba851687c15c4e763d66e5c56dd8838a035c4646f9682918afe4a8270cc4678f82adb216308c3a62186f9df6c215501005f938933b99b5b467a2ee96cc36d016798bb5f4a03fc55371508d350fecc48696042949bd5fc3bafd02eca2b9ec49dfe28297d689b97f9cebb5e0c025224202be633faed472ee29929\",\"proofRegId\":\"219339990f7825bae9d0ea6229e30df599fcce26954cb31b8b3945699e4300d22aef94a66c38361745777d8c688b86ac3ea5b671976658f2acfa7072d67a2f8a41700040249c5e8e048c67c8bd143fade881925cb2ec0879a74951eb10e3fe6f39ffa32d5ed0c33ebaf6b4c9905985e6c54bbae4dcd58e4a7d3ecda25579d97231f7bebaee194d3a4537dbb50517a4db83e702066f5d3358fdfa2b81aa1a6680\",\"sig\":\"ac29c1687176945762b5de9606b004dd6fb5e78c10d183682053e77a5901977b1f096a20c526bb5372acf8f7f25e60618d6f749593a106881ad3f3452ea3202dbd8667bb5b5033923e82abfe845039ecacf81db76d70899c27002a2f333ee6ed\"},\"revocationThreshold\":2}"
 }
 let seedPhrase =  "throw action salad convince north kit zero rude mango whip dinner situate remove maple oval draw diesel envelope inmate laptop hill visa magic stand"

 // call signAndSubmit() and print the result
 await signAndSubmit(seedPhrase, serializedCredentialDeploymentTransaction)
 */

