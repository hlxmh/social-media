import Foundation
import SwiftUI

/// A single thing on a page: text, sticker, image, washi tape, or a doodle stroke.
struct PageElement: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Who placed the element. Equal to the page author for the page owner's own content;
    /// different for reactions placed by other users.
    let authorId: UUID
    var content: ElementContent
    /// Position normalized to the page's bounding box (0...1, anchored center).
    var position: CGPoint
    /// In radians.
    var rotation: Double
    /// Multiplier on the element's intrinsic size.
    var scale: Double
    /// Stacking order; higher draws on top.
    var zIndex: Double
    var placedAt: Date

    init(
        id: UUID = UUID(),
        authorId: UUID,
        content: ElementContent,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        rotation: Double = 0,
        scale: Double = 1,
        zIndex: Double = 0,
        placedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.content = content
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
        self.placedAt = placedAt
    }
}

enum ElementContent: Hashable, Sendable {
    case text(TextContent)
    case sticker(StickerContent)
    case image(ImageContent)
    case tape(TapeContent)
    case doodle(DoodleContent)
}

struct TextContent: Hashable, Sendable {
    var text: String
    var font: PageFont
    var color: StickerTint
    var size: Double
    /// True if this text was placed as a comment-style reaction; rendered in a bubble.
    var isComment: Bool

    init(text: String, font: PageFont = .handwritten,
         color: StickerTint = .ink, size: Double = 22,
         isComment: Bool = false) {
        self.text = text
        self.font = font
        self.color = color
        self.size = size
        self.isComment = isComment
    }
}

struct StickerContent: Hashable, Sendable {
    var sticker: Sticker
    var tint: StickerTint
    var size: Double

    init(sticker: Sticker, tint: StickerTint = .pink, size: Double = 56) {
        self.sticker = sticker
        self.tint = tint
        self.size = size
    }
}

/// Image data is stored inline so the mock backend stays in-memory.
/// In a real backend this would be a remote URL.
struct ImageContent: Hashable, Sendable {
    var data: Data
    var width: Double
    var height: Double
}

struct TapeContent: Hashable, Sendable {
    var color: StickerTint
    var width: Double  // long axis
    var height: Double // short axis
}

struct DoodleContent: Hashable, Sendable {
    /// Points in the page's normalized coordinate space.
    var points: [CGPoint]
    var color: StickerTint
    var strokeWidth: Double
}

// MARK: - Helpers

extension PageElement {
    var isReaction: Bool { false } // computed in context (depends on page author)

    func isReaction(on page: Page) -> Bool { authorId != page.authorId }
}
