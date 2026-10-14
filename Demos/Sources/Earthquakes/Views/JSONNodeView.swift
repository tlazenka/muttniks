import ScopedUserDefaults
import SemanticCore
import SwiftUI
import UIKit

struct JSONNodeView: View {
    let root: JSONNode

    let analytics: AnalyticsStore?

    let defaults = UserDefaults.standard.providing(
        ExplorerDefaults.self,
        SearchDefaults.self,
    )

    var explorerDefaults: ExplorerDefaults {
        defaults(ExplorerDefaults.self)
    }

    var searchDefaults: SearchDefaults {
        defaults(SearchDefaults.self)
    }

    init(
        root: JSONNode,
        analytics: AnalyticsStore? = nil,
        initialFilter: FieldFilter? = nil,
    ) {
        self.root = root
        self.analytics = analytics
        _filter = State(initialValue: initialFilter)
    }

    @State private var filter: FieldFilter?
    @State private var scrubOrigin: FieldFilter?
    @State private var scrubStartTouchPoint: CGPoint?
    @State private var feedback = UISelectionFeedbackGenerator()
    @State private var markers: [String: FieldMarker] = [:]
    @State private var searchText = ""
    @State private var tokens: [SearchToken] = []
    @State private var suggestedTokens: [SearchToken] = []
    @State private var synchronizingTokens = false
    @State private var suggestionScores: [String: Int] = [:]
    @State private var didRestoreDefaults = false

    var filteredDataRoot: JSONNode {
        guard let filter else { return root }
        return root.filtering(filter) ?? root
    }

    var displayedRoot: JSONNode {
        if let fieldName = selectedFieldName {
            return filteredDataRoot.filtering(
                fieldName: fieldName,
                categoricalValue: selectedValue
            ) ?? emptyRoot(from: filteredDataRoot)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredDataRoot }
        return filteredDataRoot.filtering(query) ?? emptyRoot(from: filteredDataRoot)
    }

    func emptyRoot(from root: JSONNode) -> JSONNode {
        JSONNode(id: root.id, name: root.name, path: root.path, value: root.value, children: [])
    }

    var resultCount: Int {
        if let field = selectedFieldName, let value = selectedValue {
            return facetedResultCount(fieldName: field, value: value)
        }
        return filteredDataRoot.children.first(where: { $0.name == "items" })?.children.count ?? 0
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
                if selectedValue != nil {
                    Button(isCurrentFacetSaved ? "Saved" : "Save") {
                        saveCurrentFacet()
                    }
                    .disabled(isCurrentFacetSaved)
                }
                if filter != nil || !tokens.isEmpty {
                    Button("Clear") {
                        analytics?.record("filter_cleared")
                        filter = nil
                        tokens = []
                        refreshSuggestedTokens()
                    }
                }
            }
            .padding(.horizontal)

