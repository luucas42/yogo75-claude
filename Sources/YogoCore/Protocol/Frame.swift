/// One 6×6 screen image, row-major from the top-left (0 = top-left, 5 = top-right, 30 = bottom-left).
public struct Frame: Hashable, Sendable {
    public static let width = 6
    public static let height = 6
    public static let pixelCount = width * height

    public private(set) var pixels: [RGB]

    public init(pixels: [RGB]) {
        precondition(pixels.count == Frame.pixelCount, "a frame has exactly 36 pixels")
        self.pixels = pixels
    }

    public static let blank = Frame(pixels: Array(repeating: .off, count: pixelCount))

    public static func filled(_ c: RGB) -> Frame { Frame(pixels: Array(repeating: c, count: pixelCount)) }

    public subscript(x: Int, y: Int) -> RGB {
        get { pixels[y * Frame.width + x] }
        set { pixels[y * Frame.width + x] = newValue }
    }

    /// The two 0x3C reports for this frame: RGB565 bytes 0..<56 at offset 0, 56..<72 at offset 56.
    public func liveReports() -> [[UInt8]] {
        let bytes = pixels.flatMap(\.rgb565LE)
        return [
            Packet.encode(.liveFrame, offset: 0, data: Array(bytes[0..<56])),
            Packet.encode(.liveFrame, offset: 56, data: Array(bytes[56..<72])),
        ]
    }
}
