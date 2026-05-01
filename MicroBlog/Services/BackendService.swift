import Foundation

protocol BackendService: AnyObject, Sendable {
    var currentUser: User { get }

    // Posts
    func todayPost() async throws -> Post
    func post(byAuthor authorId: UUID, on day: Date) async throws -> Post?
    func post(withId id: UUID) async throws -> Post?
    func posts(byAuthor authorId: UUID) async throws -> [Post]

    /// Posts from people the current user follows + the current user, newest first.
    func feed() async throws -> [Post]

    /// Replace today's post for the current user with the given collages.
    @discardableResult
    func saveTodayPost(collages: [Collage]) async throws -> Post

    // Users
    func user(withId id: UUID) async throws -> User?
    func searchUsers(query: String) async throws -> [User]
    func suggestedUsers(limit: Int) async throws -> [User]

    @discardableResult
    func toggleFollow(userId: UUID) async throws -> Bool

    func isFollowing(userId: UUID) async -> Bool
    func followingIds() async -> Set<UUID>

    // Notifications
    func notifications() async throws -> [AppNotification]
    func markNotificationsRead() async
    func unreadNotificationCount() async -> Int
}
