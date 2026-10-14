import XCTest
@testable import YogoCore

final class EditorDocumentTests: XCTestCase {
    let red = RGB(255, 0, 0)
    let blue = RGB(0, 0, 255)

    func blankDoc(frames: Int = 1) -> EditorDocument {
        EditorDocument(animation: PixelAnimation(id: "user.t", name: "t", loop: true,
                                                 frames: Array(repeating: AnimationFrame(durationMs: 200, frame: .blank), count: frames)))
    }

    func testPencilAndEraser() {
        var d = blankDoc()
        d.paint(.pencil, x: 2, y: 3, color: red)
        XCTAssertEqual(d.currentFrame[2, 3], red)
        d.paint(.eraser, x: 2, y: 3, color: red)
        XCTAssertEqual(d.currentFrame[2, 3], .off)
    }

    func testOutOfBoundsIsIgnored() {
        var d = blankDoc()
        d.paint(.pencil, x: 6, y: 0, color: red)
        d.paint(.pencil, x: -1, y: 0, color: red)
        d.paint(.fill, x: 0, y: 6, color: red)
        XCTAssertEqual(d.currentFrame, .blank)
    }

    func testFillStopsAtDifferentColours() {
        var d = blankDoc()
        for y in 0..<6 { d.paint(.pencil, x: 2, y: y, color: blue) }   // a wall at x = 2
        d.paint(.fill, x: 0, y: 0, color: red)
        for y in 0..<6 {
            XCTAssertEqual(d.currentFrame[0, y], red)
            XCTAssertEqual(d.currentFrame[1, y], red)
            XCTAssertEqual(d.currentFrame[2, y], blue)
            XCTAssertEqual(d.currentFrame[3, y], .off)
        }
    }

    func testOneStrokeIsOneUndoStep() {
        var d = blankDoc()
        d.checkpoint()
        d.paint(.pencil, x: 0, y: 0, color: red)
        d.paint(.pencil, x: 1, y: 0, color: red)
        d.paint(.pencil, x: 2, y: 0, color: red)
        d.undo()
        XCTAssertEqual(d.currentFrame, .blank)
        XCTAssertFalse(d.canUndo)
        d.redo()
        XCTAssertEqual(d.currentFrame[2, 0], red)
        XCTAssertFalse(d.canRedo)
    }

    func testNewEditClearsRedo() {
        var d = blankDoc()
        d.checkpoint(); d.paint(.pencil, x: 0, y: 0, color: red)
        d.undo()
        XCTAssertTrue(d.canRedo)
        d.checkpoint()
        XCTAssertFalse(d.canRedo)
    }

    func testFrameOperations() {
        var d = blankDoc()
        d.paint(.pencil, x: 0, y: 0, color: red)
        d.duplicateFrame()
        XCTAssertEqual(d.animation.frames.count, 2); XCTAssertEqual(d.selected, 1); XCTAssertEqual(d.currentFrame[0, 0], red)
        d.addFrame()
        XCTAssertEqual(d.animation.frames.count, 3); XCTAssertEqual(d.selected, 2); XCTAssertEqual(d.currentFrame, .blank)
        XCTAssertEqual(d.animation.frames[2].durationMs, 200)
        d.deleteFrame()
        XCTAssertEqual(d.animation.frames.count, 2); XCTAssertEqual(d.selected, 1)
        d.select(99); XCTAssertEqual(d.selected, 1)
        d.select(-3); XCTAssertEqual(d.selected, 0)
        d.undo()
        XCTAssertEqual(d.animation.frames.count, 3, "frame operations are undoable")
    }

    func testFrameLimitsAndDurations() throws {
        var full = blankDoc(frames: PixelAnimation.maxFrames)
        full.addFrame(); full.duplicateFrame()
        XCTAssertEqual(full.animation.frames.count, PixelAnimation.maxFrames)
        XCTAssertNoThrow(try full.animation.validate())
        var one = blankDoc()
        one.deleteFrame()
        XCTAssertEqual(one.animation.frames.count, 1)
        one.setDuration(10); XCTAssertEqual(one.animation.frames[0].durationMs, 50)
        one.setDuration(99999); XCTAssertEqual(one.animation.frames[0].durationMs, 5000)
        one.setLoop(false); XCTAssertFalse(one.animation.loop)
    }

    func testUndoHistoryIsCapped() {
        var d = blankDoc()
        for i in 0..<150 {
            d.checkpoint()
            d.paint(.pencil, x: i % 6, y: 0, color: RGB(UInt8(i), 0, 0))
        }
        var n = 0
        while d.canUndo { d.undo(); n += 1 }
        XCTAssertEqual(n, EditorDocument.undoLimit)
    }

    func testAdoptRewritesIdentityIncludingHistory() {
        var d = blankDoc()
        d.checkpoint(); d.paint(.pencil, x: 0, y: 0, color: red)
        d.adopt(id: "user.new", name: "Yeni")
        d.undo()
        XCTAssertEqual(d.animation.id, "user.new")
        XCTAssertEqual(d.animation.name, "Yeni")
    }
}
