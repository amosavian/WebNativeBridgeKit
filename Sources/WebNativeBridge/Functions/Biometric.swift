//
//  Biometric.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import LocalAuthentication

extension FunctionArgumentKeyword {
    fileprivate static let policy: Self = "policy"
    fileprivate static let localizedReason: Self = "localizedReason"
    fileprivate static let id: Self = "id"
    fileprivate static let credential: Self = "credential"
    static let synchronizable: Self = "synchronizable"
    fileprivate static let useBiometric: Self = "useBiometric"
    fileprivate static let useDevicePin: Self = "useDevicePin"
    fileprivate static let currentUser: Self = "currentUser"
}

struct BiometricModule: Module {
    static let name: ModuleName = "biometrics"
    
    static let functions: [FunctionName: FunctionSignature] = [
        "type": biometricType,
        "domainState": domainState,
        "canEvalulate": canEvaluate,
        "evaluate": evaluate,
        "setCredential": setCredential,
        "getCredential": getCredential,
    ]
    
    static func biometricType(_ context: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let context = LAContext()
        var error: NSError?
        let result = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if let error = error {
            throw error
        }
        if !result {
            return nil
        }
        return context.biometryType.name
    }
    
    static func domainState(_ context: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let context = LAContext()
        var error: NSError?
        let result = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if let error = error {
            throw error
        }
        if !result {
            return nil
        }
        return context.evaluatedPolicyDomainState
    }
    
    static func canEvaluate(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let policy = LAPolicy(name: kwArgs[.policy] as? String)
        
        var error: NSError?
        let result = LAContext().canEvaluatePolicy(policy, error: &error)
        if let error = error {
            throw error
        }
        return result
    }
    
    static func evaluate(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let policy = LAPolicy(name: kwArgs[.policy] as? String)
        let localizedReason = kwArgs[.localizedReason] as? String ?? ""
        
        let context = LAContext()
        return try await context.evaluatePolicy(policy, localizedReason: localizedReason)
    }
    
    static func setCredential(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let username = kwArgs[.id] as? String, let credential = kwArgs[.credential] as? String else {
            return nil
        }
        let syncronizable = (kwArgs[.synchronizable] as? Bool ?? false)
        guard let url = context.frameInfo.url, let host = url.host else { return nil }
        return try await Task.detached(priority: .userInitiated) {
            let query = try [
                kSecClass: kSecClassInternetPassword,
                kSecAttrProtocol: kSecAttrProtocolHTTPS,
                kSecAttrServer: host as CFString,
                kSecAttrSynchronizable: syncronizable ? kCFBooleanTrue! : kCFBooleanFalse!,
                kSecAttrAccount: username,
                kSecAttrAccessControl: SecAccessControl.create(kwArgs: kwArgs),
                kSecValueData: Data(credential.utf8),
            ] as CFDictionary
            
            return SecItemAdd(query, nil)
        }.value
    }
    
    static func getCredential(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let username = kwArgs[.id] as? String else {
            return nil
        }
        guard let url = context.frameInfo.url, let host = url.host else { return nil }
        
        // To prevent blocking main thread and UI.
        return try await Task.detached(priority: .userInitiated) {
            let query = [
                kSecClass: kSecClassInternetPassword,
                kSecAttrProtocol: kSecAttrProtocolHTTPS,
                kSecAttrServer: host as CFString,
                kSecAttrAccount: username,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny,
                kSecReturnData: kCFBooleanTrue!,
                kSecMatchLimit: kSecMatchLimitOne,
            ] as CFDictionary
            
            var dataTypeRef: AnyObject? = nil
            let status = SecItemCopyMatching(query, &dataTypeRef)
            if status == noErr {
                return (dataTypeRef as? Data).flatMap {
                    String(decoding: $0, as: UTF8.self)
                }
            } else {
                throw NSError(
                    domain: "kSecurityOSStatus",
                    code: Int(status),
                    userInfo: [
                        NSLocalizedDescriptionKey: SecCopyErrorMessageString(status, nil) ?? "",
                    ]
                )
            }
        }.value
    }
}

extension SecAccessControl {
    static func create(kwArgs: FunctionArguments) throws -> SecAccessControl {
        let useBiometric = (kwArgs[.useBiometric] as? Bool ?? false)
        let useDevicePin = (kwArgs[.useDevicePin] as? Bool ?? false)
        let currentUser = (kwArgs[.currentUser] as? Bool ?? false)
        
        var flags: SecAccessControlCreateFlags = []
        switch (useBiometric, currentUser) {
        case (true, false):
            flags = .biometryAny
        case (true, true):
            flags = .biometryCurrentSet
        default:
            break
        }
        if useDevicePin {
            flags.formUnion([.or, .devicePasscode])
        }
        return try .create(flags: flags)
    }
    
    static func create(flags: SecAccessControlCreateFlags) throws -> SecAccessControl {
        var access: SecAccessControl?
        var error: Unmanaged<CFError>?
        
        access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            &error
        )
        if let error = error?.takeRetainedValue() {
            throw error
        }
        guard let access = access else {
            assert(access != nil, "SecAccessControlCreateWithFlags failed")
            throw LAError(.invalidContext)
        }
        
        return access
    }
}

extension LAPolicy {
    init(name: String?) {
        switch name {
        case "any":
            self = .deviceOwnerAuthentication
        case "biometrics":
            self = .deviceOwnerAuthenticationWithBiometrics
        case "watch":
#if os(macOS)
            self = .deviceOwnerAuthenticationWithWatch
#else
            fallthrough
#endif
        case "biometricsOrCompanion":
#if os(macOS)
            self = .deviceOwnerAuthenticationWithBiometricsOrWatch
#else
            fallthrough
#endif
        case "companion":
#if os(macOS)
            self = .deviceOwnerAuthenticationWithWatch
#else
            fallthrough
#endif
        default:
            self = .deviceOwnerAuthentication
        }
    }
}

extension LABiometryType {
    var name: String {
        switch self {
        case .none:
            "none"
        case .touchID:
            "touchID"
        case .faceID:
            "faceID"
        case .opticID:
            "opticID"
        @unknown default:
            "touchID"
        }
    }
}
