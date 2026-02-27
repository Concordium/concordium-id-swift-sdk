import Foundation

/// Supported WalletConnect request methods used by Concordium ID App popup flows.
public enum IDAppRequestMethod: String, Codable {
    case requestAccountsV1 = "request_accounts_v1"
    case requestVerifiablePresentationV1 = "request_verifiable_presentation_v1"
}
