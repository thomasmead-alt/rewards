import Foundation

/// The currency style a child picks for themselves during onboarding.
/// Purely cosmetic — all values and costs are denominated in "units".
public enum RewardUnit: String, Codable, CaseIterable, Sendable, Equatable {
    case star
    case gem
    case coin
    case heart
    case paw

    public var emoji: String {
        switch self {
        case .star: return "⭐️"
        case .gem: return "💎"
        case .coin: return "🪙"
        case .heart: return "❤️"
        case .paw: return "🐾"
        }
    }

    public var singularName: String {
        switch self {
        case .star: return "Star"
        case .gem: return "Gem"
        case .coin: return "Coin"
        case .heart: return "Heart"
        case .paw: return "Paw"
        }
    }

    public var pluralName: String {
        switch self {
        case .star: return "Stars"
        case .gem: return "Gems"
        case .coin: return "Coins"
        case .heart: return "Hearts"
        case .paw: return "Paws"
        }
    }

    /// A short label like "12 ⭐️".
    public func label(for amount: Int) -> String {
        "\(amount) \(emoji)"
    }
}
