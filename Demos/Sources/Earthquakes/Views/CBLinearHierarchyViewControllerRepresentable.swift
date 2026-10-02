import PuzzolaJSON
import PuzzolaUIKit
import SwiftUI

final class CBHierarchyNode: NSObject, CBHierarchyNodeProvider {
    let node: JSONNode
    init(_ node: JSONNode) { self.node = node }
    var identifier: String { node.id }
    var title: String { node.name }
    var subtitle: String { node.summary }
    var jsonPath: String { node.path }
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
    lazy var children: [any CBHierarchyNodeProvider] = node.children.map(CBHierarchyNode.init)
}

struct CBLinearHierarchyViewControllerRepresentable: UIViewControllerRepresentable {
    let root: JSONNode
    let onScrub: (JSONNode, CGFloat, UIGestureRecognizer.State) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScrub: onScrub) }
    func makeUIViewController(context: Context) -> _CBLinearHierarchyViewController {
        let controller = _CBLinearHierarchyViewController(rootNode: CBHierarchyNode(root))
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: _CBLinearHierarchyViewController, context: Context) {
        context.coordinator.onScrub = onScrub
        controller.setRootNode(CBHierarchyNode(root), animated: true)
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
