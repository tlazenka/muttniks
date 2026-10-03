import Foundation

extension Bundle {
    enum BundleError: Error {
        case resourceNotFound
    }

    func stringFromResource(withName name: String, type: String?) throws -> String {
        guard let path = path(forResource: name, ofType: type) else {
            throw BundleError.resourceNotFound
        }
        return try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }
}
