import Foundation

enum ShogiPlayer: Hashable, Codable {
    case sente
    case gote

    var label: String {
        switch self {
        case .sente: return "先手"
        case .gote: return "後手"
        }
    }

    var forward: Int {
        switch self {
        case .sente: return -1
        case .gote: return 1
        }
    }

    var opposite: ShogiPlayer {
        self == .sente ? .gote : .sente
    }
}

enum ShogiPieceType: CaseIterable, Hashable, Codable {
    case king
    case gold
    case silver
    case knight
    case lance
    case bishop
    case rook
    case pawn

    var symbol: String {
        switch self {
        case .king: return "王"
        case .gold: return "金"
        case .silver: return "銀"
        case .knight: return "桂"
        case .lance: return "香"
        case .bishop: return "角"
        case .rook: return "飛"
        case .pawn: return "歩"
        }
    }

    var name: String {
        switch self {
        case .king: return "王将"
        case .gold: return "金将"
        case .silver: return "銀将"
        case .knight: return "桂馬"
        case .lance: return "香車"
        case .bishop: return "角行"
        case .rook: return "飛車"
        case .pawn: return "歩兵"
        }
    }

    var promotedSymbol: String {
        switch self {
        case .silver: return "全"
        case .knight: return "圭"
        case .lance: return "杏"
        case .pawn: return "と"
        case .bishop: return "馬"
        case .rook: return "龍"
        case .king, .gold: return symbol
        }
    }

    var canPromote: Bool {
        switch self {
        case .king, .gold:
            return false
        default:
            return true
        }
    }

    static let handOrder: [ShogiPieceType] = [.rook, .bishop, .gold, .silver, .knight, .lance, .pawn]
}

struct ShogiPiece: Codable {
    let owner: ShogiPlayer
    let type: ShogiPieceType
    var isPromoted: Bool = false

    var displaySymbol: String {
        isPromoted ? type.promotedSymbol : type.symbol
    }
}

struct BoardSquare: Hashable, Codable {
    let row: Int
    let col: Int
}

struct PromotionPendingMove: Codable {
    let from: BoardSquare
    let to: BoardSquare
}

struct ShogiGameSnapshot: Codable {
    let board: [[ShogiPiece?]]
    let selected: BoardSquare?
    let selectedDropType: ShogiPieceType?
    let senteHand: [ShogiPieceType: Int]
    let goteHand: [ShogiPieceType: Int]
    let pendingPromotionMove: PromotionPendingMove?
    let turn: ShogiPlayer
    let winner: ShogiPlayer?
    let winReason: String
    let isSennichite: Bool
    let isInterrupted: Bool
    let positionCounts: [String: Int]
    let moveRecords: [String]
}

struct KifVariationBlock: Codable {
    let fromMove: Int
    let lines: [String]
}

struct KifExtendedData: Codable {
    /// KIFヘッダ（キー: 先手/後手/棋戦 など）
    let headers: [String: String]
    /// 手数ごとのコメント（0は局前コメント）
    let commentsByMove: [Int: [String]]
    /// 手数ごとの時間文字列（例: "0:01/00:00:01"）
    let timeTextByMove: [Int: String]
    /// 変化手順ブロック
    let variations: [KifVariationBlock]

    init(
        headers: [String: String] = [:],
        commentsByMove: [Int: [String]] = [:],
        timeTextByMove: [Int: String] = [:],
        variations: [KifVariationBlock] = []
    ) {
        self.headers = headers
        self.commentsByMove = commentsByMove
        self.timeTextByMove = timeTextByMove
        self.variations = variations
    }
}

struct PersistedShogiGameRecord: Codable {
    let snapshot: ShogiGameSnapshot
    /// ボード履歴（nullable）: メモリ節約のため、フル棋譜では nil に設定して lazy 生成
    /// - ファイルスキャン時: nil（メタデータのみ）
    /// - レビューモード: 必要に応じて復元・生成
    let moveHistory: [ShogiGameSnapshot]?
    let savedAt: Date
    let kifExtendedData: KifExtendedData?

    init(
        snapshot: ShogiGameSnapshot,
        moveHistory: [ShogiGameSnapshot]? = nil,
        savedAt: Date,
        kifExtendedData: KifExtendedData? = nil
    ) {
        self.snapshot = snapshot
        self.moveHistory = moveHistory
        self.savedAt = savedAt
        self.kifExtendedData = kifExtendedData
    }
}

struct SavedKifFileModel: Identifiable {
    let id: UUID
    /// SwiftData 管理外の旧ファイルパス。SwiftData 管理レコードは nil
    let fileURL: URL?
    let fileName: String
    let savedAt: Date
    let summary: String
    /// フォルダ名（"" = 未分類）
    let folderName: String

    var listIdentity: String {
        if let fileURL {
            return "file:\(fileURL.standardizedFileURL.path)"
        }
        return "db:\(id.uuidString.lowercased())"
    }

    /// 旧ファイルベース互換イニシャライザ
    init(id: UUID = UUID(), url: URL, fileName: String, savedAt: Date, summary: String, folderName: String = "") {
        self.id = id
        self.fileURL = url
        self.fileName = fileName
        self.savedAt = savedAt
        self.summary = summary
        self.folderName = folderName
    }

    /// SwiftData バックドイニシャライザ
    init(id: UUID, fileURL: URL?, fileName: String, savedAt: Date, summary: String, folderName: String = "") {
        self.id = id
        self.fileURL = fileURL
        self.fileName = fileName
        self.savedAt = savedAt
        self.summary = summary
        self.folderName = folderName
    }
}

enum KifuSourceProvider: String, CaseIterable, Codable, Hashable {
    case shogiWars
    case dojo81
    case shogiDB2
    case other

    var label: String {
        switch self {
        case .shogiWars: return "ウォーズ"
        case .dojo81: return "81道場"
        case .shogiDB2: return "ShogiDB2"
        case .other: return "その他"
        }
    }

    static func detect(from urlString: String) -> KifuSourceProvider {
        let host = URL(string: urlString)?.host?.lowercased() ?? ""
        if host.contains("wars") || host.contains("shogiwars") {
            return .shogiWars
        }
        if host.contains("81dojo") {
            return .dojo81
        }
        if host.contains("shogidb2") || host.contains("shogidb") {
            return .shogiDB2
        }
        return .other
    }
}

struct RegisteredKifuSourceModel: Identifiable, Codable, Hashable {
    let id: UUID
    let urlString: String
    let createdAt: Date

    init(id: UUID = UUID(), urlString: String, createdAt: Date = Date()) {
        self.id = id
        self.urlString = urlString
        self.createdAt = createdAt
    }

    var hostLabel: String {
        URL(string: urlString)?.host ?? "URL"
    }

    var provider: KifuSourceProvider {
        KifuSourceProvider.detect(from: urlString)
    }
}

struct RegisteredShogiWarsUserModel: Identifiable, Codable, Hashable {
    let id: UUID
    let username: String
    let createdAt: Date

    init(id: UUID = UUID(), username: String, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
    }

    var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var searchURLString: String {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        return "https://www.shogi-extend.com/swars/search?query=\(encoded)&page=1"
    }
}
