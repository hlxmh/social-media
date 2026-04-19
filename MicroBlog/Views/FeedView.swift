import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel
    @EnvironmentObject private var appState: AppState
    @State private var followingIds: Set<UUID> = []

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
            } else if viewModel.pages.isEmpty {
                if case .loaded = viewModel.state {
                    EmptyStateView(title: "Quiet day",
                                   subtitle: "Pages from people you follow will appear here.",
                                   systemImage: "book.pages")
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                grid
            }
        }
        .navigationTitle("Pages")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: PageRoute.self) { route in
            switch route {
            case .detail(let id):
                PageDetailView(pageId: id, backend: viewModel.backend)
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
            followingIds = await viewModel.backend.followingIds()
        }
        .refreshable {
            await viewModel.refresh()
            followingIds = await viewModel.backend.followingIds()
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { idx, page in
                    NavigationLink(value: PageRoute.detail(page.id)) {
                        PolaroidThumbnailView(
                            page: page,
                            author: viewModel.authors[page.authorId],
                            tilt: idx.isMultiple(of: 2) ? -1.5 : 1.5,
                            showReactions: true,
                            visibleReactionAuthors: visibleReactionAuthors
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

    private var visibleReactionAuthors: Set<UUID> {
        followingIds.union([appState.currentUser.id])
    }
}

enum PageRoute: Hashable { case detail(UUID) }
enum UserRoute: Hashable { case profile(UUID) }

#if DEBUG
#Preview("Feed") {
    NavigationStack {
        FeedView(backend: MockBackend())
    }
    .environmentObject(AppState())
}
#endif
