//
//  ConcordiumIDAppSDK.swift
//  ConcordiumIDApp
//
//

import Foundation
import MnemonicSwift
import CryptoKit
import ConcordiumWalletCrypto
import Concordium
import GRPC

// MARK: - SDK Error Definitions

extension ConcordiumIDAppSDK {
    /// Errors that can be thrown by `ConcordiumIDAppSDK` public APIs.
    enum SDKError: LocalizedError {
        case notInitialized
        case invalidTransactionData
        case invalidString
        case networkFailure(String)
        case serializationFailure(String)

        var errorDescription: String? {
            switch self {
            case .notInitialized:
                return "Concordium ID SDK not initialized. Please call initialize() first."
            case .invalidTransactionData:
                return "Transaction data is invalid or improperly formatted."
            case .invalidString:
                return "Please Provide Non-Empty String."
            case .networkFailure(let reason):
                return "Network operation failed: \(reason)"
            case .serializationFailure(let details):
                return "Failed to serialize/deserialize data: \(details)"
            }
        }
    }
}

// MARK: - SDK Core

/// Core entry point for Concordium ID App SDK.
///
/// Provides utilities to sign and submit credential deployment transactions,
/// generate account key pairs, and build request payloads required by the
/// Concordium ecosystem.
public final class ConcordiumIDAppSDK {

    // MARK: - Initialization

    private init() {}

    // MARK: - Public APIs

    /// Creates, signs, and submits a credential deployment transaction to the Concordium blockchain.
    ///
    /// This method derives the account keys from a BIP39 seed phrase, signs the provided
    /// unsigned credential deployment information, serializes the transaction, and submits
    /// it to the specified network.
    ///
    /// - Parameters:
    ///   - accountIndex: The credential counter or index used to derive the account from the wallet seed.
    ///   - seedPhrase: The BIP39 mnemonic phrase used to derive the wallet’s deterministic seed.
    ///   - expiry: The transaction expiry timestamp, expressed in Unix seconds (`UInt64`).
    ///   - unsignedCdiStr: A JSON string representation of the unsigned credential deployment information.
    ///   - network: The target blockchain network (`.mainnet` or `.testnet`).
    ///
    /// - Returns: A hexadecimal string representing the hash of the successfully submitted transaction.
    ///
    /// - Throws: An `SDKError` if the input strings are invalid, decoding fails,
    ///   key derivation or signing fails, or the network submission is unsuccessful.
    public static func signAndSubmit(
        accountIndex: CredentialCounter,
        seedPhrase: String,
        expiry: UInt64,
        unsignedCdiStr: String,
        network: Network
    ) async throws -> String {

        guard !seedPhrase.isEmpty, !unsignedCdiStr.isEmpty  else { throw SDKError.invalidString }

        // Parse transaction input JSON
        let unsignedCdi = try AccountCredential.fromJSON(unsignedCdiStr)

        // Create WalletSeed from mnemonic
        let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
        let seed = try WalletSeed(seedHex: seedHex, network: network)

        setConfiguration(for: network)

        // Fetch cryptographic parameters from chain
        guard let configuration = Self.configuration else { throw SDKError.notInitialized }

        let cryptoParams = try await withGRPCClient(configuration: configuration) {
            try await $0.cryptographicParameters(block: .lastFinal)
        }

        // Derive account credentials and sign transaction
        let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)

        let seedIndexes = AccountCredentialSeedIndexes(
            identity: IdentitySeedIndexes(providerID: 0, index: 0),
            counter: accountIndex
        )

        let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])
        let signedTransaction = try account.keys.sign(deployment: unsignedCdi, expiry: expiry)

        // Serialize and submit transaction
        let serializedTransaction = try signedTransaction.serialize()
        guard let configuration = Self.configuration else { throw SDKError.notInitialized }

        let txHash = try await withGRPCClient(configuration: configuration) { client in
            let txResponse = try await client.send(deployment: serializedTransaction)
            return txResponse.hash
        }

        return txHash.value.map { String(format: "%02x", $0) }.joined()
    }

    private static func setConfiguration(for network: Network) {
        switch network {
        case .testnet:
            configuration = .testnet
        case .mainnet:
            configuration = .mainnet
        }
    }

    // MARK: - GRPC Client Wrapper

    /// Opens a GRPC connection, executes the provided async operation, and
    /// ensures the connection and event loop group are shut down correctly.
    ///
    /// - Parameters:
    ///   - configuration: The Concordium network configuration to connect to (e.g., `.mainnet` or `.testnet`).
    ///   - execute: Operation that receives a configured `GRPCNodeClient`.
    /// - Returns: Result of the provided operation.
    /// - Throws: `SDKError.networkFailure` if the operation or teardown fails.
    static func withGRPCClient<T>(
        configuration: ConcordiumConfiguration,
        _ execute: (GRPCNodeClient) async throws -> T
    ) async throws -> T {
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

        let connectionBuilder = configuration.useTLS
            ? ClientConnection.usingPlatformAppropriateTLS(for: group)
            : ClientConnection.insecure(group: group)

        let connection = connectionBuilder.connect(host: configuration.host, port: configuration.port)
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

}

