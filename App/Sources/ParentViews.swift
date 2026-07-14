import SwiftUI
import RewardsKit

// MARK: - PIN gate

struct ParentGateView: View {
    @Environment(RewardsEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false

    var body: some View {
        NavigationStack {
            if unlocked {
                ParentView()
            } else {
                PINPadView(
                    title: "Parent Zone",
                    subtitle: "Enter your PIN to continue."
                ) { pin in
                    if engine.verifyPIN(pin) {
                        unlocked = true
                        return true
                    }
                    return false
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Parent home

struct ParentView: View {
    @Environment(RewardsEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    private var pendingCount: Int {
        engine.state.pendingCompletions.count + engine.pendingRedemptions.count
    }

    var body: some View {
        List {
            Section("Needs your OK") {
                NavigationLink {
                    ApprovalsView()
                } label: {
                    Label("Approvals", systemImage: "checkmark.seal")
                        .badge(pendingCount)
                }
            }
            Section("Set up") {
                NavigationLink {
                    ResponsibilitiesEditor()
                } label: {
                    Label("Responsibilities", systemImage: "list.bullet.clipboard")
                }
                NavigationLink {
                    TasksEditor()
                } label: {
                    Label("Quests (tasks)", systemImage: "star")
                }
                NavigationLink {
                    RewardsEditor()
                } label: {
                    Label("Real-life rewards", systemImage: "gift")
                }
            }
            Section("Household") {
                NavigationLink {
                    HistoryView()
                } label: {
                    Label("History", systemImage: "clock")
                }
                NavigationLink {
                    ParentSettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Parent Zone")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Approvals

struct ApprovalsView: View {
    @Environment(RewardsEngine.self) private var engine

    var body: some View {
        List {
            Section("Finished quests") {
                if engine.state.pendingCompletions.isEmpty {
                    Text("Nothing waiting.").foregroundStyle(.secondary)
                }
                ForEach(engine.state.pendingCompletions) { completion in
                    HStack {
                        Text(completion.icon).font(.title2)
                        VStack(alignment: .leading) {
                            Text(completion.title)
                            Text("Worth \(completion.value)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("No") { try? engine.declineTaskCompletion(completion.id) }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        Button("Yes") { try? engine.approveTaskCompletion(completion.id) }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Section("Reward requests") {
                if engine.pendingRedemptions.isEmpty {
                    Text("Nothing waiting.").foregroundStyle(.secondary)
                }
                ForEach(engine.pendingRedemptions) { redemption in
                    HStack {
                        Text(redemption.icon).font(.title2)
                        VStack(alignment: .leading) {
                            Text(redemption.title)
                            Text("Costs \(redemption.cost) — already paid, declining refunds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("No") { try? engine.declineRedemption(redemption.id) }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        Button("Yes") { try? engine.approveRedemption(redemption.id) }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .navigationTitle("Approvals")
    }
}

// MARK: - Responsibilities editor

struct ResponsibilitiesEditor: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var editing: Responsibility?
    @State private var creating = false

    var body: some View {
        List {
            ForEach(engine.state.responsibilities) { responsibility in
                Button {
                    editing = responsibility
                } label: {
                    HStack {
                        Text(responsibility.icon).font(.title2)
                        VStack(alignment: .leading) {
                            Text(responsibility.title).foregroundStyle(.primary)
                            Text(weekdaysLabel(responsibility.weekdays))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !responsibility.isActive {
                            Text("Off").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    engine.deleteResponsibility(engine.state.responsibilities[index].id)
                }
            }
        }
        .navigationTitle("Responsibilities")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { responsibility in
            ResponsibilityForm(responsibility: responsibility)
        }
        .sheet(isPresented: $creating) {
            ResponsibilityForm(responsibility: Responsibility(title: "", icon: "🧽"))
        }
    }

    private func weekdaysLabel(_ weekdays: Set<Int>) -> String {
        if weekdays == Set(1...7) { return "Every day" }
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
    }
}

struct ResponsibilityForm: View {
    @Environment(RewardsEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State var responsibility: Responsibility

    private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        NavigationStack {
            Form {
                Section("What is it?") {
                    TextField("Title (e.g. Brush your teeth)", text: $responsibility.title)
                    TextField("Icon (an emoji)", text: $responsibility.icon)
                }
                Section("Which days?") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(weekdayNames[day - 1], isOn: Binding(
                            get: { responsibility.weekdays.contains(day) },
                            set: { on in
                                if on { responsibility.weekdays.insert(day) }
                                else { responsibility.weekdays.remove(day) }
                            }
                        ))
                    }
                }
                Section {
                    Toggle("Active", isOn: $responsibility.isActive)
                }
            }
            .navigationTitle("Responsibility")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        engine.upsertResponsibility(responsibility)
                        dismiss()
                    }
                    .disabled(responsibility.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Tasks editor

struct TasksEditor: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var editing: ChoreTask?
    @State private var creating = false

    var body: some View {
        List {
            ForEach(engine.state.tasks) { task in
                Button {
                    editing = task
                } label: {
                    HStack {
                        Text(task.icon).font(.title2)
                        VStack(alignment: .leading) {
                            Text(task.title).foregroundStyle(.primary)
                            Text(details(task))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(task.value)")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    engine.deleteTask(engine.state.tasks[index].id)
                }
            }
        }
        .navigationTitle("Quests")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { task in
            TaskForm(task: task)
        }
        .sheet(isPresented: $creating) {
            TaskForm(task: ChoreTask(title: "", icon: "🧹", value: 5))
        }
    }

    private func details(_ task: ChoreTask) -> String {
        var parts: [String] = [task.isRepeatable ? "Repeatable" : "Once a day"]
        if task.requiresApproval { parts.append("needs approval") }
        if !task.isActive { parts.append("off") }
        return parts.joined(separator: " · ")
    }
}

struct TaskForm: View {
    @Environment(RewardsEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State var task: ChoreTask

    var body: some View {
        NavigationStack {
            Form {
                Section("What is it?") {
                    TextField("Title (e.g. Water the plants)", text: $task.title)
                    TextField("Icon (an emoji)", text: $task.icon)
                }
                Section("Reward") {
                    Stepper("Worth \(task.value)", value: $task.value, in: 1...100)
                }
                Section("Rules") {
                    Toggle("Can be done many times a day", isOn: $task.isRepeatable)
                    Toggle("Needs a parent to approve", isOn: $task.requiresApproval)
                    Toggle("Active", isOn: $task.isActive)
                }
            }
            .navigationTitle("Quest")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        engine.upsertTask(task)
                        dismiss()
                    }
                    .disabled(task.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Rewards editor

struct RewardsEditor: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var editing: RealReward?
    @State private var creating = false

    var body: some View {
        List {
            ForEach(engine.state.rewards) { reward in
                Button {
                    editing = reward
                } label: {
                    HStack {
                        Text(reward.icon).font(.title2)
                        Text(reward.title).foregroundStyle(.primary)
                        Spacer()
                        if !reward.isActive {
                            Text("Off").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(reward.cost)")
                            .font(.headline)
                            .foregroundStyle(.purple)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    engine.deleteReward(engine.state.rewards[index].id)
                }
            }
        }
        .navigationTitle("Real-life rewards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { reward in
            RewardForm(reward: reward)
        }
        .sheet(isPresented: $creating) {
            RewardForm(reward: RealReward(title: "", icon: "🎁", cost: 20))
        }
    }
}

struct RewardForm: View {
    @Environment(RewardsEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    @State var reward: RealReward

    var body: some View {
        NavigationStack {
            Form {
                Section("What is it?") {
                    TextField("Title (e.g. Trip to the park)", text: $reward.title)
                    TextField("Icon (an emoji)", text: $reward.icon)
                }
                Section("Cost") {
                    Stepper("Costs \(reward.cost)", value: $reward.cost, in: 1...500, step: 5)
                }
                Section {
                    Toggle("Active", isOn: $reward.isActive)
                }
            }
            .navigationTitle("Reward")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        engine.upsertReward(reward)
                        dismiss()
                    }
                    .disabled(reward.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(RewardsEngine.self) private var engine

    var body: some View {
        List {
            ForEach(engine.state.ledger.reversed()) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.title)
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(entry.amount > 0 ? "+\(entry.amount)" : "\(entry.amount)")
                        .font(.headline)
                        .foregroundStyle(entry.amount > 0 ? .green : .red)
                }
            }
            if engine.state.ledger.isEmpty {
                Text("No activity yet.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("History")
    }
}

// MARK: - Settings

struct ParentSettingsView: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var adjustment = 0
    @State private var showPINChange = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Balance") {
                LabeledContent("Current balance", value: "\(engine.balance)")
                Stepper("Adjust by \(adjustment)", value: $adjustment, in: -200...200)
                Button("Apply adjustment") {
                    engine.adjustBalance(by: adjustment, note: "Parent adjustment")
                    adjustment = 0
                }
                .disabled(adjustment == 0)
            }
            Section("Security") {
                Button("Change PIN") { showPINChange = true }
            }
            Section("Danger zone") {
                Button("Reset all data", role: .destructive) { showResetConfirm = true }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPINChange) {
            NavigationStack {
                PINPadView(title: "New PIN", subtitle: "Enter a new 4-digit PIN.") { pin in
                    engine.setPIN(pin)
                    showPINChange = false
                    return true
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showPINChange = false }
                    }
                }
            }
        }
        .confirmationDialog(
            "Really delete everything? This removes the profile, history, pet and stickers.",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                engine.resetAllData()
            }
        }
    }
}
