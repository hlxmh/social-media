import SwiftUI

/// Renders a Collage at any size while preserving the 4:5 aspect ratio.
/// The gutter color paints the background; photo cells fill their preset
/// rects; overlay elements draw on top; the outer frame finishes everything.
struct CollageView: View {
    let collage: Collage
    /// Optional accent inside empty cells, used by the editor to make them
    /// inviting to tap. The viewer leaves them as plain placeholders.
    var emptyCellLabel: ((Int) -> String)? = nil
    /// Editor-only: highlight this cell index with a focus ring.
    var focusedCellIndex: Int? = nil
    /// Editor-only: tap callback for an empty/filled cell.
    var onTapCell: ((Int) -> Void)? = nil
    /// When false, the read-only overlay layer is suppressed so an editor
    /// can render its own interactive overlays on top.
    var renderOverlays: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = sizeFor(width: proxy.size.width, height: proxy.size.height)
            ZStack {
                gutterBackground(size: size)
                photoLayer(size: size)
                if renderOverlays {
                    overlayLayer(size: size)
                }
                FrameOverlay(style: collage.border.frame)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(Collage.aspectRatio, contentMode: .fit)
    }

    /// Largest 4:5 rectangle that fits in the container.
    private func sizeFor(width: CGFloat, height: CGFloat) -> CGSize {
        let aspect = Collage.aspectRatio
        if width / height < aspect {
            return CGSize(width: width, height: width / aspect)
        } else {
            return CGSize(width: height * aspect, height: height)
        }
    }

    private func gutterBackground(size: CGSize) -> some View {
        Rectangle()
            .fill(collage.border.gutterColor.color)
            .frame(width: size.width, height: size.height)
    }

    private func photoLayer(size: CGSize) -> some View {
        let inset = collage.border.frame.contentInset
        let gutterX = CGFloat(collage.border.gutterWidth) / max(size.width, 1)
        let gutterY = CGFloat(collage.border.gutterWidth) / max(size.height, 1)
        let rects = collage.preset.cellRects(inset: inset,
                                             gutterX: gutterX, gutterY: gutterY)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(zip(rects.indices, collage.cells)), id: \.0) { idx, cell in
                let rect = rects[idx]
                let pixelRect = CGRect(
                    x: rect.minX * size.width,
                    y: rect.minY * size.height,
                    width: rect.width * size.width,
                    height: rect.height * size.height
                )
                CollageCellView(
                    cell: cell,
                    placeholderLabel: emptyCellLabel?(idx),
                    isFocused: focusedCellIndex == idx,
                    onTap: onTapCell.map { handler in { handler(idx) } }
                )
                .frame(width: pixelRect.width, height: pixelRect.height)
                .position(x: pixelRect.midX, y: pixelRect.midY)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func overlayLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(collage.overlays.sorted { $0.zIndex < $1.zIndex }) { el in
                OverlayElementView(element: el, canvasSize: size)
                    .position(x: el.position.x * size.width,
                              y: el.position.y * size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Cell view

struct CollageCellView: View {
    let cell: CollageCell
    var placeholderLabel: String? = nil
    var isFocused: Bool = false
    /// When non-nil, the cell becomes tappable. When nil, taps fall through
    /// to whatever wraps the cell (e.g. a `NavigationLink` in a thumbnail).
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            visual
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        } else {
            visual
        }
    }

    @ViewBuilder
    private var visual: some View {
        ZStack {
            if let data = cell.image, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Color(.tertiarySystemFill))
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let label = placeholderLabel {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .clipped()
        .overlay(
            Rectangle()
                .strokeBorder(Color.accentColor,
                              lineWidth: isFocused ? 2 : 0)
        )
    }
}

// MARK: - Overlay rendering

struct OverlayElementView: View {
    let element: OverlayElement
    let canvasSize: CGSize

    var body: some View {
        Group {
            switch element.content {
            case .sticker(let s):    StickerOverlay(content: s)
            case .tape(let t):       TapeOverlay(content: t)
            case .doodle(let d):     DoodleOverlay(content: d, canvasSize: canvasSize)
            case .straightLine(let l): StraightLineOverlay(content: l, canvasSize: canvasSize)
            }
        }
        .scaleEffect(element.scale)
        .rotationEffect(.radians(element.rotation))
    }
}

private struct StickerOverlay: View {
    let content: StickerContent
    var body: some View {
        switch content.sticker.glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: content.size))
                .foregroundStyle(content.tint.color)
                .symbolRenderingMode(.hierarchical)
                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
        case .emoji(let emoji):
            Text(emoji).font(.system(size: content.size))
        }
    }
}

