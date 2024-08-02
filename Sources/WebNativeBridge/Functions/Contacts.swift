//
//  Contacts.swift
//
//
//  Created by Amir Abbas Mousavian on 7/21/24.
//

import Contacts
import Foundation

extension FunctionArgumentName {
    fileprivate static let vcard: Self = "vcard"
}

struct ContactsModule: Module {
    static let name: ModuleName = "contacts"
    
    static let functions: [FunctionName: FunctionSignature] = [
        "contacts.getAuthorizationStatus": getAuthorizationStatus,
        "contacts.authorize": authorize,
        "contacts.fetch": fetch,
        "contacts.store": store,
    ]
    
    static func getAuthorizationStatus(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        CNContactStore.authorizationStatus(for: .contacts).name
    }
    
    static func authorize(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable)? {
        let store = CNContactStore()
        return try await store.requestAccess(for: .contacts)
    }
    
    static func fetch(_: FunctionContext, _: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        let keys: [any CNKeyDescriptor] = [
            CNContactIdentifierKey,
            CNContactNamePrefixKey, CNContactGivenNameKey,
            CNContactMiddleNameKey, CNContactFamilyNameKey,
            CNContactNameSuffixKey, CNContactNicknameKey,
            CNContactOrganizationNameKey, CNContactDepartmentNameKey,
            CNContactJobTitleKey,
            CNContactBirthdayKey,
            CNContactImageDataKey,
            CNContactTypeKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactPostalAddressesKey,
            CNContactDatesKey,
            CNContactUrlAddressesKey,
        ].map(NSString.init(string:))
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        var contacts: [CNContact] = []
        let contactStore = CNContactStore()
        try contactStore.enumerateContacts(with: request) {
            contact, _ in
            // Array containing all unified contacts from everywhere
            contacts.append(contact)
        }
        return try CNContactVCardSerialization.data(with: contacts)
    }
    
    static func store(_: FunctionContext, _ kwArgs: FunctionArguments) async throws -> (any Encodable & Sendable)? {
        guard let vcard = kwArgs[.vcard] as? String else {
            return nil
        }
        let contacts = try CNContactVCardSerialization.contacts(with: .init(vcard.utf8))
            .compactMap { $0.mutableCopy() as? CNMutableContact }
        
        let contactStore = CNContactStore()
        let request = CNSaveRequest()
        for contact in contacts {
            request.add(contact, toContainerWithIdentifier: nil)
        }
        try contactStore.execute(request)
        return nil
    }
}

extension CNAuthorizationStatus {
    var name: String {
        switch self {
        case .notDetermined:
            "notDetermined"
        case .restricted:
            "restricted"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        @unknown default:
            "denied"
        }
    }
}
