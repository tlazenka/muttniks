import SQLiteJSONBlaster
import ScopedUserDefaults
import SwiftUI
import UIKit

struct QuakesView: View {
    enum SessionState: Equatable {
        case anonymous
        case signedIn(userID: String)

        var isSignedIn: Bool {
            switch self {
            case .anonymous:
                false
            case .signedIn(let userID):
                true
            }
        }
    }

    let provider: QuakesProvider
    @State private var jsonRoot: JSONNode?
    @State private var errorMessage: String?
    @State private var sessionState: SessionState = .anonymous
    @State private var isPresentingSignIn = false
    @State private var fetchDate = 0
    @State private var defaultFilter: FieldFilter?
    @State var authDefaults = AuthDefaults()
    @State var isSignedIn: Bool?

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if let jsonRoot {
                        JSONNodeView(
                            root: jsonRoot,
                            analytics: provider.analytics,
                            initialFilter: defaultFilter
                        )
                        .id(fetchDate)
                    } else {
                        ProgressView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if sessionState.isSignedIn {
                            Menu {
                                Text("Signed in")
                                Button("Sign Out", role: .destructive) {
                                    signOut()
                                }
                            } label: {
                                Label("Account", systemImage: "person.crop.circle.fill")
                            }
                        } else {
                            Button {
                                isPresentingSignIn = true
                            } label: {
                                Label("Sign In", systemImage: "person.crop.circle")
                            }
                        }
                    }
                }
                .sheet(isPresented: $isPresentingSignIn) {
                    SignInFlow { signedIn in
                        authDefaults.token = signedIn.token
                        sessionState = .signedIn(userID: signedIn.userID)
                        isPresentingSignIn = false
                        Task {
                            await fetchFeed(token: signedIn.token, applyPhotosFilter: true)
                        }
                    }
                }
            }
            .tabItem {
                Label("Home", systemImage: (isSignedIn == true) ? "icloud" : "icloud.slash")
            }

            WrappedView(analytics: provider.analytics)
                .tabItem {
                    Label("Scrubapped", systemImage: "service.dog")
                }
        }
        .onReceive(
            authDefaults.didChangePublisher(
                for: \.token,
            )
            .scan(
                (String?.none, String?.none)
            ) {
                ($0.1, $1)
            },
            perform: { previous, current in
                isSignedIn = current?.isEmpty == false
            }
        )
        .task {
            isSignedIn = authDefaults.token?.isEmpty == false
            do {
                try await provider.prepare()
                try await provider.refresh()
                jsonRoot = try JSONNode.loadBundledEarthquakes()
                await restoreSession()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    @MainActor func restoreSession() async {
        guard let token = authDefaults.token else {
            return
        }
        do {
            let restored = try await AuthRepository().session(token: token)
            sessionState = .signedIn(userID: restored.userID)
            await fetchFeed(token: restored.token, applyPhotosFilter: true)
        } catch {
            authDefaults.token = nil
            sessionState = .anonymous
        }
    }

    func signOut() {
        authDefaults.token = nil
        sessionState = .anonymous
        defaultFilter = nil
        fetchDate += 1
        do {
            jsonRoot = try JSONNode.loadBundledEarthquakes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor func fetchFeed(token: String, applyPhotosFilter: Bool) async {
        do {
            let photos = try await RemotePhotosProvider().fetch(token: token)
            jsonRoot = try JSONNode.loadCombinedEarthquakesAndPhotos(photos)
            if applyPhotosFilter {
                defaultFilter = .category(
                    path: "$.type",
                    value: "photograph",
                    values: ["Feature", "photograph"]
                )
                fetchDate += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    let database = try! Database(path: ":memory:")
    QuakesView(provider: QuakesProvider(database: database))
}
#endif
