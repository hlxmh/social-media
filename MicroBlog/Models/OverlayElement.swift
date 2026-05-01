import Foundation
import CoreGraphics

/// A free-floating decoration drawn on top of a collage. Stickers, washi tape,
/// and lines (freehand and straight). All positions are normalized to the
/// collage canvas (0...1).
struct OverlayElement: Identifiable, Hashable, Sendable {
    let id: UUID
    var content: OverlayContent
    /// Center position in the collage's normalized coordinate space.
    var position: CGPoint
    var rotation: Double  // radians
    var scale: Double
    var zIndex: Double
    var placedAt: Date

    init(
        id: UUID = UUID(),
        content: OverlayContent,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        rotation: Double = 0,
        scale: Double = 1,
        zIndex: Double = 0,
        placedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.zIndex = zIndex
        self.placedAt = placedAt
    }
}

enum OverlayContent: Hashable, Sendable {
    case sticker(StickerContent)
    case tape(TapeContent)
    case doodle(DoodleContent)
    case straightLine(StraightLineContent)
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

struct TapeContent: Hashable, Sendable {
    var color: StickerTint
    var width: Double  // long axis, points
    var height: Double // short axis, points
}

struct DoodleContent: Hashable, Sendable {
    /// Points in the collage's normalized coordinate space.
    var points: [CGPoint]
    var color: StickerTint
    var strokeWidth: Double
}

/// A single straight rule from start to end, both in normalized space.
struct StraightLineContent: Hashable, Sendable {
    var start: CGPoint
    var end: CGPoint
    var color: StickerTint
    var thickness: Double
}
