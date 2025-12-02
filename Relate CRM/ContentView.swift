//
//  ContentView.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import SwiftUI
import SwiftData
import Contacts

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var contactsService: ContactsService
    @Query private var contextData: [ContactContext]

    @State private var searchText: String = ""
    @State private var selectedContactID: String?
    @State private var showingOnlyFavorites: Bool = false

    var body: some View {
        NavigationSplitView {
            Group {
                switch contactsService.authorizationStatus {
                case .authorized:
                    contactListView
                case .notDetermined:
                    requestAccessView
                case .denied, .restricted:
                    deniedAccessView
                @unknown default:
                    requestAccessView
                }
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            #endif
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingOnlyFavorites.toggle()
                    } label: {
                        Label(
                            "Favorites",
                            systemImage: showingOnlyFavorites ? "star.fill" : "star"
                        )
                    }
                }
                ToolbarItem {
                    Button {
                        Task {
                            await contactsService.fetchContacts()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            if let contactID = selectedContactID,
               let contact = contactsService.getContact(identifier: contactID) {
                ContactDetailView(
                    contact: contact,
                    context: contextData.first { $0.contactIdentifier == contactID }
                )
            } else {
                ContentUnavailableView(
                    "Select a Contact",
                    systemImage: "person.crop.circle",
                    description: Text("Choose a contact from the list to view details")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search contacts")
        .task {
            if contactsService.authorizationStatus == .authorized {
                await contactsService.fetchContacts()
            }
        }
    }

    // MARK: - Contact List

    private var contactListView: some View {
        List(selection: $selectedContactID) {
            ForEach(filteredContacts, id: \.identifier) { contact in
                ContactRowView(
                    contact: contact,
                    context: contextData.first { $0.contactIdentifier == contact.identifier }
                )
                .tag(contact.identifier)
            }
        }
        .overlay {
            if contactsService.isLoading {
                ProgressView("Loading contacts...")
            } else if filteredContacts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var filteredContacts: [CNContact] {
        var result = contactsService.contacts

        // Filter by search text
        if !searchText.isEmpty {
            result = contactsService.searchContacts(query: searchText)
        }

        // Filter by favorites
        if showingOnlyFavorites {
            let favoriteIDs = Set(contextData.filter { $0.isFavorite }.map { $0.contactIdentifier })
            result = result.filter { favoriteIDs.contains($0.identifier) }
        }

        return result
    }

    // MARK: - Permission Views

    private var requestAccessView: some View {
        ContentUnavailableView {
            Label("Contacts Access Required", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text("Relate CRM needs access to your contacts to help you manage relationships.")
        } actions: {
            Button("Grant Access") {
                Task {
                    let granted = await contactsService.requestAccess()
                    if granted {
                        await contactsService.fetchContacts()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var deniedAccessView: some View {
        ContentUnavailableView {
            Label("Access Denied", systemImage: "person.crop.circle.badge.xmark")
        } description: {
            Text("Contacts access was denied. Please enable it in System Settings to use Relate CRM.")
        } actions: {
            Button("Open Settings") {
                #if os(macOS)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                    NSWorkspace.shared.open(url)
                }
                #else
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: CNContact
    let context: ContactContext?

    var body: some View {
        HStack(spacing: 12) {
            // Contact photo or placeholder
            contactPhoto
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ContactsService.shared.fullName(for: contact))
                        .font(.headline)

                    if context?.isFavorite == true {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                if let howWeMet = context?.howWeMet, !howWeMet.isEmpty {
                    Text(howWeMet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Show tags if any
            if let tags = context?.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var contactPhoto: some View {
        if let imageData = contact.thumbnailImageData ?? contact.imageData,
           let image = crossPlatformImage(from: imageData) {
            image
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
        }
    }

    private func crossPlatformImage(from data: Data) -> Image? {
        #if os(macOS)
        if let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
}

#Preview {
    ContentView()
        .environmentObject(ContactsService.shared)
        .modelContainer(for: [ContactContext.self, Interaction.self], inMemory: true)
}
