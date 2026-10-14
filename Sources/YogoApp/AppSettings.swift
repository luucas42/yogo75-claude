import Foundation

struct AppSettings: Codable, Equatable {
    enum IdleBehavior: String, Codable, CaseIterable {
        case keyboard
        case pinned
    }

    var claudeModeEnabled = true
    var idleBehavior: IdleBehavior = .keyboard
    var pinnedAnimationID: String?
    var staleTimeoutMinutes = 10
    var waitingTimeoutMinutes = 120
    /// ClaudeState.rawValue → animation id. Missing keys use the built-in default.
    var assignments: [String: String] = [:]

    private static let key = "settings.v1"

    static func load(from defaults: UserDefaults = .standard) -> AppSettings {
        guard let data = defaults.data(forKey: key), let s = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return s
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
