//
//  StateBlaster.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/13/26.
//

public enum StateMachineMode {
    case witness
    case transitionAuthority
    case scopedStateAuthority
    case stateAuthority
}

@attached(peer, names: suffixed(Machine))
public macro StateMachine(
    mode: StateMachineMode = .witness
) =
    #externalMacro(
        module: "StateBlasterMacros",
        type: "StateMachineMacro"
    )

@attached(member, names: named(machine))
public macro StateMachineModel(
    _ machine: Any.Type,
    state: String = "state"
) =
    #externalMacro(
        module: "StateBlasterMacros",
        type: "StateMachineModelMacro"
    )

@attached(peer)
public macro MachineState(
    initial: Bool = false,
    transitions: [String] = [],
    back: String? = nil
) =
    #externalMacro(
        module: "StateBlasterMacros",
        type: "MachineStateMacro"
    )

public enum ScreenKind {
    case form, progress, error, help, success
}

public struct ScreenField: Sendable {
    public enum Kind: Sendable { case text }
    public let kind: Kind
    public let name: String
    public let label: String
    public let contentType: String?

    private init(kind: Kind, name: String, label: String, contentType: String?) {
        self.kind = kind; self.name = name; self.label = label; self.contentType = contentType
    }

    public static func text(_ name: String, label: String, contentType: String? = nil) -> Self {
        .init(kind: .text, name: name, label: label, contentType: contentType)
    }
}

public indirect enum ScreenCondition: Sendable {
    case always
    case flag(String)
    case nonEmpty(String)
    case not(ScreenCondition)
    case all([ScreenCondition])
    case any([ScreenCondition])
}

public struct ScreenAction: Sendable {
    public enum Kind: Sendable { case sync, async }
    public let kind: Kind
    public let name: String
    public let title: String
    public let enabledWhen: ScreenCondition

    private init(kind: Kind, name: String, title: String, enabledWhen: ScreenCondition) {
        self.kind = kind; self.name = name; self.title = title; self.enabledWhen = enabledWhen
    }

    public static func sync(_ name: String, title: String, enabledWhen: ScreenCondition = .always) -> Self {
        .init(kind: .sync, name: name, title: title, enabledWhen: enabledWhen)
    }
    public static func async(_ name: String, title: String, enabledWhen: ScreenCondition = .always) -> Self {
        .init(kind: .async, name: name, title: title, enabledWhen: enabledWhen)
    }
}

@attached(peer)
public macro Screen(
    title: String,
    message: String,
    systemImage: String,
    kind: ScreenKind,
    fields: [ScreenField] = [],
    actions: [ScreenAction] = [],
    visibleWhen: ScreenCondition = .always,
    fallback: ScreenKind? = nil
) =
    #externalMacro(
        module: "StateBlasterMacros",
        type: "ScreenMacro"
    )

@attached(peer)
public macro SwiftUIPresentation() =
    #externalMacro(
        module: "StateBlasterMacros",
        type: "SwiftUIPresentationMacro"
    )
