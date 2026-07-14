import SwiftUI
import RewardsKit

@main
struct SproutRewardsApp: App {
    @State private var engine = RewardsEngine(store: JSONFileStore.standard())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .onChange(of: scenePhase) { _, phase in
                    // Process a day rollover whenever the app comes back.
                    if phase == .active {
                        engine.refreshDay()
                    }
                }
        }
    }
}
