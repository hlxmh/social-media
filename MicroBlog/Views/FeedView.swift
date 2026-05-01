import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: FeedViewModel(backend: backend))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        Group {
            if case let .failed(message) = viewModel.state {
                EmptyStateView(title: "Couldn't load",
                               subtitle: message,
                               systemImage: "exclamationmark.triangle")
            } else if viewModel.posts.isEmpty {
                if case .loaded = viewModel.state {
                    EmptyStateView(title: "Quiet day",
                                   subtitle: "Posts from people you follow will appear here.",
                                   systemImage: "rectangle.stack")
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                grid
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: PostRoute.self) { route in
            switch route {
            case .detail(let id):
                PostDetailView(postId: id, backend: viewModel.backend)
            }
        }
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id):
                ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.refresh() }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { idx, post in
                    NavigationLink(value: PostRoute.detail(post.id)) {
                        PostThumbnailView(
                            post: post,
                            author: viewModel.authors[post.authorId],
                            tilt: idx.isMultiple(of: 2) ? -1.5 : 1.5
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
    }
}

enum PostRoute: Hashable { case detail(UUID) }
enum UserRoute: Hashable { case profile(UUID) }

#if DEBUG
#Preview("Feed") {
    PreviewScaffold.WithAppState {
        NavigationStack {
            FeedView(backend: PreviewScaffold.backend)
        }
    }
}
#endif
