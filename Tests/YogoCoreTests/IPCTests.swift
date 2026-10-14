import XCTest
@testable import YogoCore

final class IPCTests: XCTestCase {
    var path: String!

    override func setUp() {
        path = FileManager.default.temporaryDirectory.appendingPathComponent("yogo-\(UUID().uuidString.prefix(8)).sock").path
    }

    override func tearDown() { unlink(path) }

    func testSignalReachesTrackerThroughRealSocket() throws {
        let tracker = ClaudeTracker()
        let got = expectation(description: "signal")
        let server = SocketServer(path: path, handlerQueue: DispatchQueue(label: "test.handler")) { line in
            IPCDispatch.handle(line,
                               onSignal: { tracker.apply($0, at: Date()); got.fulfill() },
                               status: { StatusReply(connection: "usb", state: tracker.state(at: Date()), sessions: tracker.sessionCount) })
        }
        try server.start()
        defer { server.stop() }

        let payload = Data(#"{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"hi"}"#.utf8)
        let msg = try XCTUnwrap(SignalMessage.fromHookPayload(payload))
        _ = try UnixSocket.request(path: path, line: JSONEncoder().encode(IPCRequest.forSignal(msg)), expectReply: false, timeout: 0.3)
        wait(for: [got], timeout: 2)

        let reply = try XCTUnwrap(UnixSocket.request(path: path, line: JSONEncoder().encode(IPCRequest.status), expectReply: true, timeout: 0.3))
        let status = try JSONDecoder().decode(StatusReply.self, from: reply)
        XCTAssertEqual(status, StatusReply(connection: "usb", state: .thinking, sessions: 1))
    }

    /// Review Focus #3: a second Yogo instance must not steal the socket from a running one.
    func testSecondServerRefusesToStealSocket() throws {
        let a = SocketServer(path: path, handlerQueue: DispatchQueue(label: "a")) { _ in nil }
        try a.start()
        defer { a.stop() }
        let b = SocketServer(path: path, handlerQueue: DispatchQueue(label: "b")) { _ in nil }
        XCTAssertThrowsError(try b.start()) { XCTAssertEqual($0 as? SocketServer.ServerError, .alreadyRunning) }
        XCTAssertTrue(UnixSocket.isListening(path: path))
    }

    func testStaleSocketFileIsReplaced() throws {
        FileManager.default.createFile(atPath: path, contents: Data())
        let s = SocketServer(path: path, handlerQueue: DispatchQueue(label: "s")) { _ in nil }
        XCTAssertNoThrow(try s.start())
        XCTAssertTrue(UnixSocket.isListening(path: path))
        s.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testSocketFileIsPrivate() throws {
        let s = SocketServer(path: path, handlerQueue: DispatchQueue(label: "p")) { _ in nil }
        try s.start()
        defer { s.stop() }
        let perms = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }

    func testClientFailsFastWhenNoServer() {
        let t0 = Date()
        XCTAssertThrowsError(try UnixSocket.request(path: path, line: Data("x".utf8), expectReply: false, timeout: 0.3))
        XCTAssertLessThan(Date().timeIntervalSince(t0), 0.5)
        XCTAssertFalse(UnixSocket.isListening(path: path))
    }

    func testDispatchIgnoresGarbage() {
        var signals = 0
        let r = IPCDispatch.handle(Data("nope".utf8), onSignal: { _ in signals += 1 },
                                   status: { StatusReply(connection: "x", state: .idle, sessions: 0) })
        XCTAssertNil(r)
        XCTAssertEqual(signals, 0)
    }

    func testLogRotatesKeepingThreeFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("yogo-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("yogo.log")
        let log = Log(file: file, limit: 200, keep: 3)
        for i in 0..<60 { log.info("line \(i) 0123456789") }
        log.flush()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted(), ["yogo.log", "yogo.log.1", "yogo.log.2"])
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int)
        XCTAssertLessThan(size, 300)
    }
}
