import SwiftUI

struct WrappedView: View {
    let analytics: AnalyticsStore
    @State private var insights: [WrappedInsight] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(insights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(insight.eyebrow)
                            .textCase(.uppercase)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(insight.value)
                            .font(.largeTitle.bold())
                        Text(insight.detail)
                            .font(.body)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .listStyle(.plain)
            .padding()
            .navigationTitle("Wrapped")
            .task {
                refresh()
            }
            .refreshable {
                refresh()
            }
            .overlay {
                if insights.isEmpty && error == nil {
                    ContentUnavailableView(
                        "Not (yet) a Wrap",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Tap and scrub around on the home tab and then wrap up here")
                    )
                }
            }
        }
    }

    func refresh() {
        do {
            insights = try analytics.wrapped()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
