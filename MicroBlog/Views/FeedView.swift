import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: FeedViewModel(backend: backend))
    }

    var body: some View {
        Group {
            if case let .failed(message) = viewModel.state {
                EmptyStateView(title: "Couldn't load",
                               subtitle: message,
                               systemImage: "exclamationmark.triangle")
            } else if viewModel.posts.isEmpty {
                if case .loaded = viewModel.state {
                    EmptyStateView(title: "Nothing yet",
                                   subtitle: "Follow people to see their posts here.",
                                   systemImage: "list.bullet.rectangle")
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                log
            }
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("FEED")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .kerning(2)
            }
        }
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

    // MARK: - Log list

    private var log: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: PostRoute.detail(post.id)) {
                        LogRowView(
                            post: post,
                            author: viewModel.authors[post.authorId]
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.markViewed(post)
                    })
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
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
