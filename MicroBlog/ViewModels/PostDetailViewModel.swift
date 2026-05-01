import Foundation
import SwiftUI

@MainActor
final class PostDetailViewModel: ObservableObject {
    @Published private(set) var post: Post?
    @Published private(set) var author: User?
    @Published var error: String?

    let backend: BackendService
    let postId: UUID

    init(backend: BackendService, postId: UUID) {
        self.backend = backend
        self.postId = postId
    }

    func load() async {
        do {
            let p = try await backend.post(withId: postId)
            post = p
            if let p { author = try await backend.user(withId: p.authorId) }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
