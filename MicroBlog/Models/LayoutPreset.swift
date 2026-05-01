import CoreGraphics

/// The fixed cell arrangements a collage can use. Each preset reports the
/// normalized rects (0...1 in the collage's coordinate system) for its photo
/// cells, with a configurable inset and gutter.
enum LayoutPreset: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case full
    case twoVertical
    case twoHorizontal
    case fourGrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full:          return "Full"
        case .twoVertical:   return "2 stacked"
        case .twoHorizontal: return "2 side"
        case .fourGrid:      return "4 grid"
        }
    }

    var cellCount: Int {
        switch self {
        case .full: return 1
        case .twoVertical, .twoHorizontal: return 2
        case .fourGrid: return 4
        }
    }

    /// Normalized rects (0...1) for each cell. `inset` is normalized to the
    /// canvas's smaller dimension; `gutterX` / `gutterY` are normalized to the
    /// canvas's width and height respectively, so a 1pt gutter looks 1pt wide
    /// regardless of axis.
    func cellRects(inset: CGFloat, gutterX: CGFloat, gutterY: CGFloat) -> [CGRect] {
        let hgX = gutterX / 2
        let hgY = gutterY / 2
        switch self {
        case .full:
            return [CGRect(x: inset, y: inset,
                           width: 1 - 2*inset, height: 1 - 2*inset)]
        case .twoVertical:
            return [
                CGRect(x: inset, y: inset,
                       width: 1 - 2*inset, height: 0.5 - inset - hgY),
                CGRect(x: inset, y: 0.5 + hgY,
                       width: 1 - 2*inset, height: 0.5 - inset - hgY)
            ]
        case .twoHorizontal:
            return [
                CGRect(x: inset, y: inset,
                       width: 0.5 - inset - hgX, height: 1 - 2*inset),
                CGRect(x: 0.5 + hgX, y: inset,
                       width: 0.5 - inset - hgX, height: 1 - 2*inset)
            ]
        case .fourGrid:
            let w = 0.5 - inset - hgX
            let h = 0.5 - inset - hgY
            return [
                CGRect(x: inset, y: inset, width: w, height: h),
                CGRect(x: 0.5 + hgX, y: inset, width: w, height: h),
                CGRect(x: inset, y: 0.5 + hgY, width: w, height: h),
                CGRect(x: 0.5 + hgX, y: 0.5 + hgY, width: w, height: h)
            ]
        }
    }
}
