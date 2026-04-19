import Foundation
import SwiftUI

/// In-memory mock with seeded users and a few days of seeded pages.
actor MockBackend: BackendService {

    // MARK: - State

    private var users: [UUID: User] = [:]
    private var pages: [UUID: Page] = [:]
    private var followGraph: [UUID: Set<UUID>] = [:]
    private var notificationsByUser: [UUID: [PageNotification]] = [:]

    let currentUserId: UUID
    private let _currentUserSnapshot: Snapshot<User>

    nonisolated var currentUser: User { _currentUserSnapshot.value }

    // MARK: - Init / Seed

    init() {
        let me = User(
            username: "you",
            displayName: "You",
            bio: "Today's page is a work in progress.",
            avatarHue: 0.58,
            joinedAt: Date().addingTimeInterval(-60 * 86_400),
            followersCount: 12,
            followingCount: 7
        )
        self.currentUserId = me.id
        self._currentUserSnapshot = Snapshot(me)
        seed(me: me)
    }

    private func seed(me: User) {
        let seedUsers: [User] = [
            me,
            User(username: "ada",      displayName: "Ada Lovelace",
                 bio: "Notes on the Analytical Engine.",
                 avatarHue: 0.05, followersCount: 4_213, followingCount: 88),
            User(username: "grace",    displayName: "Grace Hopper",
                 bio: "Nanoseconds, mostly.",
                 avatarHue: 0.78, followersCount: 9_887, followingCount: 201),
            User(username: "alan",     displayName: "Alan Turing",
                 bio: "Out walking. Will think later.",
                 avatarHue: 0.33, followersCount: 22_341, followingCount: 17),
            User(username: "margaret", displayName: "Margaret Hamilton",
                 bio: "Pioneers, by necessity.",
                 avatarHue: 0.92, followersCount: 7_654, followingCount: 142),
            User(username: "donald",   displayName: "Donald K.",
                 bio: "Premature optimization is the root of all evil.",
                 avatarHue: 0.46, followersCount: 18_902, followingCount: 6)
        ]
        for u in seedUsers { users[u.id] = u }
        followGraph[currentUserId] = Set(seedUsers.dropFirst().prefix(3).map(\.id))

        // Build sample pages for the last few days for a few users.
        let today = Date().dayKey
        let dayOffsets = [0, -1, -2, -3]
        for user in seedUsers.dropFirst() {
            for offset in dayOffsets where Bool.random() {
                let day = Calendar.current.date(byAdding: .day, value: offset, to: today)!
                let page = makeSeedPage(for: user, on: day, allUsers: seedUsers)
                pages[page.id] = page
            }
        }

        // Seed a handful of notifications for the current user.
        let firstFollowed = followGraph[currentUserId]?.first
        let canned: [PageNotification] = [
            PageNotification(kind: .follow, actorId: seedUsers[1].id, createdAt: Date().addingTimeInterval(-300)),
            firstFollowed.map {
                PageNotification(kind: .reaction, actorId: $0,
                                 pageId: pages.values.first(where: { $0.authorId == currentUserId })?.id,
                                 createdAt: Date().addingTimeInterval(-1_800))
            }
        ].compactMap { $0 }
        notificationsByUser[currentUserId] = canned
    }

    private func makeSeedPage(for author: User, on day: Date, allUsers: [User]) -> Page {
        let themes: [PageTheme] = [.warmPaper, .y2k, .dreamy, .zine, .midnight, .grid]
        let theme = themes.randomElement() ?? .warmPaper

        var elements: [PageElement] = []
        var z: Double = 0

        let titleColor = theme.defaultInk
        elements.append(.init(
            authorId: author.id,
            content: .text(TextContent(
                text: titlePool.randomElement()!,
                font: [.handwritten, .serif, .rounded].randomElement()!,
                color: titleColor,
                size: Double.random(in: 26...36)
            )),
            position: .init(x: Double.random(in: 0.25...0.6), y: Double.random(in: 0.10...0.18)),
            rotation: Double.random(in: -0.18...0.18),
            scale: 1, zIndex: z
        ))
        z += 1

        // A washi tape strip.
        if Bool.random() {
            elements.append(.init(
                authorId: author.id,
                content: .tape(TapeContent(
                    color: [StickerTint.peach, .lemon, .mint, .lilac, .pink].randomElement()!,
                    width: 180, height: 28
                )),
                position: .init(x: Double.random(in: 0.3...0.7), y: Double.random(in: 0.4...0.55)),
                rotation: Double.random(in: -0.6...0.6),
                scale: Double.random(in: 0.85...1.15), zIndex: z
            ))
            z += 1
        }

        // A cluster of stickers.
        for _ in 0..<Int.random(in: 2...5) {
            elements.append(.init(
                authorId: author.id,
                content: .sticker(StickerContent(
                    sticker: Sticker.allCases.randomElement()!,
                    tint: StickerTint.allCases.randomElement()!,
                    size: Double.random(in: 36...64)
                )),
                position: .init(x: Double.random(in: 0.15...0.85),
                                y: Double.random(in: 0.25...0.85)),
                rotation: Double.random(in: -0.5...0.5),
                scale: 1, zIndex: z
            ))
            z += 1
        }

        // A short caption.
        elements.append(.init(
            authorId: author.id,
            content: .text(TextContent(
                text: captionPool.randomElement()!,
                font: .handwritten,
                color: titleColor,
                size: 16
            )),
            position: .init(x: Double.random(in: 0.3...0.7), y: Double.random(in: 0.7...0.88)),
            rotation: Double.random(in: -0.1...0.1),
            scale: 1, zIndex: z
        ))

        return Page(authorId: author.id, day: day, theme: theme, elements: elements)
    }

    private let titlePool = ["good morning", "today", "field notes", "scraps", "notebook",
                             "soft focus", "sunday", "tiny things", "saw this", "playlist"]
    private let captionPool = ["mood: gentle", "🌿 outside hours",
                               "thinking about lattices", "rewatched a film",
                               "wrote one sentence", "no notes",
                               "the cat helped", "a small win"]

    // MARK: - Reads

    func todayPage() async throws -> Page {
        let day = Date().dayKey
        if let existing = pages.values.first(where: { $0.authorId == currentUserId && $0.day == day }) {
            return existing
        }
        let blank = Page(authorId: currentUserId, day: day, theme: .warmPaper, elements: [])
        pages[blank.id] = blank
        return blank
    }

    func page(byAuthor authorId: UUID, on day: Date) async throws -> Page? {
        let key = day.dayKey
        return pages.values.first { $0.authorId == authorId && $0.day == key }
    }

    func page(withId id: UUID) async throws -> Page? {
        try await simulate()
        return pages[id]
    }

    func pages(byAuthor authorId: UUID) async throws -> [Page] {
        try await simulate()
        return pages.values.filter { $0.authorId == authorId }.sorted { $0.day > $1.day }
    }

    func feed() async throws -> [Page] {
        try await simulate()
        let visible = (followGraph[currentUserId] ?? []).union([currentUserId])
        return pages.values
            .filter { visible.contains($0.authorId) && !$0.elements.isEmpty }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Mutations

    func saveTodayPage(theme: PageTheme, ownElements: [PageElement]) async throws -> Page {
        try await simulate()
        let day = Date().dayKey
        var page = pages.values.first(where: { $0.authorId == currentUserId && $0.day == day })
            ?? Page(authorId: currentUserId, day: day, theme: theme)
        let reactions = page.reactions
        page.theme = theme
        page.elements = ownElements + reactions
        page.updatedAt = Date()
        pages[page.id] = page
        return page
    }

    func addReaction(to pageId: UUID, element: PageElement) async throws -> Page {
        try await simulate(short: true)
        guard var page = pages[pageId] else { throw BackendError.notFound }
        page.elements.append(element)
        page.updatedAt = Date()
        pages[pageId] = page
        if page.authorId != currentUserId {
            appendNotification(for: page.authorId,
                               PageNotification(kind: .reaction, actorId: currentUserId, pageId: pageId))
        }
        return page
    }

    func removeReaction(elementId: UUID, on pageId: UUID) async throws -> Page {
        try await simulate(short: true)
        guard var page = pages[pageId] else { throw BackendError.notFound }
        page.elements.removeAll { $0.id == elementId && $0.authorId == currentUserId }
        page.updatedAt = Date()
        pages[pageId] = page
        return page
    }

    // MARK: - Users

    func user(withId id: UUID) async throws -> User? {
        try await simulate(short: true)
        return users[id]
    }

    func searchUsers(query: String) async throws -> [User] {
        try await simulate(short: true)
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return users.values
            .filter { $0.id != currentUserId &&
                ($0.username.lowercased().contains(q) || $0.displayName.lowercased().contains(q)) }
            .sorted { $0.followersCount > $1.followersCount }
    }

    func suggestedUsers(limit: Int) async throws -> [User] {
        try await simulate(short: true)
        let following = followGraph[currentUserId] ?? []
        return users.values
            .filter { $0.id != currentUserId && !following.contains($0.id) }
            .sorted { $0.followersCount > $1.followersCount }
            .prefix(limit)
            .map { $0 }
    }

    func toggleFollow(userId: UUID) async throws -> Bool {
        try await simulate(short: true)
        guard userId != currentUserId else { return false }
        var following = followGraph[currentUserId] ?? []
        let nowFollowing: Bool
        if following.contains(userId) {
            following.remove(userId)
            nowFollowing = false
            mutateUser(userId) { $0.followersCount = max(0, $0.followersCount - 1) }
            mutateUser(currentUserId) { $0.followingCount = max(0, $0.followingCount - 1) }
        } else {
            following.insert(userId)
            nowFollowing = true
            mutateUser(userId) { $0.followersCount += 1 }
            mutateUser(currentUserId) { $0.followingCount += 1 }
            appendNotification(for: userId,
                               PageNotification(kind: .follow, actorId: currentUserId))
        }
        followGraph[currentUserId] = following
        return nowFollowing
    }

    func isFollowing(userId: UUID) -> Bool {
        (followGraph[currentUserId] ?? []).contains(userId)
    }

    func followingIds() -> Set<UUID> {
        followGraph[currentUserId] ?? []
    }

    // MARK: - Notifications

    func notifications() async throws -> [PageNotification] {
        try await simulate(short: true)
        return (notificationsByUser[currentUserId] ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    func markNotificationsRead() {
        guard var list = notificationsByUser[currentUserId] else { return }
        for i in list.indices { list[i].isRead = true }
        notificationsByUser[currentUserId] = list
    }

    func unreadNotificationCount() -> Int {
        (notificationsByUser[currentUserId] ?? []).filter { !$0.isRead }.count
    }

    // MARK: - Helpers

    private func mutateUser(_ id: UUID, _ block: (inout User) -> Void) {
        guard var u = users[id] else { return }
        block(&u)
        users[id] = u
        if id == currentUserId { _currentUserSnapshot.value = u }
    }

    private func appendNotification(for userId: UUID, _ n: PageNotification) {
        var list = notificationsByUser[userId] ?? []
        list.append(n)
        notificationsByUser[userId] = list
    }

    private func simulate(short: Bool = false) async throws {
        try await Task.sleep(nanoseconds: short ? 60_000_000 : 220_000_000)
    }
}

enum BackendError: LocalizedError {
    case notFound
    var errorDescription: String? {
        switch self { case .notFound: return "Not found." }
    }
}

/// Tiny lock-protected wrapper used to expose the current user synchronously
/// from the actor without relying on actor isolation.
final class Snapshot<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { self._value = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}
