import Muttniks
import SwiftUI

@main
struct EarthquakesApp: App {
    let quakesProvider: QuakesProvider

    init() {
        do {
            let directory = URL.applicationSupportDirectory.appendingPathComponent("MuttniksDemo", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let database = try Database(path: directory.appendingPathComponent("SampleData.sqlite").path)
            quakesProvider = try QuakesProvider(database: database)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            QuakesView(provider: quakesProvider)
        }
    }
}