            CBLinearHierarchyViewControllerRepresentable(
                root: displayedRoot,
                markers: markers,
                activeFilter: filter,
                resultCount: resultCount,
                onScrub: { node, translation, touchPoint, state in
                    scrub(node: node, translationX: translation, touchPoint: touchPoint, state: state)
                },
                onAdjust: { node, direction in
                    adjustAccessibility(node: node, direction: direction)
                }
            )
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
        .task {
            defaults.register()
            restoreDefaultsIfNeeded()
            reloadWarehouseSignals()
        }
        .onReceive(explorerDefaults.didChangePublisher) {
            refreshSuggestedTokens()
            reloadWarehouseSignals()
        }
        .overlay {
            GeometryReader { geometryProxy in
                if isScrubbing, let filter, let startTouch = scrubStartTouchPoint {
                    FeedbackHUD(message: filter.description, monospaced: true)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: max(0, geometryProxy.size.width - 24))
                        .position(
                            x: geometryProxy.size.width / 2,
                            y: scrubHUDY(startTouch: startTouch, in: geometryProxy)
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // Start off the HUD a bit above the finger, and keep it stable
    func scrubHUDY(startTouch: CGPoint, in geometry: GeometryProxy) -> CGFloat {
        let centerY = geometry.size.height / 2
        let startY = startTouch.y - geometry.frame(in: .global).minY
        // TODO: Dynamic Type, safe area
        return startY < centerY ? max(16, startY - 100) : centerY
    }

    func scrub(node: JSONNode, translationX: CGFloat, touchPoint: CGPoint, state: UIGestureRecognizer.State) {
        guard let relativePath = featureRelativePath(from: node.path) else { return }
        switch state {
        case .began:
            scrubStartTouchPoint = touchPoint
            feedback.prepare()
            scrubOrigin = initialFilter(path: relativePath, value: node.value)
            filter = scrubOrigin
            analytics?
                .record(
                    "scrub_started",
                    properties: [
                        "path": relativePath,
                        "kind": node.value.analyticsKind,
                    ]
                )
        case .changed:
            guard let origin = scrubOrigin else { return }
            let next = adjusted(origin, translationX: translationX)
            if next != filter {
                feedback.selectionChanged()
                feedback.prepare()
                analytics?.record("filter_changed", properties: next.analyticsProperties)
            }
            filter = next
        case .ended:
            if let filter {
                applyFilter(filter, source: "touch")
                UIPasteboard.general.string = dockerCommand(for: filter)
                analytics?
                    .record(
                        "docker_command_copied",
                        properties: [
                            "path": filter.path
                        ]
                    )
            }
            scrubOrigin = nil
            scrubStartTouchPoint = nil
        case .cancelled, .failed:
            scrubOrigin = nil
            scrubStartTouchPoint = nil
        default:
            break
        }
    }

    func reloadWarehouseSignals() {
        guard let analytics else { return }
        Task { @MainActor in
            async let loadedMarkers = analytics.fieldMarkers()
            async let loadedScores = analytics.suggestionScores()
            markers = (try? await loadedMarkers) ?? [:]
            suggestionScores = (try? await loadedScores) ?? [:]
            refreshSuggestedTokens()
        }
    }

    func searchSubmitted() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if let fieldName = selectedFieldName {
            let values = categoricalValues(named: fieldName)
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
            var values = categoricalValues(named: fieldName)
                .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }

            if searchDefaults.savedField == fieldName,
                let saved = searchDefaults.savedValue,
                let index = values.firstIndex(of: saved)
            {
                values.remove(at: index)
                values.insert(saved, at: 0)
            }
            suggestedTokens = values.prefix(12).map(SearchToken.categoricalValue)
            return
        }

        var fields = categoricalFieldNames()
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }

        if let saved = searchDefaults.savedField,
            let index = fields.firstIndex(of: saved)
        {
            fields.remove(at: index)
            fields.insert(saved, at: 0)
        }
        suggestedTokens = fields.prefix(12).map(SearchToken.fieldName)
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
            analytics?
                .record(
                    "filter_field_selected",
                    properties: [
                        "fieldName": fieldName,
                        "source": "faceted_search",
                    ]
                )
            suggestedTokens = categoricalValues(named: fieldName)
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
        explorerDefaults.lastField = fieldName
        explorerDefaults.lastValue = value
        analytics?
            .record(
                "filter_suggestion_selected",
                properties: [
                    "fieldName": fieldName,
                    "value": value,
                    "source": "field_name_value_tokens",
                    "resultsAfter": facetedResultCount(fieldName: fieldName, value: value),
                ]
            )
        reloadWarehouseSignals()
    }

