# TODO

## Rename app to Kologe
Update all branding and identifiers to "Kologe". Scope:
- `project.yml`: `name`, `PRODUCT_BUNDLE_IDENTIFIER` (`com.example.Kologe`), `INFOPLIST_KEY_CFBundleDisplayName`
- Rename the Xcode target and scheme from `MicroBlog` → `Kologe` (regenerate with xcodegen)
- Rename the source root folder `MicroBlog/` → `Kologe/` and update `project.yml` `sources` path
- App entry point: `MicroBlogApp` struct → `KologeApp`
- `AppState`: no rename needed (not brand-specific), but audit any user-facing strings that say "MicroBlog"
- Tab bar, navigation titles, empty-state subtitles, README, and any other user-visible strings
- `Assets.xcassets` `AppIcon` and `AccentColor` — update accent color to match a new Kologe palette if desired
- `Bundle.main` resource lookups (e.g. `Frank_Ocean_1.jpg`) are path-independent; no change needed there

## Implement invite-only
Gate sign-up behind invite codes. Each existing user gets a small pool of
codes; new accounts can't be created without a valid one. Needs a code model,
issuance/redemption flows, and a paywall-style screen on first launch when no
session exists.

## UI overhaul
Refresh the app shell now that the page-as-canvas model is settled. Targets:
- Tighter typography scale and spacing tokens.
- Better empty / loading / error states across tabs.
- Reconsider tab bar vs. a top navigation; the floating editor button feels
  redundant next to a permanent "today" tab.
- Polish the editor's tool palette (sizing, active state, haptics).

## Movable reactions
Let viewers reposition reactions they've placed (and drag stickers from the
picker straight onto the page instead of auto-placing at random). Today the
detail view only supports add/remove. Needs:
- Drag/scale/rotate gestures on reaction elements (reuse `EditableElementView`
  scoped to elements where `authorId == currentUserId`).
- A "save reaction layout" call on the backend (extend `BackendService` with
  an `updateReaction` or batch reaction update method).
- Visual hint that reactions are interactive only for their author.

## Page covers
Let users designate one element as the "cover" of a page — the thing that
dominates the Polaroid thumbnail in feed and profile grids. Needs a
`coverElementId: UUID?` field on `Page`, a long-press or context-menu action
in the editor ("Set as cover"), and a cropped/zoomed render in
`PolaroidThumbnailView` when a cover is set.

## Archive view
A calendar or scrollable year-strip on the profile that maps days to pages,
so the profile feels like a physical journal you can flip back through. Tapping
a day navigates to that page (or shows an empty state if none exists). An "On
this day" banner at the top of the feed surfaces the equivalent page from a
year ago.

## Tags / moods
A small fixed set of mood tags (color + emoji, e.g. ✦ grateful, 🌧 heavy,
🌿 calm) that a user pins to a page before saving. Stored as an optional
`[PageTag]` on `Page`. Profile and archive views get a filter bar; no free-text
search, keeping the UI ambient rather than query-driven.

## Reaction privacy
Add a `reactionVisibility` setting per page: reactions are visible only to the
page author by default, with an opt-in to show them publicly. Viewers always
see the reaction count; the stickers and comment bubbles are author-only unless
the author toggles them open. Removes the performance anxiety of public
reactions.

## Profile themes
Extend `PageTheme` (or add a separate `ProfileTheme`) so users can skin their
profile page — background, accent color, font choice — independently of
individual post pages. Affects the header area and grid background in
`ProfileView`. A "Customize profile" entry point in the editor or settings.

## Collaborative pages
Allow the page owner to invite specific followers to co-author today's page.
Invited collaborators can add their own elements (same editor flow, scoped to
their `authorId`). Needs: a `collaboratorIds: [UUID]` field on `Page`, an
invite UI (follower picker), and backend methods to check write permission
before accepting an `addElement` call. The page shows a multi-avatar byline
in feed and profile.

## Cell pan / zoom (photo crop)
Photos currently `scaledToFill` and clip, which can crop tall portraits
poorly. Let users pan and zoom inside an individual cell after dropping a
photo so they can frame it. Needs: a `crop: CellCrop { offset, scale }`
field on `CollageCell`; gestures on `CollageCellView` in the editor that
write back to the crop; the renderer applies offset+scale before clipping.

## Reorderable collages
Today the carousel is fixed in insertion order. Add a "rearrange" mode (or
drag the page dots) so users can reorder collages within a post and delete
individual ones from a list. Reuse `viewModel.collages` array with a
`.move(fromOffsets:toOffset:)` operation.

## Digital log UI: NotificationsView
Highest-impact / smallest scope. Mirrors feed row structure directly:
- Drop system `List` and purple SF Symbol icon.
- Each notification → a log row: left bracket (green dot for unread), `@handle
  started following you`, relative time right-aligned. Same monospaced voice as
  `LogRowView`.
