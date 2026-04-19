import SwiftUI
import PhotosUI

struct PageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PageEditorViewModel

    @State private var showThemes = false
    @State private var showStickers = false
    @State private var photoItem: PhotosPickerItem?
    @State private var editingTextId: UUID? = nil
    @State private var draftText: String = ""

    /// Live in-progress doodle stroke (normalized points).
    @State private var doodlePoints: [CGPoint] = []

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: PageEditorViewModel(backend: backend))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                themeBar
                canvas
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                ToolPalette(
                    isDoodleMode: $viewModel.isDoodleMode,
                    onAddText: addText,
                    onAddSticker: { showStickers = true },
                    onPickPhoto: { /* opens PhotosPicker via overlay below */ },
                    onAddTape: addTape,
                    onUndo: undoLast,
                    photoItem: $photoItem
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .padding(.top, 4)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save() { dismiss() }
                        }
                    } label: {
                        if viewModel.isSaving { ProgressView() }
                        else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showStickers) {
                StickerPickerView { sticker, tint in
                    viewModel.add(.sticker(StickerContent(sticker: sticker, tint: tint, size: 56)))
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Edit text",
                   isPresented: Binding(get: { editingTextId != nil },
                                        set: { if !$0 { editingTextId = nil } })) {
                TextField("Text", text: $draftText)
                Button("Save") {
                    if let id = editingTextId { viewModel.updateText(id, newText: draftText) }
                    editingTextId = nil
                }
                Button("Cancel", role: .cancel) { editingTextId = nil }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadPhoto(newItem); photoItem = nil }
            }
            .task { await viewModel.load() }
        }
    }

    // MARK: - Theme bar

    private var themeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PageTheme.allCases) { theme in
                    Button { viewModel.theme = theme } label: {
                        HStack(spacing: 6) {
                            ZStack {
                                theme.background()
                            }
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                            Text(theme.displayName).font(.footnote)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(viewModel.theme == theme
                                           ? Color.primary.opacity(0.1)
                                           : Color(.secondarySystemBackground))
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width / Page.aspectRatio
            let canvasSize = CGSize(width: width, height: height)

            ZStack(alignment: .topLeading) {
                // Background + own elements (read-only renderer hidden when editor is active)
                viewModel.theme.background()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                ForEach($viewModel.ownElements) { $element in
                    EditableElementView(
                        element: $element,
                        canvasSize: canvasSize,
                        isSelected: viewModel.selectedId == element.id,
                        onTap: { viewModel.selectedId = element.id; viewModel.bringToFront(element.id) },
                        onDoubleTap: { startEditing(element) },
                        onDelete: { viewModel.delete(element.id) }
                    )
                }

                // Live doodle preview while drawing.
                if viewModel.isDoodleMode {
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
                    .frame(width: width, height: height)
                    .allowsHitTesting(true)
                    .gesture(doodleGesture(in: canvasSize))
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectedId = nil }

            if viewModel.isDoodleMode {
                doodleColorBar
                    .padding(8)
            }
        }
        .aspectRatio(Page.aspectRatio, contentMode: .fit)
    }

    private var doodleColorBar: some View {
        HStack(spacing: 8) {
            ForEach([StickerTint.ink, .pink, .coral, .lemon, .mint, .sky, .lilac], id: \.self) { tint in
                Circle()
                    .fill(tint.color)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(Color.white,
                                        lineWidth: viewModel.doodleColor == tint ? 2 : 0)
                    )
                    .onTapGesture { viewModel.doodleColor = tint }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func doodleGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let pt = CGPoint(x: clamp(value.location.x / size.width, 0, 1),
                                 y: clamp(value.location.y / size.height, 0, 1))
                doodlePoints.append(pt)
            }
            .onEnded { _ in
                guard doodlePoints.count > 1 else { doodlePoints = []; return }
                viewModel.add(
                    .doodle(DoodleContent(points: doodlePoints,
                                          color: viewModel.doodleColor,
                                          strokeWidth: 4)),
                    at: .init(x: 0.5, y: 0.5)
                )
                doodlePoints = []
            }
    }

    // MARK: - Element creators

    private func addText() {
        viewModel.add(.text(TextContent(
            text: "your words",
            font: .handwritten,
            color: viewModel.theme.defaultInk,
            size: 24
        )))
    }

    private func addTape() {
        viewModel.add(
            .tape(TapeContent(color: [StickerTint.peach, .lemon, .mint, .lilac, .pink].randomElement()!,
                              width: 180, height: 28)),
            rotation: Double.random(in: -0.3...0.3)
        )
    }

    private func startEditing(_ element: PageElement) {
        if case let .text(t) = element.content {
            draftText = t.text
            editingTextId = element.id
        }
    }

    private func undoLast() {
        guard let last = viewModel.ownElements.last else { return }
        viewModel.delete(last.id)
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        let maxSide: CGFloat = 280
        let aspect = img.size.width / img.size.height
        let (w, h): (Double, Double) = aspect >= 1
            ? (maxSide, maxSide / aspect)
            : (maxSide * aspect, maxSide)
        viewModel.add(.image(ImageContent(data: data, width: w, height: h)))
    }
}

// MARK: - Tool palette

private struct ToolPalette: View {
    @Binding var isDoodleMode: Bool
    let onAddText: () -> Void
    let onAddSticker: () -> Void
    let onPickPhoto: () -> Void
    let onAddTape: () -> Void
    let onUndo: () -> Void
    @Binding var photoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 4) {
            ToolButton(systemImage: "textformat", label: "Text", action: onAddText)
            ToolButton(systemImage: "face.smiling", label: "Sticker", action: onAddSticker)
            PhotosPicker(selection: $photoItem, matching: .images) {
                ToolLabel(systemImage: "photo", label: "Photo")
            }
            ToolButton(systemImage: "scribble", label: "Tape", action: onAddTape)
            ToolButton(
                systemImage: isDoodleMode ? "scribble.variable" : "pencil.tip",
                label: isDoodleMode ? "Done" : "Draw",
                isActive: isDoodleMode
            ) { isDoodleMode.toggle() }
            Spacer(minLength: 0)
            ToolButton(systemImage: "arrow.uturn.backward", label: "Undo", action: onUndo)
        }
    }
}

private struct ToolButton: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { ToolLabel(systemImage: systemImage, label: label, isActive: isActive) }
            .buttonStyle(.plain)
    }
}

private struct ToolLabel: View {
    let systemImage: String
    let label: String
    var isActive: Bool = false

    var body: some View {
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
}

private func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }

#if DEBUG
#Preview("Editor") {
    PageEditorView(backend: MockBackend())
}
#endif
