import Foundation
import Observation

public enum EngineError: Error, Equatable {
    case tasksLocked
    case alreadyCompletedToday
    case insufficientBalance
    case notFound
    case alreadyOwned
    case noPet
    case itemNotOwned
}

/// The single source of truth the app talks to. Owns the state, enforces the
/// rules (unlock gating, economy, approvals, day rollover, streaks) and
/// persists after every mutation.
@Observable
public final class RewardsEngine {
    public private(set) var state: AppState

    @ObservationIgnored private let store: PersistenceStore
    @ObservationIgnored public let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    public init(
        store: PersistenceStore,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.state = (try? store.load())?.flatMap { $0 } ?? AppState()
        rolloverIfNeeded()
    }

    private func persist() {
        try? store.save(state)
    }

    // MARK: - Day handling

    public var todayKey: String {
        DayKey.key(for: now(), calendar: calendar)
    }

    private var yesterdayKey: String {
        DayKey.yesterdayKey(for: now(), calendar: calendar)
    }

    public var todayLog: DayLog {
        state.dayLogs[todayKey] ?? DayLog()
    }

    /// Call when the app comes to the foreground; processes a day change if
    /// midnight passed since the last time the app was used.
    public func refreshDay() {
        rolloverIfNeeded()
    }

    private func rolloverIfNeeded() {
        let key = todayKey
        guard state.lastOpenedDayKey != key else { return }

        // A missed day breaks the streak.
        if let lastDone = state.streak.lastCompletedDayKey,
           lastDone != key, lastDone != yesterdayKey {
            state.streak.count = 0
        }

        // The pet gets gently sleepier between days, never miserable.
        if var pet = state.pet, state.lastOpenedDayKey != nil {
            pet.happiness = max(20, pet.happiness - 10)
            state.pet = pet
        }

        // Keep roughly two months of day logs.
        if let cutoffDate = calendar.date(byAdding: .day, value: -60, to: now()) {
            let cutoff = DayKey.key(for: cutoffDate, calendar: calendar)
            state.dayLogs = state.dayLogs.filter { $0.key >= cutoff }
        }

        state.lastOpenedDayKey = key
        persist()
    }

    // MARK: - Balance

    public var balance: Int { state.balance }

    private func credit(_ amount: Int, kind: LedgerKind, title: String) {
        state.ledger.append(
            LedgerEntry(date: now(), amount: amount, kind: kind, title: title)
        )
    }

    // MARK: - Responsibilities

    /// Responsibilities scheduled for today's weekday.
    public var todaysResponsibilities: [Responsibility] {
        let weekday = calendar.component(.weekday, from: now())
        return state.responsibilities.filter { $0.isActive && $0.weekdays.contains(weekday) }
    }

    public func isResponsibilityCompletedToday(_ id: UUID) -> Bool {
        todayLog.completedResponsibilityIDs.contains(id)
    }

    /// True when every responsibility scheduled for today is checked off
    /// (vacuously true when none are scheduled). This is the unlock gate.
    public var allResponsibilitiesDoneToday: Bool {
        todaysResponsibilities.allSatisfy { todayLog.completedResponsibilityIDs.contains($0.id) }
    }

    public var tasksUnlocked: Bool { allResponsibilitiesDoneToday }

    public func setResponsibility(_ id: UUID, completed: Bool) {
        var log = todayLog
        if completed {
            log.completedResponsibilityIDs.insert(id)
        } else {
            log.completedResponsibilityIDs.remove(id)
        }
        state.dayLogs[todayKey] = log
        if completed && allResponsibilitiesDoneToday && !todaysResponsibilities.isEmpty {
            registerStreakDay()
        }
        persist()
    }

    private func registerStreakDay() {
        guard state.streak.lastCompletedDayKey != todayKey else { return }
        if state.streak.lastCompletedDayKey == yesterdayKey {
            state.streak.count += 1
        } else {
            state.streak.count = 1
        }
        state.streak.lastCompletedDayKey = todayKey
    }

    // MARK: - Tasks

    public var activeTasks: [ChoreTask] {
        state.tasks.filter(\.isActive)
    }

    public func completionCount(forTask id: UUID) -> Int {
        todayLog.taskCompletionCounts[id] ?? 0
    }

    public func canComplete(_ task: ChoreTask) -> Bool {
        tasksUnlocked && (task.isRepeatable || completionCount(forTask: task.id) == 0)
    }

