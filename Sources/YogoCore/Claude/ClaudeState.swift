public enum ClaudeState: String, Codable, CaseIterable, Sendable, Comparable {
    case idle, done, thinking, tool, waiting

    /// Aggregation priority (spec §5): waiting > tool > thinking > done > idle.
    public var priority: Int {
        switch self {
        case .idle: return 0
        case .done: return 1
        case .thinking: return 2
        case .tool: return 3
        case .waiting: return 4
        }
    }

    public static func < (a: ClaudeState, b: ClaudeState) -> Bool { a.priority < b.priority }
}
