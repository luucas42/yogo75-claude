import Foundation

public protocol ScreenDevice: AnyObject {
    var isOpen: Bool { get }
    /// Sends one 64-byte output report. Throws on I/O failure.
    func send(_ report: [UInt8]) throws
}

/// Streams frames to the keyboard (spec §4). Call `tick` at 20 Hz from a single queue.
public final class ScreenDriver {
    public static let sessionRefresh: TimeInterval = 2

    public private(set) var isLive = false
    public private(set) var consecutiveErrors = 0
    private var device: ScreenDevice?
    private var lastSessionAt: Date?
    private var seq: UInt16 = 0

    public init() {}

    /// A newly attached (or re-opened) device always starts without a session.
    public func attach(_ device: ScreenDevice?) {
        self.device = device
        isLive = false
        lastSessionAt = nil
        consecutiveErrors = 0
    }

    /// `frame == nil` gives the screen back to the keyboard (0x3D + 0x11, exactly once).
    public func tick(frame: Frame?, at now: Date) {
        guard let device, device.isOpen else { return }
        do {
            if let frame {
                if lastSessionAt.map({ now.timeIntervalSince($0) >= Self.sessionRefresh }) ?? true {
                    seq &+= 1
                    try device.send(Packet.encode(.startSession, seq: seq))
                    lastSessionAt = now
                }
                for report in frame.liveReports() { try device.send(report) }
                isLive = true
            } else if isLive {
                // Flip state first: if the device is gone, the firmware reverts on its own in 0.5 s.
                isLive = false
                lastSessionAt = nil
                try device.send(Packet.encode(.endLive))
                try device.send(Packet.encode(.endSession))
            }
            consecutiveErrors = 0
        } catch {
            consecutiveErrors += 1
        }
    }

    /// Clean shutdown before quit or sleep.
    public func release() { tick(frame: nil, at: Date()) }
}
