//
//  Haptics.swift
//
//
//  Created by Amir Abbas Mousavian on 7/17/24.
//

import CoreHaptics
import Foundation
#if canImport(UIKit.UIFeedbackGenerator)
import UIKit
#endif

extension FunctionName {
    fileprivate static let haptic: Self = "haptic"
    fileprivate static let vibrate: Self = "vibrate"
}

extension FunctionArgumentName {
    fileprivate static let type: Self = "type"
    fileprivate static let style: Self = "style"
    fileprivate static let intensity: Self = "intensity"
    fileprivate static let notificationType: Self = "notificationType"
}

struct HapticsModule: Module {
    static let name: ModuleName = "haptics"
    
    static let functions: [FunctionName: FunctionSignature] = [
        .haptic: haptic,
        .vibrate: vibrate,
    ]
    
    @MainActor
    static func haptic(_: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit.UIFeedbackGenerator)
        switch kwArgs[.type] as? String {
        case "impact":
            let feedback = UIImpactFeedbackGenerator(style: .init(name: kwArgs[.style] as? String))
            if let intensity = kwArgs[.intensity] as? Double {
                feedback.impactOccurred(intensity: intensity)
            } else {
                feedback.impactOccurred()
            }
        case "selection":
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        case "notification":
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.init(name: kwArgs[.notificationType] as? String))
        default:
            break
        }
#endif
        return nil
    }
    
    @MainActor
    static var engine: CHHapticEngine?
    
    @MainActor
    static func vibrate(_: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let timeSeries = kwArgs.values.first else { return nil }
        
        switch timeSeries {
        case let durations as [NSNumber]:
            try await vibrate(timeSeries: durations.map(\.doubleValue).map { .init(duration: $0) })
        case let duration as NSNumber:
            try await vibrate(timeSeries: [.init(duration: duration.doubleValue)])
        default:
            break
        }
        
        return nil
    }
    
    private struct Vibration {
        let duration: TimeInterval
        let type: CHHapticEvent.EventType
        
        init(duration: TimeInterval, type: CHHapticEvent.EventType = .hapticContinuous) {
            self.duration = duration
            self.type = type
        }
    }
    
    @MainActor
    private static func vibrate(timeSeries: [Vibration]) async throws {
        if engine == nil {
            try await MainActor.run {
                engine = try CHHapticEngine()
                try engine?.start()
            }
            
            // If something goes wrong, attempt to restart the engine immediately
            engine?.resetHandler = {
                do {
                    try engine?.start()
                } catch {
                    print("Failed to restart the engine: \(error)")
                }
            }
        }
        
        var events: [CHHapticEvent] = []
        switch timeSeries.count {
        case 1:
            events = [
                .init(eventType: timeSeries[0].type, parameters: [], relativeTime: 0.6, duration: timeSeries[0].duration),
            ]
        default:
            var totalDuration: TimeInterval = 0.0
            for (index, action) in timeSeries.enumerated() {
                let duration = action.duration / 1000
                defer { totalDuration += duration }
                guard index.isMultiple(of: 2) else { continue }
                events.append(.init(eventType: action.type, parameters: [], relativeTime: totalDuration, duration: duration))
            }
        }
        let pattern = try CHHapticPattern(events: events, parameters: [])
        let player = try engine?.makePlayer(with: pattern)
        try player?.start(atTime: 0)
    }
}

#if canImport(UIKit.UIFeedbackGenerator)
extension UIImpactFeedbackGenerator.FeedbackStyle {
    init(name: String?) {
        switch name {
        case "light":
            self = .light
        case "medium":
            self = .medium
        case "heavy":
            self = .heavy
        case "soft":
            self = .soft
        case "rigid":
            self = .rigid
        default:
            self = .medium
        }
    }
}

extension UINotificationFeedbackGenerator.FeedbackType {
    init(name: String?) {
        switch name {
        case "success":
            self = .success
        case "error":
            self = .error
        case "warning":
            self = .warning
        default:
            self = .error
        }
    }
}
#endif
