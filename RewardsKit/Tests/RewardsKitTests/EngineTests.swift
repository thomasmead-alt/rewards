import Foundation
import XCTest
@testable import RewardsKit

// MARK: - Unlock gate

final class UnlockGateTests: XCTestCase {
    func testTasksLockedUntilAllResponsibilitiesDone() throws {
        let teeth = Responsibility(title: "Brush teeth", icon: "🪥")
        let bed = Responsibility(title: "Make bed", icon: "🛏️")
        let chore = ChoreTask(title: "Set the table", icon: "🍽️", value: 5)
        let (engine, _, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [teeth, bed], tasks: [chore])
        )

        XCTAssertFalse(engine.tasksUnlocked)
        XCTAssertThrowsError(try engine.completeTask(chore.id)) { error in
            XCTAssertEqual(error as? EngineError, .tasksLocked)
        }

        engine.setResponsibility(teeth.id, completed: true)
        XCTAssertFalse(engine.tasksUnlocked, "one of two responsibilities should not unlock")

        engine.setResponsibility(bed.id, completed: true)
        XCTAssertTrue(engine.tasksUnlocked)
        XCTAssertNoThrow(try engine.completeTask(chore.id))
        XCTAssertEqual(engine.balance, 5)
    }

    func testUntogglingResponsibilityRelocksTasks() {
        let teeth = Responsibility(title: "Brush teeth", icon: "🪥")
        let (engine, _, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [teeth])
        )

        engine.setResponsibility(teeth.id, completed: true)
        XCTAssertTrue(engine.tasksUnlocked)
        engine.setResponsibility(teeth.id, completed: false)
        XCTAssertFalse(engine.tasksUnlocked)
    }

    func testNoResponsibilitiesScheduledTodayUnlocksTasks() {
        // Sunday-only responsibility; test clock is a Monday.
        let sundayOnly = Responsibility(title: "Water plants", icon: "🪴", weekdays: [1])
        let (engine, _, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [sundayOnly])
        )

        XCTAssertTrue(engine.todaysResponsibilities.isEmpty)
        XCTAssertTrue(engine.tasksUnlocked)
    }

    func testInactiveResponsibilityIgnoredByGate() {
        let active = Responsibility(title: "Brush teeth", icon: "🪥")
        let inactive = Responsibility(title: "Old chore", icon: "🗑️", isActive: false)
        let (engine, _, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [active, inactive])
        )

        engine.setResponsibility(active.id, completed: true)
        XCTAssertTrue(engine.tasksUnlocked)
    }

    func testWeekdaySchedulingFiltersToday() {
        let monday = Responsibility(title: "Library book", icon: "📖", weekdays: [2])
        let sunday = Responsibility(title: "Sunday job", icon: "🧽", weekdays: [1])
        let (engine, _, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [monday, sunday])
        )

        XCTAssertEqual(engine.todaysResponsibilities.map(\.id), [monday.id])
    }
}

// MARK: - Task economy

final class TaskEconomyTests: XCTestCase {
    /// Engine with no responsibilities, so tasks start unlocked.
    private func unlockedEngine(tasks: [ChoreTask], ledger: [LedgerEntry] = []) -> RewardsEngine {
        TestSupport.makeEngine(
            state: TestSupport.onboardedState(tasks: tasks, ledger: ledger)
        ).engine
    }

    func testOncePerDayTaskCannotRepeat() throws {
        let chore = ChoreTask(title: "Water plants", icon: "🪴", value: 3)
        let engine = unlockedEngine(tasks: [chore])

        try engine.completeTask(chore.id)
        XCTAssertEqual(engine.balance, 3)
        XCTAssertThrowsError(try engine.completeTask(chore.id)) { error in
            XCTAssertEqual(error as? EngineError, .alreadyCompletedToday)
        }
        XCTAssertFalse(engine.canComplete(chore))
    }

    func testRepeatableTaskEarnsEachTime() throws {
        let chore = ChoreTask(title: "Help cook", icon: "🧑‍🍳", value: 4, isRepeatable: true)
        let engine = unlockedEngine(tasks: [chore])

        try engine.completeTask(chore.id)
        try engine.completeTask(chore.id)
        XCTAssertEqual(engine.balance, 8)
        XCTAssertEqual(engine.completionCount(forTask: chore.id), 2)
    }

    func testApprovalRequiredTaskCreditsOnlyOnApproval() throws {
        let chore = ChoreTask(title: "Vacuum", icon: "🧹", value: 8, requiresApproval: true)
        let engine = unlockedEngine(tasks: [chore])

        try engine.completeTask(chore.id)
        XCTAssertEqual(engine.balance, 0, "no credit before approval")
        XCTAssertEqual(engine.state.pendingCompletions.count, 1)
        XCTAssertTrue(engine.hasPendingApproval(forTask: chore.id))

        try engine.approveTaskCompletion(engine.state.pendingCompletions[0].id)
        XCTAssertEqual(engine.balance, 8)
        XCTAssertTrue(engine.state.pendingCompletions.isEmpty)
    }

    func testDeclinedCompletionGivesAttemptBack() throws {
        let chore = ChoreTask(title: "Vacuum", icon: "🧹", value: 8, requiresApproval: true)
        let engine = unlockedEngine(tasks: [chore])

        try engine.completeTask(chore.id)
        try engine.declineTaskCompletion(engine.state.pendingCompletions[0].id)

        XCTAssertEqual(engine.balance, 0)
        XCTAssertEqual(engine.completionCount(forTask: chore.id), 0)
        XCTAssertTrue(engine.canComplete(chore), "child can redo a declined task")
    }

