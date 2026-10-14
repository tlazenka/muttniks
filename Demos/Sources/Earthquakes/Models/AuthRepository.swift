import Foundation

struct AuthRepository {
    struct Challenge: Decodable {
        let userID: String
        let previewCode: String
    }

    struct Session: Codable, Equatable {
        let userID: String
        let token: String
        let expiresAt: String
    }

    struct VerifyRequest: Encodable {
        let phone: String
        let code: String
    }

    struct PhoneRequest: Encodable { let phone: String }

    var baseURL: URL {
        if let value = ProcessInfo.processInfo.environment["FEED_BASE_URL"], let url = URL(string: value) {
            return url
        }
        return URL(string: "http://127.0.0.1:8080")!
    }

    func requestCode(phone: String) async throws -> Challenge {
        try await post("api/auth/request-code", body: PhoneRequest(phone: phone), as: Challenge.self)
    }

    func verify(phone: String, code: String) async throws -> Session {
        try await post("api/auth/verify", body: VerifyRequest(phone: phone, code: code), as: Session.self)
    }

    func session(token: String) async throws -> Session {
        var request = URLRequest(url: baseURL.appending(path: "api/auth/session"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print(request.cURLDescription)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        return try JSONDecoder().decode(Session.self, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        as: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        print(request.cURLDescription)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private extension URLRequest {
    var cURLDescription: String {
        var parts = ["curl", "-i"]
        if let method = httpMethod, method != "GET" { parts += ["-X", shellQuote(method)] }
        for (name, value) in allHTTPHeaderFields ?? [:] { parts += ["-H", shellQuote("\(name): \(value)")] }
        if let body = httpBody, let text = String(data: body, encoding: .utf8) {
            parts += ["--data", shellQuote(text)]
        }
        if let url { parts.append(shellQuote(url.absoluteString)) }
        return parts.joined(separator: " ")
    }
    func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
