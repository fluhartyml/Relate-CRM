//
//  ShareViewController.swift
//  Relate CRM Share
//
//  Created by Michael Fluharty on 12/2/25.
//

import Cocoa
import SwiftUI
import Contacts
import UniformTypeIdentifiers

class ShareViewController: NSViewController {

    private var sharedText: String = ""

    override func loadView() {
        // Create view programmatically instead of XIB
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 450))

        // Extract shared content and show SwiftUI
        extractSharedContent { [weak self] text in
            guard let self = self else { return }
            self.sharedText = text

            DispatchQueue.main.async {
                let shareView = ShareExtensionView(
                    sharedText: text,
                    onSave: { contactID, interactionType, note in
                        self.saveInteraction(contactID: contactID, type: interactionType, note: note)
                    },
                    onCancel: {
                        self.cancelRequest()
                    }
                )

                let hostingView = NSHostingView(rootView: shareView)
                hostingView.frame = self.view.bounds
                hostingView.autoresizingMask = [.width, .height]
                self.view.addSubview(hostingView)
            }
        }
    }

    private func extractSharedContent(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            completion("")
            return
        }

        // Try to get plain text first
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, error in
                    if let text = data as? String {
                        completion(text)
                        return
                    }
                }
                return
            }

            // Try URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, error in
                    if let url = data as? URL {
                        completion(url.absoluteString)
                        return
                    }
                }
                return
            }
        }

        // Fallback to attributed text from the item
        if let attributedText = item.attributedContentText {
            completion(attributedText.string)
            return
        }

        completion("")
    }

    private func saveInteraction(contactID: String, type: String, note: String) {
        // Save to App Group shared UserDefaults
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.NightGard.Relate-CRM") else {
            print("[ShareExtension] Failed to access App Group")
            completeRequest()
            return
        }

        let interaction: [String: Any] = [
            "contactID": contactID,
            "type": type,
            "note": note,
            "date": Date().timeIntervalSince1970
        ]

        // Get existing pending interactions and append
        var pending = sharedDefaults.array(forKey: "pendingInteractions") as? [[String: Any]] ?? []
        pending.append(interaction)
        sharedDefaults.set(pending, forKey: "pendingInteractions")
        sharedDefaults.synchronize()

        print("[ShareExtension] Saved interaction for contact: \(contactID)")

        // Open main app to show the logged interaction
        if let url = URL(string: "relatecrm://contact/\(contactID)") {
            NSWorkspace.shared.open(url)
        }

        completeRequest()
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancelRequest() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        extensionContext?.cancelRequest(withError: error)
    }

    @IBAction func send(_ sender: AnyObject?) {
        completeRequest()
    }

    @IBAction func cancel(_ sender: AnyObject?) {
        cancelRequest()
    }
}

// MARK: - SwiftUI Share View

struct ShareExtensionView: View {
    let sharedText: String
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var selectedContactID: String = ""
    @State private var interactionType: String = "Text message"
    @State private var note: String = ""
    @State private var contacts: [CNContact] = []
    @State private var searchText: String = ""

    private let interactionTypes = [
        "Met in person",
        "Phone call",
        "Text message",
        "Email",
        "Video call",
        "Note"
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Log to Relate CRM")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    onSave(selectedContactID, interactionType, note.isEmpty ? sharedText : note)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedContactID.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Divider()

            // Contact Search/Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Contact")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredContacts, id: \.identifier) { contact in
                            Button {
                                selectedContactID = contact.identifier
                            } label: {
                                ContactPickerRow(
                                    contact: contact,
                                    isSelected: selectedContactID == contact.identifier
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            // Interaction Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Interaction Type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Type", selection: $interactionType) {
                    ForEach(interactionTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // Shared Content Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Content")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $note)
                    .frame(height: 80)
                    .font(.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .onAppear {
                        note = sharedText
                    }
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(width: 400, height: 450)
        .onAppear {
            loadContacts()
        }
    }

    private var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            return fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadContacts() {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        var fetchedContacts: [CNContact] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                fetchedContacts.append(contact)
            }
            contacts = fetchedContacts
        } catch {
            print("Failed to fetch contacts: \(error)")
        }
    }
}

struct ContactPickerRow: View {
    let contact: CNContact
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Photo
            if let imageData = contact.thumbnailImageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(CNContactFormatter.string(from: contact, style: .fullName) ?? "No Name")
                    .font(.body)

                if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}
