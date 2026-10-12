import Foundation
import WhaleyCore

#if os(Linux)
import Glibc
#else
import Darwin
#endif

#if os(Linux)
private let streamSocketType: Int32 = Int32(SOCK_STREAM.rawValue)
#else
private let streamSocketType: Int32 = SOCK_STREAM
#endif

enum WhaleyCLI {
    static func run() {
        var cameraSize = 9
        let relay = WhaleyRelayClient()
        relay.hello()
        let terminal = RawTerminal()
        defer {
            terminal.restore()
            writeTerminal("\u{001B}[?25h\r\n")
        }
        writeTerminal("\u{001B}[?25l")

        var running = true
        while running {
            let snapshot = relay.snapshot()
            render(
                snapshot: snapshot,
                size: cameraSize,
                relayConnected: relay.lastRequestSucceeded,
                sessionID: relay.sessionID,
                endpoint: relay.endpointDescription,
                error: relay.lastError
            )
            switch terminal.readKey(timeoutMilliseconds: 100) {
            case .up?: cameraSize = min(31, cameraSize + 2)
            case .down?: cameraSize = max(1, cameraSize - 2)
            case .quit?: running = false
            case .other?, nil: break
            }
        }
    }

    static func render(
        snapshot: LiveSnapshot?,
        size: Int,
        relayConnected: Bool,
        sessionID: String?,
        endpoint: String,
        error: String?
    ) {
        guard let snapshot else {
            let lines = [
                "Whaley: waiting for mobile game",
                "relay \(relayConnected ? "reachable" : "unreachable")   endpoint \(endpoint)",
                "error \(error ?? "none")",
                "No level data output until mobile game publishes live state",
                "↑ larger  ↓ smaller   q quit",
            ]
            writeTerminal("\u{001B}[2J\u{001B}[H" + lines.joined(separator: "\r\n"))
            return
        }
        var lines = [
            "Whaley: level \(snapshot.level)   camera \(size)×\(size)   mobile \(relayConnected ? "live" : "waiting")",
            "relay \(endpoint)   session \(sessionID ?? "none")   frame \(snapshot.sequence)",
            "time \(String(format: "%.1f", snapshot.gameTime))s   \(snapshot.dead ? "DEAD" : "alive")",
            "↑ larger  ↓ smaller   q quit",
        ]
        lines += WhaleyTerminalRenderer.lines(snapshot, size: size)
        lines.append("W Whaley  o bubble  $ coin  ^ flame  O goal  # wall  = ground")
        writeTerminal("\u{001B}[2J\u{001B}[H" + lines.joined(separator: "\r\n"))
    }

    static func writeTerminal(_ value: String) {
        FileHandle.standardOutput.write(Data(value.utf8))
    }
}

enum Key { case up, down, quit, other }

final class RawTerminal {
    private var original = termios(), active = false
    init() {
        guard isatty(STDIN_FILENO) == 1, tcgetattr(STDIN_FILENO, &original) == 0 else { return }
        var raw = original
        cfmakeraw(&raw)
        active = tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0
    }
    func restore() {
        if active {
            var value = original
            _ = tcsetattr(STDIN_FILENO, TCSANOW, &value)
        }
    }
    func readKey(timeoutMilliseconds: Int32) -> Key? {
        var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, timeoutMilliseconds) > 0, let first = byte() else { return nil }
        if first == 113 || first == 81 { return .quit }
        guard first == 27, byte() == 91, let third = byte() else { return .other }
        switch third {
        case 65: return .up
        case 66: return .down
        default: return .other
        }
    }
    private func byte() -> UInt8? {
        var value: UInt8 = 0
        return read(STDIN_FILENO, &value, 1) == 1 ? value : nil
    }
}

typealias LiveSnapshot = WhaleySceneSnapshot

final class WhaleyRelayClient {
    private let clientID = "cli-\(ProcessInfo.processInfo.processIdentifier)"
    private let host = ProcessInfo.processInfo.environment["WHALEY_RELAY_HOST"] ?? "127.0.0.1"
    private let port = UInt16(ProcessInfo.processInfo.environment["WHALEY_RELAY_PORT"] ?? "8092") ?? 8092
    private(set) var lastRequestSucceeded = false
    private(set) var sessionID: String?
    private(set) var lastError: String?
    var endpointDescription: String { "http://\(host):\(port)" }

    func hello() {
        _ = get(path: "/hello")
    }

    func snapshot() -> LiveSnapshot? {
        guard let data = get(path: "/state"),
            let snapshot = try? JSONDecoder().decode(WhaleySceneSnapshot.self, from: data)
        else { return nil }
        lastRequestSucceeded = true
        sessionID = snapshot.session
        return snapshot
    }

    private func get(path: String) -> Data? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = streamSocketType
        var result: UnsafeMutablePointer<addrinfo>?
        let resolution = getaddrinfo(host, String(port), &hints, &result)
        guard resolution == 0 else {
            lastError = "getaddrinfo \(host): \(String(cString: gai_strerror(resolution)))"
            return nil
        }
        defer { freeaddrinfo(result) }
        var cursor = result
        while let info = cursor?.pointee {
            let fd = socket(info.ai_family, info.ai_socktype, info.ai_protocol)
            if fd >= 0, connect(fd, info.ai_addr, info.ai_addrlen) == 0 {
                defer { close(fd) }
                let request = """
                    GET \(path) HTTP/1.1\r
                    Host: \(host)\r
                    X-Whaley-Client: CLI\r
                    X-Whaley-Client-ID: \(clientID)\r
                    Connection: close\r
                    \r\n
                    """
                _ = request.withCString { send(fd, $0, strlen($0), 0) }
                var bytes = Data()
                var buffer = [UInt8](repeating: 0, count: 2048)
                while true {
                    let n = recv(fd, &buffer, buffer.count, 0)
                    if n <= 0 { break }
                    bytes.append(contentsOf: buffer.prefix(n))
                }
                if let range = bytes.range(of: Data("\r\n\r\n".utf8)) {
                    lastError = nil
                    return Data(bytes[range.upperBound...])
                }
                lastError = "relay returned malformed HTTP response"
            } else if fd >= 0 {
                lastError = "connect \(host):\(port) failed errno=\(errno) \(String(cString: strerror(errno)))"
                close(fd)
            }
            cursor = info.ai_next
        }
        if lastError == nil { lastError = "no relay address accepted connection" }
        return nil
    }
}

WhaleyCLI.run()
