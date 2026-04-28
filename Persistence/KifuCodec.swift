import Foundation

// MARK: - KifuCodec
//
// アプリ独自の KIF エンコード／デコードを一元管理する。
// ContentView から抽出し、KifuRepository・KifuFetcher（将来）からも参照できるようにした。

enum KifuCodec {

    // MARK: - エンコード

    /// `PersistedShogiGameRecord` → 標準KIF互換テキスト
    ///
    /// フォーマット:
    /// ```
    /// 開始日時：…
    /// 手合割：平手
    /// 先手：先手
    /// 後手：後手
    /// 結果：…
    /// 手数----指手---------
    /// 1 ７六歩(77)
    /// 2 ３四歩(33)
    /// 3 投了
    /// ```
    static func encode(_ record: PersistedShogiGameRecord) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"

        let extended = record.kifExtendedData
        let headers = extended?.headers ?? [:]
        let senteName = headers["先手"] ?? "先手"
        let goteName = headers["後手"] ?? "後手"
        let handicap = headers["手合割"] ?? "平手"
        let gameDateText = headers["開始日時"] ?? formatter.string(from: record.savedAt)

        var lines = [
            "開始日時：\(gameDateText)",
            "手合割：\(handicap)",
            "先手：\(senteName)",
            "後手：\(goteName)",
            "結果：\(resultSummary(for: record.snapshot))",
            "手数----指手---------",
        ]

        if let openingComments = extended?.commentsByMove[0] {
            for comment in openingComments {
                lines.append("*\(comment)")
            }
        }

        let standardMoves = standardKIFMoves(from: record.snapshot.moveRecords)
        for (index, move) in standardMoves.enumerated() {
            let moveNumber = index + 1
            var line = "\(moveNumber) \(move)"
            if let timeText = extended?.timeTextByMove[moveNumber], !timeText.isEmpty {
                line += " (\(timeText))"
            }
            lines.append(line)

            if let comments = extended?.commentsByMove[moveNumber] {
                for comment in comments {
                    lines.append("*\(comment)")
                }
            }
        }

        if let terminal = terminalMoveText(for: record.snapshot) {
            lines.append("\(standardMoves.count + 1) \(terminal)")
        }

        if let footer = footerSummary(for: record.snapshot, moveCount: standardMoves.count) {
            lines.append(footer)
        }

