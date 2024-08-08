//
//  View.swift
//
//
//  Created by Amir Abbas Mousavian on 7/17/24.
//

import CoreGraphics
import Foundation
import WebKit
#if canImport(UIKit)
import UIKit
#endif

extension FunctionArgumentName {
    fileprivate static let title: Self = "title"
    fileprivate static let style: Self = "style"
    fileprivate static let elementID: Self = "elementID"
    fileprivate static let format: Self = "format"
    fileprivate static let compressionQuality: Self = "compressionQuality"
}

struct ViewModule: Module {
    static let name: ModuleName = "view"
    
#if canImport(UIKit)
    @MainActor
    static let events: [EventName: EventPublisher] = [
        "keyboardWillShow": NotificationCenter.default
            .webEvent(
                for: UIResponder.keyboardWillShowNotification, \.mapKeyboardParams
            ),
        "keyboardDidShow": NotificationCenter.default
            .webEvent(for: UIResponder.keyboardDidShowNotification, \.mapKeyboardParams),
        "keyboardWillHide": NotificationCenter.default
            .webEvent(for: UIResponder.keyboardWillHideNotification, \.mapKeyboardParams),
        "keyboardDidHide": NotificationCenter.default
            .webEvent(for: UIResponder.keyboardDidHideNotification, \.mapKeyboardParams),
    ]
#endif
    
    static let functions: [FunctionName: FunctionSignature] = [
        "getViewTitle": getViewTitle,
        "setViewTitle": setViewTitle,
        "getStatusbarStyle": getStatusbarStyle,
        "setStatusbarStyle": setStatusbarStyle,
        "getScreenshot": getScreenshot,
    ]
    
    @MainActor
    static func getViewTitle(_ context: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        guard let vc = context.webView?.parentViewController else { return nil }
        return vc.navigationItem.title ?? vc.title
#elseif canImport(AppKit)
        fatalError("Not implemented")
#else
        return nil
#endif
    }
    
    @MainActor
    static func setViewTitle(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let title = kwArgs[.title] as? String else {
            return nil
        }
#if canImport(UIKit)
        guard let vc = context.webView?.parentViewController else { return nil }
        
        vc.navigationItem.title = title
        return nil
#elseif canImport(AppKit)
        fatalError("Not implemented")
#else
        return nil
#endif
    }
    
    @MainActor
    static func getStatusbarStyle(_ context: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        guard let vc = context.webView?.parentViewController else { return nil }
        
        return switch (vc.prefersStatusBarHidden, vc.preferredStatusBarStyle) {
        case (true, _):
            "none"
        case (_, .default):
            "default"
        case (_, .darkContent):
            "light"
        case (_, .lightContent):
            "dark"
        case (false, _):
            nil
        }
#else
        return nil
#endif
    }
    
    @MainActor
    static func setStatusbarStyle(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let style = kwArgs[.style] as? String else {
            return nil
        }
#if canImport(UIKit)
        guard let vc = context.webView?.parentViewController as? PreferenceCustomizableViewController else { return nil }
        
        switch style {
        case "none":
            vc.prefersStatusBarHidden = true
        case "default":
            vc.prefersStatusBarHidden = false
            vc.preferredStatusBarStyle = .default
        case "light":
            vc.prefersStatusBarHidden = false
            vc.preferredStatusBarStyle = .darkContent
        case "dark":
            vc.prefersStatusBarHidden = false
            vc.preferredStatusBarStyle = .lightContent
        default:
            break
        }
        vc.setNeedsStatusBarAppearanceUpdate()
        return nil
#else
        return nil
#endif
    }
    
    @MainActor
    static func getScreenshot(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let webView = context.webView else {
            return nil
        }
        let rect: CGRect?
        if let id = kwArgs[.elementID] as? String {
            rect = try await webView.rectOfElement(id: id)
        } else {
            rect = nil
        }
        
        let configuration = WKSnapshotConfiguration()
        configuration.rect = rect ?? .null
        let image = try await webView.takeSnapshot(configuration: configuration)
        switch kwArgs[.format] as? String {
        case "image/jpeg":
            let compressionQuality = kwArgs[.compressionQuality] as? Double ?? 0.9
            return image.jpegData(compressionQuality: compressionQuality)
        case "image/heic":
#if canImport(UIKit)
            if #available(iOS 17.0, *) {
                return image.heicData()
            }
#endif
            return nil
        case "image/png":
            fallthrough
        default:
            return image.pngData()
        }
    }
}

#if canImport(AppKit)
extension NSImage {
    func pngData() -> Data? {
        (representations.first as? NSBitmapImageRep)?.representation(using: .png, properties: [:])
    }
    
    func jpegData(compressionQuality: CGFloat) -> Data? {
        (representations.first as? NSBitmapImageRep)?.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#endif

#if canImport(UIKit)
public protocol PreferenceCustomizableViewController: UIViewController {
    var preferredStatusBarStyle: UIStatusBarStyle { get set }
    var prefersStatusBarHidden: Bool { get set }
}

extension UIStatusBarStyle {
    fileprivate init(name: String?) {
        switch name {
        case "default":
            self = .default
        case "lightContent":
            self = .lightContent
        case "darkContent":
            self = .darkContent
        default:
            self = .default
        }
    }
    
    fileprivate var name: String {
        switch self {
        case .default:
            "default"
        case .lightContent:
            "lightContent"
        case .darkContent:
            "darkContent"
        @unknown default:
            "default"
        }
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        // Starts from next (As we know self is not a UIViewController).
        var parentResponder: UIResponder? = next
        while parentResponder != nil {
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}
#endif

extension WKWebView {
    @MainActor
    func rectOfElement(id: String) async throws -> CGRect? {
        let js = """
        function f() {
            var r = document.getElementById('\(id)').getBoundingClientRect();
            if (r) {
                return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}';
            }
            return null;
        }
        f();
        """
        let rect = try await evaluateJavaScript(js) as? String
#if canImport(UIKit)
        return rect.map(NSCoder.cgRect(for:))
#else
        return nil
#endif
    }
}

extension CGRect {
    var dictionary: [String: Double] {
        [
            "x": origin.x,
            "y": origin.y,
            "width": width,
            "height": height,
        ]
    }
}

#if canImport(UIKit)
extension UIView.AnimationCurve {
    var string: String {
        switch self {
        case .easeInOut:
            "ease-in-out"
        case .easeIn:
            "ease-in"
        case .easeOut:
            "ease-out"
        case .linear:
            "linear"
        @unknown default:
            "linear"
        }
    }
}

extension [AnyHashable: Any] {
    var mapKeyboardParams: [String: any Encodable & Sendable]? {
        MainActor.assumeIsolated {
            [
                "beginFrame": (self[UIView.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.dictionary,
                "endFrame": (self[UIView.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.dictionary,
                "duration": (self[UIView.keyboardAnimationDurationUserInfoKey] as? Double),
                "curve": (self[UIView.keyboardAnimationDurationUserInfoKey] as? Int)
                    .flatMap(UIView.AnimationCurve.init(rawValue:))?.string,
            ]
        }
    }
}
#endif
