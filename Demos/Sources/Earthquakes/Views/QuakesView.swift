import Puzzola
import PuzzolaJSON
import SwiftUI

struct QuakesView: View {
    let provider: QuakesProvider
    @State var jsonRoot: JSONNode?
    @State var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let jsonRoot { JSONNodeView(root: jsonRoot) } else { ProgressView() }
            }
        }
        .task {
            do {
                try provider.refresh()
                jsonRoot = try JSONNode.loadEarthquakes()
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}

#if DEBUG
#Preview {
    let database = try! Database(path: ":memory:")
    let provider = try! QuakesProvider(database: database)
    QuakesView(provider: provider)
}
#endif
