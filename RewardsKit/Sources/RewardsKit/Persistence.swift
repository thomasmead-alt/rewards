import Foundation

public protocol PersistenceStore: Sendable {
    func load() throws -> AppState?
    func save(_ state: AppState) throws
}

/// Saves the state as a JSON file, atomically.
public struct JSONFileStore: PersistenceStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The standard location inside the app's Documents directory.
    public static func standard() -> JSONFileStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return JSONFileStore(url: documents.appendingPathComponent("rewards-state.json"))
    }

    public func load() throws -> AppState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: data)
    }

    public func save(_ state: AppState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }
}

/// Test double; also handy for SwiftUI previews.
public final class InMemoryStore: PersistenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: AppState?

    public init(state: AppState? = nil) {
        self.state = state
    }

    public func load() throws -> AppState? {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func save(_ state: AppState) throws {
        lock.lock()
        defer { lock.unlock() }
        self.state = state
    }
}
