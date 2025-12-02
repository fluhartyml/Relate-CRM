//
//  ContactDetailView.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import SwiftUI
import SwiftData
import Contacts

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let contact: CNContact
    let context: ContactContext?

    @State private var isEditingContext: Bool = false
    @State private var showingAddInteraction: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with photo and name
                headerSection

                // Quick actions
                quickActionsSection

                // Context section (our data)
                contextSection

                // Contact info from Apple
                contactInfoSection

                // Interaction log
                interactionsSection
            }
            .padding()
        }
        .navigationTitle(ContactsService.shared.fullName(for: contact))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                Button {
                    toggleFavorite()
                } label: {
                    Label(
                        "Favorite",
                        systemImage: context?.isFavorite == true ? "star.fill" : "star"
                    )
                }
            }
            ToolbarItem {
                Button("Edit Context") {
                    isEditingContext = true
                }
            }
        }
        .sheet(isPresented: $isEditingContext) {
            ContextEditorView(contact: contact, existingContext: context)
        }
        .sheet(isPresented: $showingAddInteraction) {
            AddInteractionView(contact: contact, context: getOrCreateContext())
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Contact photo
            contactPhoto
                .frame(width: 100, height: 100)

            Text(ContactsService.shared.fullName(for: contact))
                .font(.title)
                .fontWeight(.semibold)

            if !contact.organizationName.isEmpty {
                Text(contact.organizationName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Tags
            if let tags = context?.tags, !tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contactPhoto: some View {
        if let imageData = contact.imageData ?? contact.thumbnailImageData,
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

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            if let phone = contact.primaryPhone {
                QuickActionButton(
                    icon: "phone.fill",
                    label: "Call",
                    color: .green
                ) {
                    openURL("tel:\(phone.replacingOccurrences(of: " ", with: ""))")
                }
            }

            if let email = contact.primaryEmail {
                QuickActionButton(
                    icon: "envelope.fill",
                    label: "Email",
                    color: .blue
                ) {
                    openURL("mailto:\(email)")
                }
            }

            QuickActionButton(
                icon: "note.text.badge.plus",
                label: "Log",
                color: .orange
            ) {
                showingAddInteraction = true
            }

            QuickActionButton(
                icon: "bell.badge",
                label: "Remind",
                color: .purple
            ) {
                createReminder()
            }
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Relationship Context", systemImage: "person.text.rectangle")
                    .font(.headline)

                if let ctx = context {
                    if !ctx.howWeMet.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How We Met")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ctx.howWeMet)
                        }
                    }

                    if !ctx.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ctx.notes)
                        }
                    }

                    if ctx.howWeMet.isEmpty && ctx.notes.isEmpty {
                        Button("Add context about this contact") {
                            isEditingContext = true
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Add context about this contact") {
                        isEditingContext = true
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Contact Info Section

    private var contactInfoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Contact Info", systemImage: "person.crop.rectangle")
                    .font(.headline)

                // Phone numbers
                ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                    InfoRow(
                        icon: "phone",
                        label: phone.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "Phone",
                        value: phone.value.stringValue
                    )
                }

                // Emails
                ForEach(contact.emailAddresses, id: \.identifier) { email in
                    InfoRow(
                        icon: "envelope",
                        label: email.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "Email",
                        value: email.value as String
                    )
                }

                // Birthday
                if let birthday = contact.birthdayString {
                    InfoRow(icon: "gift", label: "Birthday", value: birthday)
                }

                // Note from Apple Contacts
                if !contact.note.isEmpty {
                    InfoRow(icon: "note.text", label: "Note", value: contact.note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Interactions Section

    private var interactionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Interaction Log", systemImage: "clock.arrow.circlepath")
                        .font(.headline)

                    Spacer()

                    Button {
                        showingAddInteraction = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }

                if let interactions = context?.interactions.sorted(by: { $0.date > $1.date }),
                   !interactions.isEmpty {
                    ForEach(interactions) { interaction in
                        InteractionRowView(interaction: interaction)
                    }
                } else {
                    Text("No interactions logged yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helper Functions

    private func toggleFavorite() {
        let ctx = getOrCreateContext()
        ctx.isFavorite.toggle()
        ctx.lastModified = Date()
    }

    private func getOrCreateContext() -> ContactContext {
        if let existing = context {
            return existing
        }

        let newContext = ContactContext(contactIdentifier: contact.identifier)
        modelContext.insert(newContext)
        return newContext
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func createReminder() {
        let name = ContactsService.shared.fullName(for: contact)
        let urlString = "x-apple-reminderkit://REMCDReminder/create?title=Follow%20up%20with%20\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"
        openURL(urlString)
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

// MARK: - Supporting Views

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(width: 60, height: 60)
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
            }
        }
    }
}

struct InteractionRowView: View {
    let interaction: Interaction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: interaction.type.icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(interaction.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(interaction.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(interaction.note)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
