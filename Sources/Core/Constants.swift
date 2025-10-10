import Foundation

public struct NetworkConfiguration: Equatable, Codable {
    public let grpcUrl: String
    public let grpcPort: Int
    public let genesisHash: String
    public let name: String
    public let explorerUrl: String
    public let ccdScanUrl: String
}

public enum Status: String, Codable {
    case success
    case error
}

public enum IDAppErrorCode: Int, Codable {
    case accountNotFound = 1
    case accountCreationFailed = 2
    case networkError = 3
    case invalidInput = 4
    case unauthorized = 5
    case timeout = 6
    case duplicateAccountCreationRequest = 7
    case requestRejected = 8
    case unknownError = 99
}

public struct IDAppHosts {
    public static let mobile = "concordiumidapp://"
}


public enum IDAppSdkWallectConnectMethods: String, Codable {
    case create_account
    case recover_account
}

public let GRPCTIMEOUT: TimeInterval = 15.0

public struct IDAPPHOSTS {
    public static let mobile = "concordiumidapp://"
}

public let CLOUDFLARE_CDN_FOR_QRCODE = "https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"

public let mainnet = NetworkConfiguration(
    grpcUrl: "https://grpc.mainnet.concordium.software",
    grpcPort: 20000,
    genesisHash: "9dd9ca4d19e9393877d2c44b70f89acbfc0883c2243e5eeaecc0d1cd0503f478",
    name: "Concordium Mainnet",
    explorerUrl: "https://wallet-proxy.mainnet.concordium.software",
    ccdScanUrl: "https://ccdscan.io/"
)

public let testnet = NetworkConfiguration(
    grpcUrl: "https://grpc.testnet.concordium.com",
    grpcPort: 20000,
    genesisHash: "4221332d34e1694168c2a0c0b3fd0f273809612cb13d000d5c2e00e85f50f796",
    name: "Concordium Testnet",
    explorerUrl: "https://wallet-proxy.testnet.concordium.com",
    ccdScanUrl: "https://testnet.ccdscan.io/"
)


