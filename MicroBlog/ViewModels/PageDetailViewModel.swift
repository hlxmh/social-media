import Foundation
import SwiftUI

@MainActor
final class PageDetailViewModel: ObservableObject {
    @Published private(set) var page: Page?
    @Published private(set) var author: User?
    @Published private(set) var followingIds: Set<UUID> = []
    @Published var showReactions: Bool = true
    @Published var error: String?

    let backend: BackendService
    let pageId: UUID

    init(backend: BackendService, pageId: UUID) {
        self.backend = backend
        self.pageId = pageId
    }

    var visibleReactionAuthors: Set<UUID>? {
        guard let page else { return nil }
        return followingIds.union([backend.currentUser.id, page.authorId])
    }

    var visibleReactions: [PageElement] {
        guard let page else { return [] }
        let allowed = visibleReactionAuthors ?? []
        return page.reactions.filter { allowed.contains($0.authorId) }
    }

    func load() async {
        do {
            let p = try await backend.page(withId: pageId)
            page = p
            if let p { author = try await backend.user(withId: p.authorId) }
            followingIds = await backend.followingIds()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addStickerReaction(_ sticker: Sticker, tint: StickerTint) async {
        guard let page else { return }
        let element = PageElement(
            authorId: backend.currentUser.id,
            content: .sticker(StickerContent(sticker: sticker, tint: tint, size: 56)),
            position: .init(x: Double.random(in: 0.2...0.8),
                            y: Double.random(in: 0.2...0.8)),
            rotation: Double.random(in: -0.4...0.4),
            zIndex: (page.elements.map(\.zIndex).max() ?? 0) + 1
        )
        if let updated = try? await backend.addReaction(to: page.id, element: element) {
            self.page = updated
        }
    }

    func addCommentReaction(_ text: String) async {
        guard let page, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let element = PageElement(
            authorId: backend.currentUser.id,
            content: .text(TextContent(text: text, font: .rounded,
                                       color: .ink, size: 14, isComment: true)),
            position: .init(x: Double.random(in: 0.25...0.75),
                            y: Double.random(in: 0.6...0.85)),
            rotation: Double.random(in: -0.08...0.08),
            zIndex: (page.elements.map(\.zIndex).max() ?? 0) + 1
        )
        if let updated = try? await backend.addReaction(to: page.id, element: element) {
            self.page = updated
        }
    }

    func removeMyReaction(_ elementId: UUID) async {
        guard let page else { return }
        if let updated = try? await backend.removeReaction(elementId: elementId, on: page.id) {
            self.page = updated
        }
    }
}
