import Foundation

/// Spec §11: five rejected replies in a row pause live mode for 30 s.
public struct RejectionGuard {
    public static let limit = 5
    public static let pause: TimeInterval = 30

    private var streak = 0
    public private(set) var pausedUntil: Date?

    public init() {}

    public mutating func record(reply: [UInt8], at now: Date) {
        guard Packet.isRejection(reply) else {
            streak = 0
            return
        }
        streak += 1
        if streak >= Self.limit {
            pausedUntil = now + Self.pause
            streak = 0
        }
    }

    public func isPaused(at now: Date) -> Bool { pausedUntil.map { now < $0 } ?? false }
}
