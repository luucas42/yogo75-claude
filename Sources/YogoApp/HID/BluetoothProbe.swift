import Foundation
import IOKit
import IOKit.hid

enum BluetoothProbe {
    /// Bluetooth identity from Owlbay (spec §14, unverified). Registry lookup only: the device is never
    /// opened, so this cannot trigger an Input Monitoring prompt.
    static func isPresent() -> Bool {
        let matching = IOServiceMatching("IOHIDDevice") as NSMutableDictionary
        matching[kIOPropertyMatchKey] = [kIOHIDVendorIDKey: 0x36B0, kIOHIDProductIDKey: 0x3004]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching as CFDictionary, &iterator) == KERN_SUCCESS else {
            return false
        }
        defer { IOObjectRelease(iterator) }
        var found = false
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            found = true
            IOObjectRelease(service)
        }
        return found
    }
}
