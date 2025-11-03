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

    // MARK: - Initialization

    private init() {}

    // MARK: - Public APIs

    /// Creates and submits a credential deployment transaction.
    ///
    /// - Parameters:
    ///   - seedPhrase: BIP39 mnemonic phrase used to derive the wallet seed.
    ///   - transactionInput: JSON string containing fields `unsignedCdiStr` (stringified JSON) and `expiry` (Int64 Unix seconds).
    ///   - identityProviderID: Not used directly here, kept for potential future routing/validation.
    /// - Throws: SDKError when initialization, parsing, network, or serialization fails.
    public static func signAndSubmit(
        accountIndex: CredentialCounter,
        seedPhrase: String,
        transactionInput: SerializedCredentialDeploymentTransaction,
        network: Network
    ) async throws {

        log("Starting credential deployment process...")

        // Parse transaction input JSON
        let unsignedCdi = try AccountCredential.fromJSON(transactionInput.unsignedCdi)
        log("Parsed transaction data: expiry=\(transactionInput.expiry)")

        // Create WalletSeed from mnemonic
        let seedHex = try Mnemonic.deterministicSeedString(from: seedPhrase)
        let seed = try WalletSeed(seedHex: seedHex, network: network)

        // Fetch cryptographic parameters, sign and submit using a GRPC client
        try await withGRPCClient { client in
            // Fetch cryptographic parameters from chain
            log("Fetching cryptographic parameters...")
            let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)

            // Derive account credentials and sign transaction
            log("Deriving account and signing transaction...")
            let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)

            let seedIndexes = AccountCredentialSeedIndexes(
                identity: IdentitySeedIndexes(providerID: 0, index: 0),
                counter: accountIndex
            )

            let account = try accountDerivation.deriveAccount(credentials: [seedIndexes])
            let signedTransaction = try account.keys.sign(deployment: unsignedCdi, expiry: transactionInput.expiry)

            // Serialize and submit transaction
            let serializedTransaction = try signedTransaction.serialize()
            log("Submitting credential deployment transaction...")

            let txResponse = try await client.send(deployment: serializedTransaction)
            let (blockHash, summary) = try await txResponse.waitUntilFinalized(timeoutSeconds: 10)

            log("Transaction finalized in block \(blockHash): \(summary)")
        }
    }
    // MARK: - GRPC Client Wrapper

    struct GRPCOptions: Encodable {
        var host: String = "grpc.testnet.concordium.com"
        var port: Int = 20000
        var insecure: Bool = false
    }

    static func withGRPCClient<T>(_ execute: (GRPCNodeClient) async throws -> T) async throws -> T {
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
        print("[ConcordiumSDK] \(message)")
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

        let privateKey = try seed.signingKey(accountCredentialIndexes: indexes).rawRepresentation.map { String(format: "%02x", $0) }.joined()

        let publicKey = try seed.signingKey(accountCredentialIndexes: indexes).publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()

        return CCDAccountKeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}

// MARK: - Model: CCDAccountKeyPair

public struct CCDAccountKeyPair {
    public let privateKey: String
    public let publicKey: String
}

// MARK: - Public model for serialized credential deployment transaction
public struct SerializedCredentialDeploymentTransaction: Codable {
    public let expiry: UInt64
    public let randomness: Randomness
    public let unsignedCdi: String

    public init(expiry: UInt64, randomness: Randomness, unsignedCdi: String) {
        self.expiry = expiry
        self.randomness = randomness
        self.unsignedCdi = unsignedCdi
    }

    public struct Randomness: Codable {
        public let attributesRand: AttributesRand
        public let credCounterRand: String
        public let idCredSecRand: String
        public let maxAccountsRand: String
        public let prfRand: String

        public init(
            attributesRand: AttributesRand,
            credCounterRand: String,
            idCredSecRand: String,
            maxAccountsRand: String,
            prfRand: String
        ) {
            self.attributesRand = attributesRand
            self.credCounterRand = credCounterRand
            self.idCredSecRand = idCredSecRand
            self.maxAccountsRand = maxAccountsRand
            self.prfRand = prfRand
        }
    }

    public struct AttributesRand: Codable {
        public let countryOfResidence: String
        public let dob: String
        public let firstName: String
        public let idDocExpiresAt: String
        public let idDocIssuedAt: String
        public let idDocIssuer: String
        public let idDocNo: String
        public let idDocType: String
        public let lastName: String
        public let nationalIdNo: String
        public let nationality: String
        public let sex: String
        public let taxIdNo: String

        public init(
            countryOfResidence: String,
            dob: String,
            firstName: String,
            idDocExpiresAt: String,
            idDocIssuedAt: String,
            idDocIssuer: String,
            idDocNo: String,
            idDocType: String,
            lastName: String,
            nationalIdNo: String,
            nationality: String,
            sex: String,
            taxIdNo: String
        ) {
            self.countryOfResidence = countryOfResidence
            self.dob = dob
            self.firstName = firstName
            self.idDocExpiresAt = idDocExpiresAt
            self.idDocIssuedAt = idDocIssuedAt
            self.idDocIssuer = idDocIssuer
            self.idDocNo = idDocNo
            self.idDocType = idDocType
            self.lastName = lastName
            self.nationalIdNo = nationalIdNo
            self.nationality = nationality
            self.sex = sex
            self.taxIdNo = taxIdNo
        }
    }
}

// MARK: - Public models for account requests

public struct CreateAccountCreationRequestMessage: Codable {
    public let publicKey: String
    public let reason: String

    public init(publicKey: String, reason: String) {
        self.publicKey = publicKey
        self.reason = reason
    }
}

public struct RecoverAccountRequestMessage: Codable {
    public let publicKey: String
    public let description: String

    public init(publicKey: String, description: String) {
        self.publicKey = publicKey
        self.description = description
    }
}
