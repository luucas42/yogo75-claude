import XCTest
@testable import YogoCore

final class HooksInstallerTests: XCTestCase {
    let cli = "/Users/u/Applications/Yogo.app/Contents/MacOS/yogo"
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("yogo-hooks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func json(_ d: Data) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: d) as? [String: Any]) }

    func handlers(_ root: [String: Any], _ event: String) -> [[String: Any]] {
        let groups = (root["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
    }

    func testInstallIntoEmptyFileAddsAllEvents() throws {
        let root = try json(HooksInstaller.install(into: Data(), cliPath: cli))
        XCTAssertEqual(HooksInstaller.events.count, 10)
        for e in HooksInstaller.events {
            let hs = handlers(root, e)
            XCTAssertEqual(hs.count, 1, e)
            XCTAssertEqual(hs.first?["command"] as? String, "'\(cli)' hook")
            XCTAssertEqual(hs.first?["type"] as? String, "command")
            XCTAssertEqual(hs.first?["async"] as? Bool, true)
            XCTAssertEqual(hs.first?["timeout"] as? Int, 5)
        }
    }

    /// Review Focus #1: the user already has hooks, including on the same events and with matchers.
    func testExistingSettingsAndHooksArePreserved() throws {
        let existing = """
        {"model":"opus","permissions":{"allow":["Bash(ls:*)"]},
         "hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"~/bin/status.sh start"}]}],
                  "PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"~/bin/guard.sh"}]}]}}
        """
        let root = try json(HooksInstaller.install(into: Data(existing.utf8), cliPath: cli))
        XCTAssertEqual(root["model"] as? String, "opus")
        XCTAssertEqual((root["permissions"] as? [String: Any])?["allow"] as? [String], ["Bash(ls:*)"])
        XCTAssertEqual(handlers(root, "SessionStart").compactMap { $0["command"] as? String },
                       ["~/bin/status.sh start", "'\(cli)' hook"])
        let pre = (root["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]]
        XCTAssertEqual(pre?.first?["matcher"] as? String, "Bash")
        XCTAssertEqual(handlers(root, "PreToolUse").compactMap { $0["command"] as? String },
                       ["~/bin/guard.sh", "'\(cli)' hook"])
    }

    func testInstallIsIdempotent() throws {
        let once = try HooksInstaller.install(into: Data(), cliPath: cli)
        XCTAssertEqual(try HooksInstaller.install(into: once, cliPath: cli), once)
    }

    func testReinstallFromAnotherPathReplacesOldEntry() throws {
        let old = try HooksInstaller.install(into: Data(), cliPath: "/Users/u/Desktop/yogo/build/Yogo.app/Contents/MacOS/yogo")
        let root = try json(HooksInstaller.install(into: old, cliPath: cli))
        XCTAssertEqual(handlers(root, "Stop").compactMap { $0["command"] as? String }, ["'\(cli)' hook"])
    }

    func testUninstallRemovesOnlyOurs() throws {
        let existing = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"afplay /System/Library/Sounds/Glass.aiff"}]}]}}"#
        let installed = try HooksInstaller.install(into: Data(existing.utf8), cliPath: cli)
        XCTAssertTrue(HooksInstaller.isInstalled(installed))
        let removed = try HooksInstaller.uninstall(from: installed)
        XCTAssertFalse(HooksInstaller.isInstalled(removed))
        let root = try json(removed)
        XCTAssertEqual(handlers(root, "Stop").compactMap { $0["command"] as? String }, ["afplay /System/Library/Sounds/Glass.aiff"])
        XCTAssertNil((root["hooks"] as? [String: Any])?["PreToolUse"], "events that only had our hook disappear")
    }

    func testUninstallOfOnlyOurHooksRemovesHooksKey() throws {
        let root = try json(HooksInstaller.uninstall(from: HooksInstaller.install(into: Data("{}".utf8), cliPath: cli)))
        XCTAssertNil(root["hooks"])
    }

    func testInvalidShapesAreRefused() {
        XCTAssertThrowsError(try HooksInstaller.install(into: Data("{not json".utf8), cliPath: cli)) {
            XCTAssertEqual($0 as? HooksInstaller.InstallError, .invalidJSON)
        }
        XCTAssertThrowsError(try HooksInstaller.install(into: Data("[]".utf8), cliPath: cli)) {
            XCTAssertEqual($0 as? HooksInstaller.InstallError, .invalidJSON)
        }
        XCTAssertThrowsError(try HooksInstaller.install(into: Data(#"{"hooks":"x"}"#.utf8), cliPath: cli)) {
            XCTAssertEqual($0 as? HooksInstaller.InstallError, .unexpectedShape("hooks"))
        }
        XCTAssertThrowsError(try HooksInstaller.install(into: Data(#"{"hooks":{"Stop":{}}}"#.utf8), cliPath: cli)) {
            XCTAssertEqual($0 as? HooksInstaller.InstallError, .unexpectedShape("hooks.Stop"))
        }
    }

    func testApplyBacksUpAndNeverTouchesInvalidFile() throws {
        let url = dir.appendingPathComponent("settings.json")
        try Data("{broken".utf8).write(to: url)
        XCTAssertThrowsError(try HooksInstaller.apply(to: url) { try HooksInstaller.install(into: $0, cliPath: self.cli) })
        XCTAssertEqual(try Data(contentsOf: url), Data("{broken".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["settings.json"])

        try Data(#"{"model":"opus"}"#.utf8).write(to: url)
        let backup = try XCTUnwrap(HooksInstaller.apply(to: url) { try HooksInstaller.install(into: $0, cliPath: self.cli) })
        XCTAssertTrue(backup.lastPathComponent.hasPrefix("settings.json.yogo-backup-"))
        XCTAssertEqual(try Data(contentsOf: backup), Data(#"{"model":"opus"}"#.utf8))
        XCTAssertTrue(HooksInstaller.isInstalled(try Data(contentsOf: url)))
    }

    /// Review Focus #2: dotfiles managers symlink ~/.claude/settings.json.
    func testApplyWritesThroughSymlink() throws {
        let real = dir.appendingPathComponent("real.json")
        try Data("{}".utf8).write(to: real)
        let link = dir.appendingPathComponent("settings.json")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: real.path)
        try HooksInstaller.apply(to: link) { try HooksInstaller.install(into: $0, cliPath: self.cli) }
        let type = try FileManager.default.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType   // lstat
        XCTAssertEqual(type, .typeSymbolicLink, "the symlink itself must survive")
        XCTAssertTrue(HooksInstaller.isInstalled(try Data(contentsOf: real)))
    }

    func testMissingFileIsCreated() throws {
        let url = dir.appendingPathComponent("sub/settings.json")
        let backup = try HooksInstaller.apply(to: url) { try HooksInstaller.install(into: $0, cliPath: self.cli) }
        XCTAssertNil(backup)
        XCTAssertTrue(HooksInstaller.isInstalled(try Data(contentsOf: url)))
    }
}