    func categoricalFieldNames() -> [String] {
        var names = Set<String>()
        for feature in featureNodes() {
            collectCategoricalNames(in: feature, into: &names)
        }
        return names.sorted {
            let left = bestScore(forFieldName: $0)
            let right = bestScore(forFieldName: $1)
            if left != right { return left > right }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func collectCategoricalNames(in node: JSONNode, into names: inout Set<String>) {
        switch node.value {
        case .string, .bool:
            names.insert(node.name)
        default:
            break
        }
        for child in node.children {
            collectCategoricalNames(in: child, into: &names)
        }
    }

    func categoricalValues(named fieldName: String) -> [String] {
        var values = Set<String>()
        for feature in featureNodes() {
            collectCategoricalValues(named: fieldName, in: feature, into: &values)
        }
        return values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func collectCategoricalValues(
        named fieldName: String,
        in node: JSONNode,
        into values: inout Set<String>
    ) {
        if node.name == fieldName {
            switch node.value {
            case .string(let value):
                values.insert(value)
            case .bool(let value):
                values.insert(value ? "true" : "false")
            default:
                break
            }
        }
        for child in node.children {
            collectCategoricalValues(named: fieldName, in: child, into: &values)
        }
    }

    func bestScore(forFieldName name: String) -> Int {
        categoricalFields()
            .filter { $0.name == name }
            .map(\.score)
            .max() ?? 0
    }

    func facetedResultCount(fieldName: String, value: String) -> Int {
        featureNodes().filter { $0.containsCategorical(name: fieldName, value: value) }.count
    }

    func categoricalFields() -> [FieldChoice] {
        var valuesByPath: [String: Set<String>] = [:]
        var namesByPath: [String: String] = [:]

        for feature in featureNodes() {
            collectCategoricalFields(in: feature, valuesByPath: &valuesByPath, namesByPath: &namesByPath)
        }

        return valuesByPath.compactMap { path, values in
            guard !values.isEmpty else { return nil }
            return FieldChoice(
                path: path,
                name: namesByPath[path] ?? fieldName(for: path),
                values: values.sorted(),
                marker: markers[path]?.label,
                score: suggestionScores[path] ?? 0
            )
        }
    }

    func collectCategoricalFields(
        in node: JSONNode,
        valuesByPath: inout [String: Set<String>],
        namesByPath: inout [String: String]
    ) {
        if let path = featureRelativePath(from: node.path) {
            switch node.value {
            case .string(let value):
                valuesByPath[path, default: []].insert(value)
                namesByPath[path] = node.name
            case .bool(let value):
                valuesByPath[path, default: []].insert(value ? "true" : "false")
                namesByPath[path] = node.name
            default:
                break
            }
        }
        for child in node.children {
            collectCategoricalFields(in: child, valuesByPath: &valuesByPath, namesByPath: &namesByPath)
        }
    }

    func fieldName(for path: String) -> String {
        path.split(separator: ".").last.map(String.init) ?? path
    }

    var isCurrentFacetSaved: Bool {
        guard let field = selectedFieldName, let value = selectedValue else { return false }
        return searchDefaults.savedField == field && searchDefaults.savedValue == value
    }

    func saveCurrentFacet() {
        guard let field = selectedFieldName, let value = selectedValue else { return }
        searchDefaults.savedField = field
        searchDefaults.savedValue = value
        refreshSuggestedTokens()
    }

    func restoreDefaultsIfNeeded() {
        guard !didRestoreDefaults else { return }
        didRestoreDefaults = true
        guard
            let field = explorerDefaults.lastField,
            let value = explorerDefaults.lastValue,
            categoricalValues(named: field).contains(value)
        else { return }
        synchronizingTokens = true
        tokens = [.fieldName(field), .categoricalValue(value)]
        synchronizingTokens = false
    }

    func dockerCommand(for filter: FieldFilter) -> String {
        let expression: String
        switch filter {
        case .minimum(let path, let value, _):
            expression = "\(path) >= \(value)"
        case .category(let path, let value, _):
            expression = "\(path) = \"\(escapeQueryString(value))\""
        }

        return "docker compose run --rm earthquakes-cli \(shellQuote(expression))"
    }

    func escapeQueryString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    func initialFilter(path: String, value: JSONNode.Value) -> FieldFilter? {
        switch value {
        case .number(let text):
            guard let value = Double(text) else { return nil }
            return .minimum(path: path, value: value, values: numericValues(at: path))
        case .string(let value):
            return .category(path: path, value: value, values: stringValues(at: path))
        case .bool(let value):
            let values = scalarValues(at: path)
                .compactMap {
                    if case .bool(let v) = $0 { return v ? "true" : "false" }
                    return nil
                }
            return .category(path: path, value: value ? "true" : "false", values: Array(Set(values)).sorted())
        case .null, .object, .array:
            return nil
        }
    }

    func adjusted(_ filter: FieldFilter, translationX: CGFloat) -> FieldFilter {
        filter.stepped(by: SemanticScrubInterpreter(pointsPerStep: 28).steps(for: Double(translationX)))
    }

    // TODO: VoiceOver
    func adjustAccessibility(node: JSONNode, direction: Int) {
        guard let relativePath = featureRelativePath(from: node.path),
            let origin = initialFilter(path: relativePath, value: node.value)
        else { return }

        let base = filter?.path == relativePath ? filter! : origin
        let next = base.stepped(by: direction)
        guard next != base else { return }
        feedback.selectionChanged()
        applyFilter(next, source: "accessibility")
        UIAccessibility.post(notification: .announcement, argument: "\(next.description), \(resultCount) results")
    }

    func applyFilter(_ next: FieldFilter, source: String) {
        filter = next
        analytics?
            .record(
                "filter_changed",
                properties: next.analyticsProperties.merging([
                    "source": source
                ]) { _, new in new }
            )
        analytics?
            .record(
                "filter_finished",
                properties:
                    next.analyticsProperties.merging([
                        "description": next.description,
                        "resultsAfter": resultCount,
                        "source": source,
                    ]) { _, new in new }
            )
        synchronizingTokens = true
        if case .category(let path, let value, let values) = next {
            let field = FieldChoice(
                path: path,
                name: fieldName(for: path),
                values: values,
                marker: markers[path]?.label,
                score: suggestionScores[path] ?? 0
            )
            tokens = [.fieldName(field.name), .categoricalValue(value)]
        } else {
            tokens = []
        }
        synchronizingTokens = false
        reloadWarehouseSignals()
    }

    func featureRelativePath(from path: String) -> String? {
        guard path.hasPrefix("$.items["), let close = path.firstIndex(of: "]") else { return nil }
        let suffix = path[path.index(after: close)...]
        return suffix.isEmpty ? nil : "$" + suffix
    }

    func featureNodes() -> [JSONNode] {
        root.children.first(where: { $0.name == "items" })?.children ?? []
    }
    func scalarValues(at path: String) -> [JSONNode.Value] {
        featureNodes().compactMap { $0.node(atRelativePath: path)?.value }
    }
    func numericValues(at path: String) -> [Double] {
        Array(
            Set(
                scalarValues(at: path)
                    .compactMap {
                        if case .number(let s) = $0 { return Double(s) }
                        return nil
                    }
            )
        )
        .sorted()
    }
    func stringValues(at path: String) -> [String] {
        Array(
            Set(
                scalarValues(at: path)
                    .compactMap {
                        if case .string(let s) = $0 { return s }
                        return nil
                    }
            )
        )
        .sorted()
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
    @Environment(\.searchSuggestionsPlacement) private var placement
    let token: SearchToken
    let searchDefaults = UserDefaults.standard.providing(SearchDefaults.self)(SearchDefaults.self)

    var isSaved: Bool {
        switch token {
        case .fieldName(let name):
            return searchDefaults.savedField == name
        case .categoricalValue(let value):
            return searchDefaults.savedValue == value
        }
    }

    var body: some View {
        switch token {
        case .fieldName(let name):
            if placement == .menu {
                HStack(spacing: 6) {
                    Text(name)
                    if isSaved {
                        Text("Saved")
                            .textCase(.uppercase)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
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
                HStack(spacing: 6) {
                    Text(value)
                    if isSaved {
                        Text("Saved")
                            .textCase(.uppercase)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
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

#if DEBUG
#Preview {
    NavigationStack {
        JSONNodeView(root: try! JSONNode.loadBundledEarthquakes())
    }
}
#endif

struct FeedbackHUD: View {
    let message: String
    var monospaced = false

    var body: some View {
        Text(message)
            .font(monospaced ? .title3.monospaced().weight(.semibold) : .headline)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 8)
    }
}
