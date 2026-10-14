import XCTest
@testable import YogoCore

final class SceneTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let pinnedAnim = PixelAnimation(id: "user.pin", name: "pin", loop: false,
                                    frames: [AnimationFrame(durationMs: 100, frame: .filled(RGB(0, 0, 255)))])

    func play(_ s: ScreenScene) -> (id: String, since: Date, loop: Bool)? {
        if case let .play(a, since, loop) = s { return (a.id, since, loop) }
        return nil
    }

    func testPriorityOrder() {
        var sel = SceneSelector()
        let preview = BuiltinAnimations.tool
        XCTAssertEqual(play(sel.select(SceneInputs(preview: preview, claudeState: .waiting, pinned: pinnedAnim), at: t0))?.id, preview.id)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .waiting, pinned: pinnedAnim), at: t0))?.id, BuiltinAnimations.waiting.id)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .idle, pinned: pinnedAnim), at: t0))?.id, "user.pin")
        XCTAssertEqual(sel.select(SceneInputs(claudeState: .idle), at: t0), .release)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeModeEnabled: false, claudeState: .tool, pinned: pinnedAnim), at: t0))?.id, "user.pin")
        XCTAssertEqual(sel.select(SceneInputs(claudeModeEnabled: false, claudeState: .tool), at: t0), .release)
    }

    func testPreviewAndPinnedAlwaysLoopClaudeFollowsAnimation() {
        var sel = SceneSelector()
        XCTAssertEqual(play(sel.select(SceneInputs(pinned: pinnedAnim), at: t0))?.loop, true)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .done), at: t0))?.loop, false)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .tool), at: t0))?.loop, true)
    }

    func testStartTimeOnlyResetsWhenSourceChanges() {
        var sel = SceneSelector()
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .tool), at: t0))?.since, t0)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .tool), at: t0 + 1))?.since, t0)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .thinking), at: t0 + 2))?.since, t0 + 2)
        var edited = BuiltinAnimations.tool
        edited.frames[0].durationMs = 500
        XCTAssertEqual(play(sel.select(SceneInputs(preview: BuiltinAnimations.tool), at: t0 + 3))?.since, t0 + 3)
        XCTAssertEqual(play(sel.select(SceneInputs(preview: edited), at: t0 + 4))?.since, t0 + 3,
                       "editing the previewed animation must not restart it")
        _ = sel.select(SceneInputs(), at: t0 + 5)
        XCTAssertEqual(play(sel.select(SceneInputs(claudeState: .thinking), at: t0 + 6))?.since, t0 + 6)
    }

    func testQuantize() {
        XCTAssertEqual([110, 140, 160, 260, 90, 10, 700].map(Player.quantize), [100, 150, 150, 250, 100, 50, 700])
        XCTAssertEqual(Player.totalMs(BuiltinAnimations.done), 1350)
    }

    func testLoopingPlayback() {
        let s = ScreenScene.play(BuiltinAnimations.tool, since: t0, loop: true)
        XCTAssertEqual(Player.frame(for: s, at: t0), BuiltinAnimations.plus)
        XCTAssertEqual(Player.frame(for: s, at: t0 + 0.249), BuiltinAnimations.plus)
        XCTAssertEqual(Player.frame(for: s, at: t0 + 0.25), BuiltinAnimations.xray)
        XCTAssertEqual(Player.frame(for: s, at: t0 + 0.5), BuiltinAnimations.plus)
        XCTAssertEqual(Player.frame(for: s, at: t0 - 1), BuiltinAnimations.plus, "clock skew never crashes")
    }

    func testOneShotHoldsLastFrame() {
        let s = ScreenScene.play(BuiltinAnimations.done, since: t0, loop: false)
        XCTAssertEqual(Player.frame(for: s, at: t0), BuiltinAnimations.dot)
        XCTAssertEqual(Player.frame(for: s, at: t0 + 1.2), BuiltinAnimations.ringg)
        XCTAssertEqual(Player.frame(for: s, at: t0 + 60), BuiltinAnimations.ringg)
    }

    func testReleaseHasNoFrame() {
        XCTAssertNil(Player.frame(for: .release, at: t0))
    }
}
