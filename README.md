# MicroBlog

A daily-page micro-blog for iOS. Each user gets one scrapbook-style page per day — a freeform canvas for text, stickers, photos, washi tape, and doodles. Reactions from people you follow appear as stickers and comment bubbles right on the page; flip the eye-icon to see the clean version.

The backend is a fully in-memory mock (`MockBackend` actor) so the app runs end-to-end without any server.

## What you can do

- **Make today's page**. Tap the floating compose button. Drop on text, stickers, photos (PhotosPicker), washi tape strips, or freehand doodles. Drag to move, pinch to scale, two-finger rotate. Pick from six page themes (Warm Paper, Y2K, Dreamy, Zine, Midnight, Grid). Pages are always editable — your daily page is more like a journal entry than a one-shot post.
- **Browse pages from people you follow.** A Polaroid grid in the Pages tab; tap any page to expand it.
- **React to other people's pages.** Drop a sticker or post a tiny comment bubble. Reactions are placed on the page itself, with a slight rotation. You can remove your own reactions at any time.
- **Follower-only reactions.** Other people's reactions on a page are only visible to you if you follow them. The detail view shows "3 of 12 shown" so you know more is happening.
- **Toggle reactions off** to see the page exactly as the author left it.
- **Find people, follow them, get notified** when they react to your page or follow you.

## App architecture

```
MicroBlog/
├── App/
│   ├── MicroBlogApp.swift      # @main, scene
│   ├── AppState.swift          # @MainActor, holds backend + notification badge
│   └── RootView.swift          # TabView shell + floating editor button
├── Models/
│   ├── User.swift
│   ├── Page.swift              # one page per author per day
│   ├── PageElement.swift       # element + content enum (text/sticker/image/tape/doodle)
│   ├── PageTheme.swift         # six page backgrounds, all SwiftUI-native
│   ├── StickerCatalog.swift    # curated SF Symbol + emoji set, tints, fonts
│   ├── PageNotification.swift
│   └── RelativeTime.swift
├── Services/
│   ├── BackendService.swift    # protocol the UI talks to
│   └── MockBackend.swift       # actor with seeded users, pages, follows, notifications
├── ViewModels/                 # @MainActor, one per screen
└── Views/
    ├── FeedView.swift              # Polaroid grid
    ├── PageDetailView.swift        # full page + reactions toggle
    ├── PageEditorView.swift        # the canvas editor
    ├── ProfileView.swift           # bio + grid of that user's pages
    ├── SearchView.swift            # debounced people search
    ├── NotificationsView.swift     # follows + reactions
    └── Components/
        ├── PageCanvasView.swift        # read-only renderer for a Page
        ├── EditableElementView.swift   # draggable/scalable/rotatable wrapper
        ├── PolaroidThumbnailView.swift # the card used in grids
        ├── StickerPickerView.swift
        ├── AvatarView.swift
        └── EmptyStateView.swift
```

The page canvas uses **normalized coordinates (0...1 × 0...1)** for every element's position, so the same page renders at any size — feed thumbnail, full detail, profile grid — without re-layout.

## Setup

Requirements: macOS with Xcode 15+, iOS 17 deployment target.

```bash
brew install xcodegen
cd /path/to/micro-blog
xcodegen generate          # creates MicroBlog.xcodeproj from project.yml
open MicroBlog.xcodeproj   # then Cmd-R
```

If you'd rather not use XcodeGen: create a new iOS App in Xcode (Swift / SwiftUI / iOS 17), delete the generated `ContentView.swift` and `MicroBlogApp.swift`, then drag the `MicroBlog/` folder into the project navigator.

## Swapping the backend

`BackendService` is a protocol; `MockBackend` is one implementation. To plug in a real API:

```swift
@StateObject private var appState = AppState(backend: MyRealBackend())
```

Every view model takes the backend through its initializer, so no SwiftUI plumbing changes.