// MARK: - Request Builders (Account Create/Recover)

extension ConcordiumIDAppSDK {
    /// Build a request message for creating an account.
    ///
    /// - Parameters:
    ///   - publicKey: Public key to use for the account.
    ///   - reason: Description of the use of this public key.
    /// - Returns: `CreateAccountCreationRequestMessage` containing the provided details.
    public static func getCreateAccountCreationRequest(
        publicKey: String,
        reason: String = "The account wallet is requesting and Identity to create an account"
    ) -> CreateAccountCreationRequestMessage {
        return CreateAccountCreationRequestMessage(publicKey: publicKey, reason: reason)
    }

    /// Build a request message for recovering an account.
    ///
    /// - Parameters:
    ///   - publicKey: Public key to use for the account.
    ///   - description: Description of the use of this public key.
    /// - Returns: `RecoverAccountRequestMessage` containing the provided details.
    public static func getRecoverAccountRecoveryRequest(
        publicKey: String,
        description: String = "Account Wallet is requesting the account address to recover"
    ) -> RecoverAccountRequestMessage {
        return RecoverAccountRequestMessage(publicKey: publicKey, description: description)
    }
}

// MARK: - Account Key Generation Utility

extension ConcordiumIDAppSDK {
    /// Generates a Concordium account key pair deterministically from a mnemonic and index.
    ///
    /// - Parameters:
    ///   - seedPhrase: BIP39 mnemonic phrase used to derive the wallet seed.
    ///   - network: Target network for key derivation.
    ///   - accountIndex: The credential counter (account index) to derive keys for.
    /// - Returns: `CCDAccountKeyPair` containing hex-encoded private/public keys.
    public static func generateAccountWithSeedPhrase(
        from seedPhrase: String,
        network: Network,
        accountIndex: CredentialCounter
    ) async throws -> CCDAccountKeyPair {
        let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
        let seed = try WalletSeed(seedHex: seedHex, network: network)

        let indexes = AccountCredentialSeedIndexes(
            identity: IdentitySeedIndexes(providerID: 0, index: 0),
            counter: accountIndex
        )
    
        let keys = try seed.signingKey(accountCredentialIndexes: indexes)

        let privateKey = keys.rawRepresentation.map { String(format: "%02x", $0) }.joined()

        let publicKey = keys.publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()

        return CCDAccountKeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}

// MARK: - Model: CCDAccountKeyPair

/// Hex-encoded Concordium account key pair.
public struct CCDAccountKeyPair {
    public let privateKey: String
    public let publicKey: String
}

// MARK: - Public models for account requests

/// Request payload for creating an account via an Identity Provider.
public struct CreateAccountCreationRequestMessage: Codable {
    public let publicKey: String
    public let reason: String

    public init(publicKey: String, reason: String) {
        self.publicKey = publicKey
        self.reason = reason
    }
}

/// Request payload for recovering an account via an Identity Provider.
public struct RecoverAccountRequestMessage: Codable {
    public let publicKey: String
    public let description: String

    public init(publicKey: String, description: String) {
        self.publicKey = publicKey
        self.description = description
    }
}

extension ConcordiumIDAppSDK {
    private static var configuration: ConcordiumConfiguration?
}

// MARK: - Configuration

/// Represents the configuration details required to establish a gRPC connection
/// with the Concordium blockchain network.
///
/// Use this structure to specify the network host, port, and whether to connect
/// securely using TLS. Predefined configurations for **mainnet** and **testnet**
/// are available via `.mainnet` and `.testnet`.
public struct ConcordiumConfiguration {

    /// The gRPC host address of the Concordium node (e.g., `"grpc.mainnet.concordium.com"`).
    public let host: String

    /// The gRPC port number used for network communication (default: `20000`).
    public let port: Int

    /// A Boolean value that determines whether TLS should be used for the connection.
    ///
    /// Set this to `true` for secure connections or `false` for insecure (non-TLS)
    /// connections — typically used only for local development or testing.
    public let useTLS: Bool

    /// Predefined configuration for the **Concordium Mainnet**.
    ///
    /// Connects securely using TLS to the main production Concordium blockchain network.
    public static let mainnet = ConcordiumConfiguration(
        host: "grpc.mainnet.concordium.software",
        port: 20000,
        useTLS: true
    )

    /// Predefined configuration for the **Concordium Testnet**.
    ///
    /// Connects securely using TLS to the Concordium public test network for testing and development.
    public static let testnet = ConcordiumConfiguration(
        host: "grpc.testnet.concordium.com",
        port: 20000,
        useTLS: true
    )

    /// Creates a new configuration instance for a custom Concordium network setup.
    ///
    /// - Parameters:
    ///   - host: The gRPC host address of the target Concordium node.
    ///   - port: The gRPC port number for the connection.
    ///   - useTLS: Indicates whether to use TLS for secure communication (default: `true`).
    public init(host: String, port: Int, useTLS: Bool = true) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }
}
