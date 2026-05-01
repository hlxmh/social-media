import SwiftUI

struct PostDetailView: View {
    @StateObject private var viewModel: PostDetailViewModel
    @State private var currentIndex = 0

    init(postId: UUID, backend: BackendService) {
        _viewModel = StateObject(wrappedValue:
            PostDetailViewModel(backend: backend, postId: postId))
    }

    var body: some View {
        Group {
            if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(post: post)
                        carousel(post: post)
                        textSection(post: post)
                    }
                    .padding(.vertical, 12)
                }
            } else if viewModel.error != nil {
                EmptyStateView(title: "Couldn't load",
                               subtitle: viewModel.error ?? "",
                               systemImage: "exclamationmark.triangle")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id):
                ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Sections

    private func header(post: Post) -> some View {
        HStack(spacing: 12) {
            if let author = viewModel.author {
                NavigationLink(value: UserRoute.profile(author.id)) {
                    AvatarView(user: author, size: 44)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(author.displayName).font(.headline)
                    Text(post.day.pageDateLabel)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if post.collages.count > 1 {
                Text("\(currentIndex + 1) / \(post.collages.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func carousel(post: Post) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(post.collages.enumerated()), id: \.element.id) { idx, collage in
                CollageView(collage: collage)
                    .padding(.horizontal, 16)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: post.collages.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: carouselHeight)
    }

    /// Approximate; the carousel sizes itself with the collage aspect.
    private var carouselHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let collageWidth = max(0, screenWidth - 32)
        let collageHeight = collageWidth / Collage.aspectRatio
        return collageHeight + 32 // dots + breathing room
    }

    @ViewBuilder
    private func textSection(post: Post) -> some View {
        let safeIndex = min(max(currentIndex, 0), post.collages.count - 1)
        let collage = post.collages[safeIndex]
        if !collage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(collage.text)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("Post detail") {
    PreviewScaffold.WithAppState {
        PreviewScaffold.PostIdLoader(backend: PreviewScaffold.backend) { id in
            NavigationStack {
                PostDetailView(postId: id, backend: PreviewScaffold.backend)
            }
        }
    }
}
#endif
