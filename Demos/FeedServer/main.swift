import Foundation
import PostgresBlaster
import QueryBlaster

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

struct Photo: Codable, Sendable {
    let id: String
    let city: String
    let country: String
    let place: String
    let capturedAt: String
    let photographer: String
    let title: String
    let imageURL: String
}

struct PhoneRequest: Decodable {
    let phone: String
}

struct VerifyRequest: Decodable {
    let phone: String
    let code: String
}

struct ChallengeResponse: Encodable {
    let userID: String
    let previewCode: String
}

struct SessionResponse: Codable {
    let userID: String
    let token: String
    let expiresAt: String
}

func ensureSchema(_ postgres: PostgresClient) async throws {
    _ = try await postgres.query("ALTER TABLE city_photos ADD COLUMN IF NOT EXISTS place text")
    _ = try await postgres.query("UPDATE city_photos SET place = city WHERE place IS NULL")
    _ = try await postgres.query(
        """
          CREATE TABLE IF NOT EXISTS app_users (id text PRIMARY KEY, phone text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now());
          CREATE TABLE IF NOT EXISTS auth_challenges (user_id text PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE, code text NOT NULL, expires_at timestamptz NOT NULL);
          CREATE TABLE IF NOT EXISTS auth_sessions (token text PRIMARY KEY, user_id text NOT NULL REFERENCES app_users(id) ON DELETE CASCADE, expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
          CREATE INDEX IF NOT EXISTS auth_sessions_user_id_idx ON auth_sessions(user_id)
        """
    )
}

func photos(target: String, postgres: PostgresClient) async throws -> [Photo] {
    let components = URLComponents(string: "http://localhost\(target)")
    let query = Dictionary(
        uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } }
    )
    var whereParts: [String] = []
    var bindings: [QueryValue] = []
    if let search = query["q"]?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
        bindings.append(.text("%\(search)%"))
        let parameter = "$\(bindings.count)"
        whereParts.append(
            "(city ILIKE \(parameter) OR country ILIKE \(parameter) OR place ILIKE \(parameter) OR photographer ILIKE \(parameter) OR title ILIKE \(parameter) OR image_url ILIKE \(parameter))"
        )
    }
    for (key, column) in [
        ("city", "city"), ("country", "country"), ("place", "place"), ("photographer", "photographer"),
    ] {
        if let value = query[key], !value.isEmpty {
            bindings.append(.text(value))
            whereParts.append("\(column) = $\(bindings.count)")
        }
    }
    let sql =
        #"SELECT id, city, country, COALESCE(place, city), to_char(captured_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), photographer, title, image_url FROM city_photos"#
        + (whereParts.isEmpty ? "" : " WHERE " + whereParts.joined(separator: " AND ")) + " ORDER BY captured_at DESC"
    return try await postgres.query(sql, bindings: bindings)
        .compactMap { row in
            guard
                row.count == 8,
                let id = row[0],
                let city = row[1],
                let country = row[2],
                let place = row[3],
                let at = row[4],
                let by = row[5],
                let title = row[6],
                let image = row[7]
            else {
                return nil
            }
            return Photo(
                id: id,
                city: city,
                country: country,
                place: place,
                capturedAt: at,
                photographer: by,
                title: title,
                imageURL: image
            )
        }
}

func requestCode(_ request: PhoneRequest, postgres: PostgresClient) async throws -> ChallengeResponse {
    let phone = request.phone.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !phone.isEmpty else {
        throw AuthError.invalidRequest
    }
    let id = UUID().uuidString.lowercased()
    let userRows = try await postgres.query(
        "INSERT INTO app_users(id, phone) VALUES ($1,$2) ON CONFLICT(phone) DO UPDATE SET phone=EXCLUDED.phone RETURNING id",
        bindings: [.text(id), .text(phone)]
    )
    guard let userID = userRows.first?.first ?? nil else {
        throw AuthError.invalidRequest
    }
    let code = String(format: "%06d", Int.random(in: 0...999_999))
    _ = try await postgres.execute(
        "INSERT INTO auth_challenges(user_id, code, expires_at) VALUES ($1,$2,now()+interval '10 minutes') ON CONFLICT(user_id) DO UPDATE SET code=EXCLUDED.code, expires_at=EXCLUDED.expires_at",
        bindings: [.text(userID), .text(code)]
    )
    return ChallengeResponse(userID: userID, previewCode: code)
}

