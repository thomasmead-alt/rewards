import Foundation
import XCTest
@testable import RewardsKit

// MARK: - Pet economy

final class PetTests: XCTestCase {
    private func richEngine(balance: Int = 100) -> RewardsEngine {
        TestSupport.makeEngine(
            state: TestSupport.onboardedState(ledger: TestSupport.grant(balance))
        ).engine
    }

    func testBuyingConsumableDebitsAndAddsInventory() throws {
        let engine = richEngine()
        try engine.buyPetItem("food.apple")
        try engine.buyPetItem("food.apple")

        XCTAssertEqual(engine.state.pet?.inventory["food.apple"], 2)
        XCTAssertEqual(engine.balance, 100 - 2 * PetCatalog.item(id: "food.apple")!.cost)
    }

    func testUsingItemBoostsHappinessAndConsumesIt() throws {
        let engine = richEngine()
        try engine.buyPetItem("food.cake")

        let before = engine.state.pet!.happiness
        try engine.usePetItem("food.cake")

        XCTAssertEqual(engine.state.pet?.happiness, min(100, before + 30))
        XCTAssertNil(engine.state.pet?.inventory["food.cake"], "consumed")
        XCTAssertThrowsError(try engine.usePetItem("food.cake")) { error in
            XCTAssertEqual(error as? EngineError, .itemNotOwned)
        }
    }

    func testHappinessCapsAtHundred() throws {
        let engine = richEngine()
        for _ in 0..<5 {
            try engine.buyPetItem("food.cake")
            try engine.usePetItem("food.cake")
        }
        XCTAssertEqual(engine.state.pet?.happiness, 100)
    }

    func testAccessoryOwnedOnceAndEquippable() throws {
        let engine = richEngine()
        try engine.buyPetItem("acc.hat")

        XCTAssertThrowsError(try engine.buyPetItem("acc.hat")) { error in
            XCTAssertEqual(error as? EngineError, .alreadyOwned)
        }

        try engine.equipAccessory("acc.hat")
        XCTAssertEqual(engine.state.pet?.equippedAccessory, "acc.hat")

        try engine.equipAccessory(nil)
        XCTAssertNil(engine.state.pet?.equippedAccessory)

        XCTAssertThrowsError(try engine.equipAccessory("acc.crown")) { error in
            XCTAssertEqual(error as? EngineError, .itemNotOwned)
        }
    }

    func testCannotAffordItem() {
        let engine = richEngine(balance: 1)
        XCTAssertThrowsError(try engine.buyPetItem("food.apple")) { error in
            XCTAssertEqual(error as? EngineError, .insufficientBalance)
        }
        XCTAssertEqual(engine.balance, 1)
    }
}

// MARK: - Stickers

final class StickerTests: XCTestCase {
    func testBuyingStickerDebitsAndOwns() throws {
        let engine = TestSupport.makeEngine(
            state: TestSupport.onboardedState(ledger: TestSupport.grant(10))
        ).engine

        try engine.buySticker("space.rocket")
        XCTAssertTrue(engine.ownsSticker("space.rocket"))
        XCTAssertEqual(engine.balance, 10 - StickerCatalog.sticker(id: "space.rocket")!.cost)

        XCTAssertThrowsError(try engine.buySticker("space.rocket")) { error in
            XCTAssertEqual(error as? EngineError, .alreadyOwned)
        }
    }

    func testStickerRequiresBalance() {
        let engine = TestSupport.makeEngine(state: TestSupport.onboardedState()).engine
        XCTAssertThrowsError(try engine.buySticker("space.rocket")) { error in
            XCTAssertEqual(error as? EngineError, .insufficientBalance)
        }
    }

    func testCatalogIDsAreUnique() {
        let ids = StickerCatalog.collections.flatMap { $0.stickers.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count)

        let itemIDs = PetCatalog.items.map(\.id)
        XCTAssertEqual(itemIDs.count, Set(itemIDs).count)
    }
}

