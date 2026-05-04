# CLAUDE.md — project brief for AI assistants

This file gives an AI coding assistant everything it needs to work on this
codebase without reading every file from scratch.

---

## What this app is

A daily photo-collage journal for iOS, currently named **MicroBlog** but
scheduled to be renamed to **Kologe** (see TODO). Each user gets one **Post**
per calendar day. A post contains an ordered list of **Collages**; viewers
swipe through them horizontally. There is no server — the backend is an
in-memory Swift `actor` (`MockBackend`).

---

## Tech stack

| Concern | Choice |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI (iOS 17+), no UIKit except `UIImage`/`UIScreen` |
| Architecture | MVVM — `@MainActor ObservableObject` view models |
| Concurrency | Swift structured concurrency (`async/await`, `actor`) |
| Backend | `BackendService` protocol + `MockBackend` actor |
| Project generation | XcodeGen (`project.yml`) — **always run `xcodegen generate` after adding/renaming/moving Swift files** |
| Deployment target | iOS 17.0 (uses `MagnifyGesture`, `RotateGesture`, `TabView` paging, `#Preview` macro) |
| No third-party dependencies | Zero SPM packages |

---

## Source layout

```
micro-blog/
├── project.yml                   # XcodeGen spec — edit here, not in .xcodeproj
├── TODO.md                       # feature backlog
├── README.md                     # user-facing docs
├── CLAUDE.md                     # this file
└── MicroBlog/
    ├── App/
    │   ├── MicroBlogApp.swift    # @main entry point
    │   ├── AppState.swift        # @MainActor global state (backend, currentUser, unread badge)
    │   └── RootView.swift        # TabView shell + floating editor FAB
    ├── Models/
    │   ├── Post.swift            # Post: id, authorId, day (start-of-day), [Collage]
    │   ├── Collage.swift         # Collage: preset, cells, border, overlays, text
    │   ├── LayoutPreset.swift    # enum + cellRects(inset:gutterX:gutterY:) -> [CGRect]
    │   ├── Border.swift          # FrameStyle enum + BorderStyle struct
    │   ├── OverlayElement.swift  # OverlayElement + OverlayContent enum
    │   ├── StickerCatalog.swift  # Sticker, StickerGlyph, StickerTint enums
    │   ├── Notification.swift    # AppNotification (follow-only for now)
    │   ├── User.swift            # User struct
    │   └── RelativeTime.swift    # RelativeTime.string(from:)
    ├── Services/
    │   ├── BackendService.swift  # protocol — the only surface views touch
    │   └── MockBackend.swift     # actor implementation with seeded data
    ├── Previews/
    │   └── PreviewSupport.swift  # PreviewScaffold — shared backend/appState for #Previews
    ├── ViewModels/               # one @MainActor ObservableObject per screen
    │   ├── FeedViewModel.swift
    │   ├── PostDetailViewModel.swift
    │   ├── PostEditorViewModel.swift
    │   ├── ProfileViewModel.swift
    │   ├── SearchViewModel.swift
    │   └── NotificationsViewModel.swift
    ├── Views/
    │   ├── FeedView.swift            # 2-column Polaroid grid, NavigationLink to detail
    │   ├── PostDetailView.swift      # horizontal TabView carousel + per-collage text body
    │   ├── PostEditorView.swift      # composer: preset bar, photo cells, overlays, text, border
    │   ├── ProfileView.swift         # avatar, bio, follow, post grid
    │   ├── SearchView.swift          # debounced people search
    │   ├── NotificationsView.swift   # follow notifications
    │   └── Components/
    │       ├── CollageView.swift         # READ-ONLY renderer; pass renderOverlays:false in editor
    │       ├── EditableOverlayView.swift # drag/magnify/rotate wrapper for editor
    │       ├── LogRowView.swift          # compact monospaced row used in FeedView
    │       ├── PostThumbnailView.swift   # Polaroid card used in profile grid (NOT feed)
    │       ├── StickerPickerView.swift
    │       ├── AvatarView.swift
    │       └── EmptyStateView.swift
    └── Resources/
        ├── Assets.xcassets/          # AppIcon, AccentColor
        ├── MockPhotos.xcassets/      # empty asset catalog for bundled stock photos
        └── MockPhotos/               # loose JPGs bundled at build time (e.g. Frank_Ocean_1.jpg)
```

