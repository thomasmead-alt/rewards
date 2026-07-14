import Foundation

/// Salted hash for the parent PIN.
///
/// This is a child gate, not a security boundary: it keeps a 6–10 year old out
/// of parent mode on a shared device. It deliberately avoids a crypto
/// dependency; a 4-digit PIN has too little entropy for hashing strength to
/// matter regardless.
public struct PINHash: Codable, Equatable, Sendable {
    public var salt: String
    public var hash: String

    public init(pin: String) {
        self.salt = UUID().uuidString
        self.hash = Self.digest(salt: salt, pin: pin)
    }

    public func matches(_ pin: String) -> Bool {
        hash == Self.digest(salt: salt, pin: pin)
    }

    /// FNV-1a 64-bit over several salted rounds.
    private static func digest(salt: String, pin: String) -> String {
        var value: UInt64 = 0xcbf29ce484222325
        for round in 0..<1000 {
            for byte in Array("\(round):\(salt):\(pin)".utf8) {
                value ^= UInt64(byte)
                value = value &* 0x100000001b3
            }
        }
        return String(value, radix: 16)
    }
}
