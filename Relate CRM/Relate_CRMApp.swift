//
//  Relate_CRMApp.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import SwiftUI
import SwiftData

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
        }
        .modelContainer(sharedModelContainer)
    }
}
