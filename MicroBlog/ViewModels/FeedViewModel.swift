import Foundation
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    enum LoadState { case idle, loading, loaded, failed(String) }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var posts: [Post] = []
    @Published private(set) var authors: [UUID: User] = [:]

    let backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    func load() async {
        state = .loading
        do {
            let fetched = try await backend.feed()
            posts = fetched
            await hydrateAuthors(for: fetched)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async { await load() }

    /// Call when the user taps a row to navigate into the post.
    /// Updates the local copy immediately (dot disappears) and notifies the backend.
    func markViewed(_ post: Post) {
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].isViewedByCurrentUser = true
        }
        Task { await backend.markPostViewed(postId: post.id) }
    }

    private func hydrateAuthors(for posts: [Post]) async {
        let missing = Set(posts.map(\.authorId)).subtracting(authors.keys)
        for id in missing {
            if let u = try? await backend.user(withId: id) { authors[id] = u }
        }
    }
}
