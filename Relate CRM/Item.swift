//
//  ContactContext.swift
//  Relate CRM
//
//  Created by Michael Fluharty on 12/2/25.
//

import Foundation
import SwiftData

/// Our metadata layer that links to Apple Contacts via identifier.
/// This stores the "context" that CNContact doesn't provide.
@Model
final class ContactContext {
    /// The CNContact.identifier - links to Apple Contacts
    @Attribute(.unique) var contactIdentifier: String

    /// How we know this person (e.g., "neighbor corner house", "met at WWDC", "spouse of John")
    var howWeMet: String

    /// General notes about this contact
    var notes: String

    /// Custom tags for organization (e.g., "work", "family", "networking")
    var tags: [String]

    /// Mark important contacts for quick access
    var isFavorite: Bool

    /// Priority level (1-5, where 1 is highest priority)
    var priority: Int

    /// When we added context for this contact
    var dateAdded: Date

    /// Last time we updated the context
    var lastModified: Date

    /// Interaction log entries
    @Relationship(deleteRule: .cascade) var interactions: [Interaction]

    init(
        contactIdentifier: String,
        howWeMet: String = "",
        notes: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        priority: Int = 3
    ) {
        self.contactIdentifier = contactIdentifier
        self.howWeMet = howWeMet
        self.notes = notes
        self.tags = tags
        self.isFavorite = isFavorite
        self.priority = priority
        self.dateAdded = Date()
        self.lastModified = Date()
        self.interactions = []
    }
}

/// Represents a single interaction/touchpoint with a contact
@Model
final class Interaction {
    /// When the interaction occurred
    var date: Date

    /// Description of what happened
    var note: String

    /// Type of interaction
    var type: InteractionType

    /// Link back to the contact context
    var contactContext: ContactContext?

    init(date: Date = Date(), note: String, type: InteractionType = .note) {
        self.date = date
        self.note = note
        self.type = type
    }
}

/// Types of interactions we can log
enum InteractionType: String, Codable, CaseIterable {
    case met = "Met in person"
    case call = "Phone call"
    case email = "Email"
    case text = "Text message"
    case video = "Video call"
    case social = "Social media"
    case note = "Note"
    case other = "Other"

    var icon: String {
        switch self {
        case .met: return "person.2"
        case .call: return "phone"
        case .email: return "envelope"
        case .text: return "message"
        case .video: return "video"
        case .social: return "at"
        case .note: return "note.text"
        case .other: return "ellipsis.circle"
        }
    }
}
