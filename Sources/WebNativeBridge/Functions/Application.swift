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

extension FunctionArgumentName {
    fileprivate static let title: Self = "title"
    fileprivate static let url: Self = "url"
    fileprivate static let universalLink: Self = "universalLink"
}

struct ApplicationModule: Module {
    static let name: ModuleName = "application"
    
#if canImport(UIKit)
    @MainActor
    static let events: [EventName: EventPublisher] = [
        "userDidTakeScreenshot": NotificationCenter.default.webEvent(for: UIApplication.userDidTakeScreenshotNotification),
        "pasteboardChanged": NotificationCenter.default.webEvent(for: UIPasteboard.changedNotification),
        "systemTimeZoneDidChange": NotificationCenter.default.webEvent(for: Notification.Name.NSSystemTimeZoneDidChange),
        "systemClockDidChange": NotificationCenter.default.webEvent(for: Notification.Name.NSSystemClockDidChange),
        "calendarDayChanged": NotificationCenter.default.webEvent(for: Notification.Name.NSCalendarDayChanged),
        "significantTimeChange": NotificationCenter.default.webEvent(for: UIApplication.significantTimeChangeNotification),
    ]
#elseif canImport(AppKit)
    @MainActor
    static let events: [EventName: EventPublisher] = [
        "pasteboardChanged": NSPasteboard.general
            .publisher(for: \.changeCount)
            .receive(on: DispatchQueue.main)
            .map { _ -> EventPublisher.Output in
                [:]
            }
            .eraseToAnyPublisher(),
        "systemTimeZoneDidChange": NotificationCenter.default.webEvent(for: Notification.Name.NSSystemTimeZoneDidChange),
        "systemClockDidChange": NotificationCenter.default.webEvent(for: Notification.Name.NSSystemClockDidChange),
        "calendarDayChanged": NotificationCenter.default.webEvent(for: Notification.Name.NSCalendarDayChanged),
    ]
#endif
    
    static let functions: [FunctionName: FunctionSignature] = [
        "getWindowTitle": getWindowTitle,
        "setWindowTitle": setWindowTitle,
        "openURL": openURL,
    ]
    
    @MainActor
    static func getWindowTitle(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        return UIApplication.shared.currentScenes.first?.title
#elseif canImport(AppKit)
        return NSApplication.shared.keyWindow?.title
#endif
    }
    
    @MainActor
    static func setWindowTitle(_: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let title = kwArgs[.title] as? String else { return nil }
#if canImport(UIKit)
        UIApplication.shared.currentScenes.first?.title = title
#elseif canImport(AppKit)
        NSApplication.shared.keyWindow?.title = title
#endif
        return nil
    }
    
    @MainActor
    static func openURL(_: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let url = (kwArgs[.url] as? String).flatMap(URL.init(string:)) else {
            return false
        }
        let universalLink = kwArgs[.universalLink] as? Bool ?? false
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
            .filter { $0.activationState != .unattached }
            .sorted { $0.activationState.rawValue < $1.activationState.rawValue }
            .compactMap { $0 as? UIWindowScene }
    }
}
#endif

#if compiler(>=6.0) && !canImport(UIKit)
extension NSRunningApplication: @retroactive @unchecked Sendable {}
#endif
