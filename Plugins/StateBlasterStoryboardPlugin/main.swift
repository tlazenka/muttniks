//
//  main.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/26/26.
//

import Foundation
import PackagePlugin

@main
struct StateBlasterStoryboardPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let tool = try context.tool(named: "StateBlasterStoryboardGenerator")
        let outputDirectory = context.pluginWorkDirectoryURL
            .appending(path: "GeneratedPresentation", directoryHint: .isDirectory)

        let presentationSources: [URL] = context.package.targets
            .compactMap { $0 as? SourceModuleTarget }
            .flatMap { sourceTarget in
                sourceTarget.sourceFiles
                    .filter { $0.type == .source && $0.url.pathExtension == "swift" }
                    .map(\.url)
            }
            .sorted { $0.path() < $1.path() }

        let generatedSwift =
            outputDirectory
            .appending(path: "\(target.name).generated.swift")
        let generatedStoryboard =
            outputDirectory
            .appending(path: "\(target.name).generated.storyboard")

        var arguments = [
            target.name,
            generatedSwift.path(),
            generatedStoryboard.path(),
        ]
        arguments.append(contentsOf: presentationSources.map { $0.path() })

        return [
            .buildCommand(
                displayName: "Generate UIKit and Interface Builder presentation from @Screen",
                executable: tool.url,
                arguments: arguments,
                inputFiles: presentationSources,
                outputFiles: [generatedSwift, generatedStoryboard]
            )
        ]
    }
}
