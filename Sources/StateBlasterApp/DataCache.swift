//
//  DataCache.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import Foundation

public final class DataCache {
    let cache = NSCache<NSString, NSData>()

    public init() {}

    public func set(data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }

    public func data(forKey key: String) -> Data? {
        guard let data = cache.object(forKey: key as NSString) else {
            return nil
        }
        return data as Data
    }
}
