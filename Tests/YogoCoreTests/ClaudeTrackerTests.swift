import XCTest
@testable import YogoCore

final class ClaudeTrackerTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    var tracker: ClaudeTracker!

    override func setUp() { tracker = ClaudeTracker() }

    func send(_ event: String, _ session: String = "s1", at dt: TimeInterval = 0,
              tool: String? = nil, id: String? = nil, type: String? = nil) {
        tracker.apply(SignalMessage(event: event, session: session, notificationType: type, tool: tool, toolUseID: id), at: t0 + dt)
    }

    func state(_ dt: TimeInterval = 0) -> ClaudeState { tracker.state(at: t0 + dt) }

    func testBasicTurn() {
        send("SessionStart"); XCTAssertEqual(state(), .idle)
        send("UserPromptSubmit"); XCTAssertEqual(state(), .thinking)
        send("PreToolUse", tool: "Read", id: "a"); XCTAssertEqual(state(), .tool)
        send("PostToolUse", tool: "Read", id: "a"); XCTAssertEqual(state(), .thinking)
        send("Stop", at: 10); XCTAssertEqual(state(10), .done)
        XCTAssertEqual(state(10 + 1.3), .done)    // doneDuration = 1.35 s; avoid float-edge comparisons
        XCTAssertEqual(state(10 + 1.4), .idle)
    }

    func testParallelToolsDoNotFlicker() {
        send("UserPromptSubmit"); send("PreToolUse", id: "a"); send("PreToolUse", id: "b")
        send("PostToolUse", id: "a"); XCTAssertEqual(state(), .tool)
        send("PostToolUseFailure", id: "b"); XCTAssertEqual(state(), .thinking)
    }

    func testPermissionApproved() {
        send("UserPromptSubmit"); send("PreToolUse", tool: "Bash", id: "a")
        send("PermissionRequest", tool: "Bash", id: "a"); XCTAssertEqual(state(), .waiting)
        send("PostToolUse", tool: "Bash", id: "a"); XCTAssertEqual(state(), .thinking)
    }

    func testParallelToolFinishingDoesNotHideAPendingPermission() {
        send("UserPromptSubmit"); send("PreToolUse", id: "a"); send("PreToolUse", id: "b")
        send("PermissionRequest", id: "b"); send("PostToolUse", id: "a")
        XCTAssertEqual(state(), .waiting)
        send("PostToolUse", id: "b"); XCTAssertEqual(state(), .thinking)
    }

    func testDeniedPermissionClearsOnNextToolCall() {
        send("UserPromptSubmit"); send("PreToolUse", id: "a"); send("PermissionRequest", id: "a")
        send("PreToolUse", id: "c"); XCTAssertEqual(state(), .tool)
    }

    func testPermissionWithoutIDClearsOnAnyPostToolUse() {
        send("UserPromptSubmit"); send("PreToolUse", id: "a"); send("Notification", type: "permission_prompt")
        XCTAssertEqual(state(), .waiting)
        send("PostToolUse", id: "a"); XCTAssertEqual(state(), .thinking)
    }

    func testQuestionToolsCountAsWaiting() {
        send("UserPromptSubmit"); send("PreToolUse", tool: "AskUserQuestion", id: "q"); XCTAssertEqual(state(), .waiting)
        send("PostToolUse", tool: "AskUserQuestion", id: "q"); XCTAssertEqual(state(), .thinking)
        send("PreToolUse", tool: "ExitPlanMode", id: "p"); XCTAssertEqual(state(), .waiting)
    }

    func testIdlePromptNeverClearsWaiting() {
        send("UserPromptSubmit"); send("PermissionRequest", id: "a")
        send("Notification", type: "idle_prompt"); XCTAssertEqual(state(), .waiting)
        send("Stop"); send("Notification", type: "idle_prompt"); XCTAssertEqual(state(), .idle)
    }

    func testElicitationAndAgentNeedsInputAreWaiting() {
        send("Notification", "e", type: "elicitation_dialog")
        send("Notification", "f", type: "agent_needs_input")
        XCTAssertEqual(state(), .waiting)
        send("Notification", "g", type: "auth_success")
        XCTAssertEqual(tracker.sessions["g"]?.rawState, .idle)
    }

    func testStaleWorkFallsBackToIdleButWaitingPersists() {
        send("UserPromptSubmit", "busy"); XCTAssertEqual(state(599), .thinking); XCTAssertEqual(state(600), .idle)
        tracker.reset()
        send("PermissionRequest", "away", id: "a")
        XCTAssertEqual(state(3600), .waiting)
        XCTAssertEqual(state(7199), .waiting)
        XCTAssertEqual(state(7200), .idle)
    }

    func testMostUrgentSessionWins() {
        send("UserPromptSubmit", "A"); send("PreToolUse", "A", id: "x")
        send("UserPromptSubmit", "B"); XCTAssertEqual(state(), .tool)
        send("PermissionRequest", "B", id: "y"); XCTAssertEqual(state(), .waiting)
        send("SessionEnd", "B"); XCTAssertEqual(state(), .tool)
        XCTAssertEqual(tracker.sessionCount, 1)
    }

    func testSessionStartDoesNotResetActiveSession() {
        send("UserPromptSubmit"); send("PreToolUse", id: "a")
        send("SessionStart")                                   // source=compact fires mid-turn
        XCTAssertEqual(state(), .tool)
    }

    /// Review Focus #5: a terminal closed without SessionEnd can be cleared from the menu.
    func testStopFailureAndReset() {
        send("UserPromptSubmit"); send("StopFailure"); XCTAssertEqual(state(), .idle)
        send("PermissionRequest", "x"); XCTAssertEqual(state(), .waiting)
        tracker.reset()
        XCTAssertEqual(state(), .idle)
        XCTAssertEqual(tracker.sessionCount, 0)
    }

    func testNoSessionsMeansIdle() { XCTAssertEqual(state(), .idle) }

    func testPriorityOrder() {
        XCTAssertEqual(ClaudeState.allCases.sorted(), [.idle, .done, .thinking, .tool, .waiting])
    }
}

