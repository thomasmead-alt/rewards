import SwiftUI
import RewardsKit

struct TodayView: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var confetti = 0
    @State private var showParentGate = false

    private var responsibilityProgress: Double {
        let todays = engine.todaysResponsibilities
        guard !todays.isEmpty else { return 1 }
        let done = todays.filter { engine.isResponsibilityCompletedToday($0.id) }.count
        return Double(done) / Double(todays.count)
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                responsibilitiesSection
                tasksSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    StreakBadge(count: engine.state.streak.count)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    BalanceBadge()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showParentGate = true
                    } label: {
                        Image(systemName: "person.circle")
                            .accessibilityLabel("Parent zone")
                    }
                }
            }
            .overlay { ConfettiView(trigger: confetti) }
            .sheet(isPresented: $showParentGate) {
                ParentGateView()
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                Text(engine.state.profile?.avatarEmoji ?? "🙂")
                    .font(.system(size: 52))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, \(engine.state.profile?.name ?? "friend")!")
                        .font(.title2.bold())
                    Text(engine.tasksUnlocked
                         ? "Quests are unlocked — go earn!"
                         : "Finish your responsibilities to unlock quests.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ProgressRing(progress: responsibilityProgress)
                    .frame(width: 64, height: 64)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Responsibilities

    private var responsibilitiesSection: some View {
        Section("My responsibilities") {
            let todays = engine.todaysResponsibilities
            if todays.isEmpty {
                Label("Nothing scheduled today — quests are open!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
            ForEach(todays) { responsibility in
                ResponsibilityRow(responsibility: responsibility) {
                    let wasUnlocked = engine.tasksUnlocked
                    let done = engine.isResponsibilityCompletedToday(responsibility.id)
                    engine.setResponsibility(responsibility.id, completed: !done)
                    if !wasUnlocked && engine.tasksUnlocked {
                        confetti += 1
                    }
                }
            }
        }
    }

    // MARK: Tasks

    private var tasksSection: some View {
        Section {
            if engine.tasksUnlocked {
                ForEach(engine.activeTasks) { task in
                    TaskRow(task: task) {
                        do {
                            try engine.completeTask(task.id)
                            confetti += 1
                        } catch {
                            // Row is disabled when not completable; nothing to do.
                        }
                    }
                }
                if engine.activeTasks.isEmpty {
                    Text("No quests yet — ask a grown-up to add some!")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quests are locked")
                            .font(.headline)
                        Text("Check off all your responsibilities first — you're nearly there!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            HStack {
                Text("Quests")
                if !engine.tasksUnlocked {
                    Image(systemName: "lock.fill")
                }
            }
        }
    }
}

// MARK: - Rows

private struct ResponsibilityRow: View {
    @Environment(RewardsEngine.self) private var engine
    let responsibility: Responsibility
    let toggle: () -> Void

    var body: some View {
        let done = engine.isResponsibilityCompletedToday(responsibility.id)
        Button(action: toggle) {
            HStack(spacing: 14) {
                Text(responsibility.icon)
                    .font(.system(size: 34))
                Text(responsibility.title)
                    .font(.body.weight(.medium))
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
                Spacer()
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(done ? .green : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: done)
    }
}

private struct TaskRow: View {
    @Environment(RewardsEngine.self) private var engine
    let task: ChoreTask
    let complete: () -> Void

    var body: some View {
        let unit = engine.state.profile?.rewardUnit ?? .star
        let count = engine.completionCount(forTask: task.id)
        let pending = engine.hasPendingApproval(forTask: task.id)
        let doneForToday = !task.isRepeatable && count > 0

        HStack(spacing: 14) {
            Text(task.icon)
                .font(.system(size: 34))
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(unit.label(for: task.value))
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    if pending {
                        Text("waiting for a grown-up 👀")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if task.isRepeatable && count > 0 {
                        Text("done ×\(count) today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if doneForToday {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            } else {
                Button("Done!", action: complete)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!engine.canComplete(task))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TodayView()
        .environment(RewardsEngine(store: InMemoryStore()))
}