- Title stamp at top: `ACTIVITY LOG` in kerned monospaced caps, same style as
  `FEED` header.
- Add `ScanlineOverlay` behind the list.

## Digital log UI: SearchView
- Replace `List` + `Section` with `LazyVStack` inside a `ScrollView`, same
  structure as `FeedView.log`.
- Each user row: left bracket bar colored by `avatarHue`, `@handle`,
  follower count right-aligned. No avatar circle — handles are the identity.
- Section header `WHO TO FOLLOW` in kerned monospaced caps.
- Scanlines over the full list.
- Style the `.searchable()` placeholder as `> search handles...`.

## Digital log UI: PostDetailView
- Replace author header with a single monospaced metadata bar:
  `@ada  ·  today  ·  2 collages` — same typographic voice as the feed row.
- Move the `N / M` collage counter into that header bar, left or center.
- Add a thin left-edge bracket to the text/caption section below the collage,
  same 3pt colored bar as `LogRowView`, anchoring the text to the log language.
- Replace generic paging dots with an inline text counter: `[ 1 — 2 ]`.
- Add `ScanlineOverlay` behind the caption section.

## Digital log UI: ProfileView
- Strip the circle avatar or reduce to a small monogram square.
- Render the header as a structured data block:
  ```
  ADA LOVELACE
  @ada  ·  4,213 followers  ·  88 following
  ─────────────────────────────────────────
  Notes on the Analytical Engine.
  ```
- Follow button becomes a monospaced `[ FOLLOW ]` / `[ FOLLOWING ]` bracket
  button — no capsule fill.
- Replace the Polaroid thumbnail grid with a tight 3-column square grid.
  Each thumbnail has a monospaced date beneath: `APR 28`. No tilt.
- Add `ScanlineOverlay` over the grid area only (not the header block).

## Digital log UI: RootView / tab bar
- Override tab bar tint to a single crisp color (primary or the green from
  the unread dot) rather than the default blue accent.
- Rename tabs to shorter, monospaced-feeling labels: `LOG / FIND / ALERTS / YOU`,
  or switch to icon-only.
- Consider making the floating `+` button square with cropped corners instead
  of fully circular, to match the blockier visual language.

## Variable row weight by recency (feed)
The most recent entry in the digital log should visually dominate — taller row,
higher photo opacity, slightly larger typography. Older entries compress. This
mirrors newspaper above-the-fold hierarchy and makes a sparse feed feel
intentional rather than empty. Implementation notes:
- Assign each row an `age` rank (0 = newest). Lerp row height from a tall
  max (~100pt) down to a compact min (~56pt) based on rank or day delta.
- Apply a matching opacity ramp to the background photo wash.
- Cap the tall-row treatment to the top 1–2 entries so the rest stay compact.
- Animate height changes when the feed refreshes (new post pushes old ones down).

## Uniform feed row height
The "N collages" subtitle in `LogRowView` is rendered as a third line in the
meta column only when `post.collages.count > 1`, which makes those rows taller
than single-collage rows and breaks the dense, modular feel of the digital log.
Move the indicator somewhere that doesn't add a row. Options:
- Inline with the time on the top line (e.g. `@ada   2▣  17h`).
- A small sticker-stack glyph rendered in the row's right margin or as part
  of the bracket on the left.
- Drop the textual "collages" word entirely and use only a count + icon.
Acceptance: every row in the feed is the same pixel height regardless of how
many collages the post contains.

## Video support
Allow short videos in collage cells alongside photos. Scope:
- Extend `CollageCell` from `image: Data?` to a richer `media: CellMedia`
  enum (`.image(Data)` | `.video(url: URL, thumbnail: Data)`).
- `PhotosPicker` already supports `.videos` and `.any(of: [.images, .videos])`
  filters — switch the picker config and branch on the picked `PhotosPickerItem`'s
  type.
- `CollageCellView`: render a still image as today, plus an overlay play
  button + autoplay-on-tap using `AVPlayerLayer` (or `VideoPlayer` from
  AVKit) for video cells.
- Thumbnail generation at pick time so `LogRowView` and profile grid stay
  cheap (`AVAssetImageGenerator.copyCGImage(at: .zero)`).
- Mute by default; tap-to-unmute in the detail view; loop short clips.
- Cap clip length (e.g. 15s) and re-encode on import to keep mock backend
  payloads sane.

## Polish the filmstrip frame
The current `.filmStrip` frame uses HStacks of rounded rectangles for sprocket
holes — visible seams when the canvas size doesn't divide evenly. Replace
with a `Canvas`-drawn frame that lays out sprockets parametrically and looks
crisp at any size. Bonus: subtle grain texture on top.

## Move stale data to bottom of list