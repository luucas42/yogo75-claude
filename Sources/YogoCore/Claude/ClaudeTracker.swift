import Foundation

/// Per-session Claude Code state machine (spec §5). Not thread-safe: use it from one queue.
public final class ClaudeTracker {
    public struct Config: Equatable {
        public var staleTimeout: TimeInterval = 600
        public var waitingTimeout: TimeInterval = 7200
        /// Length of the assigned "done" animation; the app keeps this in sync (built-in: 1.35 s).
        public var doneDuration: TimeInterval = 1.35
        public init() {}
    }

    struct Session {
        enum Phase { case idle, active, done }
        var phase: Phase = .idle
        var running: Set<String> = []
        var waitingOn: Set<String> = []
        var lastEventAt: Date
        var doneAt: Date?

        var rawState: ClaudeState {
            if !waitingOn.isEmpty { return .waiting }
            switch phase {
            case .idle: return .idle
            case .done: return .done
            case .active: return running.isEmpty ? .thinking : .tool
            }
        }
    }

    static let unknownID = "?"
    static let waitingNotifications: Set<String> = ["permission_prompt", "elicitation_dialog", "agent_needs_input"]
    static let userBlockingTools: Set<String> = ["AskUserQuestion", "ExitPlanMode"]

    public var config: Config
    private(set) var sessions: [String: Session] = [:]

    public init(config: Config = Config()) { self.config = config }

    public var sessionCount: Int { sessions.count }

    public func reset() { sessions.removeAll() }

    public func apply(_ m: SignalMessage, at now: Date) {
        if m.event == "SessionEnd" {
            sessions[m.session] = nil
            return
        }
        var s = sessions[m.session] ?? Session(lastEventAt: now)
        s.lastEventAt = now
        let id = m.toolUseID ?? Self.unknownID
        switch m.event {
        case "UserPromptSubmit":
            s.phase = .active; s.running = []; s.waitingOn = []
        case "PreToolUse":
            // Claude moving on to a new tool means any earlier prompt was answered (or denied).
            s.phase = .active; s.waitingOn = []
            if let tool = m.tool, Self.userBlockingTools.contains(tool) { s.waitingOn.insert(id) } else { s.running.insert(id) }
        case "PostToolUse", "PostToolUseFailure":
            if m.toolUseID == nil {
                s.running = []; s.waitingOn = []
            } else {
                s.running.remove(id); s.waitingOn.remove(id); s.waitingOn.remove(Self.unknownID)
            }
        case "PermissionRequest":
            s.phase = .active; s.waitingOn.insert(id)
        case "Notification":
            guard let type = m.notificationType else { break }
            if Self.waitingNotifications.contains(type) {
                s.phase = .active; s.waitingOn.insert(Self.unknownID)
            } else if type == "idle_prompt", s.waitingOn.isEmpty {
                s.phase = .idle; s.running = []
            }
        case "Stop":
            s.phase = .done; s.doneAt = now; s.running = []; s.waitingOn = []
        case "StopFailure":
            s.phase = .idle; s.running = []; s.waitingOn = []
        default:
            break   // SessionStart (incl. source=compact) and unknown events only refresh lastEventAt
        }
        sessions[m.session] = s
    }

    public func state(at now: Date) -> ClaudeState {
        sessions.values.map { effectiveState($0, at: now) }.max() ?? .idle
    }

    func effectiveState(_ s: Session, at now: Date) -> ClaudeState {
        let quiet = now.timeIntervalSince(s.lastEventAt)
        switch s.rawState {
        case .thinking, .tool: return quiet >= config.staleTimeout ? .idle : s.rawState
        case .waiting: return quiet >= config.waitingTimeout ? .idle : .waiting
        case .done: return now.timeIntervalSince(s.doneAt ?? s.lastEventAt) >= config.doneDuration ? .idle : .done
        case .idle: return .idle
        }
    }
}
