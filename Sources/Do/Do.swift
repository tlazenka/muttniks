//
//  Do.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/27/26.
//

@attached(body)
public macro Do() = #externalMacro(module: "DoMacros", type: "DoMacro")

@freestanding(expression)
public macro bind<Success, Failure: Error>(
    _ result: Result<Success, Failure>
) -> Success = #externalMacro(module: "DoMacros", type: "BindMacro")
