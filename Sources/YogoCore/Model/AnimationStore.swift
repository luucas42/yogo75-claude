import Foundation

/// Built-ins (read-only, in code) plus user animations stored as `<id>.json` (spec §7).
public final class AnimationStore {
    public enum StoreError: Error, Equatable {
        case builtinIsReadOnly(String)
        case invalidID(String)
    }

    public let directory: URL
    public private(set) var user: [PixelAnimation] = []
    /// File names that were not loaded (corrupt, invalid, duplicate, or shadowing a built-in).
    public private(set) var skippedFiles: [String] = []

    public init(directory: URL) { self.directory = directory }

    public var all: [PixelAnimation] { BuiltinAnimations.all + user }

    public func get(_ id: String) -> PixelAnimation? { all.first { $0.id == id } }

    public static func isBuiltin(_ id: String) -> Bool { id.hasPrefix("builtin.") }

    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) } && !id.contains("..")
    }

    public func reload() {
        user = []
        skippedFiles = []
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let a = try? PixelAnimation.decode(data),
                  !Self.isBuiltin(a.id), Self.isValidID(a.id),
                  !user.contains(where: { $0.id == a.id })
            else {
                skippedFiles.append(url.lastPathComponent)
                continue
            }
            user.append(a)
        }
        user.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func save(_ a: PixelAnimation) throws {
        guard !Self.isBuiltin(a.id) else { throw StoreError.builtinIsReadOnly(a.id) }
        guard Self.isValidID(a.id) else { throw StoreError.invalidID(a.id) }
        try a.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try a.encoded().write(to: fileURL(a.id), options: .atomic)
        if let i = user.firstIndex(where: { $0.id == a.id }) { user[i] = a } else { user.append(a) }
    }

    public func delete(_ id: String) throws {
        guard !Self.isBuiltin(id) else { throw StoreError.builtinIsReadOnly(id) }
        guard Self.isValidID(id) else { throw StoreError.invalidID(id) }
        try? FileManager.default.removeItem(at: fileURL(id))
        user.removeAll { $0.id == id }
    }

    /// A user-owned copy with a fresh id (used when a built-in is edited, spec §7).
    public static func copy(of a: PixelAnimation, name: String? = nil) -> PixelAnimation {
        var c = a
        c.id = "user." + UUID().uuidString.lowercased()
        c.name = name ?? "\(a.name) (kopya)"
        return c
    }

    public static func newBlank(name: String = "Yeni animasyon") -> PixelAnimation {
        PixelAnimation(id: "user." + UUID().uuidString.lowercased(), name: name, loop: true,
                       frames: [AnimationFrame(durationMs: 200, frame: .blank)])
    }

    func fileURL(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }
}

public enum Assignments {
    /// Resolves stored ids (ClaudeState.rawValue → animation id). Missing, unknown or deleted ids fall
    /// back to the built-in default (spec §11). `idle` never gets an animation.
    public static func resolve(_ ids: [String: String], lookup: (String) -> PixelAnimation?) -> [ClaudeState: PixelAnimation] {
        var out = BuiltinAnimations.defaultAssignments
        for (key, id) in ids {
            guard let state = ClaudeState(rawValue: key), state != .idle, let a = lookup(id) else { continue }
            out[state] = a
        }
        return out
    }
}
