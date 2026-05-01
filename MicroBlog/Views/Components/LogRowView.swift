import SwiftUI

/// A single row in the digital-log feed. Compact, monospaced, block-y.
///
/// The first collage photo bleeds across the full row background at low opacity.
/// Layout (left → right):
///   [ vertical bracket ] [ green dot ] [ @handle  date  collage-count ]
struct LogRowView: View {
    let post: Post
    let author: User?

    private static let monoFont  = Font.system(.footnote, design: .monospaced)
    private static let monoSmall = Font.system(.caption2, design: .monospaced)

    /// UIFont mirror of `monoSmall`, used by `MarqueeText` for deterministic
    /// width measurement.
    private static let monoSmallUIFont: UIFont = {
        let size = UIFont.preferredFont(forTextStyle: .caption2).pointSize
        return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }()

    /// First non-empty photo across all collages, decoded for display.
    private var coverImage: UIImage? {
        for collage in post.collages {
            for cell in collage.cells {
                if let data = cell.image, let img = UIImage(data: data) { return img }
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            bracket
            dot
            meta
        }
        .frame(minHeight: 56)
        .background {
            ZStack {
                Color(.secondarySystemBackground)
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .opacity(post.isViewedByCurrentUser ? 0.18 : 0.32)
                }
            }
        }
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.35))
                .frame(height: 0.5)
        }
        .contentShape(Rectangle())
    }

    /// Left-edge vertical accent bar.
    private var bracket: some View {
        Rectangle()
            .fill(bracketColor)
            .frame(width: 3)
            .padding(.vertical, 6)
            .padding(.leading, 12)
            .padding(.trailing, 10)
    }

    private var bracketColor: Color {
        post.isViewedByCurrentUser
            ? Color.primary.opacity(0.15)
            : Color(red: 0.18, green: 0.85, blue: 0.44)
    }

    /// Solid green dot for unseen posts; invisible placeholder when seen.
    private var dot: some View {
        Circle()
            .fill(Color(red: 0.18, green: 0.85, blue: 0.44))
            .frame(width: 6, height: 6)
            .opacity(post.isViewedByCurrentUser ? 0 : 1)
            .padding(.trailing, 8)
    }

    /// Three-line meta column:
    ///   1. @handle                                 time
    ///   2.                  scrolling text (right-aligned, fades on left)
    ///   3. N collages   (only when multi-collage)
    private var meta: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(author?.handle ?? "—")
                    .font(Self.monoFont.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(RelativeTime.string(from: post.day))
                    .font(Self.monoSmall)
                    .foregroundStyle(.secondary)
            }
            if let body = post.collages.first?.text, !body.isEmpty {
                MarqueeText(text: body, uiFont: Self.monoSmallUIFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.18),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            if post.collages.count > 1 {
                Text("\(post.collages.count) collages")
                    .font(Self.monoSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.trailing, 12)
    }
}

// MARK: - MarqueeText
//
// Architecture follows Monty Harper's MarqueeView pattern (Dec 2023): all the
// state that drives the animation lives in an `ObservableObject` controller
// outside the view. SwiftUI may reinitialize the View struct frequently —
// e.g. during LazyVStack recycling, when sibling state changes, or when a
// parent re-renders for unrelated reasons — but the controller persists via
// `@StateObject`, so `startTime` is captured exactly once and the offset
// keeps advancing through view rebuilds.

/// Holds the timing state and width measurements for a single marquee.
/// Widths are computed deterministically via UIFont rather than via async
/// preference keys, so the controller is fully usable from the moment it's
/// constructed.
private final class MarqueeController: ObservableObject {
    let text: String
    let endMarker: String
    let uiFont: UIFont
    let speed: Double
    let pauseDuration: Double

    let textWidth: CGFloat
    let cycleWidth: CGFloat

    /// Captured exactly once when the controller is created. Survives all
    /// view rebuilds since `@StateObject` keeps the same instance.
    private let startTime = Date()

