//
//  Relate_CRMApp.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import SwiftUI
import SwiftData
import Combine

/// Handles deep link navigation from Share Extension
@MainActor
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    @Published var pendingContactID: String?
}

@main
struct Relate_CRMApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ContactContext.self,
            Interaction.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ContactsService.shared)
                .environmentObject(DeepLinkHandler.shared)
                .onAppear {
                    importPendingInteractions(modelContainer: sharedModelContainer)
                }
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Handle incoming deep links from Share Extension
    private func handleDeepLink(url: URL) {
        // URL format: relatecrm://contact/{contactID}
        guard url.scheme == "relatecrm",
              url.host == "contact",
              let contactID = url.pathComponents.last, !contactID.isEmpty, contactID != "/" else {
            print("[RelateCRM] Invalid deep link: \(url)")
            return
        }

        print("[RelateCRM] Deep link to contact: \(contactID)")

        // Import any pending interactions first
        importPendingInteractions(modelContainer: sharedModelContainer)

        // Set the pending contact ID to trigger navigation
        DeepLinkHandler.shared.pendingContactID = contactID
    }

    /// Import pending interactions from Share Extension via App Group
    private func importPendingInteractions(modelContainer: ModelContainer) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.NightGard.Relate-CRM") else {
            print("[RelateCRM] Failed to access App Group")
            return
        }

        guard let pending = sharedDefaults.array(forKey: "pendingInteractions") as? [[String: Any]],
              !pending.isEmpty else {
            print("[RelateCRM] No pending interactions to import")
            return
        }

        print("[RelateCRM] Found \(pending.count) pending interactions")

        let context = modelContainer.mainContext

        for item in pending {
            guard let contactID = item["contactID"] as? String,
                  let typeString = item["type"] as? String,
                  let note = item["note"] as? String,
                  let timestamp = item["date"] as? TimeInterval else {
                continue
            }

            let date = Date(timeIntervalSince1970: timestamp)
            let type = InteractionType.allCases.first { $0.rawValue == typeString } ?? .note

            // Find or create ContactContext
            let descriptor = FetchDescriptor<ContactContext>(
                predicate: #Predicate { $0.contactIdentifier == contactID }
            )

            let contactContext: ContactContext
            if let existing = try? context.fetch(descriptor).first {
                contactContext = existing
            } else {
                contactContext = ContactContext(contactIdentifier: contactID)
                context.insert(contactContext)
            }

            // Create and add interaction
            let interaction = Interaction(date: date, note: note, type: type)
            interaction.contactContext = contactContext
            contactContext.interactions.append(interaction)
            contactContext.lastModified = Date()

            print("[RelateCRM] Imported interaction for contact: \(contactID)")
        }

        // Clear pending interactions
        sharedDefaults.removeObject(forKey: "pendingInteractions")
        sharedDefaults.synchronize()

        // Save context
        try? context.save()
        print("[RelateCRM] Import complete")
    }
}
