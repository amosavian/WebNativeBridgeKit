//
//  Device.swift
//
//
//  Created by Amir Abbas Mousavian on 7/17/24.
//

import Foundation

extension FunctionArgumentName {
    fileprivate static let level: Self = level
}

struct DeviceModule: Module {
    static let name: ModuleName = "device"
    
#if canImport(UIKit)
    @MainActor
    static let events: [EventName: EventPublisher] = [
        "batteryLevelDidChange": NotificationCenter.default.webEvent(for: UIDevice.batteryLevelDidChangeNotification),
        "batteryStateDidChange": NotificationCenter.default.webEvent(for: UIDevice.batteryStateDidChangeNotification),
        "brightnessDidChange": NotificationCenter.default.webEvent(for: UIScreen.brightnessDidChangeNotification),
        "proximityStateDidChange": NotificationCenter.default.webEvent(for: UIDevice.proximityStateDidChangeNotification),
    ]
#endif
    
    static let functions: [FunctionName: FunctionSignature] = [
        "getInfo": deviceInfo,
        "setBrightness": setBrightness,
        "enableMonitoring": enableMonitoring,
    ]
    
    static func deviceInfo(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        await DeviceInfo()
    }
    
    @MainActor
    static func setBrightness(_: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let brightness = (kwArgs[.level] as? CGFloat) else {
            return nil
        }
#if canImport(UIKit)
        let screen = UIApplication.shared.currentScenes.first?.screen ?? UIScreen.main
        screen.brightness = brightness
#endif
        return nil
    }
    
    @MainActor
    static func enableMonitoring(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        UIDevice.current.isProximityMonitoringEnabled = true
#endif
        return nil
    }
}

struct DeviceInfo: Encodable, Sendable {
    let id: String
    let persistedID: String
    let name: String
    let model: String
    let osName: String
    let osVersion: String
    let deviceOrientation: String
    let batteryState: String
    let batteryLevel: Float
    let isLowPowerEnabled: Bool
    let proximityState: Bool
    let idiom: String
    let processorCount: Int
    let physicalMemory: UInt64
    let systemUptime: TimeInterval
    let screenSize: CGSize
    let screenBrightness: CGFloat
}

#if canImport(UIKit.UIDevice)
import UIKit

extension DeviceInfo {
    @MainActor
    init() {
        let device = UIDevice.current
        let info = ProcessInfo.processInfo
        self.id = device.identifierForVendor?.uuidString ?? UUID().uuidString
        self.persistedID = device.identifierForVendor?.uuidString ?? UUID().uuidString
        self.name = device.name
        self.model = device.model
        self.osName = device.systemName
        self.osVersion = device.systemVersion
        self.deviceOrientation = device.orientation.name
        self.batteryState = device.batteryState.name
        self.batteryLevel = device.batteryLevel
        self.isLowPowerEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.proximityState = device.proximityState
        if info.isMacCatalystApp {
            self.idiom = "macCatalyst"
        } else if info.isiOSAppOnMac {
            self.idiom = "mac"
        } else {
            self.idiom = device.userInterfaceIdiom.name
        }
        self.processorCount = info.processorCount
        self.physicalMemory = info.physicalMemory
        self.systemUptime = info.systemUptime
        let screen = UIApplication.shared.currentScenes.first?.screen ?? UIScreen.main
        self.screenSize = screen.bounds.size
        self.screenBrightness = screen.brightness
    }
}

extension UIDeviceOrientation {
    var name: String {
        switch self {
        case .unknown:
            "unknown"
        case .portrait:
            "portrait"
        case .portraitUpsideDown:
            "portraitUpsideDown"
        case .landscapeLeft:
            "landscapeLeft"
        case .landscapeRight:
            "landscapeRight"
        case .faceUp:
            "faceUp"
        case .faceDown:
            "faceDown"
        @unknown default:
            "unknown"
        }
    }
}

extension UIDevice.BatteryState {
    var name: String {
        switch self {
        case .unknown:
            "unknown"
        case .unplugged:
            "unplugged"
        case .charging:
            "charging"
        case .full:
            "full"
        @unknown default:
            "unknown"
        }
    }
}

extension UIUserInterfaceIdiom {
    var name: String {
        switch self {
        case .unspecified:
            "unspecified"
        case .phone:
            "phone"
        case .pad:
            "pad"
        case .tv:
            "tv"
        case .carPlay:
            "carPlay"
        case .mac:
            "mac"
        case .vision:
            "vision"
        @unknown default:
            "unspecified"
        }
    }
}

#elseif canImport(AppKit)
import AppKit
import IOKit.ps

extension DeviceInfo {
    @MainActor
    init() {
        let info = ProcessInfo.processInfo
        self.id = UUID().uuidString
        self.persistedID = UUID().uuidString
        self.name = info.hostName
        self.model = DeviceInfo.modelIdentifier() ?? "Unknown"
        self.osName = "macos"
        self.osVersion = info.operatingSystemVersionString
        self.deviceOrientation = "unknown"
        self.batteryState = "unknown"
        self.batteryLevel = Self.batteryLevel() ?? 1
        self.isLowPowerEnabled = false
        self.proximityState = false
        self.idiom = "mac"
        self.processorCount = info.processorCount
        self.physicalMemory = info.physicalMemory
        self.systemUptime = info.systemUptime
        let screen = NSScreen.main
        self.screenSize = screen?.frame.size ?? .zero
        self.screenBrightness = 1
    }
    
    private static func modelIdentifier() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            return modelData.withUnsafeBytes { (cString: UnsafeRawBufferPointer) -> String in
                return String(cString: cString.assumingMemoryBound(to: UInt8.self).baseAddress!)
            }
        }

        return nil
    }
    
    private static func batteryLevel() -> Float? {
        // Take a snapshot of all the power source info
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()

        // Pull out a list of power sources
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        // For each power source...
        for ps in sources {
            // Fetch the information for a given power source out of our snapshot
            let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as! [String: AnyObject]

            // Pull out the name and capacity
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
               let max = info[kIOPSMaxCapacityKey] as? Int
            {
                return Float(Double(capacity) / Double(max))
            }
        }
        return nil
    }
}

#endif
