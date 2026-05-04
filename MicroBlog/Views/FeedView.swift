import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: FeedViewModel(backend: backend))
    }

    var body: some View {
        Group {
            if case let .failed(message) = viewModel.state {
                EmptyStateView(title: "Couldn't load",
                               subtitle: message,
                               systemImage: "exclamationmark.triangle")
            } else if viewModel.posts.isEmpty {
                if case .loaded = viewModel.state {
                    EmptyStateView(title: "Nothing yet",
                                   subtitle: "Follow people to see their posts here.",
                                   systemImage: "list.bullet.rectangle")
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                log
            }
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("FEED")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .kerning(2)
            }
        }
        .navigationDestination(for: PostRoute.self) { route in
            switch route {
            case .detail(let id):
                PostDetailView(postId: id, backend: viewModel.backend)
            }
        }
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id):
                ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task {
            if case .idle = viewModel.state { await viewModel.load() }
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Log list

    private var log: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                dateHeader
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { idx, post in
                    // Day-break divider when this entry is from a different day than the one above.
                    let prevDay = idx > 0 ? viewModel.posts[idx - 1].day : nil
                    if let prev = prevDay, !Calendar.current.isDate(prev, inSameDayAs: post.day) {
                        DayBreakRow(day: post.day)
                    }
                    NavigationLink(value: PostRoute.detail(post.id)) {
                        LogRowView(
                            post: post,
                            author: viewModel.authors[post.authorId]
                        )
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.markViewed(post)
                    })
                }
                entryCountFooter
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .overlay { ScanlineOverlay() }
    }

    /// Monospaced date stamp at the top of the log.
    private var dateHeader: some View {
        let fmt = DateFormatter()
        let _ = (fmt.dateFormat = "EEE · MMM dd · yyyy")
        return HStack {
            Text(fmt.string(from: Date()).uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)
            Spacer()
            Text("LOG")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.tertiary)
                .kerning(2)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    /// Entry count footer at the bottom of the list.
    private var entryCountFooter: some View {
        HStack {
            Spacer()
            Text("\(viewModel.posts.count) ENTR\(viewModel.posts.count == 1 ? "Y" : "IES")")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .kerning(1.5)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

// MARK: - Ambient rows

/// Thin divider row shown between entries from different days.
private struct DayBreakRow: View {
    let day: Date

    private var label: String {
        if Calendar.current.isDateInYesterday(day) { return "YESTERDAY" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE MMM d"
        return fmt.string(from: day).uppercased()
    }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .kerning(1.5)
                .fixedSize()
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Scanline + grain overlay

/// Full-bleed overlay that draws horizontal scanlines and a subtle grain
/// across the entire feed, giving it a CRT / digital-terminal texture.
/// Rendered via Canvas so it's a single draw call with no per-line views.
private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            // Scanlines — 1pt line every 4pt
            let lineSpacing: CGFloat = 4
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path,
                           with: .color(.primary.opacity(0.03)),
                           lineWidth: 1)
                y += lineSpacing
            }

            // Grain — fixed-seed random dots so the texture is stable
            var rng = SeededRNG(seed: 0xDEAD_BEEF)
            let dotCount = Int(size.width * size.height / 400)
            for _ in 0..<dotCount {
                let x = CGFloat(rng.next()) * size.width
                let dy = CGFloat(rng.next()) * size.height
                let opacity = Double(rng.next()) * 0.045
                let rect = CGRect(x: x, y: dy, width: 1.5, height: 1.5)
                ctx.fill(Path(rect),
                         with: .color(.primary.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// A tiny deterministic pseudo-random number generator (xorshift32).
/// Used to generate stable grain that doesn't flicker on every redraw.
private struct SeededRNG {
    private var state: UInt32
    init(seed: UInt32) { state = seed == 0 ? 1 : seed }
    mutating func next() -> CGFloat {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return CGFloat(state) / CGFloat(UInt32.max)
    }
}

enum PostRoute: Hashable { case detail(UUID) }
enum UserRoute: Hashable { case profile(UUID) }

#if DEBUG
#Preview("Feed") {
    PreviewScaffold.WithAppState {
        NavigationStack {
            FeedView(backend: PreviewScaffold.backend)
        }
    }
}
#endif
