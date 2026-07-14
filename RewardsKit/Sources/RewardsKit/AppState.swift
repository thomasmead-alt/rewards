import Foundation

/// The whole persisted world, saved as one JSON document.
public struct AppState: Codable, Equatable, Sendable {
    public var profile: ChildProfile?
    public var responsibilities: [Responsibility]
    public var tasks: [ChoreTask]
    public var rewards: [RealReward]
    public var dayLogs: [String: DayLog]
    public var ledger: [LedgerEntry]
    public var pendingCompletions: [TaskCompletion]
    public var redemptions: [RedemptionRequest]
    public var pet: Pet?
    public var ownedStickers: Set<String>
    public var streak: StreakState
    public var parent: ParentSettings
    /// Day key of the last day the app processed a rollover for.
    public var lastOpenedDayKey: String?

    public init(
        profile: ChildProfile? = nil,
        responsibilities: [Responsibility] = [],
        tasks: [ChoreTask] = [],
        rewards: [RealReward] = [],
        dayLogs: [String: DayLog] = [:],
        ledger: [LedgerEntry] = [],
        pendingCompletions: [TaskCompletion] = [],
        redemptions: [RedemptionRequest] = [],
        pet: Pet? = nil,
        ownedStickers: Set<String> = [],
        streak: StreakState = StreakState(),
        parent: ParentSettings = ParentSettings(),
        lastOpenedDayKey: String? = nil
    ) {
        self.profile = profile
        self.responsibilities = responsibilities
        self.tasks = tasks
        self.rewards = rewards
        self.dayLogs = dayLogs
        self.ledger = ledger
        self.pendingCompletions = pendingCompletions
        self.redemptions = redemptions
        self.pet = pet
        self.ownedStickers = ownedStickers
        self.streak = streak
        self.parent = parent
        self.lastOpenedDayKey = lastOpenedDayKey
    }

    /// The child's current balance, derived from the ledger.
    public var balance: Int {
        ledger.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Default seed content

extension AppState {
    /// Starter responsibilities, tasks, and rewards created at onboarding for
    /// the parent to edit rather than starting from a blank slate.
    public static func seedContent() -> (
        responsibilities: [Responsibility],
        tasks: [ChoreTask],
        rewards: [RealReward]
    ) {
        let responsibilities = [
            Responsibility(title: "Brush your teeth", icon: "🪥"),
            Responsibility(title: "Make your bed", icon: "🛏️"),
            Responsibility(title: "Tidy up your toys", icon: "🧸"),
            Responsibility(title: "Do your homework", icon: "📚", weekdays: [2, 3, 4, 5, 6]),
        ]
        let tasks = [
            ChoreTask(title: "Set the table", icon: "🍽️", value: 3),
            ChoreTask(title: "Water the plants", icon: "🪴", value: 3),
            ChoreTask(title: "Help with laundry", icon: "🧺", value: 5, requiresApproval: true),
            ChoreTask(title: "Vacuum your room", icon: "🧹", value: 8, requiresApproval: true),
            ChoreTask(title: "Help make dinner", icon: "🧑‍🍳", value: 5, isRepeatable: true, requiresApproval: true),
        ]
        let rewards = [
            RealReward(title: "30 minutes of screen time", icon: "📺", cost: 15),
            RealReward(title: "Pick tonight's dinner", icon: "🍕", cost: 20),
            RealReward(title: "Trip to the park", icon: "🛝", cost: 25),
            RealReward(title: "Family movie night", icon: "🍿", cost: 35),
            RealReward(title: "A small toy", icon: "🎁", cost: 50),
        ]
        return (responsibilities, tasks, rewards)
    }
}
