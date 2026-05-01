import Foundation

/// Decorative outer frame applied to a collage.
enum FrameStyle: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case none
    case polaroid       // thick white border, even thicker on bottom
    case filmStrip      // black border with sprocket holes
    case tornPaper      // off-white with ragged edge

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none:       return "None"
        case .polaroid:   return "Polaroid"
        case .filmStrip:  return "Filmstrip"
        case .tornPaper:  return "Torn"
        }
    }
}

/// Per-collage frame + gutter configuration. Gutter is the negative space
/// between photo cells; the gutter color shows through as a border between
/// adjacent photos.
struct BorderStyle: Hashable, Codable, Sendable {
    var frame: FrameStyle
    var gutterColor: StickerTint
    var gutterWidth: Double  // 0 ... ~24 pts

    init(frame: FrameStyle = .none,
         gutterColor: StickerTint = .paper,
         gutterWidth: Double = 8) {
        self.frame = frame
        self.gutterColor = gutterColor
        self.gutterWidth = gutterWidth
    }
}
