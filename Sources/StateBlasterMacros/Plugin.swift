//
//  Plugin.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StateBlasterPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] {
        [
            StateMachineMacro.self,
            StateMachineModelMacro.self,
            MachineStateMacro.self,
            ScreenMacro.self,
            SwiftUIPresentationMacro.self,
        ]
    }
}
