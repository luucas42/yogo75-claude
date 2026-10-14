/// 64-byte output report: AA <cmd> <offset lo> <offset hi> <len> <seq lo> <seq hi> 00, payload from byte 8.
public enum Packet {
    public static let size = 64
    public static let headerSize = 8
    public static let maxPayload = size - headerSize

    public static func encode(_ cmd: Command, offset: UInt16 = 0, data: [UInt8] = [], seq: UInt16 = 0) -> [UInt8] {
        precondition(data.count <= maxPayload, "payload larger than \(maxPayload) bytes")
        var p = [UInt8](repeating: 0, count: size)
        p[0] = 0xAA
        p[1] = cmd.rawValue
        p[2] = UInt8(offset & 0xFF)
        p[3] = UInt8(offset >> 8)
        p[4] = UInt8(data.count)
        p[5] = UInt8(seq & 0xFF)
        p[6] = UInt8(seq >> 8)
        p.replaceSubrange(headerSize..<(headerSize + data.count), with: data)
        return p
    }

    /// A reply whose byte 2 is 0xFF means the firmware rejected the command.
    public static func isRejection(_ reply: [UInt8]) -> Bool {
        reply.count >= headerSize && reply[0] == 0xAA && reply[2] == 0xFF
    }
}
