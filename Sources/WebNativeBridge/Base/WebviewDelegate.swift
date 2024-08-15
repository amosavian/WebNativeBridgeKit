//
//  WebviewDelegate.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import WebKit
import Combine

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
        AccessibilityModule.self,
        ApplicationModule.self,
        BiometricModule.self,
        ContactsModule.self,
        DeviceModule.self,
        HapticsModule.self,
        SecurityModule.self,
        ViewModule.self,
    ]
    
    @MainActor
    public func registerFunctions<M: Module>(module: M.Type, registry: ModuleRegistry = .shared) {
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

extension WKWebView {
    @MainActor
    func rectOfElement(id: String) async throws -> CGRect? {
        let js = """
        function f() {
            var r = document.getElementById('\(id)').getBoundingClientRect();
            if (r) {
                return '{"x": '+r.x+',"y": '+r.y+',"width": '+r.width+',"height": '+r.height+'}';
            }
            return null;
        }
        f();
        """
        guard let rectString = try await evaluateJavaScript(js) as? String else {
            return nil
        }
        let rectDictionary = try JSONDecoder().decode([String: Double].self, from: .init(rectString.utf8))
        return .init(from: rectDictionary)
    }
}

#if canImport(UIKit)
enum KeyboardCancellableKey: CancellableKey {
    nonisolated(unsafe) static var key: Int8 = 0
}

extension WKWebView {
    var keyboardCancellables: Set<AnyCancellable> {
        get { self[KeyboardCancellableKey.self] }
        set { self[KeyboardCancellableKey.self] = newValue }
    }
    
    @MainActor
    private func updateKeyboard(_ notification: Notification) {
        guard let frame = (notification.userInfo?[UIView.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        CATransaction.begin()
        let keyboardTiming = CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)
        CATransaction.setAnimationTimingFunction(keyboardTiming)
        setMinimumViewportInset(
            .init(
                top: 0, left: 0,
                bottom: frame.height, right: 0
            ),
            maximumViewportInset: .init(
                top: 0, left: 0,
                bottom: frame.height, right: 0
            )
        )
        CATransaction.commit()
    }
    
    @MainActor
    public func observeKeyboard() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .merge(
                with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification),
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification))
            .receive(on: DispatchQueue.main)
            .sink { @MainActor [weak self] notification in
                self?.updateKeyboard(notification)
            }
            .store(in: &keyboardCancellables)
    }
}
#endif
