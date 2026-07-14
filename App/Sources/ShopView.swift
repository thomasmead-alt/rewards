import SwiftUI
import RewardsKit

/// Real-life rewards the child can cash units in for.
struct ShopView: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var rewardToConfirm: RealReward?
    @State private var confetti = 0

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !engine.pendingRedemptions.isEmpty {
                        pendingSection
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(engine.activeRewards) { reward in
                            RewardCard(reward: reward) {
                                rewardToConfirm = reward
                            }
                        }
                    }
                    if engine.activeRewards.isEmpty {
                        ContentUnavailableView(
                            "No rewards yet",
                            systemImage: "gift",
                            description: Text("Ask a grown-up to add some rewards!")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { BalanceBadge() }
            }
            .overlay { ConfettiView(trigger: confetti) }
            .alert(item: $rewardToConfirm) { reward in
                let unit = engine.state.profile?.rewardUnit ?? .star
                return Alert(
                    title: Text("Get \(reward.title)?"),
                    message: Text("This costs \(unit.label(for: reward.cost)). A grown-up will say yes before it happens!"),
                    primaryButton: .default(Text("Yes please!")) {
                        if (try? engine.requestRedemption(reward.id)) != nil {
                            confetti += 1
                        }
                    },
                    secondaryButton: .cancel(Text("Not now"))
                )
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waiting for a grown-up")
                .font(.headline)
            ForEach(engine.pendingRedemptions) { redemption in
                HStack(spacing: 12) {
                    Text(redemption.icon)
                        .font(.title)
                    Text(redemption.title)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("👀")
                }
                .padding(12)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct RewardCard: View {
    @Environment(RewardsEngine.self) private var engine
    let reward: RealReward
    let redeem: () -> Void

    var body: some View {
        let unit = engine.state.profile?.rewardUnit ?? .star
        let affordable = reward.cost <= engine.balance

        VStack(spacing: 10) {
            Text(reward.icon)
                .font(.system(size: 44))
            Text(reward.title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(minHeight: 40)
            Button {
                redeem()
            } label: {
                Text(unit.label(for: reward.cost))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(affordable ? .purple : .gray)
            .disabled(!affordable)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    ShopView()
        .environment(RewardsEngine(store: InMemoryStore()))
}