    func testCompletingUnknownTaskThrows() {
        let engine = unlockedEngine(tasks: [])
        XCTAssertThrowsError(try engine.completeTask(UUID())) { error in
            XCTAssertEqual(error as? EngineError, .notFound)
        }
    }

    func testParentAdjustmentClampsAtZero() {
        let engine = unlockedEngine(tasks: [], ledger: TestSupport.grant(5))
        engine.adjustBalance(by: -20, note: "Correction")
        XCTAssertEqual(engine.balance, 0)
    }
}

// MARK: - Redemptions

final class RedemptionTests: XCTestCase {
    private func engineWithReward(balance: Int, cost: Int) -> (RewardsEngine, RealReward) {
        let reward = RealReward(title: "Screen time", icon: "📺", cost: cost)
        let engine = TestSupport.makeEngine(
            state: TestSupport.onboardedState(rewards: [reward], ledger: TestSupport.grant(balance))
        ).engine
        return (engine, reward)
    }

    func testRedemptionDebitsImmediatelyAndAwaitsApproval() throws {
        let (engine, reward) = engineWithReward(balance: 20, cost: 15)

        try engine.requestRedemption(reward.id)
        XCTAssertEqual(engine.balance, 5, "debit happens at request time")
        XCTAssertEqual(engine.pendingRedemptions.count, 1)

        try engine.approveRedemption(engine.pendingRedemptions[0].id)
        XCTAssertEqual(engine.balance, 5, "approval keeps the debit")
        XCTAssertTrue(engine.pendingRedemptions.isEmpty)
        XCTAssertEqual(engine.state.redemptions[0].status, .approved)
    }

    func testDeclinedRedemptionRefunds() throws {
        let (engine, reward) = engineWithReward(balance: 20, cost: 15)

        try engine.requestRedemption(reward.id)
        try engine.declineRedemption(engine.pendingRedemptions[0].id)

        XCTAssertEqual(engine.balance, 20)
        XCTAssertEqual(engine.state.redemptions[0].status, .declined)
    }

    func testInsufficientBalanceRejected() {
        let (engine, reward) = engineWithReward(balance: 10, cost: 15)

        XCTAssertThrowsError(try engine.requestRedemption(reward.id)) { error in
            XCTAssertEqual(error as? EngineError, .insufficientBalance)
        }
        XCTAssertEqual(engine.balance, 10)
        XCTAssertTrue(engine.state.redemptions.isEmpty)
    }
}

// MARK: - Day rollover & streaks

final class RolloverStreakTests: XCTestCase {
    private func dailyEngine() -> (RewardsEngine, TestClock, Responsibility) {
        let teeth = Responsibility(title: "Brush teeth", icon: "🪥")
        let (engine, clock, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [teeth])
        )
        return (engine, clock, teeth)
    }

    func testCompletingAllResponsibilitiesStartsStreak() {
        let (engine, _, teeth) = dailyEngine()
        engine.setResponsibility(teeth.id, completed: true)
        XCTAssertEqual(engine.state.streak.count, 1)
    }

    func testConsecutiveDaysGrowStreak() {
        let (engine, clock, teeth) = dailyEngine()

        engine.setResponsibility(teeth.id, completed: true)
        clock.advance(days: 1)
        engine.refreshDay()
        engine.setResponsibility(teeth.id, completed: true)

        XCTAssertEqual(engine.state.streak.count, 2)
    }

    func testMissedDayResetsStreak() {
        let (engine, clock, teeth) = dailyEngine()

        engine.setResponsibility(teeth.id, completed: true)
        clock.advance(days: 2)
        engine.refreshDay()

        XCTAssertEqual(engine.state.streak.count, 0, "missing a day breaks the streak")
        engine.setResponsibility(teeth.id, completed: true)
        XCTAssertEqual(engine.state.streak.count, 1)
    }

    func testNewDayRelocksTasksAndClearsCompletions() throws {
        let teeth = Responsibility(title: "Brush teeth", icon: "🪥")
        let chore = ChoreTask(title: "Set table", icon: "🍽️", value: 5)
        let (engine, clock, _) = TestSupport.makeEngine(
            state: TestSupport.onboardedState(responsibilities: [teeth], tasks: [chore])
        )

        engine.setResponsibility(teeth.id, completed: true)
        try engine.completeTask(chore.id)

        clock.advance(days: 1)
        engine.refreshDay()

        XCTAssertFalse(engine.tasksUnlocked, "new day relocks tasks")
        XCTAssertEqual(engine.completionCount(forTask: chore.id), 0)
        XCTAssertEqual(engine.balance, 5, "earned units are kept")
    }

    func testPetGetsSleepierAcrossDays() {
        let (engine, clock, _) = dailyEngine()
        XCTAssertEqual(engine.state.pet?.happiness, 80)

        clock.advance(days: 1)
        engine.refreshDay()
        XCTAssertEqual(engine.state.pet?.happiness, 70)
    }

    func testPetHappinessNeverDropsBelowFloor() {
        let (engine, clock, _) = dailyEngine()
        for _ in 0..<20 {
            clock.advance(days: 1)
            engine.refreshDay()
        }
        XCTAssertEqual(engine.state.pet?.happiness, 20, "pet never becomes miserable")
    }

    func testOldDayLogsArePruned() {
        let (engine, clock, teeth) = dailyEngine()
        engine.setResponsibility(teeth.id, completed: true)
        let oldKey = engine.todayKey

        clock.advance(days: 61)
        engine.refreshDay()

        XCTAssertNil(engine.state.dayLogs[oldKey])
    }

    func testRolloverIsIdempotentWithinSameDay() {
        let (engine, _, teeth) = dailyEngine()
        engine.setResponsibility(teeth.id, completed: true)
        let before = engine.state

        engine.refreshDay()
        XCTAssertEqual(engine.state, before)
    }
}
