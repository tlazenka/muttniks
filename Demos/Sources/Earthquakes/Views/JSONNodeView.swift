import PuzzolaJSON
import SwiftUI
import UIKit

struct JSONNodeView: View {
    let root: JSONNode
    let viewModel: JSONNodeViewModel
    let analytics: AnalyticsStore?

    init(root: JSONNode, analytics: AnalyticsStore? = nil) {
        viewModel = .init(root: root)
        self.root = root
        self.analytics = analytics
    }

    @State var filter: FieldFilter?
    @State var scrubOrigin: FieldFilter?
    @State var feedback = UISelectionFeedbackGenerator()
    @State var markers: [String: FieldMarker] = [:]
    @State var searchText = ""
    @State var tokens: [SearchToken] = []
    @State var suggestedTokens: [SearchToken] = []
    @State var synchronizingTokens = false
    @State var suggestionScores: [String: Int] = [:]

    var filteredDataRoot: JSONNode {
        guard let filter else { return root }
        return root.filtering(filter) ?? root
    }

    var displayedRoot: JSONNode {
        if let fieldName = selectedFieldName {
            return filteredDataRoot.filtering(
                fieldName: fieldName,
                categoricalValue: selectedValue
            ) ?? filteredDataRoot.asEmptyRoot()
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredDataRoot }
        return filteredDataRoot.filtering(query) ?? filteredDataRoot.asEmptyRoot()
    }

    var resultCount: Int {
        filteredDataRoot.children.first(where: { $0.name == "features" })?.children.count ?? 0
    }

    var isScrubbing: Bool { scrubOrigin != nil }

    var selectedFieldName: String? {
        guard case .fieldName(let name)? = tokens.first else { return nil }
        return name
    }

    var selectedValue: String? {
        guard tokens.count >= 2,
            case .categoricalValue(let value) = tokens[1]
        else { return nil }
        return value
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(resultCount) results")
                    .font(.headline)
                Spacer()
                if filter != nil {
                    Button("Clear") {
                        analytics?.record("filter_cleared")
                        filter = nil
                        tokens = []
                        refreshSuggestedTokens()
                    }
                }
            }
            .padding(.horizontal)

