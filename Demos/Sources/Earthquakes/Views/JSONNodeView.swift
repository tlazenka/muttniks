import PuzzolaJSON
import SwiftUI
import UIKit

struct JSONNodeView: View {
    let root: JSONNode
    let viewModel: JSONNodeViewModel

    @State var filter: FieldFilter?
    @State var scrubOrigin: FieldFilter?
    @State var feedback = UISelectionFeedbackGenerator()

    init(root: JSONNode) {
        viewModel = .init(root: root)
        self.root = root
    }

    var displayedRoot: JSONNode {
        guard let filter else { return root }
        return root.filtering(filter) ?? root
    }

    var resultCount: Int {
        displayedRoot.children.first(where: { $0.name == "features" })?.children.count ?? 0
    }

    var isScrubbing: Bool { scrubOrigin != nil }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(resultCount) results")
                    .font(.headline)
                Spacer()
                if filter != nil {
                    Button("Clear") { filter = nil }
                }
            }
            .padding(.horizontal)

            CBLinearHierarchyViewControllerRepresentable(root: displayedRoot) { node, translation, state in
                scrub(node: node, translationX: translation, state: state)
            }
        }
        .navigationTitle("Earthquakes")
        .overlay(alignment: .center) {
            if isScrubbing, let filter {
                Text(filter.description)
                    .font(.title3.monospaced().weight(.semibold))
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Active Filter")
                    .accessibilityValue(filter.description)
            }
        }
    }

    func scrub(node: JSONNode, translationX: CGFloat, state: UIGestureRecognizer.State) {
        guard let relativePath = viewModel.featureRelativePath(from: node.path) else { return }
        switch state {
        case .began:
            feedback.prepare()
            scrubOrigin = viewModel.initialFilter(path: relativePath, value: node.value)
            filter = scrubOrigin
        case .changed:
            guard let origin = scrubOrigin else { return }
            let next = viewModel.adjusted(origin, translationX: translationX)
            if next != filter { feedback.selectionChanged(); feedback.prepare() }
            filter = next
        case .ended:
            if let filter {
                UIPasteboard.general.string = dockerCommand(for: filter)
            }
            scrubOrigin = nil
        case .cancelled, .failed:
            scrubOrigin = nil
        default:
            break
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { JSONNodeView(root: try! JSONNode.loadEarthquakes()) }
}
#endif
