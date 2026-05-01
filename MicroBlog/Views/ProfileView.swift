import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel

    init(userId: UUID, backend: BackendService) {
        _viewModel = StateObject(wrappedValue:
            ProfileViewModel(backend: backend, userId: userId))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        Group {
            if let user = viewModel.user {
                ScrollView {
                    VStack(spacing: 16) {
                        header(user: user)
                        if viewModel.posts.isEmpty {
                            EmptyStateView(
                                title: "No posts yet",
                                subtitle: viewModel.isCurrentUser
                                    ? "Tap the editor to make today's first collage."
                                    : "When \(user.displayName) posts, you'll see it here.",
                                systemImage: "rectangle.stack")
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { idx, post in
                                    NavigationLink(value: PostRoute.detail(post.id)) {
                                        PostThumbnailView(
                                            post: post,
                                            author: user,
                                            tilt: idx.isMultiple(of: 2) ? -1.5 : 1.5
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(title: "User not found",
                               subtitle: "We couldn't load this profile.",
                               systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .navigationTitle(viewModel.user?.handle ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PostRoute.self) { route in
            switch route {
            case .detail(let id): PostDetailView(postId: id, backend: viewModel.backend)
            }
        }
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id): ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task { await viewModel.load() }
    }

    private func header(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AvatarView(user: user, size: 64)
                Spacer()
                if !viewModel.isCurrentUser {
                    FollowButton(isFollowing: viewModel.isFollowing) {
                        Task { await viewModel.toggleFollow() }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.title3.bold())
                Text(user.handle).font(.subheadline).foregroundStyle(.secondary)
            }
            if !user.bio.isEmpty {
                Text(user.bio).font(.callout)
            }
            HStack(spacing: 18) {
                Stat(count: viewModel.posts.count, label: "posts")
                Stat(count: user.followingCount, label: "following")
                Stat(count: user.followersCount, label: "followers")
                Spacer()
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}

private struct Stat: View {
    let count: Int
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)").fontWeight(.semibold).monospacedDigit()
            Text(label).foregroundStyle(.secondary)
        }
    }
}

private struct FollowButton: View {
    let isFollowing: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(isFollowing ? "Following" : "Follow")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(isFollowing ? Color.clear : Color.primary))
                .overlay(Capsule().stroke(Color.primary, lineWidth: isFollowing ? 1 : 0))
                .foregroundStyle(isFollowing ? Color.primary : Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("My profile") {
    PreviewScaffold.WithAppState {
        NavigationStack {
            ProfileView(userId: PreviewScaffold.backend.currentUser.id,
                        backend: PreviewScaffold.backend)
        }
    }
}
#endif
