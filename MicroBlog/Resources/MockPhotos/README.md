# Mock photos

Drop bundled photos here so the app can use them as a stand-in for the user's
`PhotosPicker` library — handy for previews, the simulator, screenshots, and
seeding example pages.

There are two places to put images, depending on how you want to load them.

## 1. `MockPhotos.xcassets` (recommended)

Add image sets to `MicroBlog/Resources/MockPhotos.xcassets/` (the asset
catalog sibling to this folder). Xcode-style:

```
MockPhotos.xcassets/
├── Contents.json
└── beach.imageset/
    ├── Contents.json
    └── beach.jpg
```

In code, load with:

```swift
let img = UIImage(named: "beach")  // ← image set name, not file name
```

The advantages: Xcode resizes/optimizes for you, dark-mode and @2x/@3x
variants are supported, and previews work without any bundle plumbing.

The simplest way to add an image set is in Xcode itself: open
`MockPhotos.xcassets`, drag a JPG/PNG into the asset catalog editor.

## 2. Loose files in this folder

If you'd rather drop raw files (e.g. for batch processing), put PNG/JPGs
directly in `MicroBlog/Resources/MockPhotos/`. Because `project.yml` includes
the entire `MicroBlog/` directory as sources, they'll get bundled, but you'll
have to load them by full bundle path:

```swift
if let url = Bundle.main.url(forResource: "beach", withExtension: "jpg"),
   let data = try? Data(contentsOf: url) {
    // use data
}
```

For consistency, prefer option 1.

## Conventions

- Square or 4:5 portraits work best on a scrapbook page.
- Keep each image under ~500 KB; the editor downsamples larger uploads
  anyway when storing them in `ImageContent`.
- Don't commit photos you don't have the rights to redistribute.
