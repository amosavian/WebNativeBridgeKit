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
#elseif canImport(AppKit)
import AppKit
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
        guard let vc = context.webView?.parentViewController as? (any PreferenceCustomizableViewController) else { return nil }
        
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
    private static func screenshotInfo(_ webView: WKWebView,_ kwArgs: FunctionArguments) async throws -> (rect: CGRect?, format: WKWebView.ImageType) {
        let rect: CGRect?
        if let id = kwArgs[.elementID] as? String {
            rect = try await webView.rectOfElement(id: id)
        } else {
            rect = nil
        }
        
        let format = (kwArgs[.format] as? String).flatMap {
            WKWebView.ImageType($0, compressionQuality: kwArgs[.compressionQuality] as? Double ?? 0.9)
        } ?? .png
        return (rect, format)
    }
    
    @MainActor
    static func getScreenshot(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let webView = context.webView else {
            return nil
        }
        let (rect, format) = try await screenshotInfo(webView, kwArgs)
        return try await webView.screenshot(rect: rect, format: format)
    }
}

#if !canImport(UIKit) && canImport(AppKit)
extension NSImage {
    func pngData() -> Data? {
        (representations.first as? NSBitmapImageRep)?.representation(using: .png, properties: [:])
    }
    
    func jpegData(compressionQuality: CGFloat) -> Data? {
        (representations.first as? NSBitmapImageRep)?.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#endif

extension WKWebView {
    enum ImageType {
        case jpeg(compression: Double)
        case png
        case heic
        case pdf
        
        init?(_ mimeType: String, compressionQuality: Double = 0.9) {
            switch mimeType {
            case "image/jpeg":
                self = .jpeg(compression: compressionQuality)
            case "image/heic":
                self = .heic
            case "image/png":
                self = .png
            case "application/pdf":
                self = .pdf
            default:
                return nil
            }
        }
    }
    
    @MainActor
    func screenshot(rect: CGRect? = nil, format: ImageType) async throws -> Data? {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = rect ?? .null
        
        switch format {
        case .jpeg(let compressionQuality):
            let image = try await takeSnapshot(configuration: configuration)
            return image.jpegData(compressionQuality: compressionQuality)
        case .heic:
#if canImport(UIKit)
            if #available(iOS 17.0, macCatalyst 17.0, tvOS 17.0, visionOS 1.0, *) {
                let image = try await takeSnapshot(configuration: configuration)
                return image.heicData()
            }
#endif
            return nil
        case .png:
            let image = try await takeSnapshot(configuration: configuration)
            return image.pngData()
        case .pdf:
            let configuration = WKPDFConfiguration()
            configuration.rect = rect ?? .null
            return try await pdf(configuration: configuration)
        }
    }
}

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

extension CGRect {
    var dictionary: [String: Double] {
        [
            "x": origin.x,
            "y": origin.y,
            "width": width,
            "height": height,
        ]
    }
    
    init(from dictionary: [String: Double]) {
        let x = dictionary["x"] ?? 0
        let y = dictionary["y"] ?? 0
        let width = dictionary["width"] ?? 0
        let height = dictionary["height"] ?? 0
        self.init(x: x, y: y, width: width, height: height)
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
        var keyboardFrameBeginUserInfoKey: String = ""
        var keyboardFrameEndUserInfoKey: String = ""
        var keyboardAnimationDurationUserInfoKey: String = ""
        var keyboardAnimationCurveUserInfoKey: String = ""
        MainActor.assumeIsolated {
            keyboardFrameBeginUserInfoKey = UIView.keyboardFrameBeginUserInfoKey
            keyboardFrameEndUserInfoKey = UIView.keyboardFrameEndUserInfoKey
            keyboardAnimationDurationUserInfoKey = UIView.keyboardAnimationDurationUserInfoKey
            keyboardAnimationCurveUserInfoKey = UIView.keyboardAnimationCurveUserInfoKey
        }
        return [
            "beginFrame": (self[keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.dictionary,
            "endFrame": (self[keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.dictionary,
            "duration": (self[keyboardAnimationDurationUserInfoKey] as? Double),
            "curve": (self[keyboardAnimationCurveUserInfoKey] as? Int)
                .flatMap(UIView.AnimationCurve.init(rawValue:))?.string,
        ]

    }
}
#endif
