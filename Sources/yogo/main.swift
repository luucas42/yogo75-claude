import Darwin
import Foundation
import YogoCore

let args = Array(CommandLine.arguments.dropFirst())
let timeout: TimeInterval = 0.3

@discardableResult
func send(_ req: IPCRequest, expectReply: Bool) -> (ok: Bool, reply: Data?) {
    guard let line = try? JSONEncoder().encode(req) else { return (false, nil) }
    do {
        return (true, try UnixSocket.request(path: YogoPaths.socket, line: line, expectReply: expectReply, timeout: timeout))
    } catch {
        return (false, nil)
    }
}

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func usage() -> Never {
    fail("""
    kullanım:
      yogo hook                                         Claude Code hook'u (JSON'u stdin'den okur)
      yogo simulate <thinking|tool|waiting|done|idle> [--session ID]
      yogo status
    """, code: 64)
}

switch args.first ?? "" {
case "hook":
    // Spec §4: never print, never fail, never block Claude Code. The alarm is a last-resort guard.
    signal(SIGALRM) { _ in _exit(0) }
    alarm(2)
    let input = FileHandle.standardInput.readDataToEndOfFile()
    if let message = SignalMessage.fromHookPayload(input) {
        send(.forSignal(message), expectReply: false)
    }
    exit(0)

case "simulate":
    guard args.count >= 2, let state = ClaudeState(rawValue: args[1]) else { usage() }
    var session = "simulate"
    if let i = args.firstIndex(of: "--session"), i + 1 < args.count { session = args[i + 1] }
    for message in SignalMessage.simulate(state, session: session) {
        guard send(.forSignal(message), expectReply: false).ok else {
            fail("Yogo çalışmıyor (socket: \(YogoPaths.socket))", code: 1)
        }
    }
    print("→ \(state.rawValue) (oturum: \(session))")

case "status":
    let r = send(.status, expectReply: true)
    guard r.ok, let data = r.reply, let status = try? JSONDecoder().decode(StatusReply.self, from: data) else {
        fail("Yogo çalışmıyor", code: 1)
    }
    print("bağlantı: \(status.connection)")
    print("claude:   \(status.state.rawValue)")
    print("oturum:   \(status.sessions)")

default:
    usage()
}