    /// True when the task has a completion waiting for parent approval today.
    public func hasPendingApproval(forTask id: UUID) -> Bool {
        state.pendingCompletions.contains { $0.taskID == id && $0.dayKey == todayKey }
    }

    public func completeTask(_ id: UUID) throws {
        guard let task = state.tasks.first(where: { $0.id == id && $0.isActive }) else {
            throw EngineError.notFound
        }
        guard tasksUnlocked else { throw EngineError.tasksLocked }
        guard task.isRepeatable || completionCount(forTask: id) == 0 else {
            throw EngineError.alreadyCompletedToday
        }

        var log = todayLog
        log.taskCompletionCounts[id, default: 0] += 1
        state.dayLogs[todayKey] = log

        if task.requiresApproval {
            state.pendingCompletions.append(
                TaskCompletion(
                    taskID: task.id,
                    title: task.title,
                    icon: task.icon,
                    value: task.value,
                    dayKey: todayKey,
                    completedAt: now()
                )
            )
        } else {
            credit(task.value, kind: .taskReward, title: task.title)
        }
        persist()
    }

    // MARK: - Parent: approvals

    public func approveTaskCompletion(_ id: UUID) throws {
        guard let index = state.pendingCompletions.firstIndex(where: { $0.id == id }) else {
            throw EngineError.notFound
        }
        let completion = state.pendingCompletions.remove(at: index)
        credit(completion.value, kind: .taskReward, title: completion.title)
        persist()
    }

    /// Declining removes the pending completion and gives the day's attempt
    /// back, so the child can redo the task properly.
    public func declineTaskCompletion(_ id: UUID) throws {
        guard let index = state.pendingCompletions.firstIndex(where: { $0.id == id }) else {
            throw EngineError.notFound
        }
        let completion = state.pendingCompletions.remove(at: index)
        if var log = state.dayLogs[completion.dayKey],
           let count = log.taskCompletionCounts[completion.taskID] {
            log.taskCompletionCounts[completion.taskID] = count > 1 ? count - 1 : nil
            state.dayLogs[completion.dayKey] = log
        }
        persist()
    }

    // MARK: - Real-life rewards

    public var activeRewards: [RealReward] {
        state.rewards.filter(\.isActive)
    }

    public var pendingRedemptions: [RedemptionRequest] {
        state.redemptions.filter { $0.status == .pending }
    }

    /// Units are debited immediately so the child can't overspend while a
    /// request waits; a declined request refunds them.
    public func requestRedemption(_ rewardID: UUID) throws {
        guard let reward = state.rewards.first(where: { $0.id == rewardID && $0.isActive }) else {
            throw EngineError.notFound
        }
        guard reward.cost <= balance else { throw EngineError.insufficientBalance }
        state.redemptions.append(
            RedemptionRequest(
                rewardID: reward.id,
                title: reward.title,
                icon: reward.icon,
                cost: reward.cost,
                requestedAt: now()
            )
        )
        credit(-reward.cost, kind: .redemption, title: reward.title)
        persist()
    }

    public func approveRedemption(_ id: UUID) throws {
        guard let index = state.redemptions.firstIndex(where: { $0.id == id && $0.status == .pending }) else {
            throw EngineError.notFound
        }
        state.redemptions[index].status = .approved
        state.redemptions[index].resolvedAt = now()
        persist()
    }

    public func declineRedemption(_ id: UUID) throws {
        guard let index = state.redemptions.firstIndex(where: { $0.id == id && $0.status == .pending }) else {
            throw EngineError.notFound
        }
        state.redemptions[index].status = .declined
        state.redemptions[index].resolvedAt = now()
        credit(state.redemptions[index].cost, kind: .refund, title: state.redemptions[index].title)
        persist()
    }

    // MARK: - Pet

    public func adoptPet(species: PetSpecies, name: String) {
        state.pet = Pet(species: species, name: name)
        persist()
    }

    public func buyPetItem(_ itemID: String) throws {
        guard let item = PetCatalog.item(id: itemID) else { throw EngineError.notFound }
        guard var pet = state.pet else { throw EngineError.noPet }
        if item.kind == .accessory {
            guard !pet.ownedAccessories.contains(item.id) else { throw EngineError.alreadyOwned }
        }
        guard item.cost <= balance else { throw EngineError.insufficientBalance }

        if item.kind == .accessory {
            pet.ownedAccessories.insert(item.id)
        } else {
            pet.inventory[item.id, default: 0] += 1
        }
        state.pet = pet
        credit(-item.cost, kind: .petPurchase, title: item.name)
        persist()
    }

