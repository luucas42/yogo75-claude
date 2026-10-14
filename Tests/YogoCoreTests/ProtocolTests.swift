import XCTest
@testable import YogoCore

final class ProtocolTests: XCTestCase {
    func testOnlySafeCommandsExist() {
        XCTAssertEqual(Set(Command.allCases.map(\.rawValue)), [0x10, 0x11, 0x3C, 0x3D])
        XCTAssertNil(Command(rawValue: 0x3B), "flash write must be unrepresentable")
        XCTAssertNil(Command(rawValue: 0x31), "factory reset must be unrepresentable")
    }

    func testHeaderLayout() {
        let p = Packet.encode(.startSession, seq: 0x1234)
        XCTAssertEqual(p.count, 64)
        XCTAssertEqual(Array(p[0..<8]), [0xAA, 0x10, 0x00, 0x00, 0x00, 0x34, 0x12, 0x00])
        XCTAssertTrue(p[8...].allSatisfy { $0 == 0 })
    }

    func testRGB565() {
        XCTAssertEqual(RGB(255, 0, 0).rgb565LE, [0x00, 0xF8])
        XCTAssertEqual(RGB(0, 255, 0).rgb565LE, [0xE0, 0x07])
        XCTAssertEqual(RGB(0, 0, 255).rgb565LE, [0x1F, 0x00])
        XCTAssertEqual(RGB(255, 255, 255).rgb565LE, [0xFF, 0xFF])
    }

    func testHexRoundTrip() throws {
        XCTAssertEqual(RGB(hex: "e2794f"), RGB(0xE2, 0x79, 0x4F))
        XCTAssertEqual(RGB(0xE2, 0x79, 0x4F).hex, "e2794f")
        XCTAssertNil(RGB(hex: "+e2794"))
        XCTAssertNil(RGB(hex: "e2794"))
        XCTAssertNil(RGB(hex: "zz794f"))
        let data = try JSONEncoder().encode([RGB(1, 2, 3)])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["010203"]"#)
        XCTAssertEqual(try JSONDecoder().decode([RGB].self, from: data), [RGB(1, 2, 3)])
    }

    /// Golden bytes: exactly what the 2026-10-14 spike sent and the user saw as a full red screen.
    func testFullRedFrameMatchesSpike() {
        let r = Frame.filled(RGB(255, 0, 0)).liveReports()
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(Array(r[0][0..<8]), [0xAA, 0x3C, 0x00, 0x00, 0x38, 0x00, 0x00, 0x00])
        XCTAssertEqual(Array(r[0][8..<64]), Array(repeating: [0x00, 0xF8], count: 28).flatMap { $0 })
        XCTAssertEqual(Array(r[1][0..<8]), [0xAA, 0x3C, 0x38, 0x00, 0x10, 0x00, 0x00, 0x00])
        XCTAssertEqual(Array(r[1][8..<24]), Array(repeating: [0x00, 0xF8], count: 8).flatMap { $0 })
        XCTAssertTrue(r[1][24...].allSatisfy { $0 == 0 })
    }

    /// Corner pattern verified on hardware: TL red, TR green, BL blue, BR white.
    func testCornerPixelPlacement() {
        var f = Frame.blank
        f[0, 0] = RGB(255, 0, 0); f[5, 0] = RGB(0, 255, 0); f[0, 5] = RGB(0, 0, 255); f[5, 5] = RGB(255, 255, 255)
        XCTAssertEqual(f.pixels[0], RGB(255, 0, 0)); XCTAssertEqual(f.pixels[5], RGB(0, 255, 0))
        XCTAssertEqual(f.pixels[30], RGB(0, 0, 255)); XCTAssertEqual(f.pixels[35], RGB(255, 255, 255))
        let r = f.liveReports()
        XCTAssertEqual(Array(r[0][8..<10]), [0x00, 0xF8])   // pixel 0  -> bytes 0,1
        XCTAssertEqual(Array(r[0][18..<20]), [0xE0, 0x07])  // pixel 5  -> bytes 10,11
        XCTAssertEqual(Array(r[1][12..<14]), [0x1F, 0x00])  // pixel 30 -> bytes 60,61 -> 2nd report data 4,5
        XCTAssertEqual(Array(r[1][22..<24]), [0xFF, 0xFF])  // pixel 35 -> bytes 70,71 -> 2nd report data 14,15
    }

    func testRejectionDetection() {
        XCTAssertTrue(Packet.isRejection([0xAA, 0x10, 0xFF, 0, 0, 0, 0, 0]))
        XCTAssertFalse(Packet.isRejection([0xAA, 0x10, 0x00, 0, 0, 0x34, 0x12, 0x55]))
        XCTAssertFalse(Packet.isRejection([0xAA]))
    }
}
