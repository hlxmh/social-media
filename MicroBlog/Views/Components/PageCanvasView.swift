import SwiftUI

/// Renders a Page at any size while keeping the 3:4 aspect ratio.
/// Reads normalized element positions (0...1) and projects them into pixel space.
struct PageCanvasView: View {
    let page: Page
    /// If false, only the page owner's elements are drawn (clean view).
    var showReactions: Bool = true
    /// Optional filter applied to reactions (used to show only followed-user reactions).
    var visibleReactionAuthors: Set<UUID>? = nil
    /// Cosmetic — adds the white Polaroid border + shadow when true.
    var asPolaroid: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width / Page.aspectRatio
            ZStack {
                page.theme.background()
                ForEach(visibleElements) { element in
                    ElementRenderer(
                        element: element,
                        canvasSize: CGSize(width: width, height: height)
                    )
                    .position(
                        x: element.position.x * width,
                        y: element.position.y * height
                    )
                    .zIndex(element.zIndex)
                }
            }
            .frame(width: width, height: height, alignment: .center)
            .clipped()
            .modifier(PolaroidFrame(enabled: asPolaroid))
        }
        .aspectRatio(Page.aspectRatio, contentMode: .fit)
    }

    private var visibleElements: [PageElement] {
        page.elements.filter { el in
            if el.authorId == page.authorId { return true }
            if !showReactions { return false }
            if let allowed = visibleReactionAuthors {
                return allowed.contains(el.authorId)
            }
            return true
        }
        .sorted { $0.zIndex < $1.zIndex }
    }
}

private struct PolaroidFrame: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(8)
                .padding(.bottom, 28)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        } else {
            content.clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Element renderer

struct ElementRenderer: View {
    let element: PageElement
    let canvasSize: CGSize

    var body: some View {
        Group {
            switch element.content {
            case .text(let t):    TextElementView(content: t)
            case .sticker(let s): StickerElementView(content: s)
            case .image(let i):   ImageElementView(content: i, canvasSize: canvasSize)
            case .tape(let t):    TapeElementView(content: t)
            case .doodle(let d):  DoodleElementView(content: d, canvasSize: canvasSize)
            }
        }
        .scaleEffect(element.scale)
        .rotationEffect(.radians(element.rotation))
    }
}

private struct TextElementView: View {
    let content: TextContent
    var body: some View {
        if content.isComment {
            Text(content.text)
                .font(content.font.font(size: content.size, weight: .medium))
                .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
        } else {
            Text(content.text)
                .font(content.font.font(size: content.size, weight: .semibold))
                .foregroundStyle(content.color.color)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(maxWidth: 220)
        }
    }
}

private struct StickerElementView: View {
    let content: StickerContent
    var body: some View {
        switch content.sticker.glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: content.size))
                .foregroundStyle(content.tint.color)
                .symbolRenderingMode(.hierarchical)
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: content.size))
        }
    }
}

private struct ImageElementView: View {
    let content: ImageContent
    let canvasSize: CGSize

    var body: some View {
        if let img = UIImage(data: content.data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: min(content.width, canvasSize.width * 0.6),
                       height: min(content.height, canvasSize.height * 0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 120, height: 90)
            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
    }
}

private struct TapeElementView: View {
    let content: TapeContent
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(content.color.color.opacity(0.78))
            .frame(width: content.width, height: content.height)
            .overlay(
                Canvas { ctx, size in
                    let edges: [CGFloat] = [0, size.height]
                    for y in edges {
                        var path = Path()
                        var x: CGFloat = 0
                        let step: CGFloat = 6
                        path.move(to: .init(x: x, y: y))
                        while x < size.width {
                            x += step
                            let dy = CGFloat.random(in: -1.5...1.5)
                            path.addLine(to: .init(x: x, y: y + dy))
                        }
                        ctx.stroke(path, with: .color(.white.opacity(0.45)), lineWidth: 1)
                    }
                }
            )
    }
}

private struct DoodleElementView: View {
    let content: DoodleContent
    let canvasSize: CGSize
    var body: some View {
        Canvas { ctx, size in
            guard content.points.count > 1 else { return }
            var path = Path()
            // Points are in normalized 0...1 space relative to the page; we render
            // them inside an unrotated bounding box equal to the canvas size.
            for (i, p) in content.points.enumerated() {
                let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path,
                       with: .color(content.color.color),
                       style: .init(lineWidth: content.strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Warm paper page") {
    let author = UUID()
    let page = Page(
        authorId: author,
        day: Date(),
        theme: .warmPaper,
        elements: [
            PageElement(authorId: author,
                        content: .text(TextContent(text: "today", font: .handwritten,
                                                   color: .ink, size: 36)),
                        position: .init(x: 0.30, y: 0.15), rotation: -0.05, scale: 1, zIndex: 0),
            PageElement(authorId: author,
                        content: .tape(TapeContent(color: .peach, width: 180, height: 28)),
                        position: .init(x: 0.55, y: 0.45), rotation: 0.4, scale: 1, zIndex: 1),
            PageElement(authorId: author,
                        content: .sticker(StickerContent(sticker: .heart, tint: .pink, size: 56)),
                        position: .init(x: 0.20, y: 0.40), rotation: -0.2, scale: 1, zIndex: 2),
            PageElement(authorId: author,
                        content: .sticker(StickerContent(sticker: .sparkles, tint: .lemon, size: 48)),
                        position: .init(x: 0.78, y: 0.30), rotation: 0.3, scale: 1, zIndex: 3),
            PageElement(authorId: author,
                        content: .text(TextContent(text: "no notes", font: .handwritten,
                                                   color: .ink, size: 18)),
                        position: .init(x: 0.50, y: 0.85), rotation: 0.05, scale: 1, zIndex: 4)
        ]
    )
    return PageCanvasView(page: page)
        .padding(20)
}

#Preview("Y2K page") {
    let author = UUID()
    let page = Page(
        authorId: author,
        day: Date(),
        theme: .y2k,
        elements: [
            PageElement(authorId: author,
                        content: .text(TextContent(text: "✦ saturday ✦", font: .rounded,
                                                   color: .paper, size: 32)),
                        position: .init(x: 0.50, y: 0.20), rotation: 0, scale: 1, zIndex: 0),
            PageElement(authorId: author,
                        content: .sticker(StickerContent(sticker: .star, tint: .lemon, size: 64)),
                        position: .init(x: 0.25, y: 0.45), rotation: -0.2, scale: 1, zIndex: 1),
            PageElement(authorId: author,
                        content: .sticker(StickerContent(sticker: .sparkles, tint: .sky, size: 56)),
                        position: .init(x: 0.75, y: 0.55), rotation: 0.4, scale: 1, zIndex: 2),
            PageElement(authorId: author,
                        content: .sticker(StickerContent(sticker: .heart, tint: .pink, size: 70)),
                        position: .init(x: 0.50, y: 0.70), rotation: 0.0, scale: 1, zIndex: 3)
        ]
    )
    return PageCanvasView(page: page)
        .padding(20)
}
#endif
