import Foundation
import Concordium

public struct CCDAccountKeyPair: Codable, Equatable {
    public let publicKey: String
    public let signingKey: String
}

public struct SerializedCredentialDeploymentDetails: Codable, Equatable {
    public init(expiry: Int, unsignedCdiStr: String, randomness: String) {
        self.expiry = expiry
        self.unsignedCdiStr = unsignedCdiStr
        self.randomness = randomness
    }
    public let expiry: Int
    public let unsignedCdiStr: String
    public let randomness: String // Placeholder; aligns to CommitmentsRandomness JSON
}

public struct CreateAccountResponseMsgType: Codable, Equatable {
    public let serializedCredentialDeploymentTransaction: SerializedCredentialDeploymentDetails
    public let accountAddress: String
}

public struct RecoverAccountMsgType: Codable, Equatable {
    public let accountAddress: String
}

public struct RecoverAccountResponse: Codable, Equatable {
    public let status: Status
    public let message: RecoverAccountMessageOrError

    public enum RecoverAccountMessageOrError: Codable, Equatable {
        case success(RecoverAccountMsgType)
        case error(IDAppError)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(RecoverAccountMsgType.self) {
                self = .success(value)
            } else {
                self = .error(try container.decode(IDAppError.self))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .success(let msg):
                try container.encode(msg)
            case .error(let err):
                try container.encode(err)
            }
        }
    }
}

public struct CreateAccountCreationResponse: Codable, Equatable {
    public let status: Status
    public let message: CreateAccountMessageOrError

    public enum CreateAccountMessageOrError: Codable, Equatable {
        case success(CreateAccountResponseMsgType)
        case error(IDAppError)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(CreateAccountResponseMsgType.self) {
                self = .success(value)
            } else {
                self = .error(try container.decode(IDAppError.self))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .success(let msg):
                try container.encode(msg)
            case .error(let err):
                try container.encode(err)
            }
        }
    }
}

public struct CreateAccountCreationRequestMessage: Codable, Equatable {
    public let publicKey: String
    public let reason: String
}

public struct RecoverAccountRequestMessage: Codable, Equatable {
    public let publicKey: String
    public let description: String
}

public struct IDAppError: Codable, Equatable {
    public let code: IDAppErrorCode
    public let details: String?
}

// Real Concordium SDK types
public struct CredentialDeploymentTransaction: Codable, Equatable {
    public let unsignedCdi: Data
    public let expiry: TransactionTime
    public let randomness: Data
    public let credential: CredentialDeploymentDetails
}

public struct SignedCredentialDeploymentTransaction: Codable, Equatable {
    public let credentialDeploymentTransaction: CredentialDeploymentTransaction
    public let signature: String
    
    public func serialize() throws -> Data {
        // Serialize the transaction for submission
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}


