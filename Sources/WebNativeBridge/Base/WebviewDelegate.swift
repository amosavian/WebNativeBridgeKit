//
//  WebviewDelegate.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import WebKit

open class WebBridgeMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    @MainActor
    private static var isCoreFunctionalityRegistered: Bool = false
    
    @MainActor
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        guard message.name == "nativeInterface" else {
            return (nil, nil)
        }
        guard let body = message.body as? [String: Any] else {
            return (nil, nil)
        }
        let context = FunctionContext(webView: message.webView, frameInfo: .init(frame: message.frameInfo))
        do {
            if !WebBridgeMessageHandler.isCoreFunctionalityRegistered {
                await CallableFunction.registerCoreFunctionalities()
            }
            let function = try Function(body)
            let result = try await CallableFunction.execute(function, context: context)
            return (result as AnyObject, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}
