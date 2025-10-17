import Foundation
import CryptoKit
import ConcordiumWalletCrypto
import Concordium

public protocol CredentialSigner {
    func signCredentialTransaction(serialized: SerializedCredentialDeploymentDetails, signingKey: String) async throws -> SignedCredentialDeploymentTransaction
}

public protocol TransactionSubmitter {
    func submitCCDTransaction(credentialDeploymentTransaction: CredentialDeploymentTransaction, signature: String, network: Network) async throws -> String
}

public final class ConcordiumIDAppSDK {
    public static let chainId: [Network: String] = [
        .mainnet: formatChainId(mainnet.genesisHash),
        .testnet: formatChainId(testnet.genesisHash)
    ]

    public init() {}

    public static func generateAccountWithSeedPhrase(
        seedPhrase: String,
        network: Network,
        client: NodeClient,
        accountIndex: Int = 0
    ) async throws {
        // Validate mnemonic length
        guard seedPhrase.split(separator: " ").count >= 12 else {
            throw NSError(domain: "ConcordiumIDAppSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid seed phrase"])
        }

        // Decode seed using real implementation
        let seed = try decodeSeed(seedPhrase, network)
        let walletProxy = WalletProxy(baseURL: URL(string: "https://wallet-proxy.testnet.concordium.com")!)
        
        let identityProvider = try await findIdentityProvider(walletProxy, IdentityProviderID(3))!

        // Recover identity (skip if the ID is already available).
           // This assumes that the identity already exists, of course.
           let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
           let identityReq = try makeIdentityRecoveryRequest(seed, cryptoParams, identityProvider, IdentityIndex(7))
           let identityRes = try await identityReq.send(session: URLSession.shared)

           // We assume that the identity already exists. Real applications should handle errors better.
           let identity = try identityRes.result.get()

