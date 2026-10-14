import XCTest
@testable import YogoCore

final class FakeScreenDevice: ScreenDevice {
    var isOpen = true
    var failuresRemaining = 0
    private(set) var sent: [[UInt8]] = []
    var commands: [UInt8] { sent.map { $0[1] } }

    func send(_ report: [UInt8]) throws {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw NSError(domain: "fake", code: 1)
        }
        sent.append(report)
    }

    func clear() { sent.removeAll() }
}

final class ScreenDriverTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let red = Frame.filled(RGB(255, 0, 0))

    func assertOnlySafeReports(_ d: FakeScreenDevice, file: StaticString = #filePath, line: UInt = #line) {
        for r in d.sent {
            XCTAssertEqual(r.count, 64, file: file, line: line)
            XCTAssertEqual(r[0], 0xAA, file: file, line: line)
            XCTAssertTrue([0x10, 0x11, 0x3C, 0x3D].contains(r[1]), "forbidden command \(r[1])", file: file, line: line)
        }
    }

    func testFirstFrameOpensSessionThenStreams() {
        let dev = FakeScreenDevice(), drv = ScreenDriver()
        drv.attach(dev)
        drv.tick(frame: red, at: t0)
        XCTAssertEqual(dev.commands, [0x10, 0x3C, 0x3C])
        dev.clear()
        drv.tick(frame: red, at: t0 + 0.05)
        XCTAssertEqual(dev.commands, [0x3C, 0x3C])
        dev.clear()
        drv.tick(frame: red, at: t0 + 2.0)
        XCTAssertEqual(dev.commands, [0x10, 0x3C, 0x3C], "session refreshed every 2 s")
        XCTAssertTrue(drv.isLive)
        assertOnlySafeReports(dev)
    }

    func testReleaseHappensExactlyOnce() {
        let dev = FakeScreenDevice(), drv = ScreenDriver()
        drv.attach(dev)
        drv.tick(frame: red, at: t0)
        dev.clear()
        drv.tick(frame: nil, at: t0 + 0.05)
        XCTAssertEqual(dev.commands, [0x3D, 0x11])
        dev.clear()
        drv.tick(frame: nil, at: t0 + 0.1)
        XCTAssertEqual(dev.commands, [])
        XCTAssertFalse(drv.isLive)
        drv.tick(frame: red, at: t0 + 0.15)
        XCTAssertEqual(dev.commands, [0x10, 0x3C, 0x3C], "after a release the next frame needs a new session")
        assertOnlySafeReports(dev)
    }

    func testIdleDriverSendsNothing() {
        let dev = FakeScreenDevice(), drv = ScreenDriver()
        drv.attach(dev)
        drv.tick(frame: nil, at: t0)
        drv.release()
        XCTAssertEqual(dev.commands, [])
    }

    func testReattachStartsANewSession() {
        let a = FakeScreenDevice(), b = FakeScreenDevice(), drv = ScreenDriver()
        drv.attach(a)
        drv.tick(frame: red, at: t0)
        drv.attach(b)
        drv.tick(frame: red, at: t0 + 0.05)
        XCTAssertEqual(b.commands, [0x10, 0x3C, 0x3C])
    }

    func testClosedOrMissingDeviceIsLeftAlone() {
        let dev = FakeScreenDevice(), drv = ScreenDriver()
        drv.tick(frame: red, at: t0)            // nothing attached
        dev.isOpen = false
        drv.attach(dev)
        drv.tick(frame: red, at: t0)
        XCTAssertEqual(dev.commands, [])
    }

    func testErrorsAreCountedAndReset() {
        let dev = FakeScreenDevice(), drv = ScreenDriver()
        drv.attach(dev)
        dev.failuresRemaining = 2
        drv.tick(frame: red, at: t0)
        drv.tick(frame: red, at: t0 + 0.05)
        XCTAssertEqual(drv.consecutiveErrors, 2)
        drv.tick(frame: red, at: t0 + 0.1)
        XCTAssertEqual(drv.consecutiveErrors, 0)
    }

    func testRejectionGuardPausesAfterFiveInARow() {
        var g = RejectionGuard()
        let rejected: [UInt8] = [0xAA, 0x3C, 0xFF, 0, 0, 0, 0, 0]
        let ok: [UInt8] = [0xAA, 0x3C, 0x00, 0, 0x38, 0, 0, 0x55]
        for _ in 0..<4 { g.record(reply: rejected, at: t0) }
        g.record(reply: ok, at: t0)
        XCTAssertFalse(g.isPaused(at: t0))
        for _ in 0..<5 { g.record(reply: rejected, at: t0) }
        XCTAssertTrue(g.isPaused(at: t0 + 29))
        XCTAssertFalse(g.isPaused(at: t0 + 30))
    }
}
