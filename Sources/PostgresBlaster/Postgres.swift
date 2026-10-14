import Foundation
import QueryBlaster

#if canImport(Network)
import Network
#elseif canImport(Glibc)
import Glibc
#endif

enum PostgresError: Error, CustomStringConvertible {
    case connection(String)
    case protocolError(String)
    case server(String)

    var description: String {
        switch self {
        case .connection(let value): "Postgres connection: \(value)"
        case .protocolError(let value): "Postgres protocol: \(value)"
        case .server(let value): "Postgres server: \(value)"
        }
    }
}

public struct PostgresNotification: Sendable, Equatable {
    public let channel: String
    public let payload: String
    public let backendPID: Int32

    public init(channel: String, payload: String, backendPID: Int32) {
        self.channel = channel
        self.payload = payload
        self.backendPID = backendPID
    }
}

public actor PostgresClient {
    public struct Configuration: Sendable {
        var host: String
        var port: UInt16
        var user: String
        var database: String

        public init(host: String, port: UInt16, user: String, database: String) {
            self.host = host
            self.port = port
            self.user = user
            self.database = database
        }

        public static func environment() -> Self {
            let env = ProcessInfo.processInfo.environment
            return .init(
                host: env["PGHOST"] ?? "127.0.0.1",
                port: UInt16(env["PGPORT"] ?? "5432") ?? 5432,
                user: env["PGUSER"] ?? "earthquake",
                database: env["PGDATABASE"] ?? "earthquakes"
            )
        }
    }

    private let configuration: Configuration
    public init(configuration: Configuration = .environment()) { self.configuration = configuration }

    public func query(_ sql: String) async throws -> [[String?]] {
        let transport = try await PGTransport.connect(configuration)
        defer { transport.cancel() }
        try await transport.startup(configuration)
        return try await transport.simpleQuery(sql)
    }

    public func query(_ sql: String, bindings: [QueryValue]) async throws -> [[String?]] {
        let transport = try await PGTransport.connect(configuration)
        defer { transport.cancel() }
        try await transport.startup(configuration)
        return try await transport.extendedQuery(sql, bindings: bindings).rows
    }

    public func execute(_ sql: String, bindings: [QueryValue]) async throws -> Int {
        let transport = try await PGTransport.connect(configuration)
        defer { transport.cancel() }
        try await transport.startup(configuration)
        return try await transport.extendedQuery(sql, bindings: bindings).affectedRows
    }

    public nonisolated func notifications(channel: String) -> AsyncThrowingStream<PostgresNotification, Error> {
        let configuration = self.configuration
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard Self.isSafeChannel(channel) else {
                        throw PostgresError.protocolError("invalid LISTEN channel")
                    }
                    let transport = try await PGTransport.connect(configuration)
                    defer { transport.cancel() }
                    try await transport.startup(configuration)
                    _ = try await transport.simpleQuery("LISTEN \(channel)")
                    try await withTaskCancellationHandler {
                        while !Task.isCancelled {
                            let notification = try await transport.nextNotification()
                            continuation.yield(notification)
                        }
                    } onCancel: {
                        transport.cancel()
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    if Task.isCancelled { continuation.finish() } else { continuation.finish(throwing: error) }
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private nonisolated static func isSafeChannel(_ channel: String) -> Bool {
        guard let first = channel.unicodeScalars.first,
            CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first)
        else { return false }
        return channel.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0)
        }
    }
}

#if canImport(Network)
private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = true

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isOpen else { return false }
        isOpen = false
        return true
    }
}

