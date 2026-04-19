import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .home
    @State private var editorShown = false

    enum Tab: Hashable { case home, search, notifications, profile }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                NavigationStack { FeedView(backend: appState.backend) }
                    .tabItem { Label("Pages", systemImage: "square.grid.2x2") }
                    .tag(Tab.home)

                NavigationStack { SearchView(backend: appState.backend) }
                    .tabItem { Label("Find", systemImage: "magnifyingglass") }
                    .tag(Tab.search)

                NavigationStack { NotificationsView(backend: appState.backend) }
                    .tabItem { Label("Activity", systemImage: "bell") }
                    .badge(appState.unreadNotifications)
                    .tag(Tab.notifications)

                NavigationStack {
                    ProfileView(userId: appState.currentUser.id, backend: appState.backend)
                }
                .tabItem { Label("You", systemImage: "person") }
                .tag(Tab.profile)
            }

            EditorFloatingButton { editorShown = true }
                .padding(.trailing, 20)
                .padding(.bottom, 70)
                .accessibilityLabel("Open today's page")
        }
        .sheet(isPresented: $editorShown) {
            PageEditorView(backend: appState.backend)
        }
    }
}

private struct EditorFloatingButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil.and.scribble")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(colors: [Color(red: 0.95, green: 0.45, blue: 0.55),
                                            Color(red: 0.55, green: 0.40, blue: 0.95)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("App") {
    RootView()
        .environmentObject(AppState())
}
#endif
