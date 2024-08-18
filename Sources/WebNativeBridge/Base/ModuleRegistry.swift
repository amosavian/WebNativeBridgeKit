//
//  ModuleRegistry.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import WebKit

@frozen
public struct ModuleName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public protocol Module {
    static var name: ModuleName { get }
    
    @MainActor
    static var registrationScript: String { get }
    
    @MainActor
    static var events: [EventName: EventPublisher] { get }

    @MainActor
    static var functions: [FunctionName: FunctionSignature] { get }
}

extension Module {
    @MainActor
    static var events: [EventName: EventPublisher] { [:] }
    
    @MainActor
    public static var registrationScript: String {
        let functionsList = functions.keys.map { functionName in
            """
            \(functionName): function (args = {}) {
                return window.webkit.messageHandlers.\(name).postMessage({"functionName": \(functionName), ...args});
            }
            """
        }
        return "let \(name) = {" + functionsList.joined(separator: ",\n") + "}"
    }
}

@MainActor
public final class ModuleRegistry {
    public static let shared = ModuleRegistry()
    
    private var functionRegistries: [ModuleName: [FunctionName: FunctionSignature]] = [:]
    
    public func add(function name: FunctionName, in module: ModuleName, body: @escaping FunctionSignature) {
        if functionRegistries.keys.contains(module) {
            functionRegistries[module]![name] = body
        } else {
            functionRegistries[module] = [name: body]
        }
    }
    
    public func add<M: Module>(module: M.Type) {
        assert(!functionRegistries.keys.contains(module.name), "Module \(module.name) is already registered.")
        functionRegistries[module.name] = module.functions
    }
    
    public func remove(function name: FunctionName, from moduleName: ModuleName) {
        functionRegistries[moduleName]?.removeValue(forKey: name)
    }
    
    public func execute(context: FunctionContext, module: ModuleName, _ name: FunctionName, _ args: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let body = functionRegistries[module]?[name] else {
            return nil
        }
        return try await body(context, args)
    }
}

extension Collection {
    subscript(safe position: Self.Index) -> Self.Element? {
        guard position < endIndex else {
            return nil
        }
        return self[position]
    }
}