private final class PGTransport: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "EarthquakesServer.Postgres")
    private var buffer = Data()

    private init(connection: NWConnection) { self.connection = connection }

    static func connect(_ configuration: PostgresClient.Configuration) async throws -> PGTransport {
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw PostgresError.connection("invalid port")
        }
        let transport = PGTransport(
            connection: NWConnection(host: NWEndpoint.Host(configuration.host), port: port, using: .tcp)
        )
        transport.connection.start(queue: transport.queue)
        try await transport.waitUntilReady()
        return transport
    }

    func cancel() { connection.cancel() }

    func startup(_ configuration: PostgresClient.Configuration) async throws {
        var body = Data()
        body.appendInt32(196608)  // Protocol 3.0
        body.appendCString("user")
        body.appendCString(configuration.user)
        body.appendCString("database")
        body.appendCString(configuration.database)
        body.appendCString("application_name")
        body.appendCString("earthquake-server")
        body.append(0)
        var packet = Data()
        packet.appendInt32(Int32(body.count + 4))
        packet.append(body)
        try await send(packet)

        while true {
            let message = try await nextMessage()
            switch message.type {
            case UInt8(ascii: "R"):
                guard message.payload.readInt32(at: 0) == 0 else {
                    throw PostgresError.protocolError("Postgres trust authentication required")
                }
            case UInt8(ascii: "E"): throw PostgresError.server(message.payload.errorText)
            case UInt8(ascii: "Z"): return
            default: continue
            }
        }
    }

    func simpleQuery(_ sql: String) async throws -> [[String?]] {
        var payload = Data(sql.utf8)
        payload.append(0)
        var packet = Data([UInt8(ascii: "Q")])
        packet.appendInt32(Int32(payload.count + 4))
        packet.append(payload)
        try await send(packet)

        var rows: [[String?]] = []
        while true {
            let message = try await nextMessage()
            switch message.type {
            case UInt8(ascii: "D"): rows.append(try message.payload.dataRow())
            case UInt8(ascii: "E"): throw PostgresError.server(message.payload.errorText)
            case UInt8(ascii: "Z"): return rows
            default: continue
            }
        }
    }

    func nextNotification() async throws -> PostgresNotification {
        while true {
            let message = try await nextMessage()
            switch message.type {
            case UInt8(ascii: "A"):
                return try message.payload.notification()
            case UInt8(ascii: "E"):
                throw PostgresError.server(message.payload.errorText)
            default:
                continue
            }
        }
    }

    func extendedQuery(_ sql: String, bindings: [QueryValue]) async throws -> (rows: [[String?]], affectedRows: Int) {
        var parse = Data()
        parse.appendCString("")
        parse.appendCString(sql)
        parse.appendInt16(0)
        try await sendMessage(type: UInt8(ascii: "P"), payload: parse)

        var bind = Data()
        bind.appendCString("")
        bind.appendCString("")
        bind.appendInt16(0)
        bind.appendInt16(Int16(bindings.count))
        for value in bindings {
            let data = Data(value.postgresText.utf8)
            bind.appendInt32(Int32(data.count))
            bind.append(data)
        }
        bind.appendInt16(0)
        try await sendMessage(type: UInt8(ascii: "B"), payload: bind)

        var describe = Data([UInt8(ascii: "P")])
        describe.appendCString("")
        try await sendMessage(type: UInt8(ascii: "D"), payload: describe)
        var execute = Data()
        execute.appendCString("")
        execute.appendInt32(0)
        try await sendMessage(type: UInt8(ascii: "E"), payload: execute)
        try await sendMessage(type: UInt8(ascii: "S"), payload: Data())

        var rows: [[String?]] = []
        var affectedRows = 0
        while true {
            let message = try await nextMessage()
            switch message.type {
            case UInt8(ascii: "D"): rows.append(try message.payload.dataRow())
            case UInt8(ascii: "C"):
                affectedRows = message.payload.commandAffectedRows
            case UInt8(ascii: "E"): throw PostgresError.server(message.payload.errorText)
            case UInt8(ascii: "Z"): return (rows, affectedRows)
            default: continue
            }
        }
    }

    private func sendMessage(type: UInt8, payload: Data) async throws {
        var packet = Data([type])
        packet.appendInt32(Int32(payload.count + 4))
        packet.append(payload)
        try await send(packet)
    }

    private func waitUntilReady() async throws {
        let gate = ContinuationGate()
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard gate.take() else { return }
                    continuation.resume(returning: ())
                case .failed(let error):
                    guard gate.take() else { return }
                    continuation.resume(throwing: error)
                case .cancelled:
                    guard gate.take() else { return }
                    continuation.resume(throwing: PostgresError.connection("cancelled"))
                default:
                    break
                }
            }
        }
    }

    private func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            )
        }
    }

    private func nextMessage() async throws -> (type: UInt8, payload: Data) {
        while true {
            if buffer.count >= 5 {
                let length = Int(buffer.readInt32(at: 1))
                let total = 1 + length
                if buffer.count >= total {
                    let type = buffer[buffer.startIndex]
                    let payload = buffer.subdata(in: 5..<total)
                    buffer.removeSubrange(0..<total)
                    return (type, payload)
                }
            }
            let chunk = try await receive()
            guard !chunk.isEmpty else { throw PostgresError.connection("unexpected EOF") }
            buffer.append(chunk)
        }
    }

    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, complete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else if complete {
                    continuation.resume(returning: Data())
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
}

