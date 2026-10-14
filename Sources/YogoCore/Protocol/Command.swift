/// The only commands Yogo can ever send to the keyboard. Flash writes (0x3B), factory reset (0x31)
/// and firmware upgrade are deliberately unrepresentable (spec §3).
public enum Command: UInt8, CaseIterable, Sendable {
    case startSession = 0x10
    case endSession = 0x11
    case liveFrame = 0x3C
    case endLive = 0x3D
}