final class SignalMessageTests: XCTestCase {
    func testParsesHookPayload() throws {
        let json = #"{"session_id":"abc","hook_event_name":"PreToolUse","tool_name":"Bash","tool_use_id":"toolu_1","tool_input":{"command":"ls"},"cwd":"/x"}"#
        let m = try XCTUnwrap(SignalMessage.fromHookPayload(Data(json.utf8)))
        XCTAssertEqual(m, SignalMessage(event: "PreToolUse", session: "abc", tool: "Bash", toolUseID: "toolu_1"))
    }

    func testParsesNotificationType() throws {
        let json = #"{"session_id":"abc","hook_event_name":"Notification","notification_type":"permission_prompt","message":"x"}"#
        XCTAssertEqual(try XCTUnwrap(SignalMessage.fromHookPayload(Data(json.utf8))).notificationType, "permission_prompt")
    }

    /// Review Focus #4: whatever arrives on stdin, `yogo hook` must stay silent.
    func testUnusablePayloadsReturnNil() {
        let inputs = ["", "garbage", "[]", "null", #"{"hook_event_name":"Stop"}"#, #"{"session_id":"a"}"#,
                      #"{"session_id":5,"hook_event_name":"Stop"}"#, #"{"session_id":"","hook_event_name":"Stop"}"#]
        for s in inputs { XCTAssertNil(SignalMessage.fromHookPayload(Data(s.utf8)), s) }
    }

    func testSimulateDrivesTrackerIntoThatState() {
        XCTAssertEqual(SignalMessage.simulate(.idle, session: "s").map(\.event), ["SessionEnd"])
        for state in ClaudeState.allCases where state != .idle {
            let t = ClaudeTracker()
            let now = Date()
            SignalMessage.simulate(state, session: "s").forEach { t.apply($0, at: now) }
            XCTAssertEqual(t.state(at: now), state)
        }
    }
}
