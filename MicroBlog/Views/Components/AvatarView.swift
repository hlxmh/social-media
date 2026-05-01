import SwiftUI

struct AvatarView: View {
    let user: User
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(user.avatarColor)
            .frame(width: size, height: size)
            .overlay(
                Text(user.initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

#if DEBUG
#Preview("Avatars") {
    HStack(spacing: 16) {
        AvatarView(user: User(username: "ada", displayName: "Ada Lovelace",
                              avatarHue: 0.05), size: 32)
        AvatarView(user: User(username: "grace", displayName: "Grace Hopper",
                              avatarHue: 0.55), size: 48)
        AvatarView(user: User(username: "alan", displayName: "Alan Turing",
                              avatarHue: 0.78), size: 72)
    }
    .padding(24)
}
#endif
