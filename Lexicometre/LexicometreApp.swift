import SwiftUI

@main
struct LexicometreApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.violet)
                .task { await model.load() }
        }
    }
}
