import MuttniksJSON
import MuttniksUIKit
import SwiftUI

final class CBHierarchyNode: NSObject, CBHierarchyNodeProvider {
    let node: JSONNode
    let markers: [String: FieldMarker]

    init(node: JSONNode, markers: [String: FieldMarker]) {
        self.node = node
        self.markers = markers
    }
    var identifier: String { node.id }
    var title: String { node.name }
    var subtitle: String { node.summary }
    var jsonPath: String { node.path }
    var markerText: String? {
        guard let relativePath = Self.featureRelativePath(from: node.path) else { return nil }
        return markers[relativePath]?.label
    }

    var sectionTitle: String? {
        guard node.path.hasPrefix("$.features["),
            node.path.filter({ $0 == "[" }).count == 1,
            case .object = node.value
        else { return nil }
        guard let properties = node.children.first(where: { $0.name == "properties" }),
            let place = properties.children.first(where: { $0.name == "place" }),
            case .string(let value) = place.value
        else { return node.name }
        return value
    }
    lazy var children: [any CBHierarchyNodeProvider] = node.children.map {
        CBHierarchyNode(node: $0, markers: markers)
    }

    static func featureRelativePath(from path: String) -> String? {
        guard path.hasPrefix("$.features["),
            let close = path.firstIndex(of: "]")
        else { return nil }
        let suffix = path[path.index(after: close)...]
        return suffix.isEmpty ? nil : "$" + suffix
    }
}

struct CBLinearHierarchyViewControllerRepresentable: UIViewControllerRepresentable {
    let root: JSONNode
    let markers: [String: FieldMarker]
    let onScrub: (JSONNode, CGFloat, UIGestureRecognizer.State) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScrub: onScrub) }
    func makeUIViewController(context: Context) -> _CBLinearHierarchyViewController {
        let controller = _CBLinearHierarchyViewController(rootNode: CBHierarchyNode(node: root, markers: markers))
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: _CBLinearHierarchyViewController, context: Context) {
        context.coordinator.onScrub = onScrub
        controller.setRootNode(CBHierarchyNode(node: root, markers: markers), animated: true)
    }

    final class Coordinator: NSObject, CBLinearHierarchyViewControllerDelegate {
        var onScrub: (JSONNode, CGFloat, UIGestureRecognizer.State) -> Void
        init(onScrub: @escaping (JSONNode, CGFloat, UIGestureRecognizer.State) -> Void) { self.onScrub = onScrub }
        func linearHierarchyViewController(
            _ viewController: _CBLinearHierarchyViewController,
            didSelectNode node: any CBHierarchyNodeProvider
        ) {}
        func linearHierarchyViewController(
            _ viewController: _CBLinearHierarchyViewController,
            didScrubNode node: any CBHierarchyNodeProvider,
            translationX: CGFloat,
            state: UIGestureRecognizer.State
        ) {
            guard let adapter = node as? CBHierarchyNode else { return }
            onScrub(adapter.node, translationX, state)
        }
    }
}
