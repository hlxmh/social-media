import Foundation

enum PageNotificationKind: String, Sendable {
    case reaction      // someone placed a sticker/comment on your page
    case follow        // someone followed you
}

struct PageNotification: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: PageNotificationKind
    let actorId: UUID
    let pageId: UUID?
    let createdAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        kind: PageNotificationKind,
        actorId: UUID,
        pageId: UUID? = nil,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.actorId = actorId
        self.pageId = pageId
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
