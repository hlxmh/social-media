import Foundation
import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var users: [User] = []
    @Published private(set) var suggested: [User] = []
    @Published private(set) var isSearching = false

    let backend: BackendService
    private var cancellables = Set<AnyCancellable>()
    private var task: Task<Void, Never>?

    init(backend: BackendService) {
        self.backend = backend
        $query
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] q in
                Task { @MainActor in self?.runSearch(q) }
            }
            .store(in: &cancellables)
    }

    func loadDefaults() async {
        suggested = (try? await backend.suggestedUsers(limit: 6)) ?? []
    }

    private func runSearch(_ q: String) {
        task?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { users = []; return }
        task = Task { [weak self] in
            guard let self else { return }
            isSearching = true
            defer { self.isSearching = false }
            let results = (try? await self.backend.searchUsers(query: trimmed)) ?? []
            if Task.isCancelled { return }
            self.users = results
        }
    }
}
