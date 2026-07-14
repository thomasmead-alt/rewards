import Foundation

// MARK: - Pet

public enum PetSpecies: String, Codable, CaseIterable, Sendable, Equatable {
    case bunny
    case kitten
    case puppy
    case dragon
    case penguin

    public var emoji: String {
        switch self {
        case .bunny: return "🐰"
        case .kitten: return "🐱"
        case .puppy: return "🐶"
        case .dragon: return "🐲"
        case .penguin: return "🐧"
        }
    }

    public var displayName: String {
        switch self {
        case .bunny: return "Bunny"
        case .kitten: return "Kitten"
        case .puppy: return "Puppy"
        case .dragon: return "Dragon"
        case .penguin: return "Penguin"
        }
    }
}

/// The child's virtual companion. Mood is upbeat-only: the pet gets "sleepy"
/// when happiness is low but never suffers — no punishment mechanics.
public struct Pet: Codable, Equatable, Sendable {
    public var species: PetSpecies
    public var name: String
    /// 0...100. Raised by feeding/playing, drifts down slowly between days.
    public var happiness: Int
    /// Consumable items owned, item ID → quantity.
    public var inventory: [String: Int]
    /// Accessory item IDs owned.
    public var ownedAccessories: Set<String>
    /// Accessory item ID currently worn, if any.
    public var equippedAccessory: String?

    public init(
        species: PetSpecies,
        name: String,
        happiness: Int = 80,
        inventory: [String: Int] = [:],
        ownedAccessories: Set<String> = [],
        equippedAccessory: String? = nil
    ) {
        self.species = species
        self.name = name
        self.happiness = happiness
        self.inventory = inventory
        self.ownedAccessories = ownedAccessories
        self.equippedAccessory = equippedAccessory
    }

    public var isSleepy: Bool { happiness < 50 }

    public var moodDescription: String {
        isSleepy ? "a little sleepy" : "super happy"
    }
}

// MARK: - Pet item catalog

public enum PetItemKind: String, Codable, Sendable, Equatable {
    case food
    case toy
    case accessory
}

public struct PetItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let cost: Int
    public let kind: PetItemKind
    /// Happiness gained when a food/toy is used. Zero for accessories.
    public let boost: Int
}

public enum PetCatalog {
    public static let items: [PetItem] = [
        // Food
        PetItem(id: "food.apple", name: "Crunchy Apple", emoji: "🍎", cost: 2, kind: .food, boost: 8),
        PetItem(id: "food.carrot", name: "Carrot Snack", emoji: "🥕", cost: 2, kind: .food, boost: 8),
        PetItem(id: "food.cookie", name: "Giant Cookie", emoji: "🍪", cost: 4, kind: .food, boost: 15),
        PetItem(id: "food.cake", name: "Party Cake", emoji: "🍰", cost: 8, kind: .food, boost: 30),
        // Toys
        PetItem(id: "toy.ball", name: "Bouncy Ball", emoji: "⚽️", cost: 3, kind: .toy, boost: 12),
        PetItem(id: "toy.kite", name: "Rainbow Kite", emoji: "🪁", cost: 5, kind: .toy, boost: 20),
        PetItem(id: "toy.skateboard", name: "Mini Skateboard", emoji: "🛹", cost: 8, kind: .toy, boost: 30),
        // Accessories (permanent, equippable)
        PetItem(id: "acc.bow", name: "Fancy Bow", emoji: "🎀", cost: 10, kind: .accessory, boost: 0),
        PetItem(id: "acc.hat", name: "Party Hat", emoji: "🎩", cost: 15, kind: .accessory, boost: 0),
        PetItem(id: "acc.glasses", name: "Cool Shades", emoji: "🕶️", cost: 15, kind: .accessory, boost: 0),
        PetItem(id: "acc.crown", name: "Royal Crown", emoji: "👑", cost: 30, kind: .accessory, boost: 0),
    ]

    public static func item(id: String) -> PetItem? {
        items.first { $0.id == id }
    }
}
