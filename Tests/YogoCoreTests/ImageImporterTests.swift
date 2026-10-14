import CoreGraphics
import ImageIO
import XCTest
@testable import YogoCore

final class ImageImporterTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("yogo-img-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func image(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(ctx)
        return ctx.makeImage()!
    }

    private func solid(_ w: Int, _ h: Int, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGImage {
        image(w, h) {
            $0.setFillColor(red: r, green: g, blue: b, alpha: 1)
            $0.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    private func write(_ images: [CGImage], delay: Double?, type: String, name: String) -> URL {
        let url = dir.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, images.count, nil)!
        for img in images {
            var props: [CFString: Any] = [:]
            if let delay { props[kCGImagePropertyGIFDictionary] = [kCGImagePropertyGIFDelayTime: delay] }
            CGImageDestinationAddImage(dest, img, props as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    func testTopLeftQuadrantLandsInTopLeftPixels() throws {
        let img = image(60, 60) { ctx in
            ctx.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
            ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 30, width: 30, height: 30))   // CG origin is bottom-left → this is the TOP-left
        }
        let a = try ImageImporter.importAnimation(from: write([img], delay: nil, type: "public.png", name: "q.png"), name: "q")
        let f = a.frames[0].frame
        XCTAssertGreaterThan(f[0, 0].r, 200); XCTAssertLessThan(f[0, 0].b, 50)
        XCTAssertGreaterThan(f[5, 0].b, 200); XCTAssertLessThan(f[5, 0].r, 50)
        XCTAssertGreaterThan(f[0, 5].b, 200)
        XCTAssertGreaterThan(f[5, 5].b, 200)
        XCTAssertEqual(a.frames.count, 1)
        XCTAssertEqual(a.frames[0].durationMs, 1000)
        XCTAssertTrue(a.id.hasPrefix("user."))
        XCTAssertTrue(a.loop)
        XCTAssertNoThrow(try a.validate())
    }

    func testNonSquareImageIsCenterCropped() throws {
        let img = image(120, 60) { ctx in   // green | red (60 px centre) | green
            ctx.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
            ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            ctx.fill(CGRect(x: 30, y: 0, width: 60, height: 60))
        }
        let f = try ImageImporter.importAnimation(from: write([img], delay: nil, type: "public.png", name: "w.png"), name: "w").frames[0].frame
        XCTAssertTrue(f.pixels.allSatisfy { $0.r > 200 && $0.g < 60 })
    }

    func testTransparentPixelsBecomeOff() throws {
        let img = image(12, 12) { _ in }
        let f = try ImageImporter.importAnimation(from: write([img], delay: nil, type: "public.png", name: "t.png"), name: "t").frames[0].frame
        XCTAssertEqual(f, .blank)
    }

    func testGIFKeepsFramesAndDelays() throws {
        let frames = [solid(12, 12, 1, 0, 0), solid(12, 12, 0, 1, 0), solid(12, 12, 0, 0, 1)]
        let a = try ImageImporter.importAnimation(from: write(frames, delay: 0.2, type: "com.compuserve.gif", name: "a.gif"), name: "a")
        XCTAssertEqual(a.frames.count, 3)
        XCTAssertEqual(a.frames.map(\.durationMs), [200, 200, 200])
        XCTAssertGreaterThan(a.frames[1].frame[2, 2].g, 200)
    }

    func testLongGIFIsSampledTo20FramesKeepingTotalTime() throws {
        let frames = (0..<30).map { i in solid(12, 12, CGFloat(i) / 29, 0, 0) }
        let a = try ImageImporter.importAnimation(from: write(frames, delay: 0.05, type: "com.compuserve.gif", name: "l.gif"), name: "l")
        XCTAssertEqual(a.frames.count, PixelAnimation.maxFrames)
        XCTAssertEqual(a.frames.reduce(0) { $0 + $1.durationMs }, 1500)
        XCTAssertNoThrow(try a.validate())
    }

    func testSampleStarts() {
        XCTAssertEqual(ImageImporter.sampleStarts(count: 3, limit: 20), [0, 1, 2])
        XCTAssertEqual(ImageImporter.sampleStarts(count: 40, limit: 20), Array(stride(from: 0, to: 40, by: 2)))
    }

    func testUnreadableFileThrows() {
        let url = dir.appendingPathComponent("x.png")
        FileManager.default.createFile(atPath: url.path, contents: Data("not an image".utf8))
        XCTAssertThrowsError(try ImageImporter.importAnimation(from: url, name: "x"))
    }
}
