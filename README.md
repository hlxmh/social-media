# MicroBlog

A daily-collage photo journal for iOS. Each user has one **post per day**; a post is an ordered list of **collages**, each built from a fixed photo layout, decorated with stickers / tape / lines / doodles, and accompanied by its own free-form text body. Viewers swipe horizontally between collages.

The backend is a fully in-memory mock (`MockBackend` actor) so the app runs end-to-end without any server.

## Concepts

- **Post**: one per author per day, holds an ordered `[Collage]`.
- **Collage**: a 4:5 portrait canvas with a `LayoutPreset` (full / 2-stacked / 2-side / 4-grid), photo cells in those preset slots, a `BorderStyle` (frame style + gutter color/width), free-floating overlays (sticker, tape, doodle, straight line), and a text body.
- **No "dead space" inside the canvas** — the preset's cells fill the entire collage, gutters and frame included.
- **Reactions are intentionally absent** in this iteration; activity is follow-only.

## What you can do

- **Compose today's post.** Pick a layout, drop photos into each cell (PhotosPicker), add stickers, washi tape, freehand doodles, and straight rule lines on top, write a journal entry below, and save. Add as many collages to today's post as you like; they appear as a swipeable carousel for viewers.
- **Customize the look** with the border tool: choose an outer frame (none / Polaroid / filmstrip / torn paper) and a gutter color + width that paints between photos.
- **Browse posts** from people you follow on the home grid; tap a post to open its carousel + read each collage's text section.
- **Find people, follow them, get notified** when they follow you.

## App architecture

```
MicroBlog/
├── App/
│   ├── MicroBlogApp.swift
│   ├── AppState.swift          # @MainActor, holds backend + notification badge
│   └── RootView.swift          # TabView + floating editor button
├── Models/
│   ├── User.swift
│   ├── Post.swift              # one per author per day
│   ├── Collage.swift           # canvas: preset, cells, border, overlays, text
│   ├── LayoutPreset.swift      # cell rects per layout
│   ├── Border.swift            # FrameStyle + BorderStyle (gutter color/width)
│   ├── OverlayElement.swift    # sticker, tape, doodle, straight line
│   ├── StickerCatalog.swift    # curated stickers + tints
│   ├── Notification.swift
│   └── RelativeTime.swift
├── Services/
│   ├── BackendService.swift
│   └── MockBackend.swift
├── ViewModels/
└── Views/
    ├── FeedView.swift              # thumbnail grid
    ├── PostDetailView.swift        # carousel + per-collage text
    ├── PostEditorView.swift        # composer
    ├── ProfileView.swift
    ├── SearchView.swift
    ├── NotificationsView.swift
    └── Components/
        ├── CollageView.swift           # read-only renderer for a Collage
        ├── EditableOverlayView.swift   # drag/scale/rotate wrapper
        ├── PostThumbnailView.swift     # card used in grids
        ├── StickerPickerView.swift
        ├── AvatarView.swift
        └── EmptyStateView.swift
```

Photo cells use the layout preset's normalized rects (`0...1` in canvas space), so the same collage renders correctly at thumbnail, carousel, and detail sizes. Overlays use the same normalized positioning.

## Setup

Requirements: macOS with Xcode 15+, iOS 17 deployment target.

```bash
brew install xcodegen
cd /path/to/micro-blog
xcodegen generate          # creates MicroBlog.xcodeproj from project.yml
open MicroBlog.xcodeproj   # then Cmd-R
```

Bundled mock photos in `MicroBlog/Resources/MockPhotos/` are used by the seeded posts so the feed has content even before the user adds any of their own.

## Swapping the backend

`BackendService` is a protocol; `MockBackend` is one implementation. To plug in a real API:

```swift
@StateObject private var appState = AppState(backend: MyRealBackend())
```

Every view model takes the backend through its initializer, so no SwiftUI plumbing changes.
