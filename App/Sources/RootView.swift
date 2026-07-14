import SwiftUI
import RewardsKit

struct RootView: View {
    @Environment(RewardsEngine.self) private var engine

    var body: some View {
        if engine.needsOnboarding {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            FunZoneView()
                .tabItem { Label("Fun Zone", systemImage: "pawprint.fill") }
            ShopView()
                .tabItem { Label("Rewards", systemImage: "gift.fill") }
        }
    }
}

#Preview {
    RootView()
        .environment(RewardsEngine(store: InMemoryStore()))
}
