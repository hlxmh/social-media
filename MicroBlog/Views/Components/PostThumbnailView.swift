import SwiftUI

/// A post rendered as a thumbnail card: the first collage on top, author name
/// + day below, and a small badge if the post has multiple collages.
struct PostThumbnailView: View {
    let post: Post
    let author: User?
    var tilt: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let collage = post.collages.first {
                    CollageView(collage: collage)
                } else {
                    placeholder
                }
                if post.collages.count > 1 {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(8)
                        .accessibilityLabel("\(post.collages.count) collages")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                if let author {
                    Text(author.displayName)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                }
                Text(post.day.pageDateLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(tilt))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .aspectRatio(Collage.aspectRatio, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            )
    }
}

#if DEBUG
#Preview("Thumbnail") {
    let author = User(username: "ada", displayName: "Ada Lovelace",
                      bio: "", avatarHue: 0.05)
    let collage = Collage(
        preset: .twoVertical,
        cells: [CollageCell(), CollageCell()],
        border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 8),
        overlays: [
            OverlayElement(content: .sticker(StickerContent(
                sticker: .star, tint: .lemon, size: 40)),
                position: .init(x: 0.85, y: 0.10), rotation: 0.3)
        ],
        text: "morning + afternoon"
    )
    let post = Post(authorId: author.id, day: Date(), collages: [collage, collage])
    return HStack(spacing: 16) {
        PostThumbnailView(post: post, author: author, tilt: -1.5)
        PostThumbnailView(post: Post(authorId: author.id, day: Date(),
                                     collages: [collage]),
                          author: author, tilt: 1.5)
    }
    .frame(width: 360)
    .padding(40)
    .background(Color(.systemGroupedBackground))
}
#endif
