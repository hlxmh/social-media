import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    let backend: BackendService

    @Published var currentUser: User
    @Published var unreadNotifications: Int = 0

    init(backend: BackendService = MockBackend()) {
        self.backend = backend
        self.currentUser = backend.currentUser
        startPollingUnread()
    }

    func refreshCurrentUser() {
        currentUser = backend.currentUser
    }

    private func startPollingUnread() {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let count = await self.backend.unreadNotificationCount()
                self.unreadNotifications = count
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}

// MARK: - Environment

private struct BackendKey: EnvironmentKey {
    static let defaultValue: BackendService = MockBackend()
}

extension EnvironmentValues {
    var backend: BackendService {
        get { self[BackendKey.self] }
        set { self[BackendKey.self] = newValue }
    }
}
