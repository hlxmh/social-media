import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel: NotificationsViewModel

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: NotificationsViewModel(backend: backend))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(title: "Nothing new",
                               subtitle: "When people react or follow you, you'll see it here.",
                               systemImage: "bell")
            } else {
                List {
                    ForEach(viewModel.notifications) { n in
                        Row(notification: n,
                            actor: viewModel.actors[n.actorId],
                            page: n.pageId.flatMap { viewModel.pages[$0] })
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PageRoute.self) { route in
            switch route {
            case .detail(let id): PageDetailView(pageId: id, backend: viewModel.backend)
            }
        }
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id): ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct Row: View {
    let notification: PageNotification
    let actor: User?
    let page: Page?

    var body: some View {
        Group {
            if let page {
                NavigationLink(value: PageRoute.detail(page.id)) { content }
            } else if let actor {
                NavigationLink(value: UserRoute.profile(actor.id)) { content }
            } else {
                content
            }
        }
        .listRowBackground(notification.isRead ? Color.clear : Color.accentColor.opacity(0.05))
    }

    private var content: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                if let actor {
                    HStack(spacing: 8) {
                        AvatarView(user: actor, size: 24)
                        Text(actor.displayName).font(.subheadline.weight(.semibold))
                        Text(RelativeTime.string(from: notification.createdAt))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Text(message).font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var iconName: String {
        switch notification.kind {
        case .reaction: return "sparkles"
        case .follow:   return "person.fill.badge.plus"
        }
    }
    private var iconColor: Color {
        switch notification.kind {
        case .reaction: return .pink
        case .follow:   return .purple
        }
    }
    private var message: String {
        switch notification.kind {
        case .reaction: return "reacted on your page"
        case .follow:   return "started following you"
        }
    }
}
