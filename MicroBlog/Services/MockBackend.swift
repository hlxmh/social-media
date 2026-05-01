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

        // Seed some posts using the bundled mock photos when available.
        let today = Date().dayKey
        let dayOffsets = [0, -1, -2]
        for user in seedUsers.dropFirst() {
            for offset in dayOffsets where Bool.random() {
                let day = Calendar.current.date(byAdding: .day, value: offset, to: today)!
                if let post = makeSeedPost(for: user, on: day) {
                    posts[post.id] = post
                }
            }
        }

        // Hand-built post anchored on the bundled "Frank_Ocean_1" photo, on a
        // followed user's account so it lands in the feed.
        if let photoPost = makeBundledPhotoPost(for: seedUsers[1], on: today) {
            posts.values
                .filter { $0.authorId == seedUsers[1].id && $0.day == today }
                .forEach { posts.removeValue(forKey: $0.id) }
            posts[photoPost.id] = photoPost
        }

        // A couple of follow notifications.
        notificationsByUser[currentUserId] = [
            AppNotification(kind: .follow, actorId: seedUsers[1].id,
                            createdAt: Date().addingTimeInterval(-300)),
            AppNotification(kind: .follow, actorId: seedUsers[2].id,
                            createdAt: Date().addingTimeInterval(-3_600), isRead: true)
        ]
    }

    // MARK: - Seed builders

    private func makeSeedPost(for author: User, on day: Date) -> Post? {
        let presets: [LayoutPreset] = [.full, .twoVertical, .twoHorizontal, .fourGrid]
        let preset = presets.randomElement()!

        let cellRects = preset.cellCount
        var cells: [CollageCell] = []
        for _ in 0..<cellRects {
            cells.append(CollageCell(image: bundledPhotoData()))
        }

        let frame: FrameStyle = [.none, .polaroid, .filmStrip, .tornPaper].randomElement()!
        let gutterColor: StickerTint = [.paper, .ink, .pink, .lemon, .mint].randomElement()!
        let collage = Collage(
            preset: preset,
            cells: cells,
            border: BorderStyle(frame: frame, gutterColor: gutterColor,
                                gutterWidth: Double.random(in: 4...12)),
            overlays: randomOverlays(),
            text: captionPool.randomElement()!
        )

        // Some posts have a second collage to exercise the carousel.
        var collages = [collage]
        if Bool.random() {
            let p2: LayoutPreset = [.full, .twoHorizontal].randomElement()!
            let c2 = Collage(
                preset: p2,
                cells: (0..<p2.cellCount).map { _ in CollageCell(image: bundledPhotoData()) },
                border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 6),
                overlays: randomOverlays(few: true),
                text: captionPool.randomElement()!
            )
            collages.append(c2)
        }

        return Post(authorId: author.id, day: day, collages: collages)
    }

    private func randomOverlays(few: Bool = false) -> [OverlayElement] {
        var overlays: [OverlayElement] = []
        var z: Double = 0
        let count = few ? Int.random(in: 0...2) : Int.random(in: 1...4)
        for _ in 0..<count {
            overlays.append(OverlayElement(
                content: .sticker(StickerContent(
                    sticker: Sticker.allCases.randomElement()!,
                    tint: StickerTint.allCases.randomElement()!,
                    size: Double.random(in: 32...56))),
                position: .init(x: Double.random(in: 0.15...0.85),
                                y: Double.random(in: 0.15...0.85)),
                rotation: Double.random(in: -0.4...0.4),
                zIndex: z
            ))
            z += 1
        }
        if Bool.random() {
            overlays.append(OverlayElement(
                content: .tape(TapeContent(
                    color: [.peach, .lemon, .mint, .lilac, .pink].randomElement()!,
                    width: 160, height: 24)),
                position: .init(x: Double.random(in: 0.3...0.7),
                                y: Double.random(in: 0.1...0.25)),
                rotation: Double.random(in: -0.6...0.6),
                zIndex: z
            ))
        }
        return overlays
    }

    private let captionPool = [
        "no notes",
        "the small joys.",
        "afternoon light, again.",
        "thinking about lattices.",
        "spent an hour learning a chord.",
        "rewatched a film I love.",
        "neighbors said hi for the first time."
    ]

    /// A hand-crafted post anchored on a bundled photo. Returns nil if the
    /// image file isn't bundled.
    private func makeBundledPhotoPost(for author: User, on day: Date) -> Post? {
        guard let data = bundledPhotoData() else { return nil }

        let collage = Collage(
            preset: .full,
            cells: [CollageCell(image: data)],
            border: BorderStyle(frame: .polaroid, gutterColor: .paper, gutterWidth: 8),
            overlays: [
                OverlayElement(
                    content: .tape(TapeContent(color: .peach, width: 140, height: 22)),
                    position: .init(x: 0.30, y: 0.08),
                    rotation: -0.45, zIndex: 0),
                OverlayElement(
                    content: .sticker(StickerContent(sticker: .music, tint: .lilac, size: 44)),
                    position: .init(x: 0.85, y: 0.92),
                    rotation: 0.3, zIndex: 1)
            ],
            text: "blonded — on repeat all week. saturday afternoon, windows open."
        )
        return Post(authorId: author.id, day: day, collages: [collage])
    }

    /// Loads the bundled mock photo and returns its raw JPEG data, or nil if
    /// the resource isn't present.
    private func bundledPhotoData() -> Data? {
        guard let url = Bundle.main.url(forResource: "Frank_Ocean_1", withExtension: "jpg") else {
            return nil
        }
        return try? Data(contentsOf: url)
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
