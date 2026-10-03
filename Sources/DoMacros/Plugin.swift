//
//  Plugin.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DoPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DoMacro.self,
        BindMacro.self,
    ]
}
