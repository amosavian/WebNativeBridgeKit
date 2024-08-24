//
//  Vault.swift
//
//
//  Created by Amir Abbas Mousavian on 8/21/24.
//

import Foundation
import LocalAuthentication
import Security

public protocol VaultStorable {
    func vaultStoreQuery() -> [CFString: Any]
}

extension VaultStorable {
    fileprivate func setMerge(into currentQuery: inout [CFString: Any]) throws {
        try currentQuery.merge(vaultStoreQuery(), uniquingKeysWith: { $1 })
    }
}

public struct Vault {
    public enum Storage: Sendable {
        public enum KeyClass: Hashable {
            case `private`
            case `public`
            
            fileprivate var toValue: CFString {
                switch self {
                case .private:
                    kSecAttrKeyClassPrivate
                case .public:
                    kSecAttrKeyClassPublic
                }
            }
        }
        
        case generic(service: String)
        case internet(url: URL)
        case key(class: KeyClass?)
        case certificate
        case identity
        
        public static var key: Self {
            .key(class: nil)
        }
        
        private func query(id: Key) throws -> [CFString: Any] {
            switch self {
            case .generic(let service):
                return [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: id.rawValue,
                ]
            case .internet(let url):
                guard let host = url.host else {
                    throw URLError(.badURL)
                }
                return [
                    kSecClass: kSecClassInternetPassword,
                    kSecAttrAccount: id.rawValue,
                    kSecAttrProtocol: url.secProtocol,
                    kSecAttrServer: host as CFString,
                    kSecAttrPort: url.port as CFNumber?,
                    kSecAttrPath: url.standardized.path.isEmpty || url.path == "/" ? nil : url.path,
                ]
            case .key(let keyClass):
                return [
                    kSecClass: kSecClassKey,
                    kSecAttrKeyClass: keyClass?.toValue,
                    kSecAttrApplicationTag: Data(id.rawValue.utf8),
                ]
            case .certificate:
                return [
                    kSecClass: kSecClassCertificate,
                    kSecAttrApplicationTag: Data(id.rawValue.utf8),
                ]
            case .identity:
                return [
                    kSecClass: kSecClassIdentity,
                    kSecAttrApplicationTag: Data(id.rawValue.utf8),
                ]
            }
        }
        
        fileprivate func merge(id: Key, into currentQuery: inout [CFString: Any]) throws {
            try currentQuery.merge(query(id: id), uniquingKeysWith: { $1 })
        }
    }
    
    public struct Key: StringRepresentable {
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    public let storage: Storage
    
    public init(_ storage: Storage) {
        self.storage = storage
    }
    
    public func get(id: Key) async throws -> Any {
        // To prevent blocking main thread and UI.
        try await Task.detached(priority: .userInitiated) {
            var query: [CFString: Any] = [
                kSecReturnRef: kCFBooleanTrue!,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny,
                kSecMatchLimit: kSecMatchLimitOne,
            ]
            try storage.merge(id: id, into: &query)
            
            var result: AnyObject? = nil
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == noErr else {
                throw NSError(osStatus: status)
            }
            guard let result = result else {
                throw NSError(osStatus: errSecItemNotFound)
            }
            return result
        }.value
    }
    
    public func getData(id: Key) async throws -> Data {
        guard let result = try await get(id: id) as? Data else {
            throw NSError(osStatus: errSecItemNotFound)
        }
        return result
    }
    
    public func set<V: VaultStorable>(_ value: V, for id: Key, isSyncrhronized: Bool = false, accessControl: SecAccessControl? = nil) async throws {
        let status = try await Task.detached(priority: .userInitiated) {
            var query: [CFString: Any] = [
                kSecAttrSynchronizable: isSyncrhronized ? kCFBooleanTrue! : kCFBooleanFalse!,
                kSecAttrAccessControl: accessControl,
            ]
            try value.setMerge(into: &query)
            try storage.merge(id: id, into: &query)
            
            return SecItemAdd(query as CFDictionary, nil)
        }.value
        guard status == noErr else {
            throw NSError(osStatus: status)
        }
    }
    
    public func delete(id: Key) async throws -> Any {
        // To prevent blocking main thread and UI.
        try await Task.detached(priority: .userInitiated) {
            var query: [CFString: Any] = [
                kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            ]
            try storage.merge(id: id, into: &query)
            
            var result: AnyObject? = nil
            let status = SecItemDelete(query as CFDictionary)
            guard status == noErr else {
                throw NSError(osStatus: status)
            }
            guard let result = result else {
                throw NSError(osStatus: errSecItemNotFound)
            }
            return result
        }.value
    }
}

extension SecAccessControl {
    public static func create(useBiometric: Bool = true, useDevicePin: Bool = false, currentUser: Bool = true) throws -> SecAccessControl {
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
    
    public static func create(flags: SecAccessControlCreateFlags) throws -> SecAccessControl {
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

extension VaultStorable where Self: Sequence<UInt8> {
    public func vaultStoreQuery() -> [CFString: Any] {
        [
            kSecValueData: Data(self) as CFData,
        ]
    }
}

extension CFData: VaultStorable {
    public func vaultStoreQuery() -> [CFString: Any] {
        [
            kSecValueData: self,
        ]
    }
}

extension String: VaultStorable {
    public func vaultStoreQuery() -> [CFString: Any] {
        [
            kSecValueData: Data(utf8) as CFData,
        ]
    }
}

extension [UInt8]: VaultStorable {}
extension ArraySlice<UInt8>: VaultStorable {}
extension ContiguousArray<UInt8>: VaultStorable {}
extension Data: VaultStorable {}
extension DispatchData: VaultStorable {}
extension DispatchData.Region: VaultStorable {}
extension EmptyCollection<UInt8>: VaultStorable {}
extension NSData: VaultStorable {}
extension Repeated<UInt8>: VaultStorable {}
extension Slice: VaultStorable where Base: DataProtocol {}
extension UnsafeBufferPointer<UInt8>: VaultStorable {}
extension UnsafeRawBufferPointer: VaultStorable {}

protocol VaultReferenceStorable: VaultStorable {}

extension VaultReferenceStorable {
    public func vaultStoreQuery() -> [CFString: Any] {
        [
            kSecValueRef: self,
        ]
    }
}

#if canImport(AppKit)
extension SecKeychainItem: VaultReferenceStorable {}
#endif
extension SecKey: VaultReferenceStorable {}
extension SecCertificate: VaultReferenceStorable {}
extension SecIdentity: VaultReferenceStorable {}

extension NSError {
    convenience init(osStatus: OSStatus) {
        self.init(
            domain: kCFErrorDomainOSStatus as String,
            code: Int(osStatus),
            userInfo: [
                NSLocalizedDescriptionKey: SecCopyErrorMessageString(osStatus, nil) ?? "",
            ]
        )
    }
}

extension URL {
    var secProtocol: CFString? {
        switch scheme?.lowercased() {
        case "https":
            kSecAttrProtocolHTTPS
        case "socks4", "socks5":
            kSecAttrProtocolSOCKS
        case "telnet" where port == 992:
            kSecAttrProtocolTelnetS
        case "telnet":
            kSecAttrProtocolTelnet
        case "ldaps", "imap" where port == 636:
            kSecAttrProtocolLDAPS
        case "imaps", "imap" where port == 993:
            kSecAttrProtocolIMAPS
        case "pop3s", "pop3" where port == 995:
            kSecAttrProtocolPOP3S
        case "ircs", "irc" where port == 6697 || port == 7000:
            kSecAttrProtocolIRCS
        default:
            scheme?.lowercased() as CFString?
        }
    }
}
