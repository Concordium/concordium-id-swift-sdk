import Foundation

public enum Network: String {
    case mainet
    case testnet
}

public func getNetworkConfiguration(_ net: Network) -> NetworkConfiguration {
    switch net {
    case .mainet:
        return mainnet
    case .testnet:
        return testnet
    }
}

// References: https://namespaces.chainagnostic.org/ccd/caip2
public func formatChainId(_ genesisHash: String) -> String {
    let prefix = String(genesisHash.prefix(32))
    return "ccd:\(prefix)"
}


