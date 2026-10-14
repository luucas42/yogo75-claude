import IOKit.hid
import YogoCore

/// Matches only the YOGO 75 PRO config interface (spec §3). The 0xFF00 firmware interface and the
/// keyboard interface never match, so they are never opened.
final class HIDMonitor {
    var onMatch: ((IOHIDDevice) -> Void)?
    var onRemove: ((IOHIDDevice) -> Void)?
    var onReport: (([UInt8]) -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    func start() {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x373B, kIOHIDProductIDKey: 0x119B,
            kIOHIDPrimaryUsagePageKey: 0xFF60, kIOHIDPrimaryUsageKey: 0x61,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            Unmanaged<HIDMonitor>.fromOpaque(ctx).takeUnretainedValue().onMatch?(device)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            guard let ctx else { return }
            Unmanaged<HIDMonitor>.fromOpaque(ctx).takeUnretainedValue().onRemove?(device)
        }, ctx)
        IOHIDManagerRegisterInputReportCallback(manager, { ctx, _, _, _, _, report, length in
            guard let ctx else { return }
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            Unmanaged<HIDMonitor>.fromOpaque(ctx).takeUnretainedValue().onReport?(bytes)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        // Same sequence as the 2026-10-14 spike: opening the manager opens only the matched vendor interface.
        let r = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if r != kIOReturnSuccess { Log.shared.warn("IOHIDManagerOpen: 0x\(String(UInt32(bitPattern: r), radix: 16))") }
    }
}
