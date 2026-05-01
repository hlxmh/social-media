import Foundation
import SwiftUI

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var actors: [UUID: User] = [:]
    @Published private(set) var isLoading = false
    @Published var error: String?

    let backend: BackendService

    init(backend: BackendService) { self.backend = backend }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let list = try await backend.notifications()
            notifications = list
            await hydrate(list)
            await backend.markNotificationsRead()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func hydrate(_ list: [AppNotification]) async {
        let userIds = Set(list.map(\.actorId)).subtracting(actors.keys)
        for id in userIds {
            if let u = try? await backend.user(withId: id) { actors[id] = u }
        }
    }
}
