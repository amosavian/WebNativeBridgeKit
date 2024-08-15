//
//  Accessibility.swift
//
//
//  Created by Amir Abbas Mousavian on 8/12/24.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AccessibilityModule: Module {
    static let name: ModuleName = "accessibility"
    
#if canImport(UIKit)
    @MainActor
    static let events: [EventName: EventPublisher] = [
        "contentSizeCategoryDidChange": NotificationCenter.default.webEvent(for: UIContentSizeCategory.didChangeNotification),
        "closedCaptioningStatusDidChange": NotificationCenter.default.webEvent(for: UIAccessibility.closedCaptioningStatusDidChangeNotification),
        "boldTextStatusDidChange": NotificationCenter.default.webEvent(for: UIAccessibility.boldTextStatusDidChangeNotification),
        "reduceMotionStatusDidChange": NotificationCenter.default.webEvent(for: UIAccessibility.reduceMotionStatusDidChangeNotification),
        "prefersCrossFadeTransitionsStatusDidChange": NotificationCenter.default.webEvent(for: UIAccessibility.prefersCrossFadeTransitionsStatusDidChange),
        "videoAutoplayStatusDidChangeNotification": NotificationCenter.default.webEvent(for: UIAccessibility.videoAutoplayStatusDidChangeNotification),
        "onOffSwitchLabelsDidChangeNotification": NotificationCenter.default.webEvent(for: UIAccessibility.onOffSwitchLabelsDidChangeNotification),
    ]
#elseif canImport(AppKit)
    @MainActor
    static let events: [EventName: EventPublisher] = [:]
#endif
    
    static let functions: [FunctionName: FunctionSignature] = [
        "getAccessibilitySettings": getAccessibilitySettings,
        "getTraits": getTraits,
    ]
    
    @MainActor
    static func getAccessibilitySettings(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        return AccessibilitySettings()
#else
        return nil
#endif
    }
    
    @MainActor
    static func getTraits(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        return Traits()
#else
        return nil
#endif
    }
}

struct AccessibilitySettings: Encodable, Sendable {
    let isVoiceOverRunning: Bool
    let isMonoAudioEnabled: Bool
    let isClosedCaptioningEnabled: Bool
    let isInvertColorsEnabled: Bool
    let isGuidedAccessEnabled: Bool
    let isBoldTextEnabled: Bool
    let buttonShapesEnabled: Bool
    let isGrayscaleEnabled: Bool
    let isReduceTransparencyEnabled: Bool
    let isReduceMotionEnabled: Bool
    let prefersCrossFadeTransitions: Bool
    let isVideoAutoplayEnabled: Bool
    let isDarkerSystemColorsEnabled: Bool
    let isSwitchControlRunning: Bool
    let isSpeakSelectionEnabled: Bool
    let isSpeakScreenEnabled: Bool
    let isShakeToUndoEnabled: Bool
    let isAssistiveTouchRunning: Bool
    let shouldDifferentiateWithoutColor: Bool
    let isOnOffSwitchLabelsEnabled: Bool
    
#if canImport(UIKit)
    @MainActor
    init() {
        self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        self.isMonoAudioEnabled = UIAccessibility.isMonoAudioEnabled
        self.isClosedCaptioningEnabled = UIAccessibility.isClosedCaptioningEnabled
        self.isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled
        self.isGuidedAccessEnabled = UIAccessibility.isGuidedAccessEnabled
        self.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        self.buttonShapesEnabled = UIAccessibility.buttonShapesEnabled
        self.isGrayscaleEnabled = UIAccessibility.isGrayscaleEnabled
        self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
        self.isVideoAutoplayEnabled = UIAccessibility.isVideoAutoplayEnabled
        self.isDarkerSystemColorsEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        self.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
        self.isSpeakSelectionEnabled = UIAccessibility.isSpeakSelectionEnabled
        self.isSpeakScreenEnabled = UIAccessibility.isSpeakScreenEnabled
        self.isShakeToUndoEnabled = UIAccessibility.isShakeToUndoEnabled
        self.isAssistiveTouchRunning = UIAccessibility.isAssistiveTouchRunning
        self.shouldDifferentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
        self.isOnOffSwitchLabelsEnabled = UIAccessibility.isOnOffSwitchLabelsEnabled
    }
#endif
}

struct Traits: Encodable, Sendable {
    var layoutDirection: String
    var preferredContentSizeCategory: String
    var accessibilityContrast: String
    var userInterfaceLevel: String
    var legibilityWeight: String
    var activeAppearance: String
    var sceneCaptureState: String
    
#if canImport(UIKit)
    init(traitCollection: UITraitCollection = .current) {
        self.layoutDirection = traitCollection.layoutDirection.description
        self.preferredContentSizeCategory = traitCollection.preferredContentSizeCategory.rawValue
            .replacingOccurrences(of: "UICTContentSizeCategory", with: "")
        self.accessibilityContrast = traitCollection.accessibilityContrast.description
        self.userInterfaceLevel = traitCollection.userInterfaceLevel.description
        self.legibilityWeight = traitCollection.legibilityWeight.description
        self.activeAppearance = traitCollection.activeAppearance.description
        if #available(iOS 17.0, macCatalyst 17.0, tvOS 17.0, visionOS 1.0, *) {
            self.sceneCaptureState = traitCollection.sceneCaptureState.description
        } else {
            self.sceneCaptureState = "unspecified"
        }
    }
#endif
}

#if canImport(UIKit)
extension UITraitEnvironmentLayoutDirection {
    fileprivate var description: String {
        switch self {
        case .unspecified:
            "auto"
        case .leftToRight:
            "ltr"
        case .rightToLeft:
            "rtl"
        @unknown default:
            "unknown"
        }
    }
}

extension UIAccessibilityContrast {
    fileprivate var description: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .normal:
            "normal"
        case .high:
            "high"
        @unknown default:
            "unspecified"
        }
    }
}

extension UIUserInterfaceLevel {
    fileprivate var description: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .base:
            "base"
        case .elevated:
            "elevated"
        @unknown default:
            "unspecified"
        }
    }
}

extension UILegibilityWeight {
    fileprivate var description: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .regular:
            "regular"
        case .bold:
            "bold"
        @unknown default:
            "unspecified"
        }
    }
}

extension UIUserInterfaceActiveAppearance {
    fileprivate var description: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .inactive:
            "inactive"
        case .active:
            "active"
        @unknown default:
            "unspecified"
        }
    }
}

@available(iOS 17.0, macCatalyst 17.0, tvOS 17.0, visionOS 1.0, *)
extension UISceneCaptureState {
    fileprivate var description: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .inactive:
            "inactive"
        case .active:
            "active"
        @unknown default:
            "unspecified"
        }
    }
}
#endif
