//
//  ContactsService.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import Foundation
import Contacts
import Combine

/// Service layer for interacting with Apple Contacts (CNContact)
@MainActor
final class ContactsService: ObservableObject {
    static let shared = ContactsService()

    @Published var contacts: [CNContact] = []
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let store = CNContactStore()

    /// Keys we want to fetch from contacts
    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor,
        CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
    ]

    private init() {
        checkAuthorizationStatus()
        print("[ContactsService] Initial status: \(authorizationStatus.rawValue)")
    }

    /// Check current authorization status
    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Request access to contacts
    func requestAccess() async -> Bool {
        print("[ContactsService] Requesting access...")

        do {
            let granted = try await store.requestAccess(for: .contacts)
            print("[ContactsService] Access granted: \(granted)")
            checkAuthorizationStatus()
            print("[ContactsService] New status: \(authorizationStatus.rawValue)")
            return granted
        } catch {
            print("[ContactsService] Error requesting access: \(error)")
            errorMessage = "Failed to request contacts access: \(error.localizedDescription)"
            return false
        }
    }

    /// Fetch all contacts from the store
    func fetchContacts() async {
        print("[ContactsService] Fetching contacts, status: \(authorizationStatus.rawValue)")

        guard authorizationStatus == .authorized else {
            errorMessage = "Contacts access not authorized"
            print("[ContactsService] Not authorized")
            return
        }

        isLoading = true
        errorMessage = nil

        // Run the synchronous enumerate on a background thread
        let keys = keysToFetch
        let contactStore = store

        do {
            let fetchedContacts: [CNContact] = try await Task.detached {
                var results: [CNContact] = []
                let request = CNContactFetchRequest(keysToFetch: keys)
                request.sortOrder = .userDefault

                try contactStore.enumerateContacts(with: request) { contact, _ in
                    results.append(contact)
                }
                return results
            }.value

            self.contacts = fetchedContacts
            self.isLoading = false
            print("[ContactsService] Fetched \(fetchedContacts.count) contacts")
        } catch {
            self.errorMessage = "Failed to fetch contacts: \(error.localizedDescription)"
            self.isLoading = false
            print("[ContactsService] Fetch error: \(error)")
        }
    }

    /// Get a single contact by identifier
    func getContact(identifier: String) -> CNContact? {
        guard authorizationStatus == .authorized else { return nil }

        do {
            return try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        } catch {
            errorMessage = "Failed to fetch contact: \(error.localizedDescription)"
            return nil
        }
    }

    /// Search contacts by name
    func searchContacts(query: String) -> [CNContact] {
        guard authorizationStatus == .authorized, !query.isEmpty else { return contacts }

        do {
            let predicate = CNContact.predicateForContacts(matchingName: query)
            return try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            return []
        }
    }

    /// Get formatted full name for a contact
    func fullName(for contact: CNContact) -> String {
        CNContactFormatter.string(from: contact, style: .fullName) ?? "No Name"
    }
}

// MARK: - CNContact Convenience Extensions

extension CNContact {
    /// Primary phone number if available
    var primaryPhone: String? {
        phoneNumbers.first?.value.stringValue
    }

    /// Primary email if available
    var primaryEmail: String? {
        emailAddresses.first?.value as String?
    }

    /// Formatted birthday string
    var birthdayString: String? {
        guard let birthday = birthday else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: birthday.date ?? Date())
    }

    /// Check if contact has a photo
    var hasPhoto: Bool {
        imageData != nil || thumbnailImageData != nil
    }
}