private struct TapeOverlay: View {
    let content: TapeContent
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(content.color.color.opacity(0.78))
            .frame(width: content.width, height: content.height)
    }
}

private struct DoodleOverlay: View {
    let content: DoodleContent
    let canvasSize: CGSize
    var body: some View {
        Canvas { ctx, size in
            guard content.points.count > 1 else { return }
            var path = Path()
            for (i, p) in content.points.enumerated() {
                let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path,
                       with: .color(content.color.color),
                       style: .init(lineWidth: content.strokeWidth,
                                    lineCap: .round, lineJoin: .round))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }
}

private struct StraightLineOverlay: View {
    let content: StraightLineContent
    let canvasSize: CGSize
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: content.start.x * size.width,
                                  y: content.start.y * size.height))
            path.addLine(to: CGPoint(x: content.end.x * size.width,
                                     y: content.end.y * size.height))
            ctx.stroke(path,
                       with: .color(content.color.color),
                       style: .init(lineWidth: content.thickness,
                                    lineCap: .round))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Outer frame

private struct FrameOverlay: View {
    let style: FrameStyle
    var body: some View {
        switch style {
        case .none:
            Color.clear
        case .polaroid:
            ZStack {
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 14)
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.001), lineWidth: 0)
                    .padding(.bottom, 24)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        case .filmStrip:
            ZStack {
                Rectangle().strokeBorder(Color.black, lineWidth: 18)
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 6, height: 4)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white)
                                .frame(width: 6, height: 4)
                        }
                    }
                }
                .padding(.vertical, 7)
            }
        case .tornPaper:
            Rectangle()
                .strokeBorder(Color(red: 0.97, green: 0.95, blue: 0.90), lineWidth: 12)
                .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
        }
    }
}

extension FrameStyle {
    /// How much (normalized) to inset photo cells inside the frame so the
    /// outer border doesn't crop the photos.
    var contentInset: CGFloat {
        switch self {
        case .none:       return 0
        case .polaroid:   return 0.04
        case .filmStrip:  return 0.06
        case .tornPaper:  return 0.035
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Full + Polaroid") {
    let data = (try? Data(contentsOf: Bundle.main.url(
        forResource: "Frank_Ocean_1", withExtension: "jpg") ?? URL(fileURLWithPath: "/")))
    let collage = Collage(
        preset: .full,
        cells: [CollageCell(image: data)],
        border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 6),
        overlays: [
            OverlayElement(content: .sticker(StickerContent(sticker: .star, tint: .lemon, size: 44)),
                           position: .init(x: 0.85, y: 0.10), rotation: 0.3),
            OverlayElement(content: .tape(TapeContent(color: .peach, width: 140, height: 22)),
                           position: .init(x: 0.30, y: 0.08), rotation: -0.45)
        ],
        text: "blonded — on repeat all week."
    )
    return CollageView(collage: collage)
        .frame(width: 320)
        .padding(20)
}

#Preview("4 grid + Filmstrip") {
    let collage = Collage(
        preset: .fourGrid,
        cells: Array(repeating: CollageCell(), count: 4),
        border: BorderStyle(frame: .filmStrip, gutterColor: .ink, gutterWidth: 6),
        overlays: [],
        text: ""
    )
    return CollageView(collage: collage,
                       emptyCellLabel: { idx in "tap to add #\(idx + 1)" })
        .frame(width: 320)
        .padding(20)
}
#endif