#elseif canImport(Glibc)
private final class PGTransport: @unchecked Sendable {
    private let fd: Int32
    private var buffer = Data()
    private init(fd: Int32) { self.fd = fd }

    static func connect(_ configuration: PostgresClient.Configuration) async throws -> PGTransport {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_UNSPEC,
            ai_socktype: Int32(SOCK_STREAM.rawValue),
            ai_protocol: Int32(IPPROTO_TCP),
            ai_addrlen: 0,
            ai_addr: nil,
            ai_canonname: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let service = String(configuration.port)
        guard getaddrinfo(configuration.host, service, &hints, &result) == 0 else {
            throw PostgresError.connection("getaddrinfo failed")
        }
        defer { if let result { freeaddrinfo(result) } }
        var cursor = result
        while let info = cursor?.pointee {
            let socketFD = socket(info.ai_family, info.ai_socktype, info.ai_protocol)
            if socketFD >= 0 {
                if Glibc.connect(socketFD, info.ai_addr, info.ai_addrlen) == 0 { return PGTransport(fd: socketFD) }
                _ = Glibc.close(socketFD)
            }
            cursor = info.ai_next
        }
        throw PostgresError.connection("connect failed")
    }

    func cancel() { _ = Glibc.close(fd) }
    func startup(_ configuration: PostgresClient.Configuration) async throws {
        var body = Data()
        body.appendInt32(196608)
        body.appendCString("user")
        body.appendCString(configuration.user)
        body.appendCString("database")
        body.appendCString(configuration.database)
        body.appendCString("application_name")
        body.appendCString("facet-feed-server")
        body.append(0)
        var packet = Data()
        packet.appendInt32(Int32(body.count + 4))
        packet.append(body)
        try send(packet)
        while true {
            let m = try nextMessage()
            switch m.type {
            case UInt8(ascii: "R"):
                guard m.payload.readInt32(at: 0) == 0 else {
                    throw PostgresError.protocolError("Postgre trust authentication required")
                }
            case UInt8(ascii: "E"): throw PostgresError.server(m.payload.errorText)
            case UInt8(ascii: "Z"): return
            default: continue
            }
        }
    }
    func simpleQuery(_ sql: String) async throws -> [[String?]] {
        var payload = Data(sql.utf8)
        payload.append(0)
        var packet = Data([UInt8(ascii: "Q")])
        packet.appendInt32(Int32(payload.count + 4))
        packet.append(payload)
        try send(packet)
        var rows: [[String?]] = []
        while true {
            let m = try nextMessage()
            switch m.type {
            case UInt8(ascii: "D"): rows.append(try m.payload.dataRow())
            case UInt8(ascii: "E"): throw PostgresError.server(m.payload.errorText)
            case UInt8(ascii: "Z"): return rows
            default: continue
            }
        }
    }
    func nextNotification() async throws -> PostgresNotification {
        while true {
            let message = try nextMessage()
            switch message.type {
            case UInt8(ascii: "A"): return try message.payload.notification()
            case UInt8(ascii: "E"): throw PostgresError.server(message.payload.errorText)
            default: continue
            }
        }
    }
    func extendedQuery(_ sql: String, bindings: [QueryValue]) async throws -> (rows: [[String?]], affectedRows: Int) {
        var parse = Data()
        parse.appendCString("")
        parse.appendCString(sql)
        parse.appendInt16(0)
        try sendMessage(type: UInt8(ascii: "P"), payload: parse)
        var bind = Data()
        bind.appendCString("")
        bind.appendCString("")
        bind.appendInt16(0)
        bind.appendInt16(Int16(bindings.count))
        for value in bindings {
            let data = Data(value.postgresText.utf8)
            bind.appendInt32(Int32(data.count))
            bind.append(data)
        }
        bind.appendInt16(0)
        try sendMessage(type: UInt8(ascii: "B"), payload: bind)
        var describe = Data([UInt8(ascii: "P")])
        describe.appendCString("")
        try sendMessage(type: UInt8(ascii: "D"), payload: describe)
        var execute = Data()
        execute.appendCString("")
        execute.appendInt32(0)
        try sendMessage(type: UInt8(ascii: "E"), payload: execute)
        try sendMessage(type: UInt8(ascii: "S"), payload: Data())
        var rows: [[String?]] = []
        var affected = 0
        while true {
            let m = try nextMessage()
            switch m.type {
            case UInt8(ascii: "D"): rows.append(try m.payload.dataRow())
            case UInt8(ascii: "C"): affected = m.payload.commandAffectedRows
            case UInt8(ascii: "E"): throw PostgresError.server(m.payload.errorText)
            case UInt8(ascii: "Z"): return (rows, affected)
            default: continue
            }
        }
    }
    private func sendMessage(type: UInt8, payload: Data) throws {
        var packet = Data([type])
        packet.appendInt32(Int32(payload.count + 4))
        packet.append(payload)
        try send(packet)
    }
    private func send(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let n = Glibc.send(fd, raw.baseAddress!.advanced(by: sent), raw.count - sent, 0)
                guard n > 0 else { throw PostgresError.connection("send failed") }
                sent += n
            }
        }
    }
    private func nextMessage() throws -> (type: UInt8, payload: Data) {
        while true {
            if buffer.count >= 5 {
                let length = Int(buffer.readInt32(at: 1))
                let total = 1 + length
                if buffer.count >= total {
                    let type = buffer[buffer.startIndex]
                    let payload = buffer.subdata(in: 5..<total)
                    buffer.removeSubrange(0..<total)
                    return (type, payload)
                }
            }
            var bytes = [UInt8](repeating: 0, count: 65536)
            let n = Glibc.recv(fd, &bytes, bytes.count, 0)
            guard n > 0 else { throw PostgresError.connection("unexpected EOF") }
            buffer.append(contentsOf: bytes.prefix(n))
        }
    }
}
#endif
private extension QueryValue {
    var postgresText: String {
        switch self {
        case .null: ""
        case .text(let value): value
        case .integer(let value): String(value)
        case .number(let value): String(value)
        case .date(let value): ISO8601DateFormatter().string(from: value)
        case .boolean(let value): value ? "true" : "false"
        }
    }
}