        if let variations = extended?.variations {
            for variation in variations {
                lines.append("変化：\(variation.fromMove)手")
                lines.append(contentsOf: variation.lines)
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - デコード

    /// 標準KIF/CSAテキスト → `PersistedShogiGameRecord`
    static func decode(from text: String) throws -> PersistedShogiGameRecord {
        try KifuParser.parse(text: text, includeHistory: false).record
    }

    // MARK: - ファイル名生成

    /// 保存日時・手数から KIF ファイル名（拡張子付き）を生成する
    static func fileName(for date: Date, moveCount: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "record_\(formatter.string(from: date))_\(moveCount)手.kif"
    }

    // MARK: - メタデータ簡易パース（KifuRepository.migrate 用）

    /// KIF テキストから手数と結果サマリーを簡易抽出する
    ///
    /// 軽量版メタデータ抽出（ファイルスキャン用）
    static func parseMetadata(from text: String, upToMoveCount: Int = 1) -> (moveCount: Int, resultSummary: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var moveCount = 0
        var resultSummary: String? = nil
        if let headerLine = lines.first(where: { $0.hasPrefix("結果：") }) {
            resultSummary = headerLine
                .replacingOccurrences(of: "結果：", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var foundMovesSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("手数----指手") {
                foundMovesSection = true
                continue
            }
            guard foundMovesSection, !trimmed.isEmpty else { continue }

            let digits = trimmed.prefix(while: { $0.isNumber })
            guard !digits.isEmpty, let num = Int(digits) else { continue }
            let afterNum = trimmed.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
            guard !afterNum.isEmpty else { continue }
            let moveText = afterNum.components(separatedBy: " (").first?
                .trimmingCharacters(in: .whitespaces) ?? afterNum

            if moveText.hasPrefix("投了") || moveText.hasPrefix("中断") ||
                moveText.hasPrefix("詰み") || moveText.hasPrefix("千日手") ||
                moveText.hasPrefix("TIME_UP") || moveText.hasPrefix("反則") ||
                moveText.hasPrefix("持将棋") || moveText.hasPrefix("入玉勝ち") ||
                moveText.hasPrefix("切れ負け") {
                if resultSummary == nil || resultSummary?.isEmpty == true {
                    resultSummary = resultSummaryForTerminalMove(moveText, moveNumber: num)
                }
                break
            }

            if num == moveCount + 1 {
                moveCount += 1
            }

            if moveCount >= upToMoveCount, resultSummary?.isEmpty == false {
                break
            }
        }

        return (moveCount, (resultSummary?.isEmpty == false ? resultSummary! : "不明"))
    }

    // MARK: - Private helpers

    private static func resultSummary(for snapshot: ShogiGameSnapshot) -> String {
        if let winner = snapshot.winner {
            return "\(winner.label)の勝ち（\(snapshot.winReason)）"
        }
        if snapshot.isSennichite { return "千日手（引き分け）" }
        if snapshot.isInterrupted { return "対局中断" }
        return "対局中"
    }

    private static func standardKIFMoves(from moveRecords: [String]) -> [String] {
        moveRecords.map { standardKIFMove(from: $0) ?? $0 }
    }

    private static func standardKIFMove(from record: String) -> String? {
        let parts = record.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        if parts.count == 4, parts[2] == "打" {
            let piece = parts[1]
            let destination = toStandardDestination(parts[3])
            return "\(destination)\(piece)打"
        }

        if parts.count == 5 {
            let from = toSourceCoordinate(parts[1])
            let piece = parts[2]
            let destinationPart = parts[4]
            let promoteSuffix = destinationPart.hasSuffix("成") ? "成" : ""
            let destinationBase = promoteSuffix.isEmpty ? destinationPart : String(destinationPart.dropLast())
            let destination = toStandardDestination(destinationBase)
            return "\(destination)\(piece)(\(from))\(promoteSuffix)"
        }

        return nil
    }

    private static func toStandardDestination(_ square: String) -> String {
        guard let first = square.first else { return square }
        let rest = String(square.dropFirst())
        return "\(toFullWidthDigit(first))\(rest)"
    }

    private static func toSourceCoordinate(_ square: String) -> String {
        guard let first = square.first else { return square }
        let rowPart = String(square.dropFirst())
        return "\(first)\(rowNumber(from: rowPart))"
    }

    private static func toFullWidthDigit(_ character: Character) -> String {
        switch character {
        case "1": return "１"
        case "2": return "２"
        case "3": return "３"
        case "4": return "４"
        case "5": return "５"
        case "6": return "６"
        case "7": return "７"
        case "8": return "８"
        case "9": return "９"
        default: return String(character)
        }
    }

    private static func rowNumber(from value: String) -> String {
        switch value {
        case "一": return "1"
        case "二": return "2"
        case "三": return "3"
        case "四": return "4"
        case "五": return "5"
        case "六": return "6"
        case "七": return "7"
        case "八": return "8"
        case "九": return "9"
        default: return value
        }
    }

    private static func terminalMoveText(for snapshot: ShogiGameSnapshot) -> String? {
        if snapshot.isSennichite {
            return "千日手"
        }

        if let winner = snapshot.winner {
            switch snapshot.winReason {
            case "投了":
                return "投了"
            case "詰み":
                return "詰み"
            case "時間切れ":
                return "TIME_UP"
            case "入玉勝ち":
                return "入玉勝ち"
            case "反則", "反則負け", "反則勝ち":
                return winner == snapshot.turn ? "反則勝ち" : "反則負け"
            default:
                return snapshot.winReason.isEmpty ? nil : snapshot.winReason
            }
        }

        if snapshot.isInterrupted {
            if snapshot.winReason == "持将棋" {
                return "持将棋"
            }
            return "中断"
        }

        return nil
    }

    private static func footerSummary(for snapshot: ShogiGameSnapshot, moveCount: Int) -> String? {
        let totalMoves = moveCount + (terminalMoveText(for: snapshot) == nil ? 0 : 1)

        if snapshot.isSennichite {
            return "まで\(totalMoves)手で千日手"
        }

        if let winner = snapshot.winner {
            let winnerText = winner == .sente ? "先手の勝ち" : "後手の勝ち"
            return "まで\(totalMoves)手で\(winnerText)"
        }

        if snapshot.isInterrupted {
            if snapshot.winReason == "持将棋" {
                return "まで\(totalMoves)手で持将棋"
            }
            return "まで\(totalMoves)手で中断"
        }

        return nil
    }

    private static func resultSummaryForTerminalMove(_ moveText: String, moveNumber: Int) -> String {
        let lastPlayer: ShogiPlayer = moveNumber % 2 == 1 ? .sente : .gote

        if moveText.hasPrefix("投了") {
            return "\(lastPlayer.opposite.label)の勝ち（投了）"
        }
        if moveText.hasPrefix("詰み") {
            return "\(lastPlayer.opposite.label)の勝ち（詰み）"
        }
        if moveText.hasPrefix("入玉勝ち") {
            return "\(lastPlayer.label)の勝ち（入玉勝ち）"
        }
        if moveText.hasPrefix("反則勝ち") {
            return "\(lastPlayer.label)の勝ち（反則）"
        }
        if moveText.hasPrefix("反則負け") || moveText.hasPrefix("反則") {
            return "\(lastPlayer.opposite.label)の勝ち（反則）"
        }
        if moveText.hasPrefix("TIME_UP") || moveText.hasPrefix("切れ負け") {
            return "\(lastPlayer.opposite.label)の勝ち（時間切れ）"
        }
        if moveText.hasPrefix("千日手") {
            return "千日手（引き分け）"
        }
        if moveText.hasPrefix("持将棋") {
            return "持将棋（引き分け）"
        }
        if moveText.hasPrefix("中断") {
            return "対局中断"
        }
        return "不明"
    }
}
