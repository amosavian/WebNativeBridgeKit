//
//  ModuleRegistry.swift
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
    
    init(frame: WKFrameInfo) {
        self.url = frame.request.url
        self.securityOrigin = frame.securityOrigin.url
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
    
    init(_ message: WKScriptMessage) {
        self.webView = message.webView
        self.frameInfo = .init(frame: message.frameInfo)
    }
    
    @MainActor
    public func checkSameSecurityOrigin() -> Bool {
        guard let mainURL = webView?.url else {
            return false
        }
        return mainURL.host == frameInfo.securityOrigin?.host
    }
}

public protocol Module {
    static var name: ModuleName { get }
    
    static var registrationScript: String { get }
    
    static var functions: [FunctionName: FunctionSignature] { get }
}

extension Module {
    public static var registrationScript: String { "" }
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

extension WKSecurityOrigin {
    public var url: URL? {
        var securityOrigin = URLComponents()
        securityOrigin.scheme = self.protocol
        securityOrigin.host = host
        securityOrigin.port = port
        return securityOrigin.url
    }
}