---

## Core data model (read this before touching any model file)

```
Post
  id: UUID
  authorId: UUID
  day: Date                    ← always start-of-day (Calendar.current.startOfDay)
  collages: [Collage]
  isViewedByCurrentUser: Bool  ← annotated by MockBackend.feed(); drives the unread dot in LogRowView

Collage
  id: UUID
  preset: LayoutPreset   ← full | twoVertical | twoHorizontal | fourGrid
  cells: [CollageCell]   ← count must equal preset.cellCount; call reconcileCells() after changing preset
  border: BorderStyle    ← frame (none|polaroid|filmStrip|tornPaper) + gutterColor + gutterWidth
  overlays: [OverlayElement]
  text: String           ← the journal body shown below the collage in PostDetailView
                            also scrolled as a marquee in LogRowView

CollageCell
  id: UUID
  image: Data?           ← raw JPEG/PNG bytes; nil = empty placeholder

OverlayElement
  id: UUID
  content: OverlayContent  ← .sticker | .tape | .doodle | .straightLine
  position: CGPoint        ← NORMALIZED 0...1 in canvas space
  rotation: Double         ← radians
  scale: Double
  zIndex: Double

LayoutPreset.cellRects(inset:gutterX:gutterY:) -> [CGRect]
  ← Returns NORMALIZED CGRects (0...1). gutterX is normalized to canvas width,
    gutterY to canvas height. Used by CollageView and PostEditorView.PresetIcon.

Date extension (Post.swift)
  .dayKey     → Calendar.current.startOfDay(for: self)
  .offset(days:) → Calendar.current.date(byAdding: .day, value: days, to: self)
```

---

## Architecture rules

1. **Views never hold a `BackendService` directly as `@State`.** They receive
   it through their initializer → view model. `AppState` is the single owner.

2. **View models are `@MainActor`**. Never dispatch UI writes inside a `Task`
   unless you annotate `@MainActor` explicitly.

3. **`@EnvironmentObject AppState`** is injected at the root in
   `MicroBlogApp.swift` and `PreviewScaffold.WithAppState`. Do not re-inject
   it deeper.

4. **Normalized coordinates everywhere.** Overlay positions, cell rects, and
   doodle points are always `0...1` relative to the canvas's pixel size. Convert
   to pixels inside the renderer (`GeometryReader`), never before.

5. **`CollageView` is read-only.** When used inside `PostEditorView`, pass
   `renderOverlays: false` so the editor's interactive `EditableOverlayView`
   layer is not duplicated by the renderer's own overlay pass.

6. **`CollageCellView.onTap` is `(() -> Void)?`.** Only attach the closure in
   the editor (`onTapCell: { idx in ... }`). When nil, taps pass through to
   outer `NavigationLink`s in the feed/profile grids.

7. **`MockBackend` is an `actor`.** `currentUser` is exposed `nonisolated` via
   a `Snapshot<User>` lock wrapper. Don't access actor-isolated state from
   synchronous contexts.

8. **One `MockBackend` instance per preview session.** Use
   `PreviewScaffold.backend` / `PreviewScaffold.appState` (defined in
   `Previews/PreviewSupport.swift`) so all previews share the same seeded data.

9. **No `environment(\.backend, ...)` injection.** That pattern was removed.
   All views take backend through their initializer.

---

## Navigation routes

```swift
enum PostRoute: Hashable { case detail(UUID) }   // defined in FeedView.swift
enum UserRoute: Hashable { case profile(UUID) }  // defined in FeedView.swift
```

Every `NavigationStack` that might push a post or profile must declare both
`.navigationDestination(for: PostRoute.self)` and
`.navigationDestination(for: UserRoute.self)`. Check `FeedView`, `ProfileView`,
`PostDetailView`, `NotificationsView`, and `SearchView`.

---

## Adding a new Swift file

1. Create the file under the appropriate `MicroBlog/` subfolder.
2. Run `xcodegen generate` in the project root.
3. Re-open / refresh the `.xcodeproj` in Xcode.

