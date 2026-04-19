import SwiftUI

/// A page rendered as a Polaroid card with author, date label, and a slight tilt.
struct PolaroidThumbnailView: View {
    let page: Page
    let author: User?
    var tilt: Double = 0
    var showReactions: Bool = true
    var visibleReactionAuthors: Set<UUID>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageCanvasView(
                page: page,
                showReactions: showReactions,
                visibleReactionAuthors: visibleReactionAuthors,
                asPolaroid: false
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                if let author {
                    Text(author.displayName)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                }
                Text(page.day.pageDateLabel)
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
}

#if DEBUG
#Preview("Polaroid") {
    let author = User(username: "ada", displayName: "Ada Lovelace",
                      bio: "", avatarHue: 0.05)
    let page = Page(
        authorId: author.id,
        day: Date(),
        theme: .dreamy,
        elements: [
            PageElement(authorId: author.id,
                        content: .text(TextContent(text: "soft focus",
                                                   font: .handwritten, color: .ink, size: 30)),
                        position: .init(x: 0.45, y: 0.20), rotation: -0.05),
            PageElement(authorId: author.id,
                        content: .sticker(StickerContent(sticker: .flower, size: 56)),
                        position: .init(x: 0.30, y: 0.55), rotation: -0.2),
            PageElement(authorId: author.id,
                        content: .sticker(StickerContent(sticker: .butterfly, size: 56)),
                        position: .init(x: 0.70, y: 0.65), rotation: 0.3)
        ]
    )
    return PolaroidThumbnailView(page: page, author: author, tilt: -1.5)
        .frame(width: 220)
        .padding(40)
        .background(Color(.systemGroupedBackground))
}
#endif
