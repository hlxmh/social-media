import Foundation

/// Currently only `follow` exists; reactions were removed in the collage
/// overhaul. Kept as an enum-backed model so additional kinds can be wired
/// in without touching call sites.
enum NotificationKind: String, Codable, Sendable {
    case follow
}

struct AppNotification: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: NotificationKind
    let actorId: UUID
    let createdAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        kind: NotificationKind,
        actorId: UUID,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.actorId = actorId
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
