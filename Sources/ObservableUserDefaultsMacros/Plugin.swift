//
//  Plugin.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ObservableUserDefaultsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DefaultKeyMacro.self,
        DefaultsMacro.self,
        RegisteredMacro.self,
    ]
}
