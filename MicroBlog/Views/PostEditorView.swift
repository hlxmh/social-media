import SwiftUI
import PhotosUI

struct PostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PostEditorViewModel

    @State private var photoCellTarget: Int? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showStickers = false
    @State private var showFrameSheet = false

    /// Live in-progress doodle stroke (normalized).
    @State private var doodlePoints: [CGPoint] = []
    /// Live in-progress straight line.
    @State private var lineStart: CGPoint? = nil
    @State private var lineEnd: CGPoint? = nil

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: PostEditorViewModel(backend: backend))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    presetBar
                    collagesCarousel
                    pageDots
                    textBody
                    Spacer(minLength: 80)
                }
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                toolPalette.background(.ultraThinMaterial)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 14) {
                        Button { showFrameSheet = true } label: {
                            Image(systemName: "square.dashed")
                        }
                        .accessibilityLabel("Border")
                        if viewModel.collages.count > 1 {
                            Button(role: .destructive) {
                                viewModel.deleteCurrent()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Delete this collage")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { if await viewModel.save() { dismiss() } }
                    } label: {
                        if viewModel.isSaving { ProgressView() }
                        else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showStickers) {
                StickerPickerView { sticker, tint in
                    viewModel.addOverlay(.sticker(StickerContent(
                        sticker: sticker, tint: tint, size: 56)))
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFrameSheet) {
                if let collage = viewModel.current {
                    BorderSettingsSheet(
                        border: collage.border,
                        onFrame: { viewModel.setFrame($0) },
                        onColor: { viewModel.setGutterColor($0) },
                        onWidth: { viewModel.setGutterWidth($0) }
                    )
                    .presentationDetents([.medium])
                }
            }
            .photosPicker(
                isPresented: Binding(
                    get: { photoCellTarget != nil },
                    set: { if !$0 { photoCellTarget = nil } }
                ),
                selection: $photoItem,
                matching: .images
            )
            .onChange(of: photoItem) { _, newItem in
                guard let target = photoCellTarget, let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.setImage(data, forCellAt: target)
                    }
                    photoItem = nil
                    photoCellTarget = nil
                }
            }
            .task { await viewModel.load() }
        }
    }

    // MARK: - Top: preset bar

    private var presetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LayoutPreset.allCases) { preset in
                    Button { viewModel.setPreset(preset) } label: {
                        VStack(spacing: 4) {
                            PresetIcon(preset: preset)
                                .frame(width: 28, height: 36)
                            Text(preset.displayName).font(.caption2)
                        }
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.current?.preset == preset
                                      ? Color.primary.opacity(0.10)
                                      : Color(.secondarySystemBackground))
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Collages carousel

    private var collagesCarousel: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(viewModel.collages.enumerated()), id: \.element.id) { idx, _ in
                editableCollage(at: idx)
                    .padding(.horizontal, 16)
                    .tag(idx)
            }
            addCollageSlide.tag(viewModel.collages.count)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: collageFrameHeight)
    }

    private var collageFrameHeight: CGFloat {
        let w = UIScreen.main.bounds.width - 32
        return w / Collage.aspectRatio + 24
    }

    private var addCollageSlide: some View {
        Button {
            viewModel.addCollage()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.tint)
                Text("Add another collage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func editableCollage(at index: Int) -> some View {
        if viewModel.collages.indices.contains(index) {
            GeometryReader { proxy in
                let size = sizeFor(width: proxy.size.width, height: proxy.size.height)
                ZStack {
                    CollageView(
                        collage: viewModel.collages[index],
                        emptyCellLabel: { _ in "tap to add a photo" },
                        focusedCellIndex: nil,
                        onTapCell: { cellIdx in
                            photoCellTarget = cellIdx
                        },
                        renderOverlays: false
                    )

                    overlayLayer(index: index, canvasSize: size)

                    if viewModel.activeTool == .doodle {
                        doodleSurface(canvasSize: size)
                    } else if viewModel.activeTool == .straightLine {
                        lineSurface(canvasSize: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(Collage.aspectRatio, contentMode: .fit)
        }
    }

    private func sizeFor(width: CGFloat, height: CGFloat) -> CGSize {
        let aspect = Collage.aspectRatio
        if width / height < aspect {
            return CGSize(width: width, height: width / aspect)
        } else {
            return CGSize(width: height * aspect, height: height)
        }
    }

    private func overlayLayer(index: Int, canvasSize: CGSize) -> some View {
        ZStack {
            ForEach(viewModel.collages[index].overlays.sorted { $0.zIndex < $1.zIndex }) { el in
                let binding = Binding<OverlayElement>(
                    get: {
                        viewModel.collages[index].overlays.first(where: { $0.id == el.id }) ?? el
                    },
                    set: { newValue in
                        viewModel.updateOverlay(newValue.id) { e in
                            e.position = newValue.position
                            e.rotation = newValue.rotation
                            e.scale = newValue.scale
                        }
                    }
                )
                EditableOverlayView(
                    element: binding,
                    canvasSize: canvasSize,
                    isSelected: viewModel.selectedOverlayId == el.id,
                    onTap: {
                        viewModel.selectedOverlayId = el.id
                        viewModel.bringOverlayToFront(el.id)
                    },
                    onDelete: { viewModel.deleteOverlay(el.id) }
                )
            }
        }
    }

    // MARK: - Doodle / line surfaces

    private func doodleSurface(canvasSize: CGSize) -> some View {
        Canvas { ctx, size in
            guard doodlePoints.count > 1 else { return }
            var path = Path()
            for (i, p) in doodlePoints.enumerated() {
                let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path,
                       with: .color(viewModel.doodleColor.color),
                       style: .init(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let pt = CGPoint(
                        x: clamp(value.location.x / canvasSize.width, 0, 1),
                        y: clamp(value.location.y / canvasSize.height, 0, 1)
                    )
                    doodlePoints.append(pt)
                }
                .onEnded { _ in
                    guard doodlePoints.count > 1 else { doodlePoints = []; return }
                    viewModel.addOverlay(
                        .doodle(DoodleContent(points: doodlePoints,
                                              color: viewModel.doodleColor,
                                              strokeWidth: 4))
                    )
                    doodlePoints = []
                }
        )
    }

    private func lineSurface(canvasSize: CGSize) -> some View {
        Canvas { ctx, size in
            if let s = lineStart, let e = lineEnd {
                var path = Path()
                path.move(to: CGPoint(x: s.x * size.width, y: s.y * size.height))
                path.addLine(to: CGPoint(x: e.x * size.width, y: e.y * size.height))
                ctx.stroke(path,
                           with: .color(viewModel.lineColor.color),
                           style: .init(lineWidth: 4, lineCap: .round))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = CGPoint(
                        x: clamp(value.startLocation.x / canvasSize.width, 0, 1),
                        y: clamp(value.startLocation.y / canvasSize.height, 0, 1)
                    )
                    let end = CGPoint(
                        x: clamp(value.location.x / canvasSize.width, 0, 1),
                        y: clamp(value.location.y / canvasSize.height, 0, 1)
                    )
                    lineStart = start
                    lineEnd = end
                }
                .onEnded { _ in
                    if let s = lineStart, let e = lineEnd, s != e {
                        viewModel.addOverlay(
                            .straightLine(StraightLineContent(
                                start: s, end: e,
                                color: viewModel.lineColor, thickness: 4))
                        )
                    }
                    lineStart = nil
                    lineEnd = nil
                }
        )
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.collages.count + 1, id: \.self) { idx in
                Circle()
                    .fill(idx == viewModel.currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: idx == viewModel.collages.count ? 6 : 7,
                           height: idx == viewModel.collages.count ? 6 : 7)
                    .overlay(
                        idx == viewModel.collages.count
                        ? Image(systemName: "plus")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(Color(.systemBackground))
                        : nil
                    )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Text body

    private var textBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Words")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if (viewModel.current?.text.isEmpty ?? true) {
                    Text("Write something about this collage…")
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: viewModel.currentText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tool palette

    private var toolPalette: some View {
        HStack(spacing: 4) {
            ToolButton(systemImage: "face.smiling", label: "Sticker") {
                showStickers = true
            }
            ToolButton(systemImage: "bandage", label: "Tape") {
                viewModel.addOverlay(
                    .tape(TapeContent(
                        color: [.peach, .lemon, .mint, .lilac, .pink].randomElement()!,
                        width: 160, height: 24)),
                    rotation: Double.random(in: -0.3...0.3)
                )
            }
            ToolButton(systemImage: "scribble.variable", label: "Draw",
                       isActive: viewModel.activeTool == .doodle) {
                viewModel.activeTool = viewModel.activeTool == .doodle ? .none : .doodle
                viewModel.selectedOverlayId = nil
            }
            ToolButton(systemImage: "line.diagonal", label: "Line",
                       isActive: viewModel.activeTool == .straightLine) {
                viewModel.activeTool = viewModel.activeTool == .straightLine ? .none : .straightLine
                viewModel.selectedOverlayId = nil
            }
            Spacer(minLength: 0)
            if viewModel.activeTool == .doodle || viewModel.activeTool == .straightLine {
                colorChips
            }
            ToolButton(systemImage: "arrow.uturn.backward", label: "Undo") {
                viewModel.undoLastOverlay()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var colorChips: some View {
        HStack(spacing: 8) {
            ForEach([StickerTint.ink, .pink, .coral, .lemon, .mint, .sky, .lilac], id: \.self) { tint in
                let active = (viewModel.activeTool == .doodle && viewModel.doodleColor == tint)
                    || (viewModel.activeTool == .straightLine && viewModel.lineColor == tint)
                Circle()
                    .fill(tint.color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.primary,
                                             lineWidth: active ? 2 : 0))
                    .onTapGesture {
                        if viewModel.activeTool == .doodle { viewModel.doodleColor = tint }
                        if viewModel.activeTool == .straightLine { viewModel.lineColor = tint }
                    }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Helpers

private struct PresetIcon: View {
    let preset: LayoutPreset
    var body: some View {
        let cells = preset.cellRects(inset: 0.06, gutterX: 0.05, gutterY: 0.05)
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.tertiarySystemFill))
                ForEach(Array(cells.enumerated()), id: \.0) { _, rect in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.primary.opacity(0.7))
                        .frame(
                            width: rect.width * proxy.size.width,
                            height: rect.height * proxy.size.height
                        )
                        .position(x: rect.midX * proxy.size.width,
                                  y: rect.midY * proxy.size.height)
                }
            }
        }
    }
}

private struct ToolButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(label).font(.caption2)
            }
            .frame(width: 56, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct BorderSettingsSheet: View {
    let border: BorderStyle
    let onFrame: (FrameStyle) -> Void
    let onColor: (StickerTint) -> Void
    let onWidth: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var localWidth: Double

    init(border: BorderStyle,
         onFrame: @escaping (FrameStyle) -> Void,
         onColor: @escaping (StickerTint) -> Void,
         onWidth: @escaping (Double) -> Void) {
        self.border = border
        self.onFrame = onFrame
        self.onColor = onColor
        self.onWidth = onWidth
        self._localWidth = State(initialValue: border.gutterWidth)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Frame") {
                    ForEach(FrameStyle.allCases) { style in
                        Button {
                            onFrame(style)
                        } label: {
                            HStack {
                                Text(style.displayName).foregroundStyle(.primary)
                                Spacer()
                                if border.frame == style {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                Section("Gutter color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                              spacing: 12) {
                        ForEach(StickerTint.allCases) { tint in
                            Circle()
                                .fill(tint.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(Color.primary,
                                                    lineWidth: border.gutterColor == tint ? 2 : 0)
                                )
                                .onTapGesture { onColor(tint) }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Gutter width") {
                    HStack {
                        Slider(value: $localWidth, in: 0...20, step: 1) {
                            Text("Gutter width")
                        }
                        Text("\(Int(localWidth)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .onChange(of: localWidth) { _, new in onWidth(new) }
                }
            }
            .navigationTitle("Border")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }

#if DEBUG
#Preview("Editor") {
    PostEditorView(backend: PreviewScaffold.backend)
}
#endif
