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
        let arguments = FunctionArguments(uniqueKeysWithValues: body.map { (FunctionArgumentName($0), $1) })
        
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
    public func registerFunctions(module: Module.Type, registry: ModuleRegistry = .shared) {
        registry.add(module: module)
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
    public func registerCoreModulesFunctions() {
        Self.coreModules.forEach { registerFunctions(module: $0) }
    }
}

extension WKWebViewConfiguration {
    @MainActor
    public static func inline() -> WKWebViewConfiguration {
        let result = WKWebViewConfiguration()
#if canImport(UIKit)
        result.allowsInlineMediaPlayback = true
#endif
        result.mediaTypesRequiringUserActionForPlayback = []
        result.preferences.javaScriptCanOpenWindowsAutomatically = true
        result.userContentController.registerCoreModulesFunctions()
        return result
    }
}

#if canImport(UIKit)
extension WKWebView {
    @MainActor
    private func updateKeyboard(_ notification: Notification) {
        guard let frame = (notification.userInfo?[UIView.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        CATransaction.begin()
        let keyboardTiming = CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)
        CATransaction.setAnimationTimingFunction(keyboardTiming)
        setMinimumViewportInset(
            .init(
                top: 0, left: 0,
                bottom: frame.height, right: 0),
            maximumViewportInset: .init(
                top: 0, left: 0,
                bottom: frame.height, right: 0))
        CATransaction.commit()
    }
    
    @MainActor
    public func observeKeyboard() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil, queue: .main) { notification in
                MainActor.assumeIsolated { [weak self] in
                    self?.updateKeyboard(notification)
                }
            }
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil, queue: .main) { notification in
                MainActor.assumeIsolated { [weak self] in
                    self?.updateKeyboard(notification)
                }
            }
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil, queue: .main) { notification in
                MainActor.assumeIsolated { [weak self] in
                    self?.updateKeyboard(notification)
                }
            }
    }
}
#endif
