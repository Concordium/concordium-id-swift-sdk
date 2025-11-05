import Foundation
import ConcordiumWalletCrypto

/// Adds JSON decoding support and convenience helpers to `AccountCredential`.
extension AccountCredential: @retroactive Decodable {
    enum CodingKeys: String, CodingKey {
        case arData
        case credId
        case credentialPublicKeys
        case ipIdentity
        case policy
        case proofs
        case revocationThreshold
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // arData comes as a JSON object with numeric-string keys (e.g. "1", "2").
        // Convert dictionary keys from String to UInt32 explicitly.
        let arDataStringKeyed = try container.decode([String: ChainArData].self, forKey: .arData)
        var arData: [UInt32: ChainArData] = [:]
        arData.reserveCapacity(arDataStringKeyed.count)
        for (key, value) in arDataStringKeyed {
            guard let u = UInt32(key) else {
                throw DecodingError.dataCorruptedError(forKey: .arData, in: container, debugDescription: "arData key \(key) is not a valid UInt32")
            }
            arData[u] = value
        }
        // credId provided as hex string
        let credIdHex = try container.decode(String.self, forKey: .credId)
        let credId = try bytesFromHexString(credIdHex)
        let credentialPublicKeys = try container.decode(CredentialPublicKeys.self, forKey: .credentialPublicKeys)
        let ipIdentity = try container.decode(UInt32.self, forKey: .ipIdentity)
        let policy = try container.decode(Policy.self, forKey: .policy)
        let proofs = try container.decode(Proofs.self, forKey: .proofs)
        let revocationThreshold = try container.decode(UInt8.self, forKey: .revocationThreshold)

        self.init(
            arData: arData,
            credId: credId,
            credentialPublicKeys: credentialPublicKeys,
            ipIdentity: ipIdentity,
            policy: policy,
            proofs: proofs,
            revocationThreshold: revocationThreshold
        )
    }
}

public extension AccountCredential {
    /// Decodes an `AccountCredential` instance from raw JSON data.
    /// - Parameters:
    ///   - data: JSON-encoded data.
    ///   - configure: Optional closure to customize the `JSONDecoder`.
    /// - Returns: Decoded `AccountCredential`.
    static func fromJSON(_ data: Data, configure: ((JSONDecoder) -> Void)? = nil) throws -> AccountCredential {
        let decoder = JSONDecoder()
        configure?(decoder)
        return try decoder.decode(AccountCredential.self, from: data)
    }

    /// Decodes an `AccountCredential` instance from a JSON string.
    /// - Parameters:
    ///   - json: UTF-8 JSON string.
    ///   - configure: Optional closure to customize the `JSONDecoder`.
    /// - Returns: Decoded `AccountCredential`.
    static func fromJSON(_ json: String, configure: ((JSONDecoder) -> Void)? = nil) throws -> AccountCredential {
        guard let data = json.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Input string is not valid UTF-8"))
        }
        return try fromJSON(data, configure: configure)
    }
}


