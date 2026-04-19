import Foundation
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var pages: [Page] = []
    @Published private(set) var isFollowing = false
    @Published private(set) var isLoading = false
    @Published var error: String?

    let backend: BackendService
    let userId: UUID

    init(backend: BackendService, userId: UUID) {
        self.backend = backend
        self.userId = userId
    }

    var isCurrentUser: Bool { backend.currentUser.id == userId }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await backend.user(withId: userId)
            pages = try await backend.pages(byAuthor: userId)
            isFollowing = await backend.isFollowing(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleFollow() async {
        if let now = try? await backend.toggleFollow(userId: userId) {
            isFollowing = now
            user = try? await backend.user(withId: userId)
        }
    }
}
