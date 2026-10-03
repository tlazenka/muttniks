import Foundation
import XCTest

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated class URLProtocolMock: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    nonisolated override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    nonisolated override class func canInit(with _: URLSessionTask) -> Bool {
        true
    }

    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    nonisolated override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            return XCTFail("requestHandler is nil")
        }
        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    nonisolated override func stopLoading() {}
}
