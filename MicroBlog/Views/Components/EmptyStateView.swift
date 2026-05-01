import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

#if DEBUG
#Preview("Empty state") {
    EmptyStateView(title: "Quiet day",
                   subtitle: "Posts from people you follow will appear here.",
                   systemImage: "rectangle.stack")
}
#endif