    /// Feed or play: consumes one of the item and boosts the pet's happiness.
    public func usePetItem(_ itemID: String) throws {
        guard let item = PetCatalog.item(id: itemID), item.kind != .accessory else {
            throw EngineError.notFound
        }
        guard var pet = state.pet else { throw EngineError.noPet }
        guard let count = pet.inventory[itemID], count > 0 else { throw EngineError.itemNotOwned }
        pet.inventory[itemID] = count > 1 ? count - 1 : nil
        pet.happiness = min(100, pet.happiness + item.boost)
        state.pet = pet
        persist()
    }

    /// Pass nil to take the current accessory off.
    public func equipAccessory(_ itemID: String?) throws {
        guard var pet = state.pet else { throw EngineError.noPet }
        if let itemID {
            guard pet.ownedAccessories.contains(itemID) else { throw EngineError.itemNotOwned }
        }
        pet.equippedAccessory = itemID
        state.pet = pet
        persist()
    }

    // MARK: - Stickers

    public func ownsSticker(_ id: String) -> Bool {
        state.ownedStickers.contains(id)
    }

    public func buySticker(_ id: String) throws {
        guard let sticker = StickerCatalog.sticker(id: id) else { throw EngineError.notFound }
        guard !state.ownedStickers.contains(id) else { throw EngineError.alreadyOwned }
        guard sticker.cost <= balance else { throw EngineError.insufficientBalance }
        state.ownedStickers.insert(id)
        credit(-sticker.cost, kind: .stickerPurchase, title: "\(sticker.name) sticker")
        persist()
    }

    // MARK: - Parent: configuration

    public func upsertResponsibility(_ responsibility: Responsibility) {
        if let index = state.responsibilities.firstIndex(where: { $0.id == responsibility.id }) {
            state.responsibilities[index] = responsibility
        } else {
            state.responsibilities.append(responsibility)
        }
        persist()
    }

    public func deleteResponsibility(_ id: UUID) {
        state.responsibilities.removeAll { $0.id == id }
        persist()
    }

    public func upsertTask(_ task: ChoreTask) {
        if let index = state.tasks.firstIndex(where: { $0.id == task.id }) {
            state.tasks[index] = task
        } else {
            state.tasks.append(task)
        }
        persist()
    }

    public func deleteTask(_ id: UUID) {
        state.tasks.removeAll { $0.id == id }
        persist()
    }

    public func upsertReward(_ reward: RealReward) {
        if let index = state.rewards.firstIndex(where: { $0.id == reward.id }) {
            state.rewards[index] = reward
        } else {
            state.rewards.append(reward)
        }
        persist()
    }

    public func deleteReward(_ id: UUID) {
        state.rewards.removeAll { $0.id == id }
        persist()
    }

    /// Manual correction by the parent. Deductions are clamped so the balance
    /// never goes negative.
    public func adjustBalance(by amount: Int, note: String) {
        let clamped = max(amount, -balance)
        guard clamped != 0 else { return }
        credit(clamped, kind: .parentAdjustment, title: note)
        persist()
    }

    // MARK: - PIN

    public func setPIN(_ pin: String) {
        state.parent.pinHash = PINHash(pin: pin)
        persist()
    }

    public func verifyPIN(_ pin: String) -> Bool {
        state.parent.pinHash?.matches(pin) ?? true
    }

    // MARK: - Onboarding & lifecycle

    public var needsOnboarding: Bool {
        state.profile == nil
    }

    public func completeOnboarding(
        name: String,
        avatarEmoji: String,
        rewardUnit: RewardUnit,
        petSpecies: PetSpecies,
        petName: String,
        pin: String
    ) {
        state.profile = ChildProfile(name: name, avatarEmoji: avatarEmoji, rewardUnit: rewardUnit)
        state.pet = Pet(species: petSpecies, name: petName)
        state.parent.pinHash = PINHash(pin: pin)
        if state.responsibilities.isEmpty && state.tasks.isEmpty && state.rewards.isEmpty {
            let seed = AppState.seedContent()
            state.responsibilities = seed.responsibilities
            state.tasks = seed.tasks
            state.rewards = seed.rewards
        }
        state.lastOpenedDayKey = todayKey
        persist()
    }

    public func updateProfile(_ profile: ChildProfile) {
        state.profile = profile
        persist()
    }

    /// Wipes everything and returns to onboarding.
    public func resetAllData() {
        state = AppState()
        persist()
    }
}
