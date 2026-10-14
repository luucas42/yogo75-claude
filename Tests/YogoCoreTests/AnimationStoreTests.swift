import XCTest
@testable import YogoCore

final class AnimationStoreTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("yogo-store-\(UUID().uuidString)")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func userAnim(_ id: String = "user.a", name: String = "A") -> PixelAnimation {
        PixelAnimation(id: id, name: name, loop: true, frames: [AnimationFrame(durationMs: 200, frame: .filled(RGB(1, 2, 3)))])
    }

    func testEmptyStoreListsBuiltinsOnly() {
        let s = AnimationStore(directory: dir)
        s.reload()
        XCTAssertEqual(s.all.map(\.id), BuiltinAnimations.all.map(\.id))
        XCTAssertTrue(s.skippedFiles.isEmpty)
    }

    func testSaveReloadDelete() throws {
        try AnimationStore(directory: dir).save(userAnim())          // creates the directory
        let t = AnimationStore(directory: dir)
        t.reload()
        XCTAssertEqual(t.get("user.a"), userAnim())
        try t.delete("user.a")
        let u = AnimationStore(directory: dir)
        u.reload()
        XCTAssertNil(u.get("user.a"))
    }

    func testBuiltinsAreReadOnly() {
        let s = AnimationStore(directory: dir)
        XCTAssertThrowsError(try s.save(BuiltinAnimations.tool)) {
            XCTAssertEqual($0 as? AnimationStore.StoreError, .builtinIsReadOnly("builtin.tool"))
        }
        XCTAssertThrowsError(try s.delete("builtin.tool"))
        XCTAssertEqual(s.get("builtin.tool"), BuiltinAnimations.tool)
    }

    func testInvalidIDAndInvalidAnimationAreRefused() {
        let s = AnimationStore(directory: dir)
        XCTAssertThrowsError(try s.save(userAnim("../evil"))) {
            XCTAssertEqual($0 as? AnimationStore.StoreError, .invalidID("../evil"))
        }
        var bad = userAnim()
        bad.frames = []
        XCTAssertThrowsError(try s.save(bad))
    }

    func testCorruptAndShadowingFilesAreSkipped() throws {
        let s = AnimationStore(directory: dir)
        try s.save(userAnim())
        try Data("{nope".utf8).write(to: dir.appendingPathComponent("broken.json"))
        try BuiltinAnimations.tool.encoded().write(to: dir.appendingPathComponent("builtin.tool.json"))
        let t = AnimationStore(directory: dir)
        t.reload()
        XCTAssertEqual(t.user.map(\.id), ["user.a"])
        XCTAssertEqual(Set(t.skippedFiles), ["broken.json", "builtin.tool.json"])
        XCTAssertEqual(t.get("builtin.tool"), BuiltinAnimations.tool)
    }

    func testCopyGetsFreshUserID() {
        let c = AnimationStore.copy(of: BuiltinAnimations.tool)
        XCTAssertTrue(c.id.hasPrefix("user."))
        XCTAssertTrue(AnimationStore.isValidID(c.id))
        XCTAssertEqual(c.name, "Araç çalıştırıyor (kopya)")
        XCTAssertEqual(c.frames, BuiltinAnimations.tool.frames)
        XCTAssertNoThrow(try AnimationStore.newBlank().validate())
    }

    func testAssignmentsFallBackToDefaults() throws {
        let s = AnimationStore(directory: dir)
        try s.save(userAnim("user.mine"))
        let r = Assignments.resolve(["done": "user.mine", "tool": "user.deleted", "idle": "user.mine", "bogus": "user.mine"],
                                    lookup: s.get)
        XCTAssertEqual(r[.done]?.id, "user.mine")
        XCTAssertEqual(r[.tool]?.id, BuiltinAnimations.tool.id)
        XCTAssertNil(r[.idle])
        XCTAssertEqual(r.count, 4)
    }
}
