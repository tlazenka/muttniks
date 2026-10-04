//
//  Plugin.swift
//  Muttniks
//
//  Created by Francis Lazenka on 10/1/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MuttniksMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        JSONPathMacro.self
    ]
}
