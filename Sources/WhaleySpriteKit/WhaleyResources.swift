import Foundation

#if canImport(UIKit) && canImport(SpriteKit) && canImport(WhaleyObjectiveC)
import UIKit
import SpriteKit
import WhaleyObjectiveC

public enum WhaleyResources {
    public static var bundled: Bundle { .module }

    @MainActor public static func configure(bundle: Bundle? = nil) {
        WhaleySrcSetResourceBundle(bundle ?? .module)
    }

    public static func url(_ name: String, in bundle: Bundle? = nil) -> URL? {
        let bundle = bundle ?? .module
        let path = name as NSString
        let ext = path.pathExtension.isEmpty ? nil : path.pathExtension
        return bundle.url(forResource: path.deletingPathExtension, withExtension: ext)
            ?? bundle.url(forResource: path.deletingPathExtension, withExtension: ext, subdirectory: "Resources")
    }

    public static func texture(_ name: String, in bundle: Bundle? = nil) -> SKTexture {
        guard let url = url(name, in: bundle), let image = UIImage(contentsOfFile: url.path) else {
            return SKTexture(imageNamed: name)
        }
        return SKTexture(image: image)
    }
}
#endif
