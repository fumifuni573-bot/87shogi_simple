import Foundation

enum ShogiWarsUserStore {
    enum AddResult: Equatable {
        case added
        case duplicate
        case invalidUsername
        case backendUnavailable
        case empty

        var isSuccess: Bool {
            if case .added = self { return true }
            return false
        }
    }

    private static let storageKey = "registered_shogi_wars_users_v1"

    static func load() -> [RegisteredShogiWarsUserModel] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RegisteredShogiWarsUserModel].self, from: data)) ?? []
    }

    @discardableResult
    static func add(username rawUsername: String) -> AddResult {
        let trimmed = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }
        guard let normalized = normalize(username: trimmed) else {
            return .invalidUsername
        }

        var current = load()
        if current.contains(where: { $0.normalizedUsername == normalized.lowercased() }) {
            return .duplicate
        }

        current.insert(RegisteredShogiWarsUserModel(username: normalized), at: 0)
        save(current)
        return .added
    }

    static func validationResult(for rawUsername: String) -> AddResult? {
        let trimmed = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }
        guard let normalized = normalize(username: trimmed) else {
            return .invalidUsername
        }
        if load().contains(where: { $0.normalizedUsername == normalized.lowercased() }) {
            return .duplicate
        }
        return nil
    }

    static func remove(id: UUID) {
        var current = load()
        current.removeAll { $0.id == id }
        save(current)
    }

    private static func save(_ items: [RegisteredShogiWarsUserModel]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func normalize(username rawUsername: String) -> String? {
        let trimmed = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return trimmed
    }
}
