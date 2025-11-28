//
//  KeyAccountsService.swift
//  ConcordiumIDApp
//

import Foundation
import Concordium

/// Remote API client responsible for fetching key-account metadata from the Concordium wallet proxy.
enum KeyAccountsService {

    /// Fetches all accounts that contain the given public key.
    ///
    /// - Parameters:
    ///   - publicKey: Hex encoded verify key to look up.
    ///   - network: Target Concordium network (mainnet or testnet).
    /// - Returns: Array of `KeyAccount` models returned by the wallet proxy.
    static func fetchKeyAccounts(publicKey: String, network: Network) async throws -> [KeyAccount] {
        guard let url = url(for: publicKey, network: network) else {
            throw ConcordiumIDAppSDK.SDKError.invalidString
        }

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw ConcordiumIDAppSDK.SDKError.networkFailure(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConcordiumIDAppSDK.SDKError.networkFailure("Invalid server response")
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            if let apiError = try? decoder.decode(WalletProxyErrorResponse.self, from: data) {
                throw ConcordiumIDAppSDK.SDKError.networkFailure(apiError.errorMessage)
            } else {
                throw ConcordiumIDAppSDK.SDKError.networkFailure("Unexpected error. Status: \(httpResponse.statusCode)")
            }
        }

        do {
            return try decoder.decode([KeyAccount].self, from: data)
        } catch {
            throw ConcordiumIDAppSDK.SDKError.serializationFailure(error.localizedDescription)
        }
    }

    private static func url(for publicKey: String, network: Network) -> URL? {
        let networkSegment: String
        switch network {
        case .mainnet:
            networkSegment = "mainnet"
        case .testnet:
            networkSegment = "testnet"
        @unknown default:
            networkSegment = "mainnet"
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "wallet-proxy.\(networkSegment).concordium.com"
        components.path = "/v0/keyAccounts/\(publicKey)"
        return components.url
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

/// Represents a single key account record returned by the wallet proxy.
public struct KeyAccount: Decodable {
    public let address: String
    public let credentialIndex: Int
    public let isSimpleAccount: Bool
    public let keyIndex: Int
    public let publicKey: KeyAccountPublicKey
}

/// Nested public key payload inside each key account entry.
public struct KeyAccountPublicKey: Decodable {
    public let schemeId: String
    public let verifyKey: String
}

/// Represents an error response returned by the Concordium Wallet Proxy API.
///
/// The Wallet Proxy may return a structured JSON error when an invalid request
/// is made — for example, if the supplied public key format is incorrect.
/// This model captures that payload so it can be decoded and surfaced
/// as a meaningful error to the calling application.
///
/// Example response:
/// ```json
/// {
///   "error": 1,
///   "errorMessage": "Parsing input failed: Invalid verify key: invalid bytestring size"
/// }
/// ```
struct WalletProxyErrorResponse: Decodable {

    /// A numeric error code provided by the wallet proxy.
    /// This value may be useful for distinguishing different failure types programmatically.
    let error: Int

    /// Human-readable error message describing the failure cause.
    /// Suitable for logging or displaying (with optional UX formatting).
    let errorMessage: String
}
