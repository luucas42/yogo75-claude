import CoreGraphics
import Foundation
import ImageIO

/// PNG/GIF/JPEG → 6×6 animation, as a starting point for the editor (spec §8).
public enum ImageImporter {
    public enum ImportError: Error, Equatable {
        case unreadable
        case noFrames
    }

    /// Draw at 48×48 with high-quality interpolation, then box-average 8×8 blocks: a true area filter at 6×6.
    static let workSide = 48

    public static func importAnimation(from url: URL, name: String) throws -> PixelAnimation {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw ImportError.unreadable }
        let count = CGImageSourceGetCount(src)
        guard count > 0 else { throw ImportError.noFrames }
        let starts = sampleStarts(count: count, limit: PixelAnimation.maxFrames)
        var frames: [AnimationFrame] = []
        for (k, start) in starts.enumerated() {
            guard let image = CGImageSourceCreateImageAtIndex(src, start, nil) else { continue }
            let end = k + 1 < starts.count ? starts[k + 1] : count
            let ms = count == 1 ? 1000 : (start..<end).reduce(0) { $0 + delayMs(src, $1) }
            frames.append(AnimationFrame(durationMs: PixelAnimation.clampDuration(ms), frame: downscale(image)))
        }
        guard !frames.isEmpty else { throw ImportError.noFrames }
        return PixelAnimation(id: "user." + UUID().uuidString.lowercased(), name: name, loop: true, frames: frames)
    }

    /// Evenly spaced source frames; each sampled frame lasts until the next sampled one starts.
    static func sampleStarts(count: Int, limit: Int) -> [Int] {
        count <= limit ? Array(0..<count) : (0..<limit).map { $0 * count / limit }
    }

    static func delayMs(_ src: CGImageSource, _ index: Int) -> Int {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 100 }
        let s = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return Int(((s > 0 ? s : 0.1) * 1000).rounded())
    }

    /// Centre-crop to a square, then downscale to 6×6. Premultiplied alpha makes transparent areas "off".
    public static func downscale(_ image: CGImage) -> Frame {
        let side = min(image.width, image.height)
        let crop = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        let square = image.cropping(to: crop) ?? image
        let n = workSide
        let block = workSide / Frame.width
        var buf = [UInt8](repeating: 0, count: n * n * 4)
        buf.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .high
            ctx.draw(square, in: CGRect(x: 0, y: 0, width: n, height: n))
        }
        // Bitmap memory row 0 is the top row of the drawn image.
        var pixels: [RGB] = []
        for by in 0..<Frame.height {
            for bx in 0..<Frame.width {
                var r = 0, g = 0, b = 0
                for y in (by * block)..<((by + 1) * block) {
                    for x in (bx * block)..<((bx + 1) * block) {
                        let i = (y * n + x) * 4
                        r += Int(buf[i]); g += Int(buf[i + 1]); b += Int(buf[i + 2])
                    }
                }
                let area = block * block
                pixels.append(RGB(UInt8(r / area), UInt8(g / area), UInt8(b / area)))
            }
        }
        return Frame(pixels: pixels)
    }
}
