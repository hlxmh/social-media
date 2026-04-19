import Foundation

protocol BackendService: AnyObject, Sendable {
    var currentUser: User { get }

    // Pages
    func todayPage() async throws -> Page
    func page(byAuthor authorId: UUID, on day: Date) async throws -> Page?
    func page(withId id: UUID) async throws -> Page?
    func pages(byAuthor authorId: UUID) async throws -> [Page]

    /// Pages from people the current user follows + the current user, newest first.
    func feed() async throws -> [Page]

    /// Replace today's page contents (theme + own elements) for the current user.
    /// Reactions placed by other users are preserved.
    @discardableResult
    func saveTodayPage(theme: PageTheme, ownElements: [PageElement]) async throws -> Page

    /// Add a reaction (sticker or comment) to someone else's page.
    @discardableResult
    func addReaction(to pageId: UUID, element: PageElement) async throws -> Page

    /// Remove your own reaction.
    @discardableResult
    func removeReaction(elementId: UUID, on pageId: UUID) async throws -> Page

    // Users
    func user(withId id: UUID) async throws -> User?
    func searchUsers(query: String) async throws -> [User]
    func suggestedUsers(limit: Int) async throws -> [User]

    @discardableResult
    func toggleFollow(userId: UUID) async throws -> Bool

    func isFollowing(userId: UUID) async -> Bool
    func followingIds() async -> Set<UUID>

    // Notifications
    func notifications() async throws -> [PageNotification]
    func markNotificationsRead() async
    func unreadNotificationCount() async -> Int
}
