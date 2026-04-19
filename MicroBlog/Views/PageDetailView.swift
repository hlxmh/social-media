import SwiftUI

struct PageDetailView: View {
    @StateObject private var viewModel: PageDetailViewModel
    @State private var showStickers = false
    @State private var showCommentField = false
    @State private var draftComment = ""

    init(pageId: UUID, backend: BackendService) {
        _viewModel = StateObject(wrappedValue:
            PageDetailViewModel(backend: backend, pageId: pageId))
    }

    var body: some View {
        Group {
            if let page = viewModel.page {
                ScrollView {
                    VStack(spacing: 18) {
                        header(page: page)
                        PageCanvasView(
                            page: page,
                            showReactions: viewModel.showReactions,
                            visibleReactionAuthors: viewModel.visibleReactionAuthors,
                            asPolaroid: false
                        )
                        .padding(.horizontal, 16)
                        reactionsRow(page: page)
                        if viewModel.showReactions {
                            myReactionsSection(page: page)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
            } else if viewModel.error != nil {
                EmptyStateView(title: "Couldn't load",
                               subtitle: viewModel.error ?? "",
                               systemImage: "exclamationmark.triangle")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.page != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showReactions.toggle() } label: {
                        Image(systemName: viewModel.showReactions
                              ? "eye.slash" : "eye")
                    }
                    .help("Hide reactions")
                }
            }
        }
        .sheet(isPresented: $showStickers) {
            StickerPickerView { sticker, tint in
                Task { await viewModel.addStickerReaction(sticker, tint: tint) }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Add a comment", isPresented: $showCommentField) {
            TextField("Say something nice", text: $draftComment)
            Button("Post") {
                let text = draftComment
                draftComment = ""
                Task { await viewModel.addCommentReaction(text) }
            }
            Button("Cancel", role: .cancel) { draftComment = "" }
        }
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id):
                ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task { await viewModel.load() }
    }

    private func header(page: Page) -> some View {
        HStack(spacing: 12) {
            if let author = viewModel.author {
                NavigationLink(value: UserRoute.profile(author.id)) {
                    AvatarView(user: author, size: 44)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(author.displayName).font(.headline)
                    Text(page.day.pageDateLabel)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func reactionsRow(page: Page) -> some View {
        HStack(spacing: 12) {
            Button {
                showStickers = true
            } label: {
                Label("Sticker", systemImage: "face.smiling")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                showCommentField = true
            } label: {
                Label("Comment", systemImage: "bubble.left")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(reactionCountLabel(page: page))
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }

    private func reactionCountLabel(page: Page) -> String {
        let visible = viewModel.visibleReactions.count
        let total = page.reactions.count
        if visible == total { return "\(visible) reaction\(visible == 1 ? "" : "s")" }
        return "\(visible) of \(total) shown"
    }

    @ViewBuilder
    private func myReactionsSection(page: Page) -> some View {
        let mine = page.reactions.filter { $0.authorId == viewModel.backend.currentUser.id }
        if !mine.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Yours on this page").font(.footnote).foregroundStyle(.secondary)
                FlowLayout(spacing: 10) {
                    ForEach(mine) { el in
                        Button {
                            Task { await viewModel.removeMyReaction(el.id) }
                        } label: {
                            myReactionChip(el)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func myReactionChip(_ element: PageElement) -> some View {
        switch element.content {
        case .sticker(let s):
            HStack(spacing: 6) {
                switch s.sticker.glyph {
                case .symbol(let name): Image(systemName: name).foregroundStyle(s.tint.color)
                case .emoji(let e): Text(e)
                }
                Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
        case .text(let t):
            HStack(spacing: 6) {
                Text("\u{201C}\(t.text)\u{201D}").font(.footnote).lineLimit(1)
                Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
        default:
            EmptyView()
        }
    }
}

/// Tiny flow layout so reaction chips wrap naturally.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, totalWidth: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }
        return CGSize(width: totalWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth { x = bounds.minX; y += lineHeight + spacing; lineHeight = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