The `project.yml` sources glob covers `path: MicroBlog` recursively, so no
manual project file edits are needed.

---

## Running / previewing

```bash
# Generate the Xcode project (required after any file add/rename/move)
brew install xcodegen   # first time only
cd ~/Documents/micro-blog
xcodegen generate
open MicroBlog.xcodeproj
```

Every major screen has a `#Preview` block that uses `PreviewScaffold` so it
boots with seeded data. Open the file in Xcode → `Editor → Canvas` (⌥⌘↩),
click the ▶︎ button for Live mode. Files with previews:

| File | Preview name |
|---|---|
| `App/RootView.swift` | App |
| `Views/FeedView.swift` | Feed |
| `Views/PostDetailView.swift` | Post detail |
| `Views/PostEditorView.swift` | Editor |
| `Views/ProfileView.swift` | My profile |
| `Views/SearchView.swift` | Find people |
| `Views/NotificationsView.swift` | Activity |
| `Views/Components/CollageView.swift` | Full + Polaroid · 4 grid + Filmstrip |
| `Views/Components/PostThumbnailView.swift` | Thumbnail |
| `Views/Components/StickerPickerView.swift` | Sticker picker |
| `Views/Components/AvatarView.swift` | Avatars |
| `Views/Components/EmptyStateView.swift` | Empty state |

---

## Known intentional omissions (don't add without discussion)

