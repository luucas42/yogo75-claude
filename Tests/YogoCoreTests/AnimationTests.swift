import XCTest
@testable import YogoCore

final class AnimationTests: XCTestCase {
    func testBuiltinsAreValidAndDistinct() {
        for a in BuiltinAnimations.all { XCTAssertNoThrow(try a.validate(), a.id) }
        XCTAssertEqual(Set(BuiltinAnimations.all.map(\.id)).count, 4)
        XCTAssertTrue(BuiltinAnimations.all.allSatisfy { $0.id.hasPrefix("builtin.") })
    }

    func testBuiltinTimingsMatchSpec() {
        XCTAssertEqual(BuiltinAnimations.tool.frames.map(\.durationMs), [260, 260])
        XCTAssertEqual(BuiltinAnimations.thinking.frames.map(\.durationMs), [160, 160, 160, 260, 160, 160, 160, 120])
        XCTAssertEqual(BuiltinAnimations.waiting.frames.map(\.durationMs), [140, 110, 140, 110, 700])
        XCTAssertEqual(BuiltinAnimations.done.frames.map(\.durationMs), [90, 90, 140, 700, 300])
        XCTAssertFalse(BuiltinAnimations.done.loop)
        XCTAssertTrue(BuiltinAnimations.thinking.loop && BuiltinAnimations.tool.loop && BuiltinAnimations.waiting.loop)
    }

    func testShapes() {
        let orange = RGB(hex: "e2794f")!
        let s = BuiltinAnimations.spark
        XCTAssertEqual((0..<6).map { s[$0, 0] == orange }, [true, false, true, true, false, true])  // "O.OO.O"
        XCTAssertTrue((0..<6).allSatisfy { s[$0, 2] == orange })                                   // "OOOOOO"
        XCTAssertEqual(BuiltinAnimations.ringG[0, 1], RGB(hex: "4fd27a")!)
        XCTAssertEqual(BuiltinAnimations.ringG[1, 1], .off)
        XCTAssertEqual(BuiltinAnimations.sparkW[0, 0], RGB(hex: "ffd9c4")!)
        XCTAssertEqual(BuiltinAnimations.done.frames.last?.frame, BuiltinAnimations.ringg)
    }

    func testJSONRoundTripUsesHexPixels() throws {
        let data = try BuiltinAnimations.tool.encoded()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"e2794f\""))
        XCTAssertTrue(text.contains("\"durationMs\" : 260"))
        XCTAssertEqual(try PixelAnimation.decode(data), BuiltinAnimations.tool)
    }

    func testValidationRejectsBadData() {
        var a = BuiltinAnimations.tool
        a.frames = []
        XCTAssertThrowsError(try a.validate()) { XCTAssertEqual($0 as? PixelAnimation.ValidationError, .noFrames) }
        a = BuiltinAnimations.tool
        a.frames[0].durationMs = 10
        XCTAssertThrowsError(try a.validate()) { XCTAssertEqual($0 as? PixelAnimation.ValidationError, .badDuration(frame: 0, ms: 10)) }
        a = BuiltinAnimations.tool
        a.frames = Array(repeating: a.frames[0], count: 21)
        XCTAssertThrowsError(try a.validate()) { XCTAssertEqual($0 as? PixelAnimation.ValidationError, .tooManyFrames(21)) }
        a = BuiltinAnimations.tool
        a.frames[1].pixels.removeLast()
        XCTAssertThrowsError(try a.validate()) { XCTAssertEqual($0 as? PixelAnimation.ValidationError, .badPixelCount(frame: 1, count: 35)) }
        a = BuiltinAnimations.tool
        a.version = 2
        XCTAssertThrowsError(try a.validate()) { XCTAssertEqual($0 as? PixelAnimation.ValidationError, .unsupportedVersion(2)) }
        let badHex = #"{"version":1,"id":"x","name":"x","loop":true,"frames":[{"durationMs":100,"pixels":["nothex"]}]}"#
        XCTAssertThrowsError(try PixelAnimation.decode(Data(badHex.utf8)))
    }

    func testClampDuration() {
        XCTAssertEqual(PixelAnimation.clampDuration(10), 50)
        XCTAssertEqual(PixelAnimation.clampDuration(260), 260)
        XCTAssertEqual(PixelAnimation.clampDuration(9000), 5000)
    }
}