            CBLinearHierarchyViewControllerRepresentable(root: displayedRoot, markers: markers) {
                node,
                translation,
                state in
                scrub(node: node, translationX: translation, state: state)
            }
        }
        .navigationTitle("Earthquakes")
        .searchable(
            text: $searchText,
            tokens: $tokens,
            suggestedTokens: $suggestedTokens,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search by node and filter"
        ) { token in
            SearchTokenLabel(token: token)
        }
        .onChange(of: searchText) { _, _ in
            refreshSuggestedTokens()
        }
        .onChange(of: tokens) { oldTokens, newTokens in
            tokensChanged(from: oldTokens, to: newTokens)
        }
        .onSubmit(of: .search) {
            searchSubmitted()
        }
        .task { reloadWarehouseSignals() }
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
            analytics?.record(
                "scrub_started",
                properties: [
                    "path": relativePath,
                    "kind": node.value.analyticsKind,
                ]
            )
        case .changed:
            guard let origin = scrubOrigin else { return }
            let next = viewModel.adjusted(origin, translationX: translationX)
            if next != filter {
                feedback.selectionChanged()
                feedback.prepare()
                analytics?.record("filter_changed", properties: next.analyticsProperties)
            }
            filter = next
        case .ended:
            if let filter {
                analytics?.record(
                    "filter_finished",
                    properties:
                        filter.analyticsProperties.merging([
                            "description": filter.description,
                            "resultsAfter": resultCount,
                        ]) { _, new in new }
                )
                UIPasteboard.general.string = dockerCommand(for: filter)
                analytics?.record(
                    "docker_command_copied",
                    properties: [
                        "path": filter.path
                    ]
                )
                synchronizingTokens = true
                if case .category(let path, let value, let values) = filter {
                    let field = FieldChoice(
                        path: path,
                        name: viewModel.fieldName(for: path),
                        values: values,
                        marker: markers[path]?.label,
                        score: suggestionScores[path] ?? 0
                    )
                    tokens = [
                        .fieldName(field.name),
                        .categoricalValue(value),
                    ]
                } else {
                    tokens = []
                }
                synchronizingTokens = false
                reloadWarehouseSignals()
            }
            scrubOrigin = nil
        case .cancelled, .failed:
            scrubOrigin = nil
        default:
            break
        }
    }

    func reloadWarehouseSignals() {
        guard let analytics else { return }
        markers = (try? analytics.fieldMarkers()) ?? [:]
        suggestionScores = (try? analytics.suggestionScores()) ?? [:]
        refreshSuggestedTokens()
    }

    func searchSubmitted() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if let fieldName = selectedFieldName {
            let values = viewModel.categoricalValues(named: fieldName)
            guard
                let value = values.first(where: {
                    $0.localizedCaseInsensitiveCompare(query) == .orderedSame
                })
                    ?? values.first(where: {
                        $0.localizedCaseInsensitiveContains(query)
                    })
            else { return }

            tokens = [.fieldName(fieldName), .categoricalValue(value)]
            Task { @MainActor in searchText = "" }
            return
        }

        let fields = categoricalFieldNames()
        guard
            let field = fields.first(where: {
                $0.localizedCaseInsensitiveCompare(query) == .orderedSame
            })
                ?? fields.first(where: {
                    $0.localizedCaseInsensitiveContains(query)
                })
        else { return }

        tokens = [.fieldName(field)]
        Task { @MainActor in searchText = "" }
    }

    func refreshSuggestedTokens() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let fieldName = selectedFieldName {
            suggestedTokens = viewModel.categoricalValues(named: fieldName)
                .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
                .prefix(12)
                .map(SearchToken.categoricalValue)
            return
        }

        suggestedTokens = categoricalFieldNames()
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .prefix(12)
            .map(SearchToken.fieldName)
    }

    func tokensChanged(from oldTokens: [SearchToken], to newTokens: [SearchToken]) {
        guard !synchronizingTokens, oldTokens != newTokens else { return }

        if newTokens.isEmpty {
            filter = nil
            refreshSuggestedTokens()
            return
        }

        guard case .fieldName(let fieldName) = newTokens[0] else {
            synchronizingTokens = true
            tokens = []
            synchronizingTokens = false
            filter = nil
            refreshSuggestedTokens()
            return
        }

        if newTokens.count > 2 {
            synchronizingTokens = true
            tokens = Array(newTokens.prefix(2))
            synchronizingTokens = false
        }

        if newTokens.count == 1 {
            filter = nil
            analytics?.record(
                "filter_field_selected",
                properties: [
                    "fieldName": fieldName,
                    "source": "faceted_search",
                ]
            )
            suggestedTokens = viewModel.categoricalValues(named: fieldName)
                .prefix(12)
                .map(SearchToken.categoricalValue)
            return
        }

        guard case .categoricalValue(let value) = newTokens[1] else {
            synchronizingTokens = true
            tokens = [.fieldName(fieldName)]
            synchronizingTokens = false
            filter = nil
            refreshSuggestedTokens()
            return
        }

        filter = nil
        analytics?.record(
            "filter_suggestion_selected",
            properties: [
                "fieldName": fieldName,
                "value": value,
                "source": "field_name_value_tokens",
                "resultsAfter": viewModel.facetedResultCount(fieldName: fieldName, value: value),
            ]
        )
        reloadWarehouseSignals()
    }

    func categoricalFieldNames() -> [String] {
        var names = Set<String>()
        for feature in viewModel.featureNodes() {
            viewModel.collectCategoricalNames(in: feature, into: &names)
        }
        return names.sorted {
            let left = bestScore(forFieldName: $0)
            let right = bestScore(forFieldName: $1)
            if left != right { return left > right }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func bestScore(forFieldName name: String) -> Int {
        categoricalFields()
            .filter { $0.name == name }
            .map(\.score)
            .max() ?? 0
    }

    func categoricalFields() -> [FieldChoice] {
        var valuesByPath: [String: Set<String>] = [:]
        var namesByPath: [String: String] = [:]

        for feature in viewModel.featureNodes() {
            viewModel.collectCategoricalFields(in: feature, valuesByPath: &valuesByPath, namesByPath: &namesByPath)
        }

        return valuesByPath.compactMap { path, values in
            guard !values.isEmpty else { return nil }
            return FieldChoice(
                path: path,
                name: namesByPath[path] ?? viewModel.fieldName(for: path),
                values: values.sorted(),
                marker: markers[path]?.label,
                score: suggestionScores[path] ?? 0
            )
        }
    }
}

struct FieldChoice: Hashable {
    let path: String
    let name: String
    let values: [String]
    let marker: String?
    let score: Int

    static func == (lhs: FieldChoice, rhs: FieldChoice) -> Bool { lhs.path == rhs.path }
    func hash(into hasher: inout Hasher) { hasher.combine(path) }
}

enum SearchToken: Identifiable, Hashable {
    case fieldName(String)
    case categoricalValue(String)

    var id: String {
        switch self {
        case .fieldName(let name): return "field-name:\(name)"
        case .categoricalValue(let value): return "categorical-value:\(value)"
        }
    }
}

struct SearchTokenLabel: View {
    @Environment(\.searchSuggestionsPlacement) var placement
    let token: SearchToken

    var body: some View {
        switch token {
        case .fieldName(let name):
            if placement == .menu {
                Text(name)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text("field")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .categoricalValue(let value):
            if placement == .menu {
                Text(value)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                    Text("equals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension JSONNode {
    var scalarDisplay: String {
        switch value {
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        case .object, .array: return ""
        }
    }
}

extension FieldFilter {
    var path: String {
        switch self {
        case .minimum(let path, _, _), .category(let path, _, _):
            return path
        }
    }

    var analyticsProperties: [String: Any] {
        switch self {
        case .minimum(let path, let value, _):
            return ["path": path, "kind": "numeric", "value": value]
        case .category(let path, let value, _):
            return ["path": path, "kind": "categorical", "value": value]
        }
    }
}

extension JSONNode.Value {
    var analyticsKind: String {
        switch self {
        case .number: return "numeric"
        case .string, .bool: return "categorical"
        case .null: return "null"
        case .object: return "object"
        case .array: return "array"
        }
    }
}

extension Array where Element == Double {
    func nearestIndex(to value: Double) -> Int? { indices.min { abs(self[$0] - value) < abs(self[$1] - value) } }
}

#if DEBUG
#Preview {
    NavigationStack { JSONNodeView(root: try! JSONNode.loadEarthquakes()) }
}
#endif
