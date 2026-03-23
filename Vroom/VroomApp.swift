import SwiftUI

@main
struct VroomApp: App {
    @StateObject private var appState: AppStateStore

    init() {
        let processInfo = ProcessInfo.processInfo
        let useInMemoryStore = processInfo.arguments.contains("UITestingSeedPreviewData")
            || processInfo.arguments.contains("UITestingInMemoryStore")
        _appState = StateObject(wrappedValue: AppStateStore(container: AppContainer.live(inMemory: useInMemoryStore)))
    }

    var body: some Scene {
        WindowGroup {
            RootScene()
                .environmentObject(appState)
        }
    }
}