private extension Data {
    mutating func appendInt16(_ value: Int16) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { append(contentsOf: $0) }
    }
    mutating func appendInt32(_ value: Int32) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { append(contentsOf: $0) }
    }
    mutating func appendCString(_ string: String) {
        append(contentsOf: string.utf8)
        append(0)
    }
    func readInt16(at offset: Int) -> Int16 {
        let bytes = self[offset..<(offset + 2)]
        return bytes.reduce(Int16(0)) { ($0 << 8) | Int16($1) }
    }
    func readInt32(at offset: Int) -> Int32 {
        let bytes = self[offset..<(offset + 4)]
        return bytes.reduce(Int32(0)) { ($0 << 8) | Int32($1) }
    }
    func dataRow() throws -> [String?] {
        var offset = 0
        let count = Int(readInt16(at: offset))
        offset += 2
        var values: [String?] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            let length = Int(readInt32(at: offset))
            offset += 4
            if length == -1 {
                values.append(nil)
                continue
            }
            guard length >= 0, offset + length <= self.count else {
                throw PostgresError.protocolError("malformed dataRow")
            }
            values.append(String(data: subdata(in: offset..<(offset + length)), encoding: .utf8))
            offset += length
        }
        return values
    }
    func notification() throws -> PostgresNotification {
        guard count >= 6 else { throw PostgresError.protocolError("malformed notification") }
        let pid = readInt32(at: 0)
        var offset = 4
        func readCString() throws -> String {
            let start = offset
            while offset < count, self[offset] != 0 { offset += 1 }
            guard offset < count, let value = String(data: subdata(in: start..<offset), encoding: .utf8) else {
                throw PostgresError.protocolError("malformed notification string")
            }
            offset += 1
            return value
        }
        let channel = try readCString()
        let payload = try readCString()
        return PostgresNotification(channel: channel, payload: payload, backendPID: pid)
    }
    var errorText: String {
        var offset = 0
        var fields: [String] = []
        while offset < count, self[offset] != 0 {
            offset += 1
            let start = offset
            while offset < count, self[offset] != 0 { offset += 1 }
            if offset > start, let text = String(data: subdata(in: start..<offset), encoding: .utf8) {
                fields.append(text)
            }
            offset += 1
        }
        return fields.joined(separator: ": ")
    }
}

private extension Data {
    var commandAffectedRows: Int {
        let bytes = prefix { $0 != 0 }
        guard let tag = String(data: bytes, encoding: .utf8),
            let last = tag.split(separator: " ").last,
            let count = Int(last)
        else { return 0 }
        return count
    }
}
