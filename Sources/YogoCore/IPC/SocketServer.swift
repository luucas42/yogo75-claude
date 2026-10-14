import Darwin
import Foundation

/// Accepts one-line requests on a Unix socket and hands them to `handler` on `handlerQueue`.
public final class SocketServer {
    public enum ServerError: Error, Equatable {
        case alreadyRunning
        case system(String, Int32)
    }

    public typealias Handler = (Data) -> Data?

    private let path: String
    private let handler: Handler
    private let handlerQueue: DispatchQueue
    private let ioQueue = DispatchQueue(label: "yogo.socket.io")
    private var listenFD: Int32 = -1
    private var source: DispatchSourceRead?

    public init(path: String, handlerQueue: DispatchQueue = .main, handler: @escaping Handler) {
        self.path = path
        self.handlerQueue = handlerQueue
        self.handler = handler
    }

    public func start() throws {
        // Spec §11: never take the socket (and with it the keyboard) from a live instance.
        if UnixSocket.isListening(path: path) { throw ServerError.alreadyRunning }
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var addr = try UnixSocket.address(path)
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ServerError.system("socket", errno) }
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard rc == 0 else {
            let e = errno
            close(fd)
            throw ServerError.system("bind", e)
        }
        chmod(path, 0o600)
        guard listen(fd, 16) == 0 else {
            let e = errno
            close(fd)
            throw ServerError.system("listen", e)
        }
        listenFD = fd
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: ioQueue)
        src.setEventHandler { [weak self] in self?.acceptOne() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func acceptOne() {
        let client = accept(listenFD, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }
        UnixSocket.setTimeouts(client, 1)
        guard let line = try? UnixSocket.readLine(client), !line.isEmpty else { return }
        let reply = handlerQueue.sync { handler(line) }
        if let reply { try? UnixSocket.writeAll(client, reply + Data([0x0A])) }
    }

    public func stop() {
        guard let src = source else { return }
        source = nil
        src.cancel()
        unlink(path)
    }

    deinit { stop() }
}
