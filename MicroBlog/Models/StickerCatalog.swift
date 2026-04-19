import SwiftUI

/// A curated set of decorative stickers users can drop on a page.
/// Backed by SF Symbols + emoji so we don't need bundled assets.
enum Sticker: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case heart, star, sparkles, sun, moon, cloud, flame, leaf, flower, music
    case camera, gift, balloon, partyHat, smiley, peace, lightning, wave
    case rainbow, paperPlane, mushroom, coffee, cherry, butterfly

    var id: String { rawValue }

    /// Returns either an SF Symbol name or an emoji string.
    var glyph: StickerGlyph {
        switch self {
        case .heart:        return .symbol("heart.fill")
        case .star:         return .symbol("star.fill")
        case .sparkles:     return .symbol("sparkles")
        case .sun:          return .symbol("sun.max.fill")
        case .moon:         return .symbol("moon.stars.fill")
        case .cloud:        return .symbol("cloud.fill")
        case .flame:        return .symbol("flame.fill")
        case .leaf:         return .symbol("leaf.fill")
        case .flower:       return .emoji("🌸")
        case .music:        return .symbol("music.note")
        case .camera:       return .symbol("camera.fill")
        case .gift:         return .symbol("gift.fill")
        case .balloon:      return .emoji("🎈")
        case .partyHat:     return .emoji("🎉")
        case .smiley:       return .emoji("☺️")
        case .peace:        return .emoji("✌️")
        case .lightning:    return .symbol("bolt.fill")
        case .wave:         return .symbol("water.waves")
        case .rainbow:      return .emoji("🌈")
        case .paperPlane:   return .symbol("paperplane.fill")
        case .mushroom:     return .emoji("🍄")
        case .coffee:       return .emoji("☕️")
        case .cherry:       return .emoji("🍒")
        case .butterfly:    return .emoji("🦋")
        }
    }
}

enum StickerGlyph: Hashable, Sendable {
    case symbol(String)
    case emoji(String)
}

/// A curated palette so the picker doesn't get overwhelming.
enum StickerTint: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case pink, coral, peach, lemon, mint, sky, lilac, ink, paper

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pink:   return Color(red: 1.00, green: 0.45, blue: 0.65)
        case .coral:  return Color(red: 1.00, green: 0.55, blue: 0.45)
        case .peach:  return Color(red: 1.00, green: 0.78, blue: 0.55)
        case .lemon:  return Color(red: 0.97, green: 0.88, blue: 0.40)
        case .mint:   return Color(red: 0.45, green: 0.85, blue: 0.70)
        case .sky:    return Color(red: 0.45, green: 0.70, blue: 1.00)
        case .lilac:  return Color(red: 0.72, green: 0.55, blue: 0.95)
        case .ink:    return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .paper:  return Color(red: 0.97, green: 0.95, blue: 0.90)
        }
    }
}

/// Fonts available for text elements.
enum PageFont: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case handwritten, serif, sans, mono, rounded

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .handwritten: return "Marker"
        case .serif:       return "Serif"
        case .sans:        return "Sans"
        case .mono:        return "Mono"
        case .rounded:     return "Round"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .handwritten: return .custom("Bradley Hand", size: size).weight(.bold)
        case .serif:       return .system(size: size, weight: weight, design: .serif)
        case .sans:        return .system(size: size, weight: weight, design: .default)
        case .mono:        return .system(size: size, weight: weight, design: .monospaced)
        case .rounded:     return .system(size: size, weight: weight, design: .rounded)
        }
    }
}
