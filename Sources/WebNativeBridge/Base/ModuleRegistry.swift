//
//  ModuleRegistry.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import WebKit

public protocol Module {
    static var name: ModuleName { get }
    
    @MainActor
    static var registrationScript: String { get }
    
    @MainActor
    static var functions: [FunctionName: FunctionSignature] { get }
}

@frozen
public struct ModuleName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension Module {
    @MainActor
    public static var registrationScript: String {
        var result = ""
        for functionName in functions.keys {
            result += """
            function \(functionName)(args) {
                window.webkit.messageHandlers.\(name).postMessage({"name": \(functionName), ...args});
            };
            """
        }
        return result
    }
}

@MainActor
public final class ModuleRegistry {
    public static let shared = ModuleRegistry()
    
    private var registries: [ModuleName: [FunctionName: FunctionSignature]] = [:]
    
    public func addFunction(module: ModuleName, name: FunctionName, body: @escaping FunctionSignature) {
        if registries.keys.contains(module) {
            registries[module]![name] = body
        } else {
            registries[module] = [name: body]
        }
    }
    
    public func addModule(of module: Module.Type) {
        assert(!registries.keys.contains(module.name))
        registries[module.name] = module.functions
    }
    
    public func removeFunction(_ name: FunctionName, from moduleName: ModuleName) {
        registries[moduleName]?.removeValue(forKey: name)
    }
    
    public func execute(context: FunctionContext, module: ModuleName, _ name: FunctionName, _ args: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let body = registries[module]?[name] else {
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
