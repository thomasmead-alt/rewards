import Foundation
import XCTest
@testable import RewardsKit

/// Controllable clock so tests can cross midnights deterministically.
final class TestClock {
    var current: Date

    init(_ date: Date) {
        self.current = date
    }

    func advance(days: Int) {
        current = current.addingTimeInterval(Double(days) * 86_400)
    }
}

enum TestSupport {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Monday 2026-01-05, 10:00 UTC.
    static var monday: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = 10
        return utcCalendar.date(from: components)!
    }

    static func makeEngine(
        state: AppState = AppState(),
        clock: TestClock = TestClock(monday),
        store: InMemoryStore? = nil
    ) -> (engine: RewardsEngine, clock: TestClock, store: InMemoryStore) {
        let store = store ?? InMemoryStore(state: state)
        let engine = RewardsEngine(store: store, calendar: utcCalendar, now: { clock.current })
        return (engine, clock, store)
    }

    /// A state with a profile so tests skip onboarding.
    static func onboardedState(
        responsibilities: [Responsibility] = [],
        tasks: [ChoreTask] = [],
        rewards: [RealReward] = [],
        ledger: [LedgerEntry] = [],
        pet: Pet? = Pet(species: .bunny, name: "Flopsy")
    ) -> AppState {
        AppState(
            profile: ChildProfile(name: "Robin", avatarEmoji: "🦊", rewardUnit: .star),
            responsibilities: responsibilities,
            tasks: tasks,
            rewards: rewards,
            ledger: ledger,
            pet: pet
        )
    }

    static func grant(_ amount: Int) -> [LedgerEntry] {
        [LedgerEntry(date: monday, amount: amount, kind: .parentAdjustment, title: "Starting balance")]
    }
}
