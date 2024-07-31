//
//  CallableFunction.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import WebKit

public struct FrameInfo: Sendable {
    public let url: URL?
    public let securityOrigin: URL?
    public let isMainFrame: Bool
    public let webView: WKWebView?
    
    @MainActor
    init(frame: WKFrameInfo) {
        self.url = frame.request.url
        var securityOrigin = URLComponents()
        securityOrigin.scheme = frame.securityOrigin.protocol
        securityOrigin.host = frame.securityOrigin.host
        securityOrigin.port = frame.securityOrigin.port
        self.securityOrigin = securityOrigin.url
        self.isMainFrame = frame.isMainFrame
        self.webView = frame.webView
    }
}

public struct FunctionContext: Sendable {
    public let webView: WKWebView?
    public let frameInfo: FrameInfo
    
    init(webView: WKWebView?, frameInfo: FrameInfo) {
        self.webView = webView
        self.frameInfo = frameInfo
    }
    
    @MainActor
    public func checkSameSecurityOrigin() -> Bool {
        guard let mainURL = webView?.url else {
            return false
        }
        return mainURL.host == frameInfo.securityOrigin?.host
    }
}

@frozen
public struct FunctionArgumentKeyword: RawRepresentable, Codable, CodingKeyRepresentable, Hashable, Sendable, LosslessStringConvertible, ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public let rawValue: String
    
    public var description: String {
        rawValue
    }
    
    public var codingKey: String {
        rawValue
    }
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
    
    public init(_ description: String) {
        self.rawValue = description
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public typealias FunctionSignature = (_ context: FunctionContext, _ args: [Any], _ kwArgs: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)?

public protocol CallableFunctionRegistry {
    @MainActor
    static var allFunctions: [FunctionName: FunctionSignature] { get }
    
    @MainActor
    static func registerFunctions()
}

extension CallableFunctionRegistry {
    @MainActor
    public static var allFunctions: [FunctionName: FunctionSignature] { [:] }
    
    @MainActor
    public static func registerFunctions() {
        CallableFunction.addFunctions(allFunctions.map { ($0, $1) })
    }
}

public struct CallableFunction {
    @MainActor
    private static var registry: [FunctionName: FunctionSignature] = [:]
    
    public let name: FunctionName
    
    public init(name: FunctionName) {
        self.name = name
    }
    
    @MainActor
    public static func addFunction(name: FunctionName, body: @escaping FunctionSignature) {
        registry[name] = body
    }
    
    @MainActor
    public static func addFunctions(_ functions: [(name: FunctionName, body: FunctionSignature)]) {
        registry.merge(functions, uniquingKeysWith: { $1 })
    }
    
    @MainActor
    public static func removeFunction(_ name: FunctionName) {
        registry.removeValue(forKey: name)
    }
    
    @MainActor
    public static func removeFunctions(_ names: [FunctionName]) {
        names.forEach { registry.removeValue(forKey: $0) }
    }
    
    @MainActor
    public static func execute(_ function: Function, context: FunctionContext) async throws -> (any Encodable & Sendable)? {
        guard let body = registry[function.name] else {
            return nil
        }
        return try await body(context, function.args, function.kwArgs)
    }
    
    @MainActor
    func callAsFunction(_ context: FunctionContext, _ args: [any Sendable], _ kwArgs: [FunctionArgumentKeyword: any Sendable]) async throws -> (any Encodable)? {
        let function = Function(name: name, args: args, kwArgs: kwArgs)
        return try await Self.execute(function, context: context)
    }
}

extension CallableFunction {
    private static let coreFunctionalities: [any CallableFunctionRegistry.Type] = [
        ApplicationFunction.self,
        BiometricFunction.self,
        ContactsFunction.self,
        DeviceFunction.self,
        HapticsFunction.self,
        SecurityFunction.self,
        ViewFunction.self,
    ]
    
    public static func registerCoreFunctionalities() async {
        await coreFunctionalities.registerFunctions()
    }
}

extension [any CallableFunctionRegistry.Type] {
    func registerFunctions() async {
        for item in self {
            await item.registerFunctions()
        }
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
