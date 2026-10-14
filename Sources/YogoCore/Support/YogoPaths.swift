import Foundation

public enum YogoPaths {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    public static var supportDir: URL { home.appendingPathComponent("Library/Application Support/Yogo", isDirectory: true) }
    public static var socket: String { supportDir.appendingPathComponent("yogo.sock").path }
    public static var animationsDir: URL { supportDir.appendingPathComponent("Animations", isDirectory: true) }
    public static var logFile: URL { home.appendingPathComponent("Library/Logs/Yogo/yogo.log") }
    public static var claudeSettings: URL { home.appendingPathComponent(".claude/settings.json") }
}
