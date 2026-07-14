import Foundation

// MARK: - Child profile

public struct ChildProfile: Codable, Equatable, Sendable {
    public var name: String
    public var avatarEmoji: String
    public var rewardUnit: RewardUnit

    public init(name: String, avatarEmoji: String, rewardUnit: RewardUnit) {
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.rewardUnit = rewardUnit
    }
}

// MARK: - Responsibilities

/// A daily expectation (brush teeth, make bed). Responsibilities earn no units;
/// completing all of today's responsibilities unlocks the day's tasks.
public struct Responsibility: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var icon: String
    /// Weekdays this responsibility applies to, using `Calendar` numbering
    /// (1 = Sunday … 7 = Saturday). Empty means never scheduled.
    public var weekdays: Set<Int>
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        weekdays: Set<Int> = Set(1...7),
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.weekdays = weekdays
        self.isActive = isActive
    }
}

// MARK: - Tasks

/// A parent-configured chore that earns units once the day's responsibilities are done.
public struct ChoreTask: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var icon: String
    public var value: Int
    /// If true the task can be completed multiple times per day; otherwise once per day.
    public var isRepeatable: Bool
    /// If true, completing the task creates a pending approval and units are
    /// only credited when a parent approves it.
    public var requiresApproval: Bool
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        value: Int,
        isRepeatable: Bool = false,
        requiresApproval: Bool = false,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.value = value
        self.isRepeatable = isRepeatable
        self.requiresApproval = requiresApproval
        self.isActive = isActive
    }
}

/// A task completion awaiting parent approval. Snapshot fields survive later
/// edits or deletion of the underlying task.
public struct TaskCompletion: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var title: String
    public var icon: String
    public var value: Int
    public var dayKey: String
    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        title: String,
        icon: String,
        value: Int,
        dayKey: String,
        completedAt: Date
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.icon = icon
        self.value = value
        self.dayKey = dayKey
        self.completedAt = completedAt
    }
}

// MARK: - Real-life rewards

public struct RealReward: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var icon: String
    public var cost: Int
    public var isActive: Bool

    public init(id: UUID = UUID(), title: String, icon: String, cost: Int, isActive: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.cost = cost
        self.isActive = isActive
    }
}

public enum RedemptionStatus: String, Codable, Sendable, Equatable {
    case pending
    case approved
    case declined
}

/// A child's request to cash units in for a real-life reward. Units are debited
/// when the request is made; declining refunds them.
public struct RedemptionRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var rewardID: UUID
    public var title: String
    public var icon: String
    public var cost: Int
    public var status: RedemptionStatus
    public var requestedAt: Date
    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        rewardID: UUID,
        title: String,
        icon: String,
        cost: Int,
        status: RedemptionStatus = .pending,
        requestedAt: Date,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.rewardID = rewardID
        self.title = title
        self.icon = icon
        self.cost = cost
        self.status = status
        self.requestedAt = requestedAt
        self.resolvedAt = resolvedAt
    }
}

// MARK: - Ledger

public enum LedgerKind: String, Codable, Sendable, Equatable {
    case taskReward
    case redemption
    case refund
    case parentAdjustment
    case petPurchase
    case stickerPurchase
}

/// Append-only record of every earn and spend. The balance is derived by
/// summing amounts (earns positive, spends negative).
public struct LedgerEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var amount: Int
    public var kind: LedgerKind
    public var title: String

    public init(id: UUID = UUID(), date: Date, amount: Int, kind: LedgerKind, title: String) {
        self.id = id
        self.date = date
        self.amount = amount
        self.kind = kind
        self.title = title
    }
}

// MARK: - Day log

/// Per-day record of what was completed. Keyed by day key ("yyyy-MM-dd").
public struct DayLog: Codable, Equatable, Sendable {
    public var completedResponsibilityIDs: Set<UUID>
    public var taskCompletionCounts: [UUID: Int]

    public init(
        completedResponsibilityIDs: Set<UUID> = [],
        taskCompletionCounts: [UUID: Int] = [:]
    ) {
        self.completedResponsibilityIDs = completedResponsibilityIDs
        self.taskCompletionCounts = taskCompletionCounts
    }
}

// MARK: - Streak

public struct StreakState: Codable, Equatable, Sendable {
    public var count: Int
    /// Day key of the most recent day on which all responsibilities were completed.
    public var lastCompletedDayKey: String?

    public init(count: Int = 0, lastCompletedDayKey: String? = nil) {
        self.count = count
        self.lastCompletedDayKey = lastCompletedDayKey
    }
}

// MARK: - Parent settings

public struct ParentSettings: Codable, Equatable, Sendable {
    public var pinHash: PINHash?

    public init(pinHash: PINHash? = nil) {
        self.pinHash = pinHash
    }
}
