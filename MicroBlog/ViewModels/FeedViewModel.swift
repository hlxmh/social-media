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

    private func hydrateAuthors(for posts: [Post]) async {
        let missing = Set(posts.map(\.authorId)).subtracting(authors.keys)
        for id in missing {
            if let u = try? await backend.user(withId: id) { authors[id] = u }
        }
    }
}
