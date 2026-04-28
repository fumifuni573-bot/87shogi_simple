import Foundation

enum URLSourceStore {
    enum AddResult: Equatable {
        case added
        case duplicate
        case invalidFormat
        case unsupportedProvider
        case empty

        var isSuccess: Bool {
            if case .added = self { return true }
            return false
        }
    }

    private static let storageKey = "registered_kifu_source_urls_v1"

    /// 外部共有（Share Extensionやディープリンク）で渡されたURLを抽出する
    ///
    /// 対応形式:
    /// - https://...（直接URL）
    /// - hanafubuki87://import?url=https%3A%2F%2F...
    /// - 87shogi://import?url=https%3A%2F%2F...
    static func extractSharedURLString(from incomingURL: URL) -> String? {
        if let scheme = incomingURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return incomingURL.absoluteString
        }

        guard let scheme = incomingURL.scheme?.lowercased() else { return nil }
        let supportedSchemes = ["hanafubuki87", "87shogi"]
        guard supportedSchemes.contains(scheme) else { return nil }

        guard let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let keyCandidates = ["url", "target", "source"]
        let value = components.queryItems?
            .first(where: { keyCandidates.contains($0.name.lowercased()) })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// 外部共有で受け取ったURLを将棋ウォーズURLとして登録する
    @discardableResult
    static func addSharedShogiWarsURL(from incomingURL: URL) -> AddResult {
        guard let raw = extractSharedURLString(from: incomingURL) else {
            return .invalidFormat
        }
        guard let normalized = normalizedURLString(from: raw) else {
            return .invalidFormat
        }
        guard KifuSourceProvider.detect(from: normalized) == .shogiWars else {
            return .unsupportedProvider
        }
        return add(rawURL: normalized)
    }

    static func load() -> [RegisteredKifuSourceModel] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RegisteredKifuSourceModel].self, from: data)) ?? []
    }

    @discardableResult
    static func add(rawURL: String) -> AddResult {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }
        guard let normalized = normalize(rawURL: rawURL) else {
            return .invalidFormat
        }

        var current = load()
        if current.contains(where: { $0.urlString.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return .duplicate
        }

        current.insert(RegisteredKifuSourceModel(urlString: normalized), at: 0)
        save(current)
        return .added
    }

    static func normalizedURLString(from rawURL: String) -> String? {
        normalize(rawURL: rawURL)
    }

    static func remove(id: UUID) {
        var current = load()
        current.removeAll { $0.id == id }
        save(current)
    }

    private static func save(_ items: [RegisteredKifuSourceModel]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func normalize(rawURL: String) -> String? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate) else { return nil }

        guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        guard components.host?.isEmpty == false else { return nil }

        components.scheme = scheme
        return components.url?.absoluteString
    }
}
