import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StateMachinePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StateMachineContractsMacro.self,
        BehaviorMarkerMacro.self,
    ]
}
