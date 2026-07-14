import SwiftUI
import RewardsKit

// MARK: - Balance badge

struct BalanceBadge: View {
    @Environment(RewardsEngine.self) private var engine

    var body: some View {
        let unit = engine.state.profile?.rewardUnit ?? .star
        HStack(spacing: 4) {
            Text(unit.emoji)
            Text("\(engine.balance)")
                .fontWeight(.bold)
                .contentTransition(.numericText())
        }
        .font(.title3)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.yellow.opacity(0.25), in: Capsule())
        .animation(.bouncy, value: engine.balance)
        .accessibilityLabel("\(engine.balance) \(unit.pluralName)")
    }
}

// MARK: - Streak flame

struct StreakBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                Text("🔥")
                Text("\(count)")
                    .fontWeight(.bold)
            }
            .font(.title3)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.2), in: Capsule())
            .accessibilityLabel("\(count) day streak")
        }
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    /// 0...1
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .pink, .purple, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.bouncy, value: progress)
            if progress >= 1 {
                Text("🎉")
                    .font(.largeTitle)
                    .transition(.scale)
            } else {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.headline)
                    .contentTransition(.numericText())
            }
        }
    }
}

// MARK: - Confetti

/// Lightweight celebration burst. Increment `trigger` to fire.
struct ConfettiView: View {
    let trigger: Int

    private struct Particle: Identifiable {
        let id = UUID()
        let emoji: String
        let x: Double
        let spin: Double
        let scale: Double
        let delay: Double
    }

    @State private var particles: [Particle] = []

    private static let emojis = ["🎉", "⭐️", "✨", "💫", "🎈", "🌟"]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(particle: particle, height: proxy.size.height)
                        .position(x: particle.x * proxy.size.width, y: -20)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            particles = (0..<18).map { _ in
                Particle(
                    emoji: Self.emojis.randomElement()!,
                    x: .random(in: 0.05...0.95),
                    spin: .random(in: -360...360),
                    scale: .random(in: 0.7...1.4),
                    delay: .random(in: 0...0.25)
                )
            }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                particles = []
            }
        }
    }

    private struct ParticleView: View {
        let particle: Particle
        let height: CGFloat
        @State private var fall = false

        var body: some View {
            Text(particle.emoji)
                .font(.title)
                .scaleEffect(particle.scale)
                .rotationEffect(.degrees(fall ? particle.spin : 0))
                .offset(y: fall ? height + 60 : 0)
                .opacity(fall ? 0.8 : 1)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.8).delay(particle.delay)) {
                        fall = true
                    }
                }
        }
    }
}

// MARK: - PIN pad

struct PINPadView: View {
    let title: String
    let subtitle: String?
    let onSubmit: (String) -> Bool

    @State private var entered = ""
    @State private var shake = false

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2.bold())
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < entered.count ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 18, height: 18)
                }
            }
            .offset(x: shake ? -8 : 0)
            .animation(shake ? .linear(duration: 0.06).repeatCount(5, autoreverses: true) : .default, value: shake)

            VStack(spacing: 12) {
                ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]], id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                tap(key)
                            } label: {
                                Text(key)
                                    .font(.title.bold())
                                    .frame(width: 72, height: 72)
                                    .background(key.isEmpty ? .clear : Color(.systemGray6), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(key.isEmpty)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func tap(_ key: String) {
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < 4 else { return }
        entered += key
        if entered.count == 4 {
            let pin = entered
            if onSubmit(pin) {
                entered = ""
            } else {
                entered = ""
                shake = true
                Task {
                    try? await Task.sleep(for: .seconds(0.4))
                    shake = false
                }
            }
        }
    }
}

// MARK: - Big friendly button style

struct BigButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
