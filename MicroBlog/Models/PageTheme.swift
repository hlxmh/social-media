import SwiftUI

/// A page's background style. Pages are deliberately allowed to look very different
/// from one another; the app shell stays neutral.
enum PageTheme: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case warmPaper
    case y2k
    case dreamy
    case zine
    case midnight
    case grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmPaper: return "Warm paper"
        case .y2k:       return "Y2K"
        case .dreamy:    return "Dreamy"
        case .zine:      return "Zine"
        case .midnight:  return "Midnight"
        case .grid:      return "Grid"
        }
    }

    /// A SwiftUI background view for the page canvas.
    @ViewBuilder
    func background() -> some View {
        switch self {
        case .warmPaper:
            ZStack {
                Color(red: 0.98, green: 0.95, blue: 0.88)
                Canvas { ctx, size in
                    var rng = SystemRandomNumberGenerator()
                    for _ in 0..<260 {
                        let x = Double.random(in: 0...size.width, using: &rng)
                        let y = Double.random(in: 0...size.height, using: &rng)
                        let r = Double.random(in: 0.3...0.9, using: &rng)
                        let rect = CGRect(x: x, y: y, width: r, height: r)
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(.brown.opacity(0.18)))
                    }
                }
                .blendMode(.multiply)
            }
        case .y2k:
            LinearGradient(colors: [
                Color(red: 1.0, green: 0.55, blue: 0.85),
                Color(red: 0.55, green: 0.85, blue: 1.0),
                Color(red: 0.95, green: 0.95, blue: 0.45)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dreamy:
            LinearGradient(colors: [
                Color(red: 0.85, green: 0.78, blue: 0.96),
                Color(red: 0.96, green: 0.86, blue: 0.93),
                Color(red: 0.78, green: 0.92, blue: 0.96)
            ], startPoint: .top, endPoint: .bottom)
        case .zine:
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.94)
                VStack(spacing: 0) {
                    Color.black.frame(height: 6)
                    Spacer()
                    Color.black.frame(height: 1.5)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
            }
        case .midnight:
            LinearGradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.16),
                Color(red: 0.10, green: 0.06, blue: 0.30)
            ], startPoint: .top, endPoint: .bottom)
        case .grid:
            ZStack {
                Color.white
                Canvas { ctx, size in
                    let step: CGFloat = 22
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += step }
                    var y: CGFloat = 0
                    while y <= size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)); y += step }
                    ctx.stroke(path, with: .color(.blue.opacity(0.18)), lineWidth: 0.5)
                }
            }
        }
    }

    /// Default ink tint when placing new text on this background.
    var defaultInk: StickerTint {
        switch self {
        case .midnight, .y2k: return .paper
        default: return .ink
        }
    }
}