    init(
        text: String,
        uiFont: UIFont,
        endMarker: String = "   ·  END  ·   ",
        speed: Double = 28,
        pauseDuration: Double = 1.2
    ) {
        self.text = text
        self.endMarker = endMarker
        self.uiFont = uiFont
        self.speed = speed
        self.pauseDuration = pauseDuration
        let attrs: [NSAttributedString.Key: Any] = [.font: uiFont]
        self.textWidth = (text as NSString).size(withAttributes: attrs).width
        self.cycleWidth = ((text + endMarker) as NSString).size(withAttributes: attrs).width
    }

    /// Sawtooth offset with a flat tail: scroll across `cycleWidth` over
    /// `cycleWidth / speed` seconds, then pause for `pauseDuration` with
    /// the end marker fully revealed, then repeat.
    func offset(at date: Date) -> CGFloat {
        guard cycleWidth > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(startTime)
        let scrollDuration = Double(cycleWidth) / speed
        let totalDuration = scrollDuration + pauseDuration
        let phase = elapsed.truncatingRemainder(dividingBy: totalDuration)
        if phase < scrollDuration {
            return -CGFloat(phase / scrollDuration) * cycleWidth
        } else {
            return -cycleWidth
        }
    }
}

/// A single-line horizontally scrolling text. If it fits its container, it
/// renders statically (right-aligned); otherwise it scrolls left, pauses on
/// an in-line `END` marker, and repeats forever.
private struct MarqueeText: View {
    @StateObject private var controller: MarqueeController

    init(text: String, uiFont: UIFont) {
        self._controller = StateObject(
            wrappedValue: MarqueeController(text: text, uiFont: uiFont)
        )
    }

    var body: some View {
        // Invisible Text without `.fixedSize()` provides the natural
        // single-line height and accepts any proposed width — bounding our
        // outer size so we can never push the row off-screen.
        Text(controller.text)
            .font(Font(controller.uiFont))
            .lineLimit(1)
            .opacity(0)
            .overlay {
                GeometryReader { geo in
                    content(containerWidth: geo.size.width)
                }
            }
            .clipped()
    }

    @ViewBuilder
    private func content(containerWidth: CGFloat) -> some View {
        if controller.textWidth <= containerWidth {
            // Fits → static, right-aligned.
            Text(controller.text)
                .font(Font(controller.uiFont))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            // Overflow → scroll. Two `text + END` pairs back-to-back hide
            // the seam when the offset wraps.
            TimelineView(.animation) { context in
                HStack(spacing: 0) {
                    pair
                    pair
                }
                .offset(x: controller.offset(at: context.date))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var pair: some View {
        HStack(spacing: 0) {
            Text(controller.text)
                .font(Font(controller.uiFont))
                .fixedSize()
                .lineLimit(1)
            Text(controller.endMarker)
                .font(Font(controller.uiFont))
                .fixedSize()
                .lineLimit(1)
                .foregroundStyle(.tertiary)
        }
    }
}

#if DEBUG
#Preview("Log row — unseen") {
    let author = User(username: "ada", displayName: "Ada Lovelace",
                      bio: "", avatarHue: 0.05)
    let data = try? Data(contentsOf: Bundle.main.url(
        forResource: "Frank_Ocean_1", withExtension: "jpg") ?? URL(fileURLWithPath: "/"))
    let collage = Collage(preset: .twoHorizontal,
                          cells: [CollageCell(image: data), CollageCell()],
                          border: BorderStyle(), overlays: [], text: "afternoon")
    let post = Post(authorId: author.id, day: Date(),
                    collages: [collage, collage], isViewedByCurrentUser: false)
    return VStack(spacing: 2) {
        LogRowView(post: post, author: author)
        LogRowView(post: Post(authorId: author.id, day: Date().addingTimeInterval(-86_400),
                              collages: [collage], isViewedByCurrentUser: true),
                   author: User(username: "grace", displayName: "Grace Hopper",
                                bio: "", avatarHue: 0.78))
        LogRowView(post: Post(authorId: author.id, day: Date().addingTimeInterval(-172_800),
                              collages: [collage], isViewedByCurrentUser: false),
                   author: User(username: "alan", displayName: "Alan Turing",
                                bio: "", avatarHue: 0.33))
    }
    .padding(.horizontal, 0)
}
#endif
