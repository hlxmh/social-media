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
            Spacer(minLength: 8)
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

    /// @handle, relative date, collage count — all monospaced.
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
            if post.collages.count > 1 {
                Text("\(post.collages.count) collages")
                    .font(Self.monoSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
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
