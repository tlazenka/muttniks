//
//  URLRequest+Extension.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLRequest {
    // TODO: implement
    public init(url: URL, mimeType: String, imageData: Data) {
        self.init(url: url)
        self.httpMethod = "POST"
        self.httpBody = imageData
    }
}
