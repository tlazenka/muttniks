//
//  DoorRemoteDataManager.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension Never: Encodable {
    public func encode(to _: Encoder) throws {}
}

extension HTTPURLResponse {
    var isOk: Bool {
        (200...299).contains(statusCode)
    }
}

extension URLRequest {
    mutating func set(apiKey: String, accessToken: String, httpMethod: String) {
        self.httpMethod = httpMethod
        setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        setValue(accessToken, forHTTPHeaderField: "X-Access-Token")
        addValue("application/json", forHTTPHeaderField: "Content-Type")
        addValue("application/json", forHTTPHeaderField: "Accept")
    }
}

public final class DoorRemoteDataManager {
    let urlSession: URLSession
    let baseUrl: URL
    public let apiKey: String

    public init(urlSession: URLSession, baseUrl: URL, apiKey: String) {
        self.urlSession = urlSession
        self.baseUrl = baseUrl
        self.apiKey = apiKey
    }

    public func url(pathComponents: [String], queryItems: [URLQueryItem]? = nil) throws -> URL {
        var url = baseUrl.appendingPathComponent("api")
        for pathComponent in pathComponents {
            url.append(component: pathComponent)
        }

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DataManagerError.invalidUrl
        }

        if let queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw DataManagerError.invalidUrl
        }

        return url
    }

    public func create(
        accessToken: String,
        httpMethod: String,
        pathComponents: [String],
        queryItems: [URLQueryItem]? = nil,
        body: (some Encodable)? = Never?.none
    ) throws -> URLRequest {
        var url = try url(pathComponents: pathComponents, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.set(apiKey: apiKey, accessToken: accessToken, httpMethod: httpMethod)

        if let body {
            do {
                request.httpBody = try JSONEncoder.doorJsonEncoder.encode(body)
            } catch {
                throw DataManagerError.errorEncoding(error)
            }
        }

        return request
    }

    public func response<ResponseType: Decodable>(for request: URLRequest) async throws -> ResponseType {
        let (data, response) = try await urlSession.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.isOk
        else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder.doorJsonDecoder.decode(ResponseType.self, from: data)
    }

    public func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.isOk
        else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    public func createUser(accessToken: String, timeOffsetMinutes: Int) async throws -> ApiPostUserResponse {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "POST",
            pathComponents: ["user"],
            queryItems: [
                URLQueryItem(name: "timeOffsetMinutes", value: String(timeOffsetMinutes))
            ]
        )
        return try await response(for: urlRequest)
    }

    public func updateFcmRegistrationToken(
        accessToken: String,
        fcmRegistrationToken: String
    ) async throws -> ApiPostUserResponse {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "POST",
            pathComponents: ["updateFcmRegistrationToken"],
            queryItems: [
                URLQueryItem(name: "fcmRegistrationToken", value: fcmRegistrationToken)
            ]
        )
        return try await response(for: urlRequest)
    }

    public func updateDoorId(accessToken: String, doorId: UUID) async throws -> ApiGetUserResponse {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "POST",
            pathComponents: ["me", "customDoor", doorId.uuidString]
        )
        return try await response(for: urlRequest)
    }

    public func updateDoorId(accessToken: String, sourceDoorId: UUID, prompt: String) async throws -> ApiGetUserResponse
    {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "POST",
            pathComponents: ["me", "customDoor"],
            body: ApiCreateCustomDoorRequest(sourceDoorId: sourceDoorId, prompt: prompt)
        )
        return try await response(for: urlRequest)
    }

    public func knock(accessToken: String, destinationUserId: UUID, imageData: Data?) async throws -> ApiKnockResponse {
        let url = try url(pathComponents: ["knock", "user", destinationUserId.uuidString])

        var request: URLRequest = {
            let request: URLRequest
            if let imageData {
                request = URLRequest(url: url, mimeType: "image/jpeg", imageData: imageData)
            } else {
                request = URLRequest(url: url)
            }
            return request
        }()

        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")

        return try await response(for: request)
    }

    public func acknowledgeKnock(accessToken: String, knockId: UUID) async throws -> ApiKnockResponse {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "POST",
            pathComponents: ["knock", knockId.uuidString, "ack"]
        )
        return try await response(for: urlRequest)
    }

    public func getUsers(accessToken: String, phoneNumbers: [PhoneNumber]) async throws -> [ApiGetUserResponse] {
        let hashedPhoneNumbers = phoneNumbers.compactMap(\.hashed)
        guard hashedPhoneNumbers.count == phoneNumbers.count else {
            throw DataManagerError.invalidPhoneNumberData
        }

        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "POST",
            pathComponents: ["users", "check"],
            body: hashedPhoneNumbers
        )
        return try await response(for: urlRequest)
    }

    public func getUser(accessToken: String) async throws -> ApiGetUserResponse {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "GET",
            pathComponents: ["me"]
        )
        return try await response(for: urlRequest)
    }

    public func deleteAccount(accessToken: String) async throws -> ApiEmptyResponse {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "DELETE",
            pathComponents: ["me"]
        )
        return try await response(for: urlRequest)
    }

    public func getImageData(accessToken: String, doorId: UUID) async throws -> Data {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "GET",
            pathComponents: ["customDoor", doorId.uuidString, "image"]
        )
        return try await data(for: urlRequest)
    }

    public func getImageData(accessToken: String, knockId: UUID) async throws -> Data {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "GET",
            pathComponents: ["knock", knockId.uuidString, "image"]
        )
        return try await data(for: urlRequest)
    }

    public func getAvailableDoors(accessToken: String) async throws -> [ApiGetCustomDoorResponse] {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "GET",
            pathComponents: ["customDoors"]
        )
        return try await response(for: urlRequest)
    }

    public func getKnocks(accessToken: String) async throws -> [ApiGetKnockResponse] {
        let urlRequest = try create(
            accessToken: accessToken,
            httpMethod: "GET",
            pathComponents: ["knocks"]
        )
        return try await response(for: urlRequest)
    }
}