- **Reactions on posts** — stripped in the collage overhaul; tracked in TODO as "Movable reactions".
- **Real networking / auth** — MockBackend only; swap by passing a real `BackendService` to `AppState(backend:)`.
- **iPad-specific layout** — portrait locked for now (`UISupportedInterfaceOrientations_iPad` includes landscape in plist but the UI isn't optimized for it yet).
- **Pagination** — feed and profile load everything in one shot from the mock.

---

## Feed screen: digital log design

The feed is a **dense, block-y digital log** — not a Polaroid grid.

### LogRowView anatomy (top → bottom, left → right)

```
[ 3pt bracket (green=unread / muted=seen) ]
[ 6pt green dot (hidden when seen) ]
[ VStack:
    @handle                                   16h
    first-collage text ← scrolling marquee →
    N collages  (only if >1)                      ]
```

Full-bleed background: first non-nil photo across all collages, `scaledToFill`,
low opacity (0.32 unread / 0.18 seen), clipped via `.clipped()` on the HStack
**after** `.background { }` — NOT inside the background closure.

### Seen/unread flow

1. `MockBackend.feed()` annotates each `Post` with `isViewedByCurrentUser`.
2. `FeedViewModel.markViewed(_:)` updates the local array immediately (instant
   dot disappear) and calls `backend.markPostViewed(postId:)` asynchronously.
3. Tapping a row triggers `markViewed` via `.simultaneousGesture(TapGesture())`.

### Marquee scrolling (LogRowView / MarqueeText)

The first collage's `text` field scrolls right-to-left when it overflows the
available width. Architecture follows Monty Harper's external-controller pattern:

- **`MarqueeController: ObservableObject`** — owns `startTime`, character widths
  (measured via `UIFont`/`NSString.size(withAttributes:)` synchronously at init),
  and the `offset(at:Date) -> CGFloat` sawtooth function with end-of-line pause.
- **`MarqueeText: View`** — holds `@StateObject var controller`. The outer view
  is a dimensionless invisible `Text` (no `.fixedSize()`) so it can never push
  the row wider than its container. The actual scrolling text lives in an
  `.overlay { GeometryReader }` that decides static-vs-scroll based on
  `controller.textWidth` vs available width.
- **Why external controller**: SwiftUI destroys and recreates view structs
  frequently (especially in `LazyVStack`). `@State startTime` inside the view
  resets to `Date()` on each recreation, resetting the animation. An
  `ObservableObject` held via `@StateObject` is kept alive by SwiftUI across
  view rebuilds.
- Cycle: scroll → `· END ·` marker appears → 1.2 s pause → seamless repeat
  (two `text + END` pairs are rendered back-to-back to hide the seam).

### MockBackend.seed() — followed users and their posts

| User | Followed | Photos used |
|---|---|---|
| ada | ✓ | Frank_Ocean_1 · 334 · 613 · 691 |
| grace | ✓ | 334 · 613 · 691 · 839 |
| alan | ✓ | 839 · 613 · 691 · Frank_Ocean_1 |
| katherine | ✓ | 18 · 839 · 691 |
| jean | ✓ | 18 · 613 |
| margaret | ✗ | 691 · 613 |
| donald | ✗ | 334 |

### photo() lookup

`MockBackend.photo(_:)` tries bundle root first, then `MockPhotos/` subdirectory,
for both `.jpg` and `.jpeg`. This handles XcodeGen bundling the folder either as
individual file references (flat) or as a directory copy (subdirectoried). Do not
simplify this to a single lookup.

### Confirmed design decisions

| Decision | Choice |
|---|---|
| Seen trigger | Tap row → navigate into post |
| Typography | Monospaced throughout (`Font.system(.X, design: .monospaced)`) |
| Color | Adaptive (system light / dark) |
| Row separator | Filled block background + left-edge 3pt bracket + 0.5pt bottom hairline |
| Own post in feed | No — profile only |
| Friends with no posts | Hidden |
| Sort order | Latest `post.day` per friend, newest first |
| Deduplication | One row per friend; their most recent post only |

---

## Active TODO (abridged — see TODO.md for full detail)

1. **Rename app to Kologe** — project.yml, bundle ID, source folder, `@main` struct, all user-facing strings
2. **Uniform feed row height** — move the "N collages" line so all rows are the same pixel height
3. Implement invite-only sign-up
4. UI overhaul (typography tokens, tab bar reconsider, editor polish)
5. Cell pan / zoom (photo crop inside a cell)
6. Reorderable collages within a post
7. Archive / calendar view on profile
8. Tags / moods per post
9. Profile themes
10. Collaborative posts
11. Video support in collage cells
12. Polish filmstrip frame with `Canvas`-drawn sprockets

---

## Gotchas learned from past sessions

- **Always run `xcodegen generate` after file changes** before opening the project in Xcode. "Cannot find X in scope" is almost always a stale project, not a code bug.
- **Async in `.task { }` closures**: avoid deeply chained `try? await ... ?? try? await ...` — the compiler loses async context inference. Extract into a named `private func` with `async` in the signature.
- **Gesture pass-through**: any `.onTapGesture` attached unconditionally (even with an empty closure) will swallow taps and prevent outer `NavigationLink`s from firing. Use an optional handler and only attach the gesture modifier when the handler is non-nil.
- **`MagnifyGesture` / `RotateGesture`**: iOS 17 renamed these from `MagnificationGesture` / `RotationGesture`. Use the new names.
- **Actor-isolated `currentUser`**: access via `backend.currentUser` (synchronous, nonisolated) everywhere. Do not `await` it.
- **Background image clipping in SwiftUI**: `.clipped()` must be applied to the **parent view** *after* `.background { }`, not inside the background closure. Inside the closure the view has no established frame yet, so clipping is a no-op and `scaledToFill` images overflow.
- **`scaledToFill` images in `LazyVStack` rows**: do not use `@State` computed images as the row background source if you can avoid it — images decode correctly when measured, but SwiftUI may not re-render the background layer on a recycled row. Prefer loading images synchronously into `CollageCell.image: Data?` and decoding fresh each time.
- **`ViewThatFits` and `.fixedSize()`**: `ViewThatFits` measures children against the *proposed* size. If a child has `.fixedSize()`, it reports its natural width as its minimum — causing it to always "fit" even when the container is narrow, so the fallback child is never chosen. Use explicit width comparison (`naturalWidth <= containerWidth`) instead.
- **Marquee / scrolling text**: animation state (`startTime`) must live in an `ObservableObject` held by `@StateObject`, not in `@State`. `@State` resets on every view struct re-initialization (common in `LazyVStack`); `@StateObject` survives rebuilds. See `MarqueeController` in `LogRowView.swift`.
- **`UIFont` for text width measurement**: `(text as NSString).size(withAttributes: [.font: uiFont]).width` gives the rendered width synchronously without any layout pass. Use this in place of `PreferenceKey`-based measurement when you need the width at init time (e.g., in `MarqueeController`).
