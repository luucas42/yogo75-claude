import Foundation

/// Append-only log with simple rotation (spec §11: 1 MB × 3 files).
public final class Log {
    public static let shared = Log(file: YogoPaths.logFile)

    public let file: URL
    let limit: Int
    let keep: Int
    private let queue = DispatchQueue(label: "yogo.log")
    private let formatter = ISO8601DateFormatter()

    public init(file: URL, limit: Int = 1_000_000, keep: Int = 3) {
        self.file = file
        self.limit = limit
        self.keep = keep
    }

    public func info(_ message: String) { write("INFO", message) }
    public func warn(_ message: String) { write("WARN", message) }

    /// Blocks until queued lines are on disk.
    public func flush() { queue.sync {} }

    private func write(_ level: String, _ message: String) {
        let line = "\(formatter.string(from: Date())) \(level) \(message)\n"
        queue.async { [self] in
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            rotateIfNeeded()
            if let h = try? FileHandle(forWritingTo: file) {
                h.seekToEndOfFile()
                h.write(Data(line.utf8))
                try? h.close()
            } else {
                try? Data(line.utf8).write(to: file)
            }
        }
    }

    func rotateIfNeeded() {
        let fm = FileManager.default
        guard let size = (try? fm.attributesOfItem(atPath: file.path))?[.size] as? Int, size >= limit else { return }
        let p = file.path
        try? fm.removeItem(atPath: "\(p).\(keep - 1)")
        if keep > 2 {
            for i in stride(from: keep - 2, through: 1, by: -1) {
                try? fm.moveItem(atPath: "\(p).\(i)", toPath: "\(p).\(i + 1)")
            }
        }
        try? fm.moveItem(atPath: p, toPath: "\(p).1")
    }
}
