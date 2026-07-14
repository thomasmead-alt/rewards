import SwiftUI
import RewardsKit

struct OnboardingView: View {
    @Environment(RewardsEngine.self) private var engine

    private enum Step: Int, CaseIterable {
        case welcome, name, unit, pet, pin
    }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var avatar = "🦊"
    @State private var unit: RewardUnit = .star
    @State private var petSpecies: PetSpecies = .puppy
    @State private var petName = ""
    @State private var firstPIN: String?
    @State private var pinMismatch = false

    private static let avatars = ["🦊", "🐸", "🦄", "🐯", "🐙", "🦖", "🧚", "🦸", "🐨", "🐼", "🚀", "🌈"]

    var body: some View {
        VStack {
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .padding(.horizontal)
                .padding(.top)

            switch step {
            case .welcome: welcome
            case .name: nameStep
            case .unit: unitStep
            case .pet: petStep
            case .pin: pinStep
            }

            Spacer()
        }
        .animation(.default, value: step)
    }

    private func nextButton(_ title: String = "Next", disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(BigButtonStyle())
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
            .padding(.horizontal, 32)
            .padding(.top, 20)
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Text("🌟")
                .font(.system(size: 90))
                .padding(.top, 40)
            Text("Welcome to Sprout Rewards!")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Do your responsibilities, unlock quests, earn rewards — and look after your very own pet!")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            nextButton("Let's go!") { step = .name }
        }
    }

    private var nameStep: some View {
        VStack(spacing: 20) {
            Text("What's your name?")
                .font(.title.bold())
                .padding(.top, 40)
            TextField("Your name", text: $name)
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
            Text("Pick your look!")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 12) {
                ForEach(Self.avatars, id: \.self) { emoji in
                    Button {
                        avatar = emoji
                    } label: {
                        Text(emoji)
                            .font(.system(size: 40))
                            .padding(8)
                            .background(
                                avatar == emoji ? Color.accentColor.opacity(0.25) : Color(.systemGray6),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            nextButton(disabled: name.trimmingCharacters(in: .whitespaces).isEmpty) { step = .unit }
        }
    }

    private var unitStep: some View {
        VStack(spacing: 20) {
            Text("Choose your treasure!")
                .font(.title.bold())
                .padding(.top, 40)
            Text("This is what you'll earn for finishing quests.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 14) {
                ForEach(RewardUnit.allCases, id: \.self) { candidate in
                    Button {
                        unit = candidate
                    } label: {
                        VStack(spacing: 6) {
                            Text(candidate.emoji).font(.system(size: 44))
                            Text(candidate.pluralName).font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            unit == candidate ? Color.accentColor.opacity(0.25) : Color(.systemGray6),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            nextButton { step = .pet }
        }
    }

    private var petStep: some View {
        VStack(spacing: 20) {
            Text("Adopt a pet pal!")
                .font(.title.bold())
                .padding(.top, 40)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 14) {
                ForEach(PetSpecies.allCases, id: \.self) { species in
                    Button {
                        petSpecies = species
                    } label: {
                        VStack(spacing: 6) {
                            Text(species.emoji).font(.system(size: 44))
                            Text(species.displayName).font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            petSpecies == species ? Color.accentColor.opacity(0.25) : Color(.systemGray6),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            TextField("Give your pet a name", text: $petName)
                .font(.title3)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
            nextButton(disabled: petName.trimmingCharacters(in: .whitespaces).isEmpty) { step = .pin }
        }
    }

    private var pinStep: some View {
        VStack(spacing: 12) {
            Text("👋 Grown-ups!")
                .font(.title.bold())
                .padding(.top, 24)
            Text(firstPIN == nil
                 ? "Set a 4-digit PIN for the parent zone. You'll use it to add chores, approve rewards, and make changes."
                 : "Type the same PIN again to confirm.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if pinMismatch {
                Text("Those didn't match — try again.")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            }
            PINPadView(
                title: firstPIN == nil ? "Create PIN" : "Confirm PIN",
                subtitle: nil
            ) { pin in
                if let firstPIN {
                    if pin == firstPIN {
                        finish(pin: pin)
                        return true
                    } else {
                        self.firstPIN = nil
                        pinMismatch = true
                        return false
                    }
                } else {
                    firstPIN = pin
                    pinMismatch = false
                    return true
                }
            }
        }
    }

    private func finish(pin: String) {
        engine.completeOnboarding(
            name: name.trimmingCharacters(in: .whitespaces),
            avatarEmoji: avatar,
            rewardUnit: unit,
            petSpecies: petSpecies,
            petName: petName.trimmingCharacters(in: .whitespaces),
            pin: pin
        )
    }
}

#Preview {
    OnboardingView()
        .environment(RewardsEngine(store: InMemoryStore()))
}
