//
//  RegisteredMacro.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct RegisteredMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
