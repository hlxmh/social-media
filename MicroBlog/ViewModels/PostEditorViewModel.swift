import Foundation
import SwiftUI

@MainActor
final class PostEditorViewModel: ObservableObject {
    @Published var collages: [Collage] = []
    @Published var currentIndex: Int = 0

    @Published var selectedOverlayId: UUID? = nil
    @Published var activeTool: EditorTool = .none
    @Published var doodleColor: StickerTint = .ink
    @Published var lineColor: StickerTint = .ink

    @Published var isSaving = false
    @Published var error: String?

    let backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    enum EditorTool: Equatable {
        case none
        case doodle
        case straightLine
    }

    var current: Collage? {
        guard collages.indices.contains(currentIndex) else { return nil }
        return collages[currentIndex]
    }

    func load() async {
        do {
            let post = try await backend.todayPost()
            collages = post.collages.isEmpty
                ? [Collage(preset: .full)]
                : post.collages
            currentIndex = 0
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Collage list

    func addCollage() {
        collages.append(Collage(preset: .full))
        currentIndex = collages.count - 1
        selectedOverlayId = nil
    }

    func deleteCurrent() {
        guard collages.indices.contains(currentIndex), collages.count > 1 else { return }
        collages.remove(at: currentIndex)
        currentIndex = min(currentIndex, collages.count - 1)
        selectedOverlayId = nil
    }

    // MARK: - Cell editing

    func setImage(_ data: Data?, forCellAt index: Int) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        guard c.cells.indices.contains(index) else { return }
        c.cells[index].image = data
        collages[currentIndex] = c
    }

    // MARK: - Preset / border

    func setPreset(_ preset: LayoutPreset) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        c.preset = preset
        c.reconcileCells()
        collages[currentIndex] = c
    }

    func setFrame(_ style: FrameStyle) {
        mutateCurrent { $0.border.frame = style }
    }

    func setGutterColor(_ tint: StickerTint) {
        mutateCurrent { $0.border.gutterColor = tint }
    }

    func setGutterWidth(_ value: Double) {
        mutateCurrent { $0.border.gutterWidth = value }
    }

    // MARK: - Overlays

    func addOverlay(_ content: OverlayContent,
                    at position: CGPoint = .init(x: 0.5, y: 0.5),
                    rotation: Double = 0,
                    scale: Double = 1) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        let z = (c.overlays.map(\.zIndex).max() ?? 0) + 1
        let element = OverlayElement(content: content, position: position,
                                      rotation: rotation, scale: scale, zIndex: z)
        c.overlays.append(element)
        collages[currentIndex] = c
        selectedOverlayId = element.id
    }

    func updateOverlay(_ id: UUID, _ block: (inout OverlayElement) -> Void) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        guard let idx = c.overlays.firstIndex(where: { $0.id == id }) else { return }
        var copy = c.overlays[idx]
        block(&copy)
        c.overlays[idx] = copy
        collages[currentIndex] = c
    }

    func deleteOverlay(_ id: UUID) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        c.overlays.removeAll { $0.id == id }
        collages[currentIndex] = c
        if selectedOverlayId == id { selectedOverlayId = nil }
    }

    func bringOverlayToFront(_ id: UUID) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        let z = (c.overlays.map(\.zIndex).max() ?? 0) + 1
        if let idx = c.overlays.firstIndex(where: { $0.id == id }) {
            c.overlays[idx].zIndex = z
            collages[currentIndex] = c
        }
    }

    func undoLastOverlay() {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        if !c.overlays.isEmpty {
            c.overlays.removeLast()
            collages[currentIndex] = c
        }
    }

    // MARK: - Text body

    var currentText: Binding<String> {
        Binding(
            get: { [weak self] in self?.current?.text ?? "" },
            set: { [weak self] new in
                self?.mutateCurrent { $0.text = new }
            }
        )
    }

    // MARK: - Save

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        let cleaned = collages.filter { collage in
            collage.cells.contains(where: { $0.image != nil }) ||
            !collage.overlays.isEmpty ||
            !collage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        do {
            _ = try await backend.saveTodayPost(collages: cleaned)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func mutateCurrent(_ block: (inout Collage) -> Void) {
        guard collages.indices.contains(currentIndex) else { return }
        var c = collages[currentIndex]
        block(&c)
        collages[currentIndex] = c
    }
}
