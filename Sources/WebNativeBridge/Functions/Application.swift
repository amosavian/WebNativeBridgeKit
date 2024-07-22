//
//  Application.swift
//
//
//  Created by Amir Abbas Mousavian on 7/17/24.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ApplicationFunction: CallableFunctionRegistry {
    static let allFunctions: [FunctionName: FunctionSignature] = [
        "application.getWindowTitle": getWindowTitle,
        "application.setWindowTitle": setWindowTitle,
        "application.openURL": openURL,
    ]
    
    @MainActor
    static func getWindowTitle(_: FunctionContext, _: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        return UIApplication.shared.currentScenes.first?.title
#elseif canImport(AppKit)
        return NSApplication.shared.keyWindow?.title
#endif
    }
    
    @MainActor
    static func setWindowTitle(_: FunctionContext, _ args: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        UIApplication.shared.currentScenes.first?.title = args.first as? String ?? ""
#elseif canImport(AppKit)
        NSApplication.shared.keyWindow?.title = args.first as? String ?? ""
#endif
        return nil
    }
    
    @MainActor
    static func openURL(_: FunctionContext, _ args: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard let url = (args.first as? String).flatMap(URL.init(string:)) else {
            return false
        }
        let universalLink = args[safe: 1] as? Bool ?? false
#if canImport(UIKit)
        let options = UIScene.OpenExternalURLOptions()
        options.universalLinksOnly = universalLink
        return await UIApplication.shared.currentScenes.first?.open(url, options: options)
#elseif canImport(AppKit)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.requiresUniversalLinks = universalLink
        try await NSWorkspace.shared.open(url, configuration: configuration)
        return true
#endif
    }
}

#if canImport(UIKit)
extension UIApplication {
    @MainActor
    var currentScenes: [UIWindowScene] {
        UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
    }
}
#endif

#if compiler(>=6.0)
extension NSRunningApplication: @retroactive @unchecked Sendable {}
#endif
