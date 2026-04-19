import Foundation
import SwiftUI

struct User: Identifiable, Hashable, Codable {
    let id: UUID
    var username: String
    var displayName: String
    var bio: String
    /// Stored as a hue value 0...1 so avatars render deterministically without bundled images.
    var avatarHue: Double
    var joinedAt: Date
    var followersCount: Int
    var followingCount: Int

    init(
        id: UUID = UUID(),
        username: String,
        displayName: String,
        bio: String = "",
        avatarHue: Double = Double.random(in: 0...1),
        joinedAt: Date = Date(),
        followersCount: Int = 0,
        followingCount: Int = 0
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarHue = avatarHue
        self.joinedAt = joinedAt
        self.followersCount = followersCount
        self.followingCount = followingCount
    }

    var handle: String { "@\(username)" }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    var avatarColor: Color {
        Color(hue: avatarHue, saturation: 0.55, brightness: 0.85)
    }
}
