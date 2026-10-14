import Foundation

public struct IPCRequest: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case signal, status }

    public var kind: Kind
    public var signal: SignalMessage?

    public static func forSignal(_ m: SignalMessage) -> IPCRequest { IPCRequest(kind: .signal, signal: m) }
    public static let status = IPCRequest(kind: .status, signal: nil)
}

public struct StatusReply: Codable, Equatable, Sendable {
    public var connection: String
    public var state: ClaudeState
    public var sessions: Int

    public init(connection: String, state: ClaudeState, sessions: Int) {
        self.connection = connection
        self.state = state
        self.sessions = sessions
    }
}

public enum IPCDispatch {
    /// Decodes one request line. Signals produce no reply; status returns one JSON line.
    public static func handle(_ line: Data, onSignal: (SignalMessage) -> Void, status: () -> StatusReply) -> Data? {
        guard let req = try? JSONDecoder().decode(IPCRequest.self, from: line) else { return nil }
        switch req.kind {
        case .signal:
            if let m = req.signal { onSignal(m) }
            return nil
        case .status:
            return try? JSONEncoder().encode(status())
        }
    }
}
