import Foundation
import CryptoKit
import ConcordiumWalletCrypto

public protocol CredentialSigner {
    func signCredentialTransaction(serialized: SerializedCredentialDeploymentDetails, signingKey: String) async throws -> SignedCredentialDeploymentTransaction
}

public protocol TransactionSubmitter {
    func submitCCDTransaction(credentialDeploymentTransaction: Any, signature: String, network: Network) async throws -> String
}

public struct SignedCredentialDeploymentTransaction {
    public let credentialDeploymentTransaction: Any
    public let signature: String
}

public final class ConcordiumIDAppSDK {
    public static let chainId: [Network: String] = [
        .mainnet: formatChainId(mainnet.genesisHash),
        .testnet: formatChainId(testnet.genesisHash)
    ]

    public init() {}

    public static func generateAccountWithSeedPhrase(
        seed: String,
        network: Network,
        accountIndex: Int = 0
    ) throws -> CCDAccountKeyPair {
        // Placeholder validation for mnemonic; implement BIP39 as needed
        guard seed.split(separator: " ").count >= 12 else {
            throw NSError(domain: "ConcordiumIDAppSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid seed phrase"])
        }
        // Since ConcordiumHdWallet is not available here, we stub a deterministic derivation
        let combined = "\(seed)|\("network.rawValue")|\(accountIndex)"
        let publicKey = SHA256.hex(of: combined + "-pub")
        let signingKey = SHA256.hex(of: combined + "-sign")
        return CCDAccountKeyPair(publicKey: publicKey, signingKey: signingKey)
    }

    public static func getCreateAccountCreationRequest(
        publicKey: String,
        reason: String = "The account wallet is requesting and Identity to create an account"
    ) -> CreateAccountCreationRequestMessage {
        return CreateAccountCreationRequestMessage(publicKey: publicKey, reason: reason)
    }

    private static func deserializeCredentialDeploymentTransaction(
        serializedCredentialDeploymentTransaction: SerializedCredentialDeploymentDetails
    ) -> Any {
        // Replace with actual deserialization into a platform type as needed.
        return [
            "unsignedCdi": serializedCredentialDeploymentTransaction.unsignedCdiStr,
            "expiry": serializedCredentialDeploymentTransaction.expiry,
            "randomness": serializedCredentialDeploymentTransaction.randomness
        ]
    }

    public static func signCredentialTransaction(
        serializedCredentialDeploymentTransaction: SerializedCredentialDeploymentDetails,
        signingKey: String
    ) async throws -> SignedCredentialDeploymentTransaction {
        let tx = deserializeCredentialDeploymentTransaction(serializedCredentialDeploymentTransaction: serializedCredentialDeploymentTransaction)
        // Stub signature via SHA256; replace with Concordium SDK signing when available on iOS.
        let payload = "\(serializedCredentialDeploymentTransaction.unsignedCdiStr)|\(serializedCredentialDeploymentTransaction.expiry)|\(serializedCredentialDeploymentTransaction.randomness)"
        let signature = SHA256.hex(of: payload + signingKey)
        return SignedCredentialDeploymentTransaction(credentialDeploymentTransaction: tx, signature: signature)
    }

    public static func submitCCDTransaction(
        credentialDeploymentTransaction: Any,
        signature: String,
        network: Network
    ) async throws -> String {
        // Serialize payload similarly to TS behavior; in real implementation this will call ConcordiumGRPC client.
        let networkConfig = getNetworkConfiguration(network)
        // Simulate submission and return a fake tx hash derived from payload + grpc endpoint
        let payloadString = String(describing: credentialDeploymentTransaction)
        let txHash = SHA256.hex(of: payloadString + signature + networkConfig.grpcUrl)
        return txHash
    }

    public static func getRecoverAccountRecoveryRequest(
        publicKey: String,
        description: String = "Account Wallet is requesting the account address to recover"
    ) -> RecoverAccountRequestMessage {
        return RecoverAccountRequestMessage(publicKey: publicKey, description: description)
    }
}

enum SHA256 {
    static func hex(of string: String) -> String {
        let data = Data(string.utf8)
        #if canImport(CryptoKit)
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback simple hash placeholder (non-cryptographic). Replace with CryptoKit in real builds.
        var hash = 5381
        for byte in data { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return String(format: "%08x", hash)
        #endif
    }
}
