import Foundation
import ConcordiumWalletCrypto

// MARK: - Proofs Decoding

/// Decodable conformance for `Proofs`.
///
/// This initializer decodes a `Proofs` instance from a keyed container where
/// all cryptographic fields are provided as hex-encoded strings.
///
/// Expected JSON keys and formats:
/// - `challenge`: Hex string representing the challenge bytes.
/// - `commitments`: Hex string with the combined commitments bytes.
/// - `credCounterLessThanMaxAccounts`: Hex string for the credential counter proof.
/// - `proofIdCredPub`: Object whose values are hex strings; each value is decoded to bytes.
/// - `proofIpSig`: Hex string representing the inner-product signature proof bytes.
/// - `proofRegId`: Hex string representing the registration identifier proof bytes.
/// - `sig` (mapped to `signature`): Hex string for the overall signature bytes.
///
/// - Parameter decoder: The decoder supplying the keyed container.
/// - Throws: An error if a required key is missing, has an unexpected type, or if any
///           hex string fails to decode into raw bytes.

extension Proofs: Decodable {
    enum CodingKeys: String, CodingKey {
        case challenge
        case commitments
        case credCounterLessThanMaxAccounts
        case proofIdCredPub
        case proofIpSig
        case proofRegId
        case signature = "sig"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let challengeHex = try container.decode(String.self, forKey: .challenge)
        let challenge = try bytesFromHexString(challengeHex)

        let commitmentsHex = try container.decode(String.self, forKey: .commitments)
        let commitments = try bytesFromHexString(commitmentsHex)

        let credCounterHex = try container.decode(String.self, forKey: .credCounterLessThanMaxAccounts)
        let credCounterLessThanMaxAccounts = try bytesFromHexString(credCounterHex)

        let proofIdCredPubHex = try container.decode([String: String].self, forKey: .proofIdCredPub)
        var proofIdCredPub: [String: Bytes] = [:]
        proofIdCredPub.reserveCapacity(proofIdCredPubHex.count)
        for (k, v) in proofIdCredPubHex { proofIdCredPub[k] = try bytesFromHexString(v) }

        let proofIpSigHex = try container.decode(String.self, forKey: .proofIpSig)
        let proofIpSig = try bytesFromHexString(proofIpSigHex)

        let proofRegIdHex = try container.decode(String.self, forKey: .proofRegId)
        let proofRegId = try bytesFromHexString(proofRegIdHex)

        let signatureHex = try container.decode(String.self, forKey: .signature)
        let signature = try bytesFromHexString(signatureHex)

        self.init(
            challenge: challenge,
            commitments: commitments,
            credCounterLessThanMaxAccounts: credCounterLessThanMaxAccounts,
            proofIdCredPub: proofIdCredPub,
            proofIpSig: proofIpSig,
            proofRegId: proofRegId,
            signature: signature
        )
    }
}


