import Foundation
import ConcordiumWalletCrypto

enum HexDecodingError: Error {
    case invalidLength
    case invalidCharacter
}

@inline(__always)
func bytesFromHexString(_ hexString: String) throws -> Bytes {
    let string = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
    let length = string.count
    guard length % 2 == 0 else { throw HexDecodingError.invalidLength }

    var bytes = Bytes()
    bytes.reserveCapacity(length / 2)

    var index = string.startIndex
    while index < string.endIndex {
        let nextIndex = string.index(index, offsetBy: 2)
        let byteString = string[index..<nextIndex]
        guard let byte = UInt8(byteString, radix: 16) else { throw HexDecodingError.invalidCharacter }
        bytes.append(byte)
        index = nextIndex
    }
    return bytes
}



