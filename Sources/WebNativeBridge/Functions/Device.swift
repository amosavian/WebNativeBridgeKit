//
//  Device.swift
//
//
//  Created by Amir Abbas Mousavian on 7/17/24.
//

import Combine
import Foundation

struct DeviceFunction: CallableFunctionRegistry {
    static let allFunctions: [FunctionName: FunctionSignature] = [
        "device.getInfo": deviceInfo,
        "device.setBrightness": setBrightness,
    ]
    
    static func deviceInfo(_: FunctionContext, _: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit.UIDevice)
        return await DeviceInfo()
#else
        return nil
#endif
    }
    
    @MainActor
    static func setBrightness(_: FunctionContext, _ args: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
#if canImport(UIKit)
        guard let brightness = (args.first as? CGFloat) else {
            return nil
        }
        let screen = UIApplication.shared.currentScenes.first?.screen ?? UIScreen.main
        screen.brightness = brightness
        return nil
#else
        return nil
#endif
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
#endif
