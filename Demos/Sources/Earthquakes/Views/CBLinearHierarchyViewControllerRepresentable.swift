import CBLinearHierarchy
import SwiftUI

final class HierarchyNode: NSObject, CBHierarchyNode {
    let node: JSONNode
    let markers: [String: FieldMarker]
    let activeFilter: FieldFilter?
    let resultCount: Int

    init(
        node: JSONNode,
        markers: [String: FieldMarker],
        activeFilter: FieldFilter?,
        resultCount: Int,
    ) {
        self.node = node
        self.markers = markers
        self.activeFilter = activeFilter
        self.resultCount = resultCount
    }

    var identifier: String { node.id }

    var title: String { node.name }

    var subtitle: String { node.summary }

    var jsonPath: String { node.path }

    var accessibilityFilterValue: String? {
        guard let path = Self.featureRelativePath(from: node.path),
            let activeFilter, activeFilter.path == path
        else { return nil }
        return "Active filter: \(activeFilter.description), \(resultCount) results"
    }

    var isAdjustable: Bool {
        guard node.children.isEmpty else { return false }
        switch node.value {
        case .string, .number, .bool: return Self.featureRelativePath(from: node.path) != nil
        case .null, .object, .array: return false
        }
    }

    var markerText: String? {
        guard let relativePath = Self.featureRelativePath(from: node.path) else { return nil }
        return markers[relativePath]?.label
    }

    var sectionTitle: String? {
        guard node.path.hasPrefix("$.items["),
            node.path.filter({ $0 == "[" }).count == 1,
            case .object = node.value
        else { return nil }
        guard let properties = node.children.first(where: { $0.name == "properties" }),
            let place = properties.children.first(where: { $0.name == "place" }),
            case .string(let value) = place.value
        else { return node.name }
        return value
    }

    lazy var children: [any CBHierarchyNode] = node.children.map {
        HierarchyNode(
            node: $0,
            markers: markers,
            activeFilter: activeFilter,
            resultCount: resultCount,
        )
    }

    static func featureRelativePath(from path: String) -> String? {
        guard path.hasPrefix("$.items["),
            let close = path.firstIndex(of: "]")
        else { return nil }
        let suffix = path[path.index(after: close)...]
        return suffix.isEmpty ? nil : "$" + suffix
    }
}

struct CBLinearHierarchyViewControllerRepresentable: UIViewControllerRepresentable {
    let root: JSONNode
    let markers: [String: FieldMarker]
    let activeFilter: FieldFilter?
    let resultCount: Int
    let onScrub: (JSONNode, CGFloat, CGPoint, UIGestureRecognizer.State) -> Void
    let onAdjust: (JSONNode, Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrub: onScrub, onAdjust: onAdjust)
    }

    func makeUIViewController(context: Context) -> CBLinearHierarchyViewController {
        let controller = CBLinearHierarchyViewController(
            rootNode: HierarchyNode(
                node: root,
                markers: markers,
                activeFilter: activeFilter,
                resultCount: resultCount
            )
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: CBLinearHierarchyViewController, context: Context) {
        context.coordinator.onScrub = onScrub
        context.coordinator.onAdjust = onAdjust
        controller.setRootNode(
            HierarchyNode(node: root, markers: markers, activeFilter: activeFilter, resultCount: resultCount),
            animated: true
        )
    }

    final class Coordinator: NSObject, CBLinearHierarchyViewControllerDelegate {
        var onScrub: (JSONNode, CGFloat, CGPoint, UIGestureRecognizer.State) -> Void
        var onAdjust: (JSONNode, Int) -> Void
        init(
            onScrub: @escaping (JSONNode, CGFloat, CGPoint, UIGestureRecognizer.State) -> Void,
            onAdjust: @escaping (JSONNode, Int) -> Void
        ) {
            self.onScrub = onScrub
            self.onAdjust = onAdjust
        }

        func linearHierarchyViewController(
            _ viewController: CBLinearHierarchyViewController,
            didSelect node: any CBHierarchyNode
        ) {}

        func linearHierarchyViewController(
            _ viewController: CBLinearHierarchyViewController,
            didScrub node: any CBHierarchyNode,
            translationX: CGFloat,
            touch: CGPoint,
            state: UIGestureRecognizer.State
        ) {
            guard let adapter = node as? HierarchyNode else { return }
            onScrub(adapter.node, translationX, touch, state)
        }

        func linearHierarchyViewController(
            _ viewController: CBLinearHierarchyViewController,
            didAdjust node: any CBHierarchyNode,
            direction: Int
        ) {
            guard let adapter = node as? HierarchyNode else { return }
            onAdjust(adapter.node, direction)
        }
    }
}
