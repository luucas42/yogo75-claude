import IOKit.hid
import YogoCore

/// The opened 0xFF60/0x61 config interface (spec §3).
final class HIDScreenDevice: ScreenDevice {
    enum HIDError: Error {
        case closed
        case io(IOReturn)
    }

    let ref: IOHIDDevice
    private(set) var isOpen = false

    init(ref: IOHIDDevice) { self.ref = ref }

    func open() -> IOReturn {
        let r = IOHIDDeviceOpen(ref, IOOptionBits(kIOHIDOptionsTypeNone))
        isOpen = r == kIOReturnSuccess
        return r
    }

    func send(_ report: [UInt8]) throws {
        guard isOpen else { throw HIDError.closed }
        var r = IOHIDDeviceSetReport(ref, kIOHIDReportTypeOutput, 0, report, report.count)
        if r != kIOReturnSuccess {   // spec §4: retry once
            r = IOHIDDeviceSetReport(ref, kIOHIDReportTypeOutput, 0, report, report.count)
        }
        guard r == kIOReturnSuccess else { throw HIDError.io(r) }
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        IOHIDDeviceClose(ref, IOOptionBits(kIOHIDOptionsTypeNone))
    }
}
