//
//  Biometric.swift
//
//
//  Created by Amir Abbas Mousavian on 7/16/24.
//

import Foundation
import LocalAuthentication

extension FunctionArgumentName {
    fileprivate static let policy: Self = "policy"
    fileprivate static let localizedReason: Self = "localizedReason"
    fileprivate static let id: Self = "id"
    fileprivate static let credential: Self = "credential"
    fileprivate static let synchronizable: Self = "synchronizable"
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
        guard let url = context.frameInfo.baseURL else { return nil }
        try await Vault(.internet(url: url)).set(
            Data(credential.utf8), for: .init(username), isSyncrhronized: syncronizable,
            accessControl: SecAccessControl.create(kwArgs: kwArgs)
        )
        return nil
    }
    
    static func getCredential(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let username = kwArgs[.id] as? String else {
            return nil
        }
        guard var url = context.frameInfo.baseURL else { return nil }
        return try await Vault(.internet(url: url)).getData(id: .init(username))
    }
}

extension SecAccessControl {
    static func create(kwArgs: FunctionArguments) throws -> SecAccessControl {
        let useBiometric = (kwArgs[.useBiometric] as? Bool ?? false)
        let useDevicePin = (kwArgs[.useDevicePin] as? Bool ?? false)
        let currentUser = (kwArgs[.currentUser] as? Bool ?? false)
        return try .create(useBiometric: useBiometric, useDevicePin: useDevicePin, currentUser: currentUser)
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
