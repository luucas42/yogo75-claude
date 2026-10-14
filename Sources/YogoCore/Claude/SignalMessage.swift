import Foundation

/// One Claude Code hook event as forwarded by `yogo hook` (spec §4).
public struct SignalMessage: Codable, Equatable, Sendable {
    public var event: String
    public var session: String
    public var notificationType: String?
    public var tool: String?
    public var toolUseID: String?

    public init(event: String, session: String, notificationType: String? = nil,
                tool: String? = nil, toolUseID: String? = nil) {
        self.event = event
        self.session = session
        self.notificationType = notificationType
        self.tool = tool
        self.toolUseID = toolUseID
    }

    /// Parses Claude Code's hook stdin JSON. Returns nil for anything unusable; the caller must stay silent.
    /// No size cap: PostToolUse payloads can be large, and dropping one would leave a tool "running".
    public static func fromHookPayload(_ data: Data) -> SignalMessage? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let event = obj["hook_event_name"] as? String, !event.isEmpty,
              let session = obj["session_id"] as? String, !session.isEmpty
        else { return nil }
        return SignalMessage(event: event, session: session,
                             notificationType: obj["notification_type"] as? String,
                             tool: obj["tool_name"] as? String,
                             toolUseID: obj["tool_use_id"] as? String)
    }

    /// Synthetic events for `yogo simulate <state>`.
    public static func simulate(_ state: ClaudeState, session: String) -> [SignalMessage] {
        switch state {
        case .thinking: return [SignalMessage(event: "UserPromptSubmit", session: session)]
        case .tool: return [SignalMessage(event: "PreToolUse", session: session, tool: "Bash", toolUseID: "simulate")]
        case .waiting: return [SignalMessage(event: "PermissionRequest", session: session)]
        case .done: return [SignalMessage(event: "Stop", session: session)]
        case .idle: return [SignalMessage(event: "SessionEnd", session: session)]
        }
    }
}