// MARK: - PIN

final class PINTests: XCTestCase {
    func testSetAndVerifyPIN() {
        let engine = TestSupport.makeEngine(state: TestSupport.onboardedState()).engine
        engine.setPIN("4271")

        XCTAssertTrue(engine.verifyPIN("4271"))
        XCTAssertFalse(engine.verifyPIN("0000"))
        XCTAssertFalse(engine.verifyPIN(""))
    }

    func testPINSurvivesCodableRoundTrip() throws {
        let hash = PINHash(pin: "1234")
        let data = try JSONEncoder().encode(hash)
        let decoded = try JSONDecoder().decode(PINHash.self, from: data)

        XCTAssertTrue(decoded.matches("1234"))
        XCTAssertFalse(decoded.matches("1235"))
    }

    func testSamePINDifferentSaltsProduceDifferentHashes() {
        XCTAssertNotEqual(PINHash(pin: "1234").hash, PINHash(pin: "1234").hash)
    }
}

// MARK: - Onboarding

final class OnboardingTests: XCTestCase {
    func testOnboardingSeedsDefaultsAndSetsProfile() {
        let (engine, _, _) = TestSupport.makeEngine()
        XCTAssertTrue(engine.needsOnboarding)

        engine.completeOnboarding(
            name: "Robin",
            avatarEmoji: "🦊",
            rewardUnit: .gem,
            petSpecies: .dragon,
            petName: "Sparky",
            pin: "1234"
        )

        XCTAssertFalse(engine.needsOnboarding)
        XCTAssertEqual(engine.state.profile?.rewardUnit, .gem)
        XCTAssertEqual(engine.state.pet?.species, .dragon)
        XCTAssertFalse(engine.state.responsibilities.isEmpty)
        XCTAssertFalse(engine.state.tasks.isEmpty)
        XCTAssertFalse(engine.state.rewards.isEmpty)
        XCTAssertTrue(engine.verifyPIN("1234"))
    }

    func testResetReturnsToOnboarding() {
        let engine = TestSupport.makeEngine(
            state: TestSupport.onboardedState(ledger: TestSupport.grant(50))
        ).engine

        engine.resetAllData()
        XCTAssertTrue(engine.needsOnboarding)
        XCTAssertEqual(engine.balance, 0)
    }
}

// MARK: - Persistence

final class PersistenceTests: XCTestCase {
    func testJSONFileStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewards-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = JSONFileStore(url: url)
        var state = TestSupport.onboardedState(ledger: TestSupport.grant(42))
        state.ownedStickers = ["space.rocket"]
        state.streak = StreakState(count: 3, lastCompletedDayKey: "2026-01-05")

        try store.save(state)
        let loaded = try store.load()

        XCTAssertEqual(loaded, state)
    }

    func testLoadReturnsNilWhenNoFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewards-missing-\(UUID().uuidString).json")
        XCTAssertNil(try JSONFileStore(url: url).load())
    }

    func testEngineStatePersistsAcrossInstances() throws {
        let clock = TestClock(TestSupport.monday)
        let teeth = Responsibility(title: "Brush teeth", icon: "🪥")
        let chore = ChoreTask(title: "Set table", icon: "🍽️", value: 5)
        let store = InMemoryStore(
            state: TestSupport.onboardedState(responsibilities: [teeth], tasks: [chore])
        )

        let first = RewardsEngine(store: store, calendar: TestSupport.utcCalendar, now: { clock.current })
        first.setResponsibility(teeth.id, completed: true)
        try first.completeTask(chore.id)

        let second = RewardsEngine(store: store, calendar: TestSupport.utcCalendar, now: { clock.current })
        XCTAssertEqual(second.balance, 5)
        XCTAssertTrue(second.isResponsibilityCompletedToday(teeth.id))
        XCTAssertEqual(second.state.profile?.name, "Robin")
    }
}
