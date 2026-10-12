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

@inline(__always) func out(_ s: String) {
    let data = Data((s + "\n").utf8)
    do {
        try FileHandle.standardOutput.write(contentsOf: data)
    } catch {
    }
}
func fail(_ what: String) -> Never {
    out("ERROR \(what) errno=\(errno) \(String(cString: strerror(errno)))")
    exit(1)
}
func json(_ object: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
}

var live: WhaleySceneSnapshot?

let port = UInt16(ProcessInfo.processInfo.environment["WHALEY_RELAY_PORT"] ?? "8092") ?? 8092

let server = socket(AF_INET, streamSocketType, 0)
guard server >= 0 else { fail("socket()") }
var yes: Int32 = 1
_ = withUnsafePointer(to: &yes) {
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
}
var addr = sockaddr_in()
addr.sin_family = sa_family_t(AF_INET)
addr.sin_port = port.bigEndian
addr.sin_addr = in_addr(s_addr: INADDR_ANY)
let bound = withUnsafePointer(to: &addr) { p in
    p.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(server, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
}
guard bound == 0 else { fail("bind(0.0.0.0:\(port))") }
guard listen(server, 32) == 0 else { fail("listen()") }
out("START listening 0.0.0.0:\(port)")

signal(SIGINT) { _ in
    let message = "SIGNAL SIGINT -> EXIT\n"
    message.withCString { pointer in _ = write(STDOUT_FILENO, pointer, strlen(pointer)) }
    _exit(130)
}
signal(SIGTERM) { _ in
    let message = "SIGNAL SIGTERM -> EXIT\n"
    message.withCString { pointer in _ = write(STDOUT_FILENO, pointer, strlen(pointer)) }
    _exit(143)
}

func sendResponse(_ fd: Int32, status: Int, object: Any, client: String) {
    let body = json(object)
    let reason = status == 200 ? "OK" : status == 409 ? "Conflict" : status == 400 ? "Bad Request" : "Not Found"
    let header = """
        HTTP/1.1 \(status) \(reason)\r
        Content-Type: application/json\r
        Content-Length: \(body.count)\r
        Connection: close\r
        \r\n
        """
    let packet = Data(header.utf8) + body
    let result = packet.withUnsafeBytes { raw in send(fd, raw.baseAddress, raw.count, 0) }
    if result < 0 {
        out("ERROR send client=\(client) errno=\(errno) \(String(cString: strerror(errno)))")
    } else {
        out("SENT -> \(client) bytes=\(result) status=\(status) body=\(String(decoding: body, as: UTF8.self))")
    }
}

while true {
    out("WAITING accept()")
    var peer = sockaddr_in()
    var peerLen = socklen_t(MemoryLayout<sockaddr_in>.size)
    let fd = withUnsafeMutablePointer(to: &peer) { p in
        p.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(server, $0, &peerLen) }
    }
    if fd < 0 {
        out("ERROR accept() errno=\(errno) \(String(cString: strerror(errno)))")
        continue
    }
    out("ACCEPTED fd=\(fd)")
    var buffer = [UInt8](repeating: 0, count: 16384)
    let count = recv(fd, &buffer, buffer.count, 0)
    guard count > 0 else {
        out(
            count == 0
                ? "RECEIVED EOF fd=\(fd)" : "ERROR recv fd=\(fd) errno=\(errno) \(String(cString: strerror(errno)))"
        )
        close(fd)
        out("CLOSED fd=\(fd)")
        continue
    }
    let request = String(decoding: buffer[0..<count], as: UTF8.self)
    out("RECEIVED bytes=\(count)\n\(request)")
    let parts = request.components(separatedBy: "\r\n\r\n")
    let head = parts.first ?? ""
    let body = parts.dropFirst().joined(separator: "\r\n\r\n")
    let lines = head.components(separatedBy: "\r\n")
    let first = lines.first?.split(separator: " ").map(String.init) ?? []
    let method = first.first ?? ""
    let path = first.count > 1 ? first[1] : ""
    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
        if let i = line.firstIndex(of: ":") {
            headers[String(line[..<i]).lowercased()] = String(line[line.index(after: i)...])
                .trimmingCharacters(in: .whitespaces)
        }
    }
    let client = headers["x-whaley-client"] ?? "unknown"
    out("PARSED client=\(client) method=\(method) path=\(path) body=\(body.isEmpty ? "<empty>" : body)")
    if method == "POST" && path == "/state" {
        if let data = body.data(using: .utf8),
            let incoming = try? JSONDecoder().decode(WhaleySceneSnapshot.self, from: data)
        {
            let session = live?.session ?? String(UUID().uuidString.prefix(8))
            let sequence = (live?.sequence ?? 0) + 1
            live = WhaleySceneSnapshot(
                sequence: sequence,
                session: session,
                level: incoming.level,
                gameTime: incoming.gameTime,
                dead: incoming.dead,
                player: incoming.player,
                elements: incoming.elements
            )
            if sequence % 50 == 1 { out("STATE CHANGED seq=\(sequence) level=\(incoming.level) session=\(session)") }
            sendResponse(fd, status: 200, object: ["ok": true, "session": session], client: client)
        } else {
            sendResponse(fd, status: 400, object: ["error": "invalid scene snapshot"], client: client)
        }
    } else if method == "GET" && path == "/hello" {
        out("HELLO client=\(client)")
        sendResponse(fd, status: 200, object: ["ok": true, "client": client], client: client)
    } else if method == "GET" && path == "/state" {
        if let s = live, let payload = try? JSONEncoder().encode(s),
            let object = try? JSONSerialization.jsonObject(with: payload)
        {
            sendResponse(fd, status: 200, object: object, client: client)
        } else {
            sendResponse(fd, status: 409, object: ["status": "waiting-for-mobile"], client: client)
        }
    } else {
        sendResponse(fd, status: 404, object: ["error": "not found"], client: client)
    }
    close(fd)
    out("CLOSED fd=\(fd)")
}
