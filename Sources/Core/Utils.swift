import Foundation
import ConcordiumWalletCrypto
import Concordium
import MnemonicSwift

//public enum Network: String {
//    case mainet
//    case testnet
//}
public typealias Network = ConcordiumWalletCrypto.Network
public func getNetworkConfiguration(_ net: Network) -> NetworkConfiguration {
    switch net {
    case .mainnet:
        return mainnet
    case .testnet:
        return testnet
    }
}

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


