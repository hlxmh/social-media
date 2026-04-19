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
