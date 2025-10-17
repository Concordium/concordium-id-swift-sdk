import Foundation
import MnemonicSwift
import CryptoKit
import ConcordiumWalletCrypto
import Concordium

public final class ConcordiumIDAppSDK {

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
}

public typealias Network = ConcordiumWalletCrypto.Network

// References: https://namespaces.chainagnostic.org/ccd/caip2
public func formatChainId(_ genesisHash: String) -> String {
    let prefix = String(genesisHash.prefix(32))
    return "ccd:\(prefix)"
}

/// Construct seed from seed phrase.
public func decodeSeed(_ seedPhrase: String, _ network: Network) throws -> WalletSeed {
    let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
    return try WalletSeed(seedHex: seedHex, network: network)
}

/// Fetch all identity providers.
public func identityProviders(_ walletProxy: WalletProxy) async throws -> [IdentityProvider] {
    let res = try await walletProxy.getIdentityProviders.send(session: URLSession.shared)
    return try res.map { try $0.toSDKType() }
}

/// Fetch an identity provider with a specific ID.
public func findIdentityProvider(_ walletProxy: WalletProxy, _ id: IdentityProviderID) async throws -> IdentityProvider? {
    let res = try await identityProviders(walletProxy)
    return res.first { $0.info.identity == id }
}

/// Create identity recovery request
public func makeIdentityRecoveryRequest(
    _ seed: WalletSeed,
    _ cryptoParams: CryptographicParameters,
    _ identityProvider: IdentityProvider,
    _ identityIndex: IdentityIndex
) throws -> IdentityRecoveryRequest {
    let identityRequestBuilder = SeedBasedIdentityRequestBuilder(
        seed: seed,
        cryptoParams: cryptoParams
    )
    let reqJSON = try identityRequestBuilder.recoveryRequestJSON(
        provider: identityProvider.info,
        index: identityIndex,
        time: Date.now
    )
    let urlBuilder = IdentityRequestURLBuilder(callbackURL: nil)
    return try urlBuilder.recoveryRequest(
        baseURL: identityProvider.metadata.recoveryStart,
        requestJSON: reqJSON
    )
}

/// Create identity issuance request
public func makeIdentityIssuanceRequest(
    _ seed: WalletSeed,
    _ cryptoParams: CryptographicParameters,
    _ identityProvider: IdentityProvider,
    _ identityIndex: IdentityIndex,
    _ anonymityRevocationThreshold: RevocationThreshold
) throws -> String {
    let identityRequestBuilder = SeedBasedIdentityRequestBuilder(
        seed: seed,
        cryptoParams: cryptoParams
    )
    return try identityRequestBuilder.issuanceRequestJSON(
        provider: identityProvider,
        index: identityIndex,
        anonymityRevocationThreshold: anonymityRevocationThreshold
    )
}


