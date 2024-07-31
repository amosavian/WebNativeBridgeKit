//
//  Secure.swift
//
//
//  Created by Amir Abbas Mousavian on 7/21/24.
//

import CryptoKit
import Foundation

extension FunctionArgumentKeyword {
    fileprivate static let hash: Self = "hash"
    fileprivate static let key: Self = "key"
    fileprivate static let data: Self = "data"
    fileprivate static let digest: Self = "digest"
    fileprivate static let signatureFormat: Self = "signatureFormat"
}

enum SecurityError: LocalizedError {
    case secureEnclaveInaccessible
    
    var errorDescription: String? {
        "Secure Enclave is not available."
    }
}

enum TypeError: LocalizedError {
    case typeMismatch
    
    var errorDescription: String? {
        "Given data type is not supported."
    }
}

struct SecurityFunction: CallableFunctionRegistry {
    static var allFunctions: [FunctionName: FunctionSignature] = [
        "security.getValue": getValueForKey,
        "secirity.setValue": saveValueForKey,
        "security.secureEnclaveIsAvailable": isAvailable,
        "security.generateKeyPair": generateKeyPair,
        "security.getPublicKey": getPublicKey,
        "security.keyAgreement": keyAgreement,
        "security.sign": sign,
    ]

    static func getValueForKey(_ context: FunctionContext, _: [Any], _ kwArgs: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        guard let key = kwArgs[.key] as? String, let service = context.frameInfo.url?.host else {
            return nil
        }
        
        // To prevent blocking main thread and UI.
        return try await Task.detached(priority: .userInitiated) {
            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: key,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny,
                kSecReturnData: kCFBooleanTrue!,
                kSecMatchLimit: kSecMatchLimitOne,
            ] as CFDictionary
            
            var dataTypeRef: AnyObject? = nil
            let status = SecItemCopyMatching(query, &dataTypeRef)
            if status == noErr {
                return (dataTypeRef as? Data)
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
    
    static func saveValueForKey(_ context: FunctionContext, _: [Any], _ kwArgs: [FunctionArgumentKeyword: any Sendable]) async throws -> (any Encodable & Sendable)? {
        guard let key = kwArgs[.key] as? String, let service = context.frameInfo.url?.host, let rawData = kwArgs[.data] else {
            return nil
        }
        let syncronizable = (kwArgs[.synchronizable] as? Bool ?? false)
        let data: Data
        switch rawData {
        case let rawData as Data:
            data = rawData
        case let rawData as String:
            guard let base64Decoded = Data(base64Encoded: rawData, options: .ignoreUnknownCharacters) else {
                throw TypeError.typeMismatch
            }
            data = base64Decoded
        default:
            return nil
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let query = try [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrSynchronizable: syncronizable ? kCFBooleanTrue! : kCFBooleanFalse!,
                kSecAttrAccount: key,
                kSecAttrAccessControl: SecAccessControl.create(kwArgs: kwArgs),
                kSecValueData: data as CFData,
            ] as CFDictionary
            
            return SecItemAdd(query, nil)
        }.value
    }
    
    static func isAvailable(_ context: FunctionContext, _: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        return SecureEnclave.isAvailable
    }
    
    static func generateKeyPair(_ context: FunctionContext, _: [Any], _ kwArgs: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        guard SecureEnclave.isAvailable else {
            throw SecurityError.secureEnclaveInaccessible
        }
        let key = try SecureEnclave.P256.Signing.PrivateKey(compactRepresentable: false, accessControl: .create(kwArgs: kwArgs))
        return key.dataRepresentation
    }
    
    private static func data(from arg: Any?) -> Data? {
        let dataRep: Data
        switch arg {
        case let arg as Data:
            dataRep = arg
        case let arg as String:
            guard let argData = Data(base64Encoded: arg) else {
                return nil
            }
            dataRep = argData
        default:
            return nil
        }
        return dataRep
    }
    
    static func getPublicKey(_ context: FunctionContext, _ args: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let key = try data(from: args.first)
            .map {
                try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: $0)
            }
        return key?.publicKey.derRepresentation
    }
    
    static func keyAgreement(_ context: FunctionContext, _ args: [Any], _: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let privateKeyData = data(from: args.first)
        let publicKeyData = data(from: args[safe: 1])
        
        return try await Task.detached(priority: .userInitiated) {
            let privateKey = try privateKeyData.map {
                try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: $0)
            }
            let publicKey = try publicKeyData.map {
                try P256.KeyAgreement.PublicKey(derRepresentation: $0)
            }
        
            return try publicKey.map {
                try privateKey?
                    .sharedSecretFromKeyAgreement(with: $0)
                    .withUnsafeBytes { Data($0) }
            }
        }.value
    }
    
    static func sign(_ context: FunctionContext, _: [Any], _ kwArgs: [FunctionArgumentKeyword: Any]) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let privateKeyData = data(from: kwArgs[.key])
        let signatureData = data(from: kwArgs[.data])
        let digest = data(from: kwArgs[.digest])
        let hash = kwArgs[.hash] as? String
        let format = kwArgs[.signatureFormat] as? String
        
        return try await Task.detached {
            let privateKey = try privateKeyData.map {
                try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: $0)
            }
            if let signatureData = signatureData {
                let hash = hash.map(HashAlgorithm.init(rawValue:)) ?? .sha256
                guard let digest = hash?.hash.hash(data: signatureData) else {
                    return nil
                }
                return switch format {
                case "der":
                    try privateKey?.signature(for: digest).derRepresentation
                default:
                    try privateKey?.signature(for: digest).rawRepresentation
                }
            } else if let digest = digest {
                let digest = RawDigest(rawValue: digest)
                return switch format {
                case "der":
                    try privateKey?.signature(for: digest).derRepresentation
                default:
                    try privateKey?.signature(for: digest).rawRepresentation
                }
            }
            return nil
        }.value
    }
}

struct RawDigest: RawRepresentable, Digest {
    static let byteCount: Int = 0
    
    let rawValue: Data
    
    init(rawValue: Data) {
        self.rawValue = rawValue
    }
    
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try rawValue.withUnsafeBytes(body)
    }
}

enum HashAlgorithm: String, Hashable {
    case sha256 = "SHA-256"
    case sha384 = "SHA-384"
    case sha512 = "SHA-512"
    
    init?(byteCount: Int) {
        switch byteCount {
        case SHA256.byteCount:
            self = .sha256
        case SHA384.byteCount:
            self = .sha384
        case SHA512.byteCount:
            self = .sha512
        default:
            return nil
        }
    }
    
    var hash: any HashFunction.Type {
        switch self {
        case .sha256:
            SHA256.self
        case .sha384:
            SHA384.self
        case .sha512:
            SHA512.self
        }
    }
}
