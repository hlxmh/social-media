import Foundation

/// A single photo collage on a post. The canvas is a fixed 4:5 portrait;
/// photo cells are determined by the layout preset, so there's never any
/// "dead space" inside the canvas.
struct Collage: Identifiable, Hashable, Sendable {
    let id: UUID
    var preset: LayoutPreset
    /// Photos slotted into the preset's cells, in cell order. Cells without
    /// a photo are rendered as a placeholder.
    var cells: [CollageCell]
    var border: BorderStyle
    /// Free-floating overlay elements (stickers, tape, doodles, straight
    /// lines) layered on top of the photo cells.
    var overlays: [OverlayElement]
    /// The journal-style text body shown beneath this collage.
    var text: String

    static let aspectRatio: CGFloat = 4.0 / 5.0

    init(
        id: UUID = UUID(),
        preset: LayoutPreset = .full,
        cells: [CollageCell]? = nil,
        border: BorderStyle = BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 6),
        overlays: [OverlayElement] = [],
        text: String = ""
    ) {
        self.id = id
        self.preset = preset
        self.cells = cells ?? Array(repeating: CollageCell(), count: preset.cellCount)
        self.border = border
        self.overlays = overlays
        self.text = text
    }

    /// Ensures `cells.count == preset.cellCount`, padding or trimming as
    /// needed. Call after changing the preset.
    mutating func reconcileCells() {
        if cells.count < preset.cellCount {
            cells.append(contentsOf:
                Array(repeating: CollageCell(), count: preset.cellCount - cells.count))
        } else if cells.count > preset.cellCount {
            cells = Array(cells.prefix(preset.cellCount))
        }
    }
}

/// A photo slot within a collage. Empty when no photo has been chosen.
struct CollageCell: Identifiable, Hashable, Sendable {
    let id: UUID
    var image: Data?

    init(id: UUID = UUID(), image: Data? = nil) {
        self.id = id
        self.image = image
    }

    var isEmpty: Bool { image == nil }
}