func verify(_ request: VerifyRequest, postgres: PostgresClient) async throws -> SessionResponse {
    let rows = try await postgres.query(
        "SELECT u.id FROM app_users u JOIN auth_challenges c ON c.user_id=u.id WHERE u.phone=$1 AND c.code=$2 AND c.expires_at > now()",
        bindings: [.text(request.phone.trimmingCharacters(in: .whitespacesAndNewlines)), .text(request.code)]
    )
    guard
        let userID = rows.first?.first ?? nil
    else {
        throw AuthError.invalidCredentials
    }
    _ = try await postgres.execute("DELETE FROM auth_challenges WHERE user_id=$1", bindings: [.text(userID)])
    let token = UUID().uuidString.lowercased() + UUID().uuidString.lowercased()
    let sessionRows = try await postgres.query(
        "INSERT INTO auth_sessions(token,user_id,expires_at) VALUES ($1,$2,now()+interval '30 days') RETURNING to_char(expires_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')",
        bindings: [.text(token), .text(userID)]
    )
    guard
        let expiresAt = sessionRows.first?.first ?? nil
    else {
        throw AuthError.invalidCredentials
    }
    return SessionResponse(userID: userID, token: token, expiresAt: expiresAt)
}

func restoreSession(token: String, postgres: PostgresClient) async throws -> SessionResponse {
    let rows = try await postgres.query(
        "SELECT user_id,to_char(expires_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM auth_sessions WHERE token=$1 AND expires_at > now()",
        bindings: [.text(token)]
    )
    guard
        let row = rows.first,
        row.count == 2,
        let userID = row[0],
        let expires = row[1]
    else {
        throw AuthError.invalidCredentials
    }
    return SessionResponse(userID: userID, token: token, expiresAt: expires)
}

enum AuthError: Error { case invalidRequest, invalidCredentials }

struct HTTPRequest {
    let method: String
    let target: String
    let headers: [String: String]
    let body: Data

    init?(_ data: Data) {
        guard
            let marker = data.range(of: Data("\r\n\r\n".utf8)),
            let head = String(data: data[..<marker.lowerBound], encoding: .utf8)
        else {
            return nil
        }
        let lines = head.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        method = String(parts[0])
        target = String(parts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let i = line.firstIndex(of: ":") {
                headers[String(line[..<i]).lowercased()] = String(line[line.index(after: i)...])
                    .trimmingCharacters(
                        in: .whitespaces
                    )
            }
        }
        self.headers = headers
        body = Data(data[marker.upperBound...])
    }
}

