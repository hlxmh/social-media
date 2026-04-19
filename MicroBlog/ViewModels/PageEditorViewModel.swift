import Foundation
import SwiftUI

@MainActor
final class PageEditorViewModel: ObservableObject {
    @Published var theme: PageTheme = .warmPaper
    @Published var ownElements: [PageElement] = []
    @Published var selectedId: UUID? = nil
    @Published var isDoodleMode = false
    @Published var doodleColor: StickerTint = .ink
    @Published var isSaving = false
    @Published var error: String?

    let backend: BackendService

    init(backend: BackendService) {
        self.backend = backend
    }

    private var nextZ: Double {
        (ownElements.map(\.zIndex).max() ?? 0) + 1
    }

    func load() async {
        do {
            let page = try await backend.todayPage()
            theme = page.theme
            ownElements = page.ownElements.sorted { $0.zIndex < $1.zIndex }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Element manipulation

    func add(_ content: ElementContent,
             at position: CGPoint = .init(x: 0.5, y: 0.5),
             rotation: Double = 0,
             scale: Double = 1) {
        let element = PageElement(
            authorId: backend.currentUser.id,
            content: content,
            position: position,
            rotation: rotation,
            scale: scale,
            zIndex: nextZ
        )
        ownElements.append(element)
        selectedId = element.id
    }

    func update(_ id: UUID, _ block: (inout PageElement) -> Void) {
        guard let idx = ownElements.firstIndex(where: { $0.id == id }) else { return }
        var copy = ownElements[idx]
        block(&copy)
        ownElements[idx] = copy
    }

    func delete(_ id: UUID) {
        ownElements.removeAll { $0.id == id }
        if selectedId == id { selectedId = nil }
    }

    func bringToFront(_ id: UUID) {
        update(id) { $0.zIndex = nextZ }
    }

    func updateText(_ id: UUID, newText: String) {
        update(id) { el in
            if case var .text(t) = el.content {
                t.text = newText
                el.content = .text(t)
            }
        }
    }

    // MARK: - Save

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await backend.saveTodayPage(theme: theme, ownElements: ownElements)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
