import Foundation
import SwiftUI

/// In-memory mock with seeded users and a few days of seeded posts.
actor MockBackend: BackendService {

    // MARK: - State

    private var users: [UUID: User] = [:]
    private var posts: [UUID: Post] = [:]
    private var followGraph: [UUID: Set<UUID>] = [:]
    private var notificationsByUser: [UUID: [AppNotification]] = [:]
    /// Set of post IDs the current user has viewed.
    private var viewedPostIds: Set<UUID> = []

    let currentUserId: UUID
    private let _currentUserSnapshot: Snapshot<User>

    nonisolated var currentUser: User { _currentUserSnapshot.value }

    // MARK: - Init

    init() {
        let me = User(
            username: "you",
            displayName: "You",
            bio: "Today's post is a work in progress.",
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
        let ada      = User(username: "ada",      displayName: "Ada Lovelace",
                            bio: "Notes on the Analytical Engine.",
                            avatarHue: 0.05, followersCount: 4_213, followingCount: 88)
        let grace    = User(username: "grace",    displayName: "Grace Hopper",
                            bio: "Nanoseconds, mostly.",
                            avatarHue: 0.78, followersCount: 9_887, followingCount: 201)
        let alan     = User(username: "alan",     displayName: "Alan Turing",
                            bio: "Out walking. Will think later.",
                            avatarHue: 0.33, followersCount: 22_341, followingCount: 17)
        let margaret = User(username: "margaret", displayName: "Margaret Hamilton",
                            bio: "Pioneers, by necessity.",
                            avatarHue: 0.92, followersCount: 7_654, followingCount: 142)
        let donald   = User(username: "donald",   displayName: "Donald K.",
                            bio: "Premature optimization is the root of all evil.",
                            avatarHue: 0.46, followersCount: 18_902, followingCount: 6)
        let katherine = User(username: "katherine", displayName: "Katherine Johnson",
                             bio: "Run the numbers again.",
                             avatarHue: 0.62, followersCount: 11_204, followingCount: 33)
        let jean      = User(username: "jean",      displayName: "Jean Sammet",
                             bio: "Languages are for people.",
                             avatarHue: 0.18, followersCount: 3_440, followingCount: 95)
        let allUsers = [me, ada, grace, alan, margaret, donald, katherine, jean]
        for u in allUsers { users[u.id] = u }

        // Current user follows ada, grace, alan, katherine, jean — their posts land in the feed.
        followGraph[currentUserId] = [ada.id, grace.id, alan.id, katherine.id, jean.id]

        let today = Date().dayKey
        let yesterday = today.offset(days: -1)
        let twoDaysAgo = today.offset(days: -2)
        let threeDaysAgo = today.offset(days: -3)

        // ── ada ─────────────────────────────────────────────────────────────
        // Today: two-collage post — Frank Ocean full-frame + a 2-up with 334/613
        addPost(Post(authorId: ada.id, day: today, collages: [
            Collage(
                preset: .full,
                cells: [CollageCell(image: photo("Frank_Ocean_1"))],
                border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 8),
                overlays: [
                    overlay(.tape(TapeContent(color: .peach, width: 140, height: 22)),
                            at: .init(x: 0.30, y: 0.08), rot: -0.45, z: 0),
                    overlay(.sticker(StickerContent(sticker: .music, tint: .lilac, size: 44)),
                            at: .init(x: 0.85, y: 0.92), rot: 0.3, z: 1)
                ],
                text: "blonded — on repeat all week. saturday afternoon, windows open."
            ),
            Collage(
                preset: .twoHorizontal,
                cells: [CollageCell(image: photo("334-3024x4032")),
                        CollageCell(image: photo("613-3000x4000"))],
                border: BorderStyle(frame: .none, gutterColor: .paper, gutterWidth: 6),
                overlays: [
                    overlay(.sticker(StickerContent(sticker: .sun, tint: .lemon, size: 38)),
                            at: .init(x: 0.82, y: 0.15), rot: 0.2, z: 0)
                ],
                text: "the light today was something else."
            )
        ]))

        // Yesterday: full-frame 691
        addPost(Post(authorId: ada.id, day: yesterday, collages: [
            Collage(
                preset: .full,
                cells: [CollageCell(image: photo("691-2000x3000"))],
                border: BorderStyle(frame: .filmStrip, gutterColor: .ink, gutterWidth: 10),
                overlays: [
                    overlay(.sticker(StickerContent(sticker: .star, tint: .pink, size: 36)),
                            at: .init(x: 0.12, y: 0.88), rot: -0.3, z: 0)
                ],
                text: "found this place by accident. definitely going back."
            )
        ]))

        // ── grace ────────────────────────────────────────────────────────────
        // Today: four-grid with all four numbered photos
        addPost(Post(authorId: grace.id, day: today, collages: [
            Collage(
                preset: .fourGrid,
                cells: [CollageCell(image: photo("334-3024x4032")),
                        CollageCell(image: photo("613-3000x4000")),
                        CollageCell(image: photo("691-2000x3000")),
                        CollageCell(image: photo("839-3024x4032"))],
                border: BorderStyle(frame: .none, gutterColor: .mint, gutterWidth: 4),
                overlays: [
                    overlay(.tape(TapeContent(color: .mint, width: 120, height: 20)),
                            at: .init(x: 0.5, y: 0.05), rot: 0.15, z: 0)
                ],
                text: "a few frames from the weekend. nothing special, everything special."
            )
        ]))

        // Two days ago: vertical split 839 / 334
        addPost(Post(authorId: grace.id, day: twoDaysAgo, collages: [
            Collage(
                preset: .twoVertical,
                cells: [CollageCell(image: photo("839-3024x4032")),
                        CollageCell(image: photo("334-3024x4032"))],
                border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 8),
                overlays: [],
                text: "rainy thursday. stayed in, made soup."
            )
        ]))

        // ── alan ─────────────────────────────────────────────────────────────
        // Today: two collages — full 839, then horizontal 613/691
        addPost(Post(authorId: alan.id, day: today, collages: [
            Collage(
                preset: .full,
                cells: [CollageCell(image: photo("839-3024x4032"))],
                border: BorderStyle(frame: .tornPaper, gutterColor: .paper, gutterWidth: 0),
                overlays: [
                    overlay(.sticker(StickerContent(sticker: .leaf, tint: .mint, size: 42)),
                            at: .init(x: 0.78, y: 0.20), rot: -0.5, z: 0)
                ],
                text: "walked for three hours. solved nothing. needed that."
            ),
            Collage(
                preset: .twoHorizontal,
                cells: [CollageCell(image: photo("613-3000x4000")),
                        CollageCell(image: photo("691-2000x3000"))],
                border: BorderStyle(frame: .none, gutterColor: .ink, gutterWidth: 6),
                overlays: [],
                text: "stopped twice."
            )
        ]))

        // Yesterday: full Frank Ocean
        addPost(Post(authorId: alan.id, day: yesterday, collages: [
            Collage(
                preset: .full,
                cells: [CollageCell(image: photo("Frank_Ocean_1"))],
                border: BorderStyle(frame: .none, gutterColor: .paper, gutterWidth: 0),
                overlays: [],
                text: "been thinking about this image for days."
            )
        ]))

        // ── margaret (not followed — appears on search/profile, not feed) ───
        addPost(Post(authorId: margaret.id, day: today, collages: [
            Collage(
                preset: .twoVertical,
                cells: [CollageCell(image: photo("691-2000x3000")),
                        CollageCell(image: photo("613-3000x4000"))],
                border: BorderStyle(frame: .filmStrip, gutterColor: .lemon, gutterWidth: 8),
                overlays: [],
                text: "code review took five minutes. lunch took two hours. correct priorities."
            )
        ]))

        // ── katherine (followed) — most recent post is yesterday → "1d" ─────
        addPost(Post(authorId: katherine.id, day: yesterday, collages: [
            Collage(
                preset: .full,
                cells: [CollageCell(image: photo("18-3024x4032"))],
                border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 8),
                overlays: [
                    overlay(.sticker(StickerContent(sticker: .star, tint: .lemon, size: 40)),
                            at: .init(x: 0.18, y: 0.12), rot: -0.2, z: 0)
                ],
                text: "checked the math three times. checked it a fourth, just to be sure."
            )
        ]))

        // Older post — proves dedup keeps only the most recent in the feed.
        addPost(Post(authorId: katherine.id, day: threeDaysAgo, collages: [
            Collage(
                preset: .twoVertical,
                cells: [CollageCell(image: photo("839-3024x4032")),
                        CollageCell(image: photo("691-2000x3000"))],
                border: BorderStyle(frame: .none, gutterColor: .ink, gutterWidth: 6),
                overlays: [],
                text: "field notes."
            )
        ]))

        // ── jean (followed) — most recent post is 3 days ago → "3d" ─────────
        addPost(Post(authorId: jean.id, day: threeDaysAgo, collages: [
            Collage(
                preset: .twoHorizontal,
                cells: [CollageCell(image: photo("18-3024x4032")),
                        CollageCell(image: photo("613-3000x4000"))],
                border: BorderStyle(frame: .filmStrip, gutterColor: .ink, gutterWidth: 10),
                overlays: [
                    overlay(.tape(TapeContent(color: .lilac, width: 130, height: 22)),
                            at: .init(x: 0.5, y: 0.07), rot: -0.2, z: 0)
                ],
                text: "drafted the syntax three times before it felt right. that's the work."
            )
        ]))

        // ── donald (not followed) ─────────────────────────────────────────
        addPost(Post(authorId: donald.id, day: yesterday, collages: [
            Collage(
                preset: .full,
                cells: [CollageCell(image: photo("334-3024x4032"))],
                border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 10),
                overlays: [
                    overlay(.tape(TapeContent(color: .lemon, width: 150, height: 22)),
                            at: .init(x: 0.35, y: 0.06), rot: 0.3, z: 0)
                ],
                text: "the real optimization was the friends we made along the way."
            )
        ]))

        // A couple of follow notifications.
        notificationsByUser[currentUserId] = [
            AppNotification(kind: .follow, actorId: ada.id,
                            createdAt: Date().addingTimeInterval(-300)),
            AppNotification(kind: .follow, actorId: grace.id,
                            createdAt: Date().addingTimeInterval(-3_600), isRead: true)
        ]
    }

    // MARK: - Seed helpers

    private func addPost(_ post: Post) {
        posts[post.id] = post
    }

    /// Short-hand for building an OverlayElement in seed code.
    private func overlay(_ content: OverlayContent, at pos: CGPoint,
                         rot: Double, z: Double) -> OverlayElement {
        OverlayElement(content: content, position: pos, rotation: rot, scale: 1, zIndex: z)
    }

    /// Loads a bundled mock photo by resource name. Tries both the bundle root
    /// and the MockPhotos subdirectory since XcodeGen may bundle the folder
    /// either way depending on how files were added.
    private func photo(_ name: String) -> Data? {
        let extensions = ["jpg", "jpeg"]
        let subdirectories: [String?] = [nil, "MockPhotos"]
        for subdir in subdirectories {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext,
                                             subdirectory: subdir),
                   let data = try? Data(contentsOf: url) {
                    return data
                }
            }
        }
        return nil
    }

    // MARK: - Reads

    func todayPost() async throws -> Post {
        let day = Date().dayKey
        if let existing = posts.values.first(where: { $0.authorId == currentUserId && $0.day == day }) {
            return existing
        }
        let blank = Post(authorId: currentUserId, day: day, collages: [])
        posts[blank.id] = blank
        return blank
    }

    func post(byAuthor authorId: UUID, on day: Date) async throws -> Post? {
        let key = day.dayKey
        return posts.values.first { $0.authorId == authorId && $0.day == key }
    }

    func post(withId id: UUID) async throws -> Post? {
        try await simulate()
        return posts[id].map { annotateViewed($0) }
    }

    func posts(byAuthor authorId: UUID) async throws -> [Post] {
        try await simulate()
        return posts.values
            .filter { $0.authorId == authorId && !$0.collages.isEmpty }
            .sorted { $0.day > $1.day }
    }

    func feed() async throws -> [Post] {
        try await simulate()
        let following = followGraph[currentUserId] ?? []
        // One post per followed author — their most recent only.
        var latestByAuthor: [UUID: Post] = [:]
        for post in posts.values {
            guard following.contains(post.authorId),
                  !post.collages.isEmpty else { continue }
            if let existing = latestByAuthor[post.authorId] {
                if post.day > existing.day { latestByAuthor[post.authorId] = post }
            } else {
                latestByAuthor[post.authorId] = post
            }
        }
        return latestByAuthor.values
            .map { annotateViewed($0) }
            .sorted { $0.day > $1.day }
    }

    func markPostViewed(postId: UUID) {
        viewedPostIds.insert(postId)
    }

    private func annotateViewed(_ post: Post) -> Post {
        var p = post
        p.isViewedByCurrentUser = viewedPostIds.contains(post.id)
        return p
    }

    // MARK: - Mutations

    func saveTodayPost(collages: [Collage]) async throws -> Post {
        try await simulate()
        let day = Date().dayKey
        var post = posts.values.first(where: { $0.authorId == currentUserId && $0.day == day })
            ?? Post(authorId: currentUserId, day: day)
        post.collages = collages
        post.updatedAt = Date()
        posts[post.id] = post
        return post
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
                ($0.username.lowercased().contains(q) ||
                 $0.displayName.lowercased().contains(q)) }
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
                AppNotification(kind: .follow, actorId: currentUserId))
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

    func notifications() async throws -> [AppNotification] {
        try await simulate(short: true)
        return (notificationsByUser[currentUserId] ?? [])
            .sorted { $0.createdAt > $1.createdAt }
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

    private func appendNotification(for userId: UUID, _ n: AppNotification) {
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
