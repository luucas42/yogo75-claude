import Foundation

/// One LED colour. Encodes to JSON as a 6-digit lowercase hex string ("e2794f").
public struct RGB: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let off = RGB(0, 0, 0)

    public init?(hex: String) {
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit), let v = UInt32(hex, radix: 16) else { return nil }
        self.init(UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF))
    }

    public var hex: String { String(format: "%02x%02x%02x", r, g, b) }

    /// RGB565 in little-endian byte order, as the 0x3C live-frame command expects.
    public var rgb565LE: [UInt8] {
        let v = UInt16(r >> 3) << 11 | UInt16(g >> 2) << 5 | UInt16(b >> 3)
        return [UInt8(v & 0xFF), UInt8(v >> 8)]
    }
}

extension RGB: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let v = RGB(hex: s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "expected 6 hex digits, got \(s)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(hex)
    }
}
