import Foundation

/// Merges Yogo's async hooks into Claude Code's settings.json without touching anything else (spec §10).
public enum HooksInstaller {
    public static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "PermissionRequest", "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    public enum InstallError: Error, Equatable {
        case invalidJSON
        case unexpectedShape(String)
    }

    static let pathMarker = "/Yogo.app/Contents/MacOS/yogo"

    public static func command(cliPath: String) -> String { "'\(cliPath)' hook" }

    static func isOurs(_ handler: Any) -> Bool {
        guard let cmd = (handler as? [String: Any])?["command"] as? String else { return false }
        return cmd.contains(pathMarker) && cmd.hasSuffix(" hook")
    }

    static func parse(_ data: Data) throws -> [String: Any] {
        if data.allSatisfy({ [0x20, 0x09, 0x0A, 0x0D].contains($0) }) { return [:] }
        guard let obj = try? JSONSerialization.jsonObject(with: data), let dict = obj as? [String: Any] else {
            throw InstallError.invalidJSON
        }
        return dict
    }

    static func serialize(_ dict: [String: Any]) throws -> Data {
        var d = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        d.append(0x0A)
        return d
    }

    static func hooksDict(_ root: [String: Any]) throws -> [String: Any] {
        guard let h = root["hooks"] else { return [:] }
        guard let dict = h as? [String: Any] else { throw InstallError.unexpectedShape("hooks") }
        return dict
    }

    /// Removes our handlers everywhere; drops matcher groups and events that only contained ours.
    /// Events we did not touch keep their original value.
    static func strip(_ hooks: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (event, value) in hooks {
            guard let groups = value as? [Any] else {
                out[event] = value
                continue
            }
            var changed = false
            var kept: [Any] = []
            for g in groups {
                guard var group = g as? [String: Any], let hs = group["hooks"] as? [Any] else {
                    kept.append(g)
                    continue
                }
                let remaining = hs.filter { !isOurs($0) }
                if remaining.count == hs.count {
                    kept.append(g)
                    continue
                }
                changed = true
                if remaining.isEmpty { continue }
                group["hooks"] = remaining
                kept.append(group)
            }
            if !changed {
                out[event] = value
            } else if !kept.isEmpty {
                out[event] = kept
            }
        }
        return out
    }

    public static func install(into data: Data, cliPath: String) throws -> Data {
        var root = try parse(data)
        var hooks = strip(try hooksDict(root))
        let handler: [String: Any] = ["type": "command", "command": command(cliPath: cliPath), "async": true, "timeout": 5]
        for e in events {
            if let existing = hooks[e], !(existing is [Any]) { throw InstallError.unexpectedShape("hooks.\(e)") }
            var groups = hooks[e] as? [Any] ?? []
            groups.append(["hooks": [handler]])
            hooks[e] = groups
        }
        root["hooks"] = hooks
        return try serialize(root)
    }

    public static func uninstall(from data: Data) throws -> Data {
        var root = try parse(data)
        let hooks = try hooksDict(root)
        let stripped = strip(hooks)
        if stripped.isEmpty && !hooks.isEmpty {
            root.removeValue(forKey: "hooks")
        } else if root["hooks"] != nil {
            root["hooks"] = stripped
        }
        return try serialize(root)
    }

    public static func isInstalled(_ data: Data) -> Bool {
        guard let root = try? parse(data), let hooks = try? hooksDict(root) else { return false }
        return events.allSatisfy { e in
            (hooks[e] as? [Any])?.contains { g in
                ((g as? [String: Any])?["hooks"] as? [Any])?.contains(where: isOurs) ?? false
            } ?? false
        }
    }

    /// Reads `url` (a missing file counts as empty), transforms it, writes a timestamped backup, then
    /// writes the result through any symlink. Nothing is written if `transform` throws.
    /// Returns the backup URL, or nil when there was no file to back up.
    @discardableResult
    public static func apply(to url: URL, now: Date = Date(), transform: (Data) throws -> Data) throws -> URL? {
        let fm = FileManager.default
        let target = url.resolvingSymlinksInPath()
        let exists = fm.fileExists(atPath: target.path)
        let original = exists ? try Data(contentsOf: target) : Data()
        let updated = try transform(original)
        var backup: URL?
        if exists {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMdd-HHmmss"
            let b = target.deletingLastPathComponent()
                .appendingPathComponent("\(target.lastPathComponent).yogo-backup-\(f.string(from: now))")
            try original.write(to: b)
            backup = b
        } else {
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try updated.write(to: target, options: .atomic)
        return backup
    }
}
