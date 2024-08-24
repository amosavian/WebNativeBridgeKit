//
//  Security.swift
//
//
//  Created by Amir Abbas Mousavian on 7/21/24.
//

import CryptoKit
import Foundation
import LocalAuthentication

extension FunctionArgumentName {
    fileprivate static let id: Self = "id"
    fileprivate static let hash: Self = "hash"
    fileprivate static let key: Self = "key"
    fileprivate static let data: Self = "data"
    fileprivate static let digest: Self = "digest"
    fileprivate static let synchronizable: Self = "synchronizable"
    fileprivate static let signatureFormat: Self = "signatureFormat"
    fileprivate static let publicKey: Self = "publicKey"
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

struct SecurityModule: Module {
    static let name: ModuleName = "security"
    
    static let functions: [FunctionName: FunctionSignature] = [
        "getValue": getValueForKey,
        "setValue": saveValueForKey,
        "secureEnclaveIsAvailable": secureEnclaveIsAvailable,
        "generateKeyPair": generateKeyPair,
        "getPublicKey": getPublicKey,
        "keyAgreement": keyAgreement,
        "sign": sign,
    ]

    static func getValueForKey(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        guard let key = kwArgs[.key] as? String, let service = context.frameInfo.url?.host else {
            return nil
        }
        
        return try await Vault(.generic(service: service)).getData(id: .init(key))
    }
    
    static func saveValueForKey(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
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
        try await Vault(.generic(service: service))
            .set(
                data, for: .init(key),
                isSyncrhronized: syncronizable,
                accessControl: SecAccessControl.create(kwArgs: kwArgs)
            )
        return nil
    }
    
    static func secureEnclaveIsAvailable(_ context: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        return SecureEnclave.isAvailable
    }
    
    static func generateKeyPair(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
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
    
    static func getPublicKey(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let key = try data(from: kwArgs[.id])
            .map {
                try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: $0)
            }
        return key?.publicKey.derRepresentation
    }
    
    static func keyAgreement(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard await context.checkSameSecurityOrigin() else { return nil }
        let privateKeyData = data(from: kwArgs[.id])
        let publicKeyData = data(from: kwArgs[.publicKey])
        
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
    
    static func sign(_ context: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
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
