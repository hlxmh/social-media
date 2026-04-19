import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel

    init(backend: BackendService) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(backend: backend))
    }

    var body: some View {
        List {
            if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                if !viewModel.suggested.isEmpty {
                    Section("Who to follow") {
                        ForEach(viewModel.suggested) { user in
                            NavigationLink(value: UserRoute.profile(user.id)) {
                                UserRow(user: user)
                            }
                        }
                    }
                }
            } else if viewModel.users.isEmpty && !viewModel.isSearching {
                EmptyStateView(title: "No results",
                               subtitle: "Try a different name or handle.",
                               systemImage: "magnifyingglass")
                    .listRowSeparator(.hidden)
            } else {
                Section("People") {
                    ForEach(viewModel.users) { user in
                        NavigationLink(value: UserRoute.profile(user.id)) {
                            UserRow(user: user)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Find people")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: "Name or handle")
        .navigationDestination(for: UserRoute.self) { route in
            switch route {
            case .profile(let id): ProfileView(userId: id, backend: viewModel.backend)
            }
        }
        .task { await viewModel.loadDefaults() }
    }
}

private struct UserRow: View {
    let user: User
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(user: user)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.subheadline.weight(.semibold))
                Text(user.handle).font(.footnote).foregroundStyle(.secondary)
                if !user.bio.isEmpty {
                    Text(user.bio).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
