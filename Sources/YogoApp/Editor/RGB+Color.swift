import AppKit
import SwiftUI
import YogoCore

extension RGB {
    /// Off pixels are drawn as a dim LED so the 6×6 grid stays visible.
    var color: Color {
        self == .off ? Color(white: 0.11) : Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        func byte(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
        self.init(byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
    }
}
