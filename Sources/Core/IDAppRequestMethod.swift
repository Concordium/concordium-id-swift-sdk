import Foundation

public enum IDAppRequestMethod: String, Codable {
    case requestAccountsV1 = "create_account"
    case requestVerifiablePresentationV1 = "request_verifiable_presentation_v1"
}
