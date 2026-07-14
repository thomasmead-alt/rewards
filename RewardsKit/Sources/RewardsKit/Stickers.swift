import Foundation

// MARK: - Sticker album

/// Stickers are bought directly — the child always sees and chooses what they
/// are buying. No random packs, so nothing gambling-like.
public struct Sticker: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let cost: Int
}

public struct StickerCollection: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let emoji: String
    public let stickers: [Sticker]
}

public enum StickerCatalog {
    public static let collections: [StickerCollection] = [
        StickerCollection(id: "space", title: "Outer Space", emoji: "🚀", stickers: [
            Sticker(id: "space.rocket", name: "Rocket", emoji: "🚀", cost: 3),
            Sticker(id: "space.moon", name: "Moon", emoji: "🌙", cost: 3),
            Sticker(id: "space.star", name: "Shooting Star", emoji: "🌠", cost: 4),
            Sticker(id: "space.planet", name: "Ringed Planet", emoji: "🪐", cost: 5),
            Sticker(id: "space.astronaut", name: "Astronaut", emoji: "🧑‍🚀", cost: 6),
            Sticker(id: "space.ufo", name: "Flying Saucer", emoji: "🛸", cost: 8),
        ]),
        StickerCollection(id: "ocean", title: "Under the Sea", emoji: "🌊", stickers: [
            Sticker(id: "ocean.fish", name: "Tropical Fish", emoji: "🐠", cost: 3),
            Sticker(id: "ocean.turtle", name: "Sea Turtle", emoji: "🐢", cost: 3),
            Sticker(id: "ocean.octopus", name: "Octopus", emoji: "🐙", cost: 4),
            Sticker(id: "ocean.dolphin", name: "Dolphin", emoji: "🐬", cost: 5),
            Sticker(id: "ocean.whale", name: "Whale", emoji: "🐳", cost: 6),
            Sticker(id: "ocean.mermaid", name: "Mermaid", emoji: "🧜", cost: 8),
        ]),
        StickerCollection(id: "dino", title: "Dinosaurs", emoji: "🦕", stickers: [
            Sticker(id: "dino.egg", name: "Dino Egg", emoji: "🥚", cost: 3),
            Sticker(id: "dino.footprint", name: "Footprint", emoji: "🐾", cost: 3),
            Sticker(id: "dino.sauropod", name: "Long Neck", emoji: "🦕", cost: 4),
            Sticker(id: "dino.trex", name: "T-Rex", emoji: "🦖", cost: 5),
            Sticker(id: "dino.volcano", name: "Volcano", emoji: "🌋", cost: 6),
            Sticker(id: "dino.fossil", name: "Fossil", emoji: "🦴", cost: 8),
        ]),
        StickerCollection(id: "animals", title: "Animal Friends", emoji: "🦊", stickers: [
            Sticker(id: "animals.fox", name: "Fox", emoji: "🦊", cost: 3),
            Sticker(id: "animals.panda", name: "Panda", emoji: "🐼", cost: 3),
            Sticker(id: "animals.koala", name: "Koala", emoji: "🐨", cost: 4),
            Sticker(id: "animals.lion", name: "Lion", emoji: "🦁", cost: 5),
            Sticker(id: "animals.unicorn", name: "Unicorn", emoji: "🦄", cost: 6),
            Sticker(id: "animals.butterfly", name: "Butterfly", emoji: "🦋", cost: 8),
        ]),
    ]

    public static func sticker(id: String) -> Sticker? {
        for collection in collections {
            if let sticker = collection.stickers.first(where: { $0.id == id }) {
                return sticker
            }
        }
        return nil
    }
}
