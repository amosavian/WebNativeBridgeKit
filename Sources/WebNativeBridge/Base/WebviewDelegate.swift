//
//  WebviewDelegate.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import WebKit

@MainActor
open class WebBridgeMessageHandler: NSObject, WKScriptMessageHandlerWithReply, @unchecked Sendable {
    public static let shared = WebBridgeMessageHandler(moduleRegistry: .shared)
    
    public let moduleRegistry: ModuleRegistry
    
    public init(moduleRegistry: ModuleRegistry) {
        self.moduleRegistry = moduleRegistry
    }
    
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        let moduleName = ModuleName(message.name)
        guard var body = message.body as? [String: any Sendable], let functionName = body["name"] as? String else {
            return (nil, nil)
        }
        _ = body.removeValue(forKey: "name")
        let arguments = FunctionArguments(uniqueKeysWithValues: body.map { (FunctionArgumentKeyword($0), $1) })
        
        do {
            let result = try await ModuleRegistry.shared.execute(
                context: .init(message),
                module: moduleName,
                .init(rawValue: functionName), arguments
            )
            return (result as AnyObject, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}

extension WKUserContentController {
    private static let coreModules: [any Module.Type] = [
        ApplicationModule.self,
        BiometricModule.self,
        ContactsModule.self,
        DeviceModule.self,
        HapticsModule.self,
        SecurityModule.self,
        ViewModule.self,
    ]
    
    @MainActor
    public func register(module: Module.Type, registry: ModuleRegistry = .shared) {
        registry.addModule(of: module)
        let handler: WebBridgeMessageHandler = registry === ModuleRegistry.shared ? .shared : .init(moduleRegistry: registry)
        addScriptMessageHandler(
            handler,
            contentWorld: .defaultClient,
            name: module.name.rawValue
        )
        addUserScript(.init(
            source: module.registrationScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
    }
    
    @MainActor
    public func registerCoreModules() {
        Self.coreModules.forEach { register(module: $0) }
    }
}
