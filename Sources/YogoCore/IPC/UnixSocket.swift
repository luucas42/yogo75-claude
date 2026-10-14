import Darwin
import Foundation

/// Minimal AF_UNIX stream helpers: one JSON line per connection.
public enum UnixSocket {
    public enum SocketError: Error, Equatable {
        case pathTooLong
        case system(String, Int32)
    }

    static func address(_ path: String) throws -> sockaddr_un {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { throw SocketError.pathTooLong }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return addr
    }

    static func setTimeouts(_ fd: Int32, _ seconds: TimeInterval) {
        var tv = timeval(tv_sec: Int(seconds), tv_usec: Int32((seconds - seconds.rounded(.down)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    }

    static func connected(_ path: String, timeout: TimeInterval) throws -> Int32 {
        var addr = try address(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketError.system("socket", errno) }
        setTimeouts(fd, timeout)
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard rc == 0 else {
            let e = errno
            close(fd)
            throw SocketError.system("connect", e)
        }
        return fd
    }

    public static func isListening(path: String) -> Bool {
        guard let fd = try? connected(path, timeout: 0.3) else { return false }
        close(fd)
        return true
    }

    /// Connects, writes `line` + "\n", and optionally reads one reply line, all within `timeout`.
    public static func request(path: String, line: Data, expectReply: Bool, timeout: TimeInterval) throws -> Data? {
        let fd = try connected(path, timeout: timeout)
        defer { close(fd) }
        try writeAll(fd, line + Data([0x0A]))
        return expectReply ? try readLine(fd) : nil
    }

    static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            var off = 0
            while off < buf.count {
                let n = write(fd, buf.baseAddress! + off, buf.count - off)
                guard n > 0 else { throw SocketError.system("write", errno) }
                off += n
            }
        }
    }

    static func readLine(_ fd: Int32, limit: Int = 1 << 20) throws -> Data {
        var out = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while out.count < limit {
            let n = read(fd, &buf, buf.count)
            if n < 0 { throw SocketError.system("read", errno) }
            if n == 0 { break }
            out.append(contentsOf: buf[0..<n])
            if let nl = out.firstIndex(of: 0x0A) { return out.subdata(in: out.startIndex..<nl) }
        }
        return out
    }
}
