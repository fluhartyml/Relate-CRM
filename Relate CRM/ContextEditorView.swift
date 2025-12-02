//
//  ContextEditorView.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import SwiftUI
import SwiftData
import Contacts

struct ContextEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: CNContact
    let existingContext: ContactContext?

    @State private var howWeMet: String = ""
    @State private var notes: String = ""
    @State private var tagsText: String = ""
    @State private var priority: Int = 3
    @State private var isFavorite: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        contactPhoto
                            .frame(width: 50, height: 50)

                        VStack(alignment: .leading) {
                            Text(ContactsService.shared.fullName(for: contact))
                                .font(.headline)
                            if !contact.organizationName.isEmpty {
                                Text(contact.organizationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("How We Met") {
                    TextField("e.g., neighbor in corner house, met at WWDC", text: $howWeMet, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Notes") {
                    TextField("Additional notes about this contact", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Tags") {
                    TextField("Comma-separated: work, family, networking", text: $tagsText)

                    if !parsedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(parsedTags, id: \.self) { tag in
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

                Section("Priority") {
                    Picker("Priority Level", selection: $priority) {
                        Text("Highest").tag(1)
                        Text("High").tag(2)
                        Text("Normal").tag(3)
                        Text("Low").tag(4)
                        Text("Lowest").tag(5)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Mark as Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle("Edit Context")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContext()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingContext()
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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

    private func loadExistingContext() {
        guard let ctx = existingContext else { return }
        howWeMet = ctx.howWeMet
        notes = ctx.notes
        tagsText = ctx.tags.joined(separator: ", ")
        priority = ctx.priority
        isFavorite = ctx.isFavorite
    }

    private func saveContext() {
        let context: ContactContext
        if let existing = existingContext {
            context = existing
        } else {
            context = ContactContext(contactIdentifier: contact.identifier)
            modelContext.insert(context)
        }

        context.howWeMet = howWeMet
        context.notes = notes
        context.tags = parsedTags
        context.priority = priority
        context.isFavorite = isFavorite
        context.lastModified = Date()
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

// MARK: - Add Interaction View

struct AddInteractionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: CNContact
    let context: ContactContext

    @State private var note: String = ""
    @State private var type: InteractionType = .note
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Log interaction with \(ContactsService.shared.fullName(for: contact))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Interaction Type") {
                    Picker("Type", selection: $type) {
                        ForEach(InteractionType.allCases, id: \.self) { interactionType in
                            Label(interactionType.rawValue, systemImage: interactionType.icon)
                                .tag(interactionType)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.wheel)
                    #endif
                }

                Section("Date") {
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Note") {
                    TextField("What happened?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Interaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInteraction()
                        dismiss()
                    }
                    .disabled(note.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }

    private func saveInteraction() {
        let interaction = Interaction(date: date, note: note, type: type)
        interaction.contactContext = context
        context.interactions.append(interaction)
        context.lastModified = Date()
        modelContext.insert(interaction)
    }
}