func receiveHTTPRequest(_ socket: Int32) -> HTTPRequest? {
    let separator = Data("\r\n\r\n".utf8)
    var data = Data()
    var expectedTotal: Int?
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while data.count < (expectedTotal ?? Int.max) {
        let count = recv(socket, &buffer, buffer.count, 0)
        guard count > 0 else { break }
        data.append(contentsOf: buffer.prefix(count))
        if expectedTotal == nil,
            let marker = data.range(of: separator),
            let head = String(data: data[..<marker.lowerBound], encoding: .utf8)
        {
            let contentLength =
                head.components(separatedBy: "\r\n")
                .dropFirst()
                .compactMap { line -> Int? in
                    guard
                        let colon = line.firstIndex(of: ":"),
                        line[..<colon].lowercased() == "content-length"
                    else {
                        return nil
                    }
                    return Int(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
                }
                .first ?? 0
            expectedTotal = marker.upperBound + contentLength
        }
        if let expectedTotal, data.count >= expectedTotal { break }
        if data.count > 1_048_576 {
            return nil
        }
    }
    guard let expectedTotal, data.count >= expectedTotal else { return nil }
    return HTTPRequest(Data(data.prefix(expectedTotal)))
}

func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(
            of: ">",
            with: "&gt;"
        )
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func html(_ photos: [Photo]) -> String {
    let cards =
        photos.map {
            """
            <article>
                <img src="\(esc($0.imageURL))" alt="">
                <div>
                    <h3>\(esc($0.title))</h3>
                    <p>\(esc($0.place)) · \(esc($0.photographer))</p>
                </div>
            </article>
            """
        }
        .joined()
    let status = photos.isEmpty ? "No photographs found" : "\(photos.count) photograph(s) found"
    return """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Photos</title>
        </head>
        <body>
            <main>
                <h1>Photos</h1>
                <p>From the Postgres</p>

                <form role="search">
                    <label for="photo-query">Search</label>
                    <input
                        id="photo-query"
                        name="q"
                        type="search"
                        placeholder="Place, country, photographer, or caption"
                    >
                    <button type="submit">Search</button>
                </form>

                <h2>Results</h2>
                <p role="status">\(status)</p>

                <section aria-label="Results">
                    \(cards)
                </section>
            </main>
        </body>
        </html>
        """
}

func response(status: String = "200 OK", type: String = "application/json", body: String) -> String {
    """
    HTTP/1.1 \(status)\r
    Content-Type: \(type)\r
    Content-Length: \(body.utf8.count)\r
    Connection: close\r
    \r
    \(body)
    """
}
func json<T: Encodable>(_ value: T) throws -> String { String(data: try JSONEncoder().encode(value), encoding: .utf8)! }

@main enum PhotoFeedServer {
    static func main() async throws {
        let postgres = PostgresClient()
        try await ensureSchema(postgres)
        let port = UInt16(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
        let server = socket(AF_INET, streamSocketType, 0)
        guard server >= 0 else { fatalError("socket") }
        var yes: Int32 = 1
        setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(server, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard
            bound == 0,
            listen(server, 32) == 0
        else {
            fatalError()
        }
        print("Feed + auth listening on \(port)")
        while true {
            let client = accept(server, nil, nil)
            if client < 0 { continue }
            guard let req = receiveHTTPRequest(client) else {
                close(client)
                continue
            }
            do {
                let body: String
                let type: String
                switch (req.method, req.target.split(separator: "?").first.map(String.init) ?? req.target) {
                case ("POST", "/api/auth/request-code"):
                    body = try json(
                        try await requestCode(
                            JSONDecoder().decode(PhoneRequest.self, from: req.body),
                            postgres: postgres
                        )
                    )
                    type = "application/json"
                case ("POST", "/api/auth/verify"):
                    body = try json(
                        try await verify(JSONDecoder().decode(VerifyRequest.self, from: req.body), postgres: postgres)
                    )
                    type = "application/json"
                case ("GET", "/api/auth/session"):
                    guard let auth = req.headers["authorization"], auth.hasPrefix("Bearer ") else {
                        throw AuthError.invalidCredentials
                    }
                    body = try json(try await restoreSession(token: String(auth.dropFirst(7)), postgres: postgres))
                    type = "application/json"
                case ("GET", "/api/private/photos"):
                    guard let auth = req.headers["authorization"], auth.hasPrefix("Bearer ") else {
                        throw AuthError.invalidCredentials
                    }
                    _ = try await restoreSession(token: String(auth.dropFirst(7)), postgres: postgres)
                    body = try json(try await photos(target: req.target, postgres: postgres))
                    type = "application/json"
                default:
                    let rows = try await photos(target: req.target, postgres: postgres)
                    let api = req.target.hasPrefix("/api/photos")
                    body = api ? try json(rows) : html(rows)
                    type = api ? "application/json" : "text/html; charset=utf-8"
                }
                let out = response(type: type, body: body)
                _ = out.withCString { send(client, $0, strlen($0), 0) }
            } catch {
                let body = "{\"error\":\"request failed\"}"
                let out = response(status: "401 Unauthorized", body: body)
                _ = out.withCString { send(client, $0, strlen($0), 0) }
            }
            close(client)
        }
    }
}
