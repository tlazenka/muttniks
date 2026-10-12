import SwiftUI

@main
struct WhaleyApp: App {
    var body: some Scene {
        WindowGroup {
            SrcWhaleyView { _, view in
            }
            .background(.black)
        }
    }
}
