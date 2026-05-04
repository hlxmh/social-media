import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel

    init(userId: UUID, backend: BackendService) {
        _viewModel = StateObject(wrappedValue:
            ProfileViewModel(backend: backend, userId: userId))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        Group {
            if let user = viewModel.user {
                ScrollView {
                    VStack(spacing: 0) {
                        headerBlock(user: user)
                        divider
                        if viewModel.posts.isEmpty {
                            EmptyStateView(
                                title: "No posts yet",
                                subtitle: viewModel.isCurrentUser
                                    ? "Tap the editor to make today's first collage."
                                    : "When \(user.displayName) posts, you'll see it here.",
                                systemImage: "rectangle.stack"
                            )
                            .padding(.top, 40)
                        } else {
                            grid
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(title: "User not found",
                               subtitle: "We couldn't load this profile.",
                               systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .navigationTitle(viewModel.user.map { $0.handle } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PostRoute.self) { route in
            switch route {
            case .detail(let id): PostDetailView(postId: id, backend: viewModel.backend)
            }
        }
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id): ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Header

    /// Structured data block: name, handle · stats, rule, bio.
    private func headerBlock(user: User) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Left bracket accent
                Rectangle()
                    .fill(Color(hue: user.avatarHue, saturation: 0.7, brightness: 0.75))
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(user.displayName.uppercased())
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .kerning(1.0)

                    // handle · followers · following
                    HStack(spacing: 0) {
                        Text(user.handle)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  ·  ")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text("\(user.followersCount.compactFormatted) followers")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  ·  ")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text("\(user.followingCount.compactFormatted) following")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 12)

                Spacer(minLength: 12)

                if !viewModel.isCurrentUser {
                    LogFollowButton(
                        isFollowing: viewModel.isFollowing,
                        hue: user.avatarHue
                    ) {
                        Task { await viewModel.toggleFollow() }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
            }

            // Bio — full width below the bracket block
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 31)   // aligns with text above (16 + 3 + 12)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
            }

            // Post count line
            HStack {
                Text("\(viewModel.posts.count) ENTR\(viewModel.posts.count == 1 ? "Y" : "IES")")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .kerning(1.5)
                    .padding(.leading, 31)
                Spacer()
            }
            .padding(.bottom, 10)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(viewModel.posts) { post in
                NavigationLink(value: PostRoute.detail(post.id)) {
                    ProfileThumbnailView(post: post)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay { ScanlineOverlay() }
    }
}

// MARK: - ProfileThumbnailView

/// Square thumbnail for the 3-column profile grid.
/// No tilt, no Polaroid frame — just the collage image, flush to the cell,
/// with a monospaced date stamp below.
private struct ProfileThumbnailView: View {
    let post: Post

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                coverImage
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                if post.collages.count > 1 {
                    Text("\(post.collages.count)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.systemBackground).opacity(0.75))
                        .padding(5)
                }
            }
            Text(post.day.gridDateLabel)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Color(.secondarySystemBackground))
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let collage = post.collages.first,
           let cell = collage.cells.first(where: { $0.image != nil }),
           let data = cell.image,
           let img = UIImage(data: data) {
            GeometryReader { geo in
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.width)
                    .clipped()
            }
            .aspectRatio(1, contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                )
        }
    }
}

// MARK: - LogFollowButton

/// Bracket-style `[ FOLLOW ]` / `[ FOLLOWING ]` button matching the terminal UI.
private struct LogFollowButton: View {
    let isFollowing: Bool
    let hue: Double
    let action: () -> Void

    private var accentColor: Color {
        Color(hue: hue, saturation: 0.7, brightness: 0.75)
    }

    var body: some View {
        Button(action: action) {
            Text(isFollowing ? "[ FOLLOWING ]" : "[ FOLLOW ]")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .kerning(0.5)
                .foregroundStyle(isFollowing ? .secondary : accentColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ScanlineOverlay (profile-local)

private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            let lineSpacing: CGFloat = 4
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(.primary.opacity(0.03)), lineWidth: 1)
                y += lineSpacing
            }
            var rng = SeededRNG(seed: 0xCAFE_BABE)
            let dotCount = Int(size.width * size.height / 500)
            for _ in 0..<dotCount {
                let x = CGFloat(rng.next()) * size.width
                let dy = CGFloat(rng.next()) * size.height
                let opacity = Double(rng.next()) * 0.04
                ctx.fill(Path(CGRect(x: x, y: dy, width: 1.5, height: 1.5)),
                         with: .color(.primary.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SeededRNG {
    private var state: UInt32
    init(seed: UInt32) { state = seed == 0 ? 1 : seed }
    mutating func next() -> CGFloat {
        state ^= state << 13; state ^= state >> 17; state ^= state << 5
        return CGFloat(state) / CGFloat(UInt32.max)
    }
}

// MARK: - Helpers

private extension Date {
    /// Short monospaced date for the profile grid: "TODAY" / "YESTERDAY" / "APR 28".
    var gridDateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "TODAY" }
        if cal.isDateInYesterday(self) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = cal.isDate(self, equalTo: Date(), toGranularity: .year)
            ? "MMM d" : "MMM d, yyyy"
        return f.string(from: self).uppercased()
    }
}

private extension Int {
    /// Compact follower/following count: 1200 → "1.2K", 22000 → "22K".
    var compactFormatted: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000     { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}

#if DEBUG
#Preview("My profile") {
    PreviewScaffold.WithAppState {
        NavigationStack {
            ProfileView(userId: PreviewScaffold.backend.currentUser.id,
                        backend: PreviewScaffold.backend)
        }
    }
}
#endif
