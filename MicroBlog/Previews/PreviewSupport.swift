#if DEBUG
import SwiftUI

/// Shared scaffolding for SwiftUI previews. Boots a `MockBackend`, an
/// `AppState`, and resolves async data (a post id, a user id) before
/// rendering the wrapped content. Lets Live previews demonstrate full app
/// flows without launching the simulator.
enum PreviewScaffold {

    /// A reusable backend + AppState across previews so every preview tree
    /// sees the same seeded data set.
    @MainActor static let backend: MockBackend = MockBackend()
    @MainActor static let appState: AppState = AppState(backend: backend)

    /// Looks up the first feed post id, then renders `content`. Callers
    /// pass the backend explicitly to avoid `@MainActor` default-parameter
    /// surprises under strict concurrency.
    struct PostIdLoader<Content: View>: View {
        @State private var postId: UUID?
        let backend: BackendService
        let content: (UUID) -> Content

        init(backend: BackendService,
             @ViewBuilder content: @escaping (UUID) -> Content) {
            self.backend = backend
            self.content = content
        }

        var body: some View {
            Group {
                if let postId {
                    content(postId)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task { await loadFirstPostId() }
        }

        private func loadFirstPostId() async {
            do {
                if let first = try await backend.feed().first {
                    postId = first.id
                    return
                }
            } catch {}

            let myId = backend.currentUser.id
            do {
                if let first = try await backend.posts(byAuthor: myId).first {
                    postId = first.id
                }
            } catch {}
        }
    }

    /// Renders `content` with the shared AppState injected as an env object.
    struct WithAppState<Content: View>: View {
        let content: () -> Content
        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
        var body: some View {
            content().environmentObject(PreviewScaffold.appState)
        }
    }
}
#endif
