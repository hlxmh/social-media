import SwiftUI

@main
struct MicroBlogApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(.primary)
        }
    }
}
