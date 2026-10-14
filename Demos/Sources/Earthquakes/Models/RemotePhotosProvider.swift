import Foundation
import QueryBlaster

struct RemotePhotosProvider {
    struct RemotePhoto: Decodable {
        let id: String
        let city: String
        let country: String
        let place: String
        let capturedAt: String
        let photographer: String
        let title: String
        let imageURL: String
    }

    var baseURL: URL {
        if let value = ProcessInfo.processInfo.environment["FEED_BASE_URL"],
            let url = URL(string: value)
        {
            return url
        }
        return URL(string: "http://127.0.0.1:8080")!
    }

    func fetch(token: String? = nil) async throws -> [FeedRecord] {
        let path = token == nil ? "api/photos" : "api/private/photos"
        var request = URLRequest(url: baseURL.appending(path: path))
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(token == nil ? .badServerResponse : .userAuthenticationRequired)
        }
        let formatter = ISO8601DateFormatter()
        return try JSONDecoder().decode([RemotePhoto].self, from: data)
            .map { remotePhoto in
                var fields: [String: QueryValue] = [
                    FeedField.city: .text(remotePhoto.city), FeedField.country: .text(remotePhoto.country),
                    FeedField.place: .text(remotePhoto.place), FeedField.photographer: .text(remotePhoto.photographer),
                    FeedField.title: .text(remotePhoto.title),
                ]
                if let date = formatter.date(from: remotePhoto.capturedAt) {
                    fields[FeedField.timestamp] = .date(date)
                }
                return FeedRecord(
                    id: remotePhoto.id,
                    kind: .photograph,
                    fields: fields,
                    imageURL: URL(string: remotePhoto.imageURL)
                )
            }
    }
}