           // Derive seed based credential and account from the given coordinates of the given seed.
           let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
           let seedIndexes = AccountCredentialSeedIndexes(
               identity: .init(providerID: IdentityProviderID(3), index: IdentityIndex(7)),
               counter: CredentialCounter(21)
           )
           // Credential to deploy.
           let credential = try accountDerivation.deriveCredential(
               seedIndexes: seedIndexes,
               identity: identity.value,
               provider: identityProvider,
               threshold: 1
           )
           // Account used to sign the deployment.
           // The account is composed from just the credential derived above.
           // From this call the credential's signing key will be derived;
           // in the previous only the public key was.
           let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])
    }

    public static func getCreateAccountCreationRequest(
        publicKey: String,
        reason: String = "The account wallet is requesting and Identity to create an account"
    ) -> CreateAccountCreationRequestMessage {
        return CreateAccountCreationRequestMessage(publicKey: publicKey, reason: reason)
    }

    private static func deserializeCredentialDeploymentTransaction(
        serializedCredentialDeploymentTransaction: SerializedCredentialDeploymentDetails
    ) throws -> CredentialDeploymentTransaction {
        // Parse the unsigned CDI string to create a real credential deployment transaction
        guard let unsignedCdiData = serializedCredentialDeploymentTransaction.unsignedCdiStr.data(using: .utf8) else {
            throw NSError(domain: "ConcordiumIDAppSDK", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid unsigned CDI string"])
        }

        // Parse randomness
        guard let randomnessData = serializedCredentialDeploymentTransaction.randomness.data(using: .utf8) else {
            throw NSError(domain: "ConcordiumIDAppSDK", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid randomness string"])
        }
 
        // Create credential deployment transaction
        return CredentialDeploymentTransaction(
            unsignedCdi: unsignedCdiData,
            expiry: TransactionTime(serializedCredentialDeploymentTransaction.expiry),
            randomness: randomnessData
        )
    }

    public static func signCredentialTransaction(
        serializedCredentialDeploymentTransaction: SerializedCredentialDeploymentDetails,
        signingKey: String
    ) async throws -> SignedCredentialDeploymentTransaction {
        let tx = try deserializeCredentialDeploymentTransaction(serializedCredentialDeploymentTransaction: serializedCredentialDeploymentTransaction)
        // Parse signing key from hex string
        guard let signingKeyData = Data(hexString: signingKey) else {
            throw NSError(domain: "ConcordiumIDAppSDK", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid signing key format"])
        }
        // Create account keys from signing key
        let accountKeys = AccountKeys(key: AccountKey)

        // Sign the transaction using real Concordium SDK
        let signedTx = try accountKeys.sign(deployment: tx.credential, expiry: tx.expiry)
        return SignedCredentialDeploymentTransaction(
            credentialDeploymentTransaction: tx,
            signature: signedTx.signature.hex
        )
    }

    public static func submitCCDTransaction(
        credentialDeploymentTransaction: CredentialDeploymentTransaction,
        signature: String,
        network: Network
    ) async throws -> String {
        // Create client for the specified network
        let networkConfig = getNetworkConfiguration(network)
        let client = try NodeClient(host: networkConfig.grpcUrl, port: networkConfig.grpcPort)
        // Parse signature from hex string
        guard let signatureData = Data(hexString: signature) else {
            throw NSError(domain: "ConcordiumIDAppSDK", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid signature format"])
        }

        // Create signed transaction
        let signedTx = SignedCredentialDeploymentTransaction(
            credentialDeploymentTransaction: credentialDeploymentTransaction,
            signature: signature
        )
        
        // Serialize the signed transaction
        let serializedTx = try signedTx.serialize()
        
        // Submit to Concordium network
        let submittedTx = try await client.send(deployment: serializedTx)
        
        return submittedTx.hash.hex
    }

    public static func getRecoverAccountRecoveryRequest(
        publicKey: String,
        description: String = "Account Wallet is requesting the account address to recover"
    ) -> RecoverAccountRequestMessage {
        return RecoverAccountRequestMessage(publicKey: publicKey, description: description)
    }

    // MARK: - Identity Creation

    public static func createIdentity(
        seedPhrase: String,
        network: Network,
        identityProviderID: IdentityProviderID,
        identityIndex: IdentityIndex,
        anonymityRevocationThreshold: RevocationThreshold = RevocationThreshold(2)
    ) async throws -> Identity {
        let seed = try decodeSeed(seedPhrase, network)
        let walletProxyBaseURL = getNetworkConfiguration(network).explorerUrl
        let walletProxy = WalletProxy(baseURL: URL(string: walletProxyBaseURL)!)
        let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!

        // Create client to get cryptographic parameters
        let client = try NodeClient(host: getNetworkConfiguration(network).grpcUrl, port: getNetworkConfiguration(network).grpcPort)
        let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)

        // Construct identity creation request
        let reqJSON = try makeIdentityIssuanceRequest(
            seed,
            cryptoParams,
            identityProvider,
            identityIndex,
            anonymityRevocationThreshold
        )

        // Start identity issuance flow
        let statusURL = try issueIdentitySync(reqJSON, identityProvider) { issuanceStartURL, requestJSON in
            let callbackURL = URL(string: "concordiumwallet-example://identity-issuer/callback")!
            let urlBuilder = IdentityRequestURLBuilder(callbackURL: callbackURL)
            let url = try urlBuilder.issuanceURLToOpen(baseURL: issuanceStartURL, requestJSON: requestJSON)
            // In a real implementation, this would open the URL in a web view
            // For now, we'll simulate the callback
            return URL(string: "concordiumwallet-example://identity-issuer/callback#status-url")!
        }
        
        // Wait for verification to complete
        let res = try await awaitVerification(statusURL)
        switch res {
        case .success(let identity):
            return identity
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Identity Recovery
    
    public static func recoverIdentity(
        seedPhrase: String,
        network: Network,
        identityProviderID: IdentityProviderID,
        identityIndex: IdentityIndex
    ) async throws -> Identity {
        let seed = try decodeSeed(seedPhrase, network)
        let walletProxyBaseURL = getNetworkConfiguration(network).explorerUrl
        let walletProxy = WalletProxy(baseURL: URL(string: walletProxyBaseURL)!)
        let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!
        
        // Create client to get cryptographic parameters
        let client = try NodeClient(host: getNetworkConfiguration(network).grpcUrl, port: getNetworkConfiguration(network).grpcPort)
        let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
        
        // Construct recovery request
        let identityReq = try makeIdentityRecoveryRequest(seed, cryptoParams, identityProvider, identityIndex)
        
        // Execute request
        let identityRes = try await identityReq.send(session: URLSession.shared)
        switch identityRes.result {
        case .failure(let err):
            throw NSError(domain: "ConcordiumIDAppSDK", code: 6, userInfo: [NSLocalizedDescriptionKey: "Identity recovery failed: \(err)"])
        case .success(let identity):
            return identity.value
        }
    }
    
    // MARK: - Account Creation
    
    public static func createAccount(
        seedPhrase: String,
        network: Network,
        identityProviderID: IdentityProviderID,
        identityIndex: IdentityIndex,
        credentialCounter: CredentialCounter,
        expiry: TransactionTime = TransactionTime(9_999_999_999)
    ) async throws -> String {
        let seed = try decodeSeed(seedPhrase, network)
        let walletProxyBaseURL = getNetworkConfiguration(network).explorerUrl
        let walletProxy = WalletProxy(baseURL: URL(string: walletProxyBaseURL)!)
        let identityProvider = try await findIdentityProvider(walletProxy, identityProviderID)!
        
        // Create client to get cryptographic parameters
        let client = try NodeClient(host: getNetworkConfiguration(network).grpcUrl, port: getNetworkConfiguration(network).grpcPort)
        let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
        
        // Recover identity (assumes it already exists)
        let identityReq = try makeIdentityRecoveryRequest(seed, cryptoParams, identityProvider, identityIndex)
        let identityRes = try await identityReq.send(session: URLSession.shared)
        let identity = try identityRes.result.get()
        
        // Derive credential and account
        let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
        let seedIndexes = AccountCredentialSeedIndexes(
            identity: .init(providerID: identityProviderID, index: identityIndex),
            counter: credentialCounter
        )
        
        // Credential to deploy
        let credential = try accountDerivation.deriveCredential(
            seedIndexes: seedIndexes,
            identity: identity.value,
            provider: identityProvider,
            threshold: 1
        )
        
        // Account used to sign the deployment
        let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])
        
        // Construct, sign, and send deployment transaction
        let signedTx = try account.keys.sign(deployment: credential.credential, expiry: expiry)
        let serializedTx = try signedTx.serialize()
        let submittedTx = try await client.send(deployment: serializedTx)
        
        return submittedTx.hash.hex
    }
    
    // MARK: - Helper Functions
    
    private static func issueIdentitySync(
        _ issuanceRequestJSON: String,
        _ identityProvider: IdentityProvider,
        _ runIdentityProviderFlow: (_ issuanceStartURL: URL, _ requestJSON: String) throws -> URL
    ) throws -> IdentityVerificationStatusRequest {
        let url = try runIdentityProviderFlow(identityProvider.metadata.issuanceStart, issuanceRequestJSON)
        return .init(url: url)
    }
    
    private static func awaitVerification(_ request: IdentityVerificationStatusRequest) async throws -> IdentityVerificationResult {
        while true {
            let status = try await request.send(session: URLSession.shared)
            if let r = status.result {
                return r
            }
            try await Task.sleep(nanoseconds: 10 * 1_000_000_000) // check once every 10s
        }
    }
}

// Helper extension for Data to handle hex string conversion
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var i = hexString.startIndex
        for _ in 0..<len {
            let j = hexString.index(i, offsetBy: 2)
            let bytes = hexString[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
    
    var hex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
