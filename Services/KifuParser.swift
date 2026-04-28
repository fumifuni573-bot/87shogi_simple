import Foundation

// MARK: - KifuParser
//
// 標準KIF形式・CSA形式の棋譜テキストを解析し、
// PersistedShogiGameRecord（ボード状態履歴付き）に変換する。
//
// 対応フォーマット:
//   KIF: 手合割、先手/後手ヘッダー、手数----指手、投了/詰み/中断/千日手
//   CSA: V2、N+/-プレイヤー名、+-移動、%終局

enum KifuParser {

    private enum Handicap {
        case none
        case lance
        case bishop
        case rook
        case twoPieces
        case fourPieces
        case sixPieces
    }

    // MARK: - Public Types

    struct ParseResult {
        let playerSente: String
        let playerGote: String
        let resultSummary: String
        let record: PersistedShogiGameRecord
    }

    enum ParseError: Error, LocalizedError {
        case unsupportedFormat
        case executionError(String)
        /// 棋譜の指し手行を解析できなかった場合（行番号・内容付き）
        case invalidMove(line: Int, content: String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "サポートされていない棋譜形式です"
            case .executionError(let m):
                return "棋譜実行エラー: \(m)"
            case .invalidMove(let line, let content):
                return "解析できない指し手です（\(line)行目:「\(content)」）"
            }
        }
    }

    // MARK: - Public API

    /// テキストを解析してParseResultを返す（KIF・CSA自動判定）
    nonisolated static func parse(
        text: String,
        upToMoveCount: Int? = nil,
        includeHistory: Bool = true
    ) throws -> ParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCSAFormat(trimmed) {
            return try parseCSA(trimmed, upToMoveCount: upToMoveCount, includeHistory: includeHistory)
        }
        return try parseKIF(trimmed, upToMoveCount: upToMoveCount, includeHistory: includeHistory)
    }

    // MARK: - Format Detection

    private static func isCSAFormat(_ text: String) -> Bool {
        text.hasPrefix("V2") ||
        text.hasPrefix("V2.2") ||
        text.range(of: "\n+[0-9]", options: .regularExpression) != nil ||
        (text.hasPrefix("+") && text.contains("FU"))
    }

    // MARK: - KIF Parser

    private static func parseKIF(
        _ text: String,
        upToMoveCount: Int?,
        includeHistory: Bool
    ) throws -> ParseResult {
        let lines = text.components(separatedBy: "\n")

        var playerSente = "先手"
        var playerGote  = "後手"
        var resultSummary = "不明"
        var handicap: Handicap = .none
        var endGameWinner: ShogiPlayer? = nil
        var endGameReason = ""
        var isSennichite  = false
        var isInterrupted = false
        var gameDate = Date()
        var headers: [String: String] = [:]
        var commentsByMove: [Int: [String]] = [:]
        var timeTextByMove: [Int: String] = [:]
        var variations: [KifVariationBlock] = []

        // --- ヘッダー解析 ---
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if let separator = firstHeaderSeparatorIndex(in: t) {
                let key = String(t[..<separator]).trimmingCharacters(in: .whitespaces)
                let value = String(t[t.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty, !value.isEmpty {
                    headers[key] = value
                }
            }
            if      let v = headerValue(t, "先手") { playerSente = v }
            else if let v = headerValue(t, "後手") { playerGote  = v }
            else if let v = headerValue(t, "下手") { playerSente = v }
            else if let v = headerValue(t, "上手") { playerGote  = v }
            else if let v = headerValue(t, "結果") { resultSummary = v }
            else if let v = headerValue(t, "開始日時") {
                gameDate = parseDateString(v) ?? Date()
            } else if let v = headerValue(t, "手合割") {
                handicap = handicapFromKIF(v)
            }
        }

        // --- 指し手解析 ---
        struct RawMove {
            let number: Int
            let text: String
            let player: ShogiPlayer
        }
        var rawMoves: [RawMove] = []
        var currentVariationFromMove: Int? = nil
        var currentVariationLines: [String] = []

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if let fromMove = variationStartMove(from: t) {
                if let existingFrom = currentVariationFromMove {
                    variations.append(KifVariationBlock(fromMove: existingFrom, lines: currentVariationLines))
                }
                currentVariationFromMove = fromMove
                currentVariationLines = []
                continue
            }

            if currentVariationFromMove != nil {
                if !t.isEmpty {
                    currentVariationLines.append(t)
                }
                continue
            }

            if t.hasPrefix("*") {
                let comment = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !comment.isEmpty {
                    let targetMove = rawMoves.last?.number ?? 0
                    commentsByMove[targetMove, default: []].append(comment)
                }
                continue
            }
            guard !t.isEmpty,
                  !t.hasPrefix("#"),
                  !t.hasPrefix("&") else { continue }

            // 先頭の数字を取り出す
            let digits = t.prefix(while: { $0.isNumber })
            guard !digits.isEmpty, let num = Int(digits) else { continue }
            let afterNum = t.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
            guard !afterNum.isEmpty else { continue }

            if let timeText = extractKifTimeText(from: afterNum) {
                timeTextByMove[num] = timeText
            }

            // 時間情報 ( MM:SS/HH:MM:SS ) を除去
            let moveText = afterNum.components(separatedBy: " (").first?
                .trimmingCharacters(in: .whitespaces) ?? afterNum

            // 終局マーカー
            if moveText.hasPrefix("投了") || moveText.hasPrefix("中断") ||
               moveText.hasPrefix("詰み") || moveText.hasPrefix("千日手") ||
               moveText.hasPrefix("TIME_UP") || moveText.hasPrefix("反則") ||
               moveText.hasPrefix("持将棋") || moveText.hasPrefix("入玉勝ち") ||
               moveText.hasPrefix("切れ負け") {
                let lastPlayer: ShogiPlayer = num % 2 == 1 ? .sente : .gote
                if moveText.hasPrefix("投了") {
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "投了"
                    resultSummary = "\(winner.label)の勝ち（投了）"
                } else if moveText.hasPrefix("詰み") {
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "詰み"
                    resultSummary = "\(winner.label)の勝ち（詰み）"
                } else if moveText.hasPrefix("入玉勝ち") {
                    let winner = lastPlayer
                    endGameWinner = winner
                    endGameReason = "入玉勝ち"
                    resultSummary = "\(winner.label)の勝ち（入玉勝ち）"
                } else if moveText.hasPrefix("反則勝ち") {
                    let winner = lastPlayer
                    endGameWinner = winner
                    endGameReason = "反則勝ち"
                    resultSummary = "\(winner.label)の勝ち（反則）"
                } else if moveText.hasPrefix("反則負け") {
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "反則負け"
                    resultSummary = "\(winner.label)の勝ち（反則）"
                } else if moveText.hasPrefix("TIME_UP") || moveText.hasPrefix("切れ負け") {
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "時間切れ"
                    resultSummary = "\(winner.label)の勝ち（時間切れ）"
                } else if moveText.hasPrefix("反則") {
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "反則"
                    resultSummary = "\(winner.label)の勝ち（反則）"
                } else if moveText.hasPrefix("持将棋") {
                    isInterrupted = true
                    resultSummary = "持将棋（引き分け）"
                } else if moveText.hasPrefix("千日手") {
                    isSennichite  = true
                    resultSummary = "千日手（引き分け）"
                } else {
                    isInterrupted = true
                    resultSummary = "対局中断"
                }
                break
            }

            guard num == rawMoves.count + 1 else { continue }
            let player: ShogiPlayer = num % 2 == 1 ? .sente : .gote
            rawMoves.append(RawMove(number: num, text: moveText, player: player))
        }

        if let existingFrom = currentVariationFromMove {
            variations.append(KifVariationBlock(fromMove: existingFrom, lines: currentVariationLines))
        }

        let extendedData = KifExtendedData(
            headers: headers,
            commentsByMove: commentsByMove,
            timeTextByMove: timeTextByMove,
            variations: variations
        )

        return try executeMoves(
            rawMoves:       rawMoves.map { ($0.text, $0.player) },
            handicap:       handicap,
            endGameWinner:  endGameWinner,
            endGameReason:  endGameReason,
            isSennichite:   isSennichite,
            isInterrupted:  isInterrupted,
            resultSummary:  resultSummary,
            playerSente:    playerSente,
            playerGote:     playerGote,
            gameDate:       gameDate,
            isKIF:          true,
            extendedData:   extendedData,
            upToMoveCount:  upToMoveCount,
            includeHistory: includeHistory
        )
    }

    // MARK: - CSA Parser

    private static func parseCSA(
        _ text: String,
        upToMoveCount: Int?,
        includeHistory: Bool
    ) throws -> ParseResult {
        let lines = text.components(separatedBy: "\n")

        var playerSente = "先手"
        var playerGote  = "後手"
        var resultSummary = "不明"
        var endGameWinner: ShogiPlayer? = nil
        var endGameReason = ""
        var isSennichite  = false
        var isInterrupted = false

        struct RawMove {
            let text: String
            let player: ShogiPlayer
        }
        var rawMoves: [RawMove] = []

        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }

            if t.hasPrefix("N+") { playerSente = String(t.dropFirst(2)) }
            else if t.hasPrefix("N-") { playerGote = String(t.dropFirst(2)) }
            else if t.hasPrefix("+") || t.hasPrefix("-") {
                // +FFTTPP or -FFTTPP
                let player: ShogiPlayer = t.hasPrefix("+") ? .sente : .gote
                rawMoves.append(RawMove(text: t, player: player))
            } else if t.hasPrefix("%") {
                // CSA終局種別（仕様書記載の全バリアント対応）
                // 直前の手を指したプレイヤーが lastPlayer
                let lastPlayer: ShogiPlayer = rawMoves.count % 2 == 0 ? .gote : .sente
                if t.hasPrefix("%TORYO") {
                    // 投了: lastPlayer が負け
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "投了"
                    resultSummary = "\(winner.label)の勝ち（投了）"
                } else if t.hasPrefix("%TSUMI") {
                    // 詰み: lastPlayer が詰めた → 勝者
                    let winner = lastPlayer
                    endGameWinner = winner
                    endGameReason = "詰み"
                    resultSummary = "\(winner.label)の勝ち（詰み）"
                } else if t.hasPrefix("%KACHI") {
                    // 入玉勝ち宣言: 宣言したプレイヤー（lastPlayer）が勝者
                    let winner = lastPlayer
                    endGameWinner = winner
                    endGameReason = "入玉勝ち宣言"
                    resultSummary = "\(winner.label)の勝ち（入玉勝ち宣言）"
                } else if t.hasPrefix("%ILLEGAL_MOVE") {
                    // 反則手: lastPlayer の反則 → 相手が勝者
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "反則"
                    resultSummary = "\(winner.label)の勝ち（反則）"
                } else if t.hasPrefix("%TIME_UP") {
                    // 時間切れ: lastPlayer の手番で時間切れ → 相手が勝者
                    let winner = lastPlayer.opposite
                    endGameWinner = winner
                    endGameReason = "時間切れ"
                    resultSummary = "\(winner.label)の勝ち（時間切れ）"
                } else if t.hasPrefix("%SENNICHITE") {
                    isSennichite  = true
                    resultSummary = "千日手（引き分け）"
                } else if t.hasPrefix("%JISHOGI") {
                    // 持将棋: 引き分け
                    isInterrupted = true
                    resultSummary = "持将棋（引き分け）"
                } else if t.hasPrefix("%MAX_MOVES") || t.hasPrefix("%HIKIWAKE") {
                    // 最大手数・引き分け宣言
                    isInterrupted = true
                    resultSummary = "引き分け（最大手数）"
                } else if t.hasPrefix("%CHUDAN") {
                    isInterrupted = true
                    resultSummary = "対局中断"
                }
                break
            }
        }

        return try executeMoves(
            rawMoves:      rawMoves.map { ($0.text, $0.player) },
            handicap:      .none,
            endGameWinner: endGameWinner,
            endGameReason: endGameReason,
            isSennichite:  isSennichite,
            isInterrupted: isInterrupted,
            resultSummary: resultSummary,
            playerSente:   playerSente,
            playerGote:    playerGote,
            gameDate:      Date(),
            isKIF:         false,
            extendedData:  nil,
            upToMoveCount: upToMoveCount,
            includeHistory: includeHistory
        )
    }

    // MARK: - Move Execution

    private static func executeMoves(
        rawMoves:      [(text: String, player: ShogiPlayer)],
        handicap:      Handicap,
        endGameWinner: ShogiPlayer?,
        endGameReason: String,
        isSennichite:  Bool,
        isInterrupted: Bool,
        resultSummary: String,
        playerSente:   String,
        playerGote:    String,
        gameDate:      Date,
        isKIF:         Bool,
        extendedData:  KifExtendedData?,
        upToMoveCount: Int?,
        includeHistory: Bool
    ) throws -> ParseResult {

        var board       = initialBoard(handicap: handicap)
        var senteHand:  [ShogiPieceType: Int] = [:]
        var goteHand:   [ShogiPieceType: Int] = [:]
        var moveRecords: [String] = []
        var moveHistory: [ShogiGameSnapshot] = []
        let effectiveMoveCount = min(max(upToMoveCount ?? rawMoves.count, 0), rawMoves.count)
        let effectiveRawMoves = Array(rawMoves.prefix(effectiveMoveCount))
        let reachedFinalMove = effectiveMoveCount == rawMoves.count

        // 初期スナップショット（手 0）
        if includeHistory {
            moveHistory.append(makeSnapshot(
                board: board, senteHand: senteHand, goteHand: goteHand,
                turn: .sente, winner: nil, winReason: "",
                isSennichite: false, isInterrupted: false,
                positionCounts: [:], moveRecords: []
            ))
        }

        var lastDest: (row: Int, col: Int)? = nil

        for (i, (text, player)) in effectiveRawMoves.enumerated() {
            let isLast = reachedFinalMove && i == effectiveRawMoves.count - 1

            guard let parsedMove = isKIF
                ? parseKIFMoveText(text, lastDest: lastDest)
                : parseCSAMoveText(text, player: player)
            else { continue }

            let result = applyMove(
                parsedMove,
                board:      board,
                senteHand:  senteHand,
                goteHand:   goteHand,
                player:     player
            )
            board      = result.board
            senteHand  = result.senteHand
            goteHand   = result.goteHand
            moveRecords.append(result.record)
            lastDest = (parsedMove.toRow, parsedMove.toCol)

            let snap = makeSnapshot(
                board:          board,
                senteHand:      senteHand,
                goteHand:       goteHand,
                turn:           player.opposite,
                winner:         isLast ? endGameWinner : nil,
                winReason:      isLast ? endGameReason : "",
                isSennichite:   isLast ? isSennichite  : false,
                isInterrupted:  isLast ? isInterrupted : false,
                positionCounts: [:],
                moveRecords:    moveRecords
            )
            if includeHistory {
                moveHistory.append(snap)
            }
        }

        // moveHistory 最後の要素が finalSnapshot
        let finalSnapshot = moveHistory.last ?? makeSnapshot(
            board: board, senteHand: senteHand, goteHand: goteHand,
            turn: effectiveRawMoves.last?.player.opposite ?? .sente,
            winner: reachedFinalMove ? endGameWinner : nil,
            winReason: reachedFinalMove ? endGameReason : "",
            isSennichite: reachedFinalMove ? isSennichite : false,
            isInterrupted: reachedFinalMove ? isInterrupted : false,
            positionCounts: [:], moveRecords: moveRecords
        )

        // PersistedShogiGameRecord は
        //   snapshot   = 最終局面
        //   moveHistory = includeHistory=true の場合のみ手0〜手(N-1) のスナップショット
        //                 includeHistory=false の場合は nil（メモリ節約のため lazy 生成）
        let record = PersistedShogiGameRecord(
            snapshot:    finalSnapshot,
            moveHistory: includeHistory ? Array(moveHistory.dropLast()) : nil,
            savedAt:     gameDate,
            kifExtendedData: extendedData
        )

        return ParseResult(
            playerSente:   playerSente,
            playerGote:    playerGote,
            resultSummary: resultSummary,
            record:        record
        )
    }

    // MARK: - KIF Move Text Parser

    /// KIF形式の指し手文字列を解析する
    /// 例: "７六歩(77)"  "同　歩(56)成"  "５五歩打"
    private static func parseKIFMoveText(
        _ text: String,
        lastDest: (row: Int, col: Int)?
    ) -> ParsedKifMove? {

        let chars = Array(text)
        var idx = 0

        // 1. 到達マス
        var toRow: Int
        var toCol: Int

        if idx < chars.count, chars[idx] == "同" {
            guard let last = lastDest else { return nil }
            toRow = last.row
            toCol = last.col
            idx += 1
            // "同　" の全角スペースや半角スペースをスキップ
            while idx < chars.count, chars[idx] == "　" || chars[idx] == " " {
                idx += 1
            }
        } else if idx + 1 < chars.count,
                  let col = fullWidthDigit(chars[idx]),
                  let row = kanjiRow(chars[idx + 1]) {
            toCol = 9 - col   // KIF列 → 内部列インデックス
            toRow = row - 1   // KIF段 → 内部行インデックス
            idx += 2
        } else {
            return nil
        }

          // 2. 駒種（成銀・成桂・成香・成歩など2文字も考慮）
          guard idx < chars.count else { return nil }
          let tail = String(chars[idx...])
          guard let match = pieceSymbolPrefix(in: tail) else { return nil }
          let pieceType = match.type
          let isSymbolPromoted = match.isPromoted
          idx += match.length

        // 3. 残り字句を順序非依存で解析
        //    例: "(77)成" / "成(77)" / "打" / "不成(88)"
        var fromRow: Int? = nil
        var fromCol: Int? = nil
        var isDrop = false
        var promote = false

        let remainder = idx < chars.count ? String(chars[idx...]) : ""

        if remainder.contains("打") {
            isDrop = true
        }

        // 移動元（括弧内2桁）
        if let open = remainder.firstIndex(of: "("),
           let close = remainder[open...].firstIndex(of: ")") {
            let coord = String(remainder[remainder.index(after: open)..<close])
            let digits = Array(coord)
            if digits.count >= 2,
               let fcKif = digits[0].wholeNumberValue,
               let frKif = digits[1].wholeNumberValue {
                fromCol = 9 - fcKif
                fromRow = frKif - 1
            }
        }

        // 成／不成（順序に依存しない）
        if remainder.contains("不成") {
            promote = false
        } else if remainder.contains("成") {
            promote = true
        }

        return ParsedKifMove(
            toRow: toRow, toCol: toCol,
            fromRow: fromRow, fromCol: fromCol,
            isDrop: isDrop, promote: promote,
            parsedPieceType: pieceType,
            parsedIsPromoted: isSymbolPromoted
        )
    }

    // MARK: - CSA Move Text Parser

    /// CSA形式の指し手文字列を解析する
    /// 例: "+7776FU"  "-3334FU"  "+0055FU" (打ち)
    private static func parseCSAMoveText(
        _ text: String,
        player: ShogiPlayer
    ) -> ParsedKifMove? {

        // フォーマット: [+-]FFTTPP (計 7 文字)
        var s = text.trimmingCharacters(in: .whitespaces)
        guard s.count >= 7 else { return nil }
        s = String(s.dropFirst())   // +/- を除く

        let chars = Array(s)
        guard chars.count >= 6,
              let fcKif  = chars[0].wholeNumberValue,
              let frKif  = chars[1].wholeNumberValue,
              let tcKif  = chars[2].wholeNumberValue,
              let trKif  = chars[3].wholeNumberValue else { return nil }

        let pieceCode = String(chars[4...5])
        guard let (pieceType, isPromoted) = csaPieceCode(pieceCode) else { return nil }

        let toCol = 9 - tcKif
        let toRow = trKif - 1
        let isDrop = fcKif == 0 && frKif == 0

        return ParsedKifMove(
            toRow: toRow, toCol: toCol,
            fromRow: isDrop ? nil : frKif - 1,
            fromCol: isDrop ? nil : 9 - fcKif,
            isDrop: isDrop, promote: false,
            parsedPieceType: pieceType,
            parsedIsPromoted: isPromoted
        )
    }

    // MARK: - Move Application

    private static func applyMove(
        _ move: ParsedKifMove,
        board: [[ShogiPiece?]],
        senteHand: [ShogiPieceType: Int],
        goteHand:  [ShogiPieceType: Int],
        player: ShogiPlayer
    ) -> (board: [[ShogiPiece?]], senteHand: [ShogiPieceType: Int],
          goteHand: [ShogiPieceType: Int], record: String) {

        var newBoard     = board
        var newSenteHand = senteHand
        var newGoteHand  = goteHand

        guard isInsideBoard(move.toRow, move.toCol) else {
            return (newBoard, newSenteHand, newGoteHand, "?")
        }

        let to = BoardSquare(row: move.toRow, col: move.toCol)

        if move.isDrop {
            // --- 打ち駒 ---
            let piece = ShogiPiece(owner: player, type: move.parsedPieceType, isPromoted: false)
            newBoard[to.row][to.col] = piece

            if player == .sente {
                newSenteHand[move.parsedPieceType, default: 0] -= 1
                if newSenteHand[move.parsedPieceType, default: 0] <= 0 {
                    newSenteHand.removeValue(forKey: move.parsedPieceType)
                }
            } else {
                newGoteHand[move.parsedPieceType, default: 0] -= 1
                if newGoteHand[move.parsedPieceType, default: 0] <= 0 {
                    newGoteHand.removeValue(forKey: move.parsedPieceType)
                }
            }

            let record = formatDropRecord(player: player, type: move.parsedPieceType, to: to)
            return (newBoard, newSenteHand, newGoteHand, record)

        } else {
            // --- 通常移動 ---
            guard let fromRow = move.fromRow, let fromCol = move.fromCol else {
                return (newBoard, newSenteHand, newGoteHand, "?")
            }
            guard isInsideBoard(fromRow, fromCol) else {
                return (newBoard, newSenteHand, newGoteHand, "?")
            }
            let from = BoardSquare(row: fromRow, col: fromCol)

            // 移動元の駒（ボード状態を優先、なければ解析値で代替）
            let movingPiece = board[fromRow][fromCol]
                ?? ShogiPiece(owner: player, type: move.parsedPieceType, isPromoted: move.parsedIsPromoted)

            // 取得駒をコマの手駒に追加
            let capturedPiece = board[to.row][to.col]
            if let captured = capturedPiece {
                if player == .sente {
                    newSenteHand[captured.type, default: 0] += 1
                } else {
                    newGoteHand[captured.type, default: 0] += 1
                }
            }

            // 移動・成り
            newBoard[fromRow][fromCol] = nil
            let finalPiece = move.promote
                ? ShogiPiece(owner: movingPiece.owner, type: movingPiece.type, isPromoted: true)
                : movingPiece
            newBoard[to.row][to.col] = finalPiece

            let record = formatMoveRecord(
                player: player, piece: movingPiece, from: from, to: to,
                captured: capturedPiece, promote: move.promote
            )
            return (newBoard, newSenteHand, newGoteHand, record)
        }
    }

    private static func isInsideBoard(_ row: Int, _ col: Int) -> Bool {
        (0..<9).contains(row) && (0..<9).contains(col)
    }

    // MARK: - Snapshot Builder

    private static func makeSnapshot(
        board: [[ShogiPiece?]],
        senteHand: [ShogiPieceType: Int],
        goteHand:  [ShogiPieceType: Int],
        turn: ShogiPlayer,
        winner: ShogiPlayer?,
        winReason: String,
        isSennichite: Bool,
        isInterrupted: Bool,
        positionCounts: [String: Int],
        moveRecords: [String]
    ) -> ShogiGameSnapshot {
        ShogiGameSnapshot(
            board: board,
            selected: nil,
            selectedDropType: nil,
            senteHand: senteHand,
            goteHand:  goteHand,
            pendingPromotionMove: nil,
            turn: turn,
            winner: winner,
            winReason: winReason,
            isSennichite: isSennichite,
            isInterrupted: isInterrupted,
            positionCounts: positionCounts,
            moveRecords: moveRecords
        )
    }

    // MARK: - Coordinate / Piece Helpers

    /// 全角数字 → 1〜9 (それ以外は nil)
    private static func fullWidthDigit(_ c: Character) -> Int? {
        guard let scalar = c.unicodeScalars.first else { return nil }
        let v = Int(scalar.value)
        guard v >= 0xFF11 && v <= 0xFF19 else { return nil }
        return v - 0xFF11 + 1
    }

    /// 漢数字 → 1〜9 (それ以外は nil)
    private static func kanjiRow(_ c: Character) -> Int? {
        switch c {
        case "一": return 1
        case "二": return 2
        case "三": return 3
        case "四": return 4
        case "五": return 5
        case "六": return 6
        case "七": return 7
        case "八": return 8
        case "九": return 9
        default:   return nil
        }
    }

    /// KIF駒記号 → (ShogiPieceType, isPromoted)
    private static func pieceSymbolPrefix(in text: String) -> (type: ShogiPieceType, isPromoted: Bool, length: Int)? {
        let candidates: [(String, ShogiPieceType, Bool)] = [
            ("成銀", .silver, true),
            ("成桂", .knight, true),
            ("成香", .lance, true),
            ("成歩", .pawn, true),
            ("王", .king, false),
            ("玉", .king, false),
            ("金", .gold, false),
            ("銀", .silver, false),
            ("桂", .knight, false),
            ("香", .lance, false),
            ("角", .bishop, false),
            ("飛", .rook, false),
            ("歩", .pawn, false),
            ("全", .silver, true),
            ("圭", .knight, true),
            ("杏", .lance, true),
            ("馬", .bishop, true),
            ("龍", .rook, true),
            ("竜", .rook, true),
            ("と", .pawn, true)
        ]

        for (symbol, type, isPromoted) in candidates {
            if text.hasPrefix(symbol) {
                return (type, isPromoted, symbol.count)
            }
        }
        return nil
    }

    /// CSA駒コード → (ShogiPieceType, isPromoted)
    private static func csaPieceCode(_ code: String) -> (ShogiPieceType, Bool)? {
        switch code {
        case "FU": return (.pawn,   false)
        case "KY": return (.lance,  false)
        case "KE": return (.knight, false)
        case "GI": return (.silver, false)
        case "KI": return (.gold,   false)
        case "KA": return (.bishop, false)
        case "HI": return (.rook,   false)
        case "OU": return (.king,   false)
        case "TO": return (.pawn,   true)
        case "NY": return (.lance,  true)
        case "NK": return (.knight, true)
        case "NG": return (.silver, true)
        case "UM": return (.bishop, true)
        case "RY": return (.rook,   true)
        default:   return nil
        }
    }

    // MARK: - Header Helpers

    private static func headerValue(_ line: String, _ key: String) -> String? {
        for sep in ["\(key)：", "\(key):"] {
            if line.hasPrefix(sep) {
                let v = String(line.dropFirst(sep.count)).trimmingCharacters(in: .whitespaces)
                return v.isEmpty ? nil : v
            }
        }
        return nil
    }

    private static func firstHeaderSeparatorIndex(in line: String) -> String.Index? {
        if let i = line.firstIndex(of: "：") { return i }
        if let i = line.firstIndex(of: ":") { return i }
        return nil
    }

    private static func variationStartMove(from line: String) -> Int? {
        guard line.hasPrefix("変化：") else { return nil }
        let payload = line.replacingOccurrences(of: "変化：", with: "")
        let digits = payload.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private static func extractKifTimeText(from afterMoveText: String) -> String? {
        guard let open = afterMoveText.firstIndex(of: "("),
              let close = afterMoveText[open...].firstIndex(of: ")") else {
            return nil
        }
        let raw = String(afterMoveText[afterMoveText.index(after: open)..<close])
            .trimmingCharacters(in: .whitespaces)
        guard raw.contains("/") else { return nil }
        return raw
    }

    private static func handicapFromKIF(_ value: String) -> Handicap {
        switch value {
        case "香落ち":  return .lance
        case "角落ち":  return .bishop
        case "飛車落ち": return .rook
        case "二枚落ち": return .twoPieces
        case "四枚落ち": return .fourPieces
        case "六枚落ち": return .sixPieces
        default:       return .none
        }
    }

    private static func initialBoard(handicap: Handicap = .none) -> [[ShogiPiece?]] {
        var board = Array(repeating: Array(repeating: nil as ShogiPiece?, count: 9), count: 9)

        let backRow: [ShogiPieceType] = [.lance, .knight, .silver, .gold, .king, .gold, .silver, .knight, .lance]

        for col in 0..<9 {
            board[0][col] = ShogiPiece(owner: .gote, type: backRow[col])
            board[2][col] = ShogiPiece(owner: .gote, type: .pawn)
            board[6][col] = ShogiPiece(owner: .sente, type: .pawn)
            board[8][col] = ShogiPiece(owner: .sente, type: backRow[col])
        }

        board[1][1] = ShogiPiece(owner: .gote, type: .rook)
        board[1][7] = ShogiPiece(owner: .gote, type: .bishop)
        board[7][1] = ShogiPiece(owner: .sente, type: .bishop)
        board[7][7] = ShogiPiece(owner: .sente, type: .rook)

        switch handicap {
        case .none:
            break
        case .lance:
            board[8][8] = nil
        case .bishop:
            board[7][1] = nil
        case .rook:
            board[7][7] = nil
        case .twoPieces:
            board[7][7] = nil
            board[7][1] = nil
        case .fourPieces:
            board[7][7] = nil
            board[7][1] = nil
            board[8][0] = nil
            board[8][8] = nil
        case .sixPieces:
            board[7][7] = nil
            board[7][1] = nil
            board[8][0] = nil
            board[8][8] = nil
            board[8][1] = nil
            board[8][7] = nil
        }

        return board
    }

    private static func squareNotation(_ square: BoardSquare) -> String {
        let rankText = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
        return "\(9 - square.col)\(rankText[square.row])"
    }

    private static func formatMoveRecord(
        player: ShogiPlayer,
        piece: ShogiPiece,
        from: BoardSquare,
        to: BoardSquare,
        captured: ShogiPiece?,
        promote: Bool
    ) -> String {
        let action = captured == nil ? "→" : "×"
        let promoteText = promote && piece.type.canPromote ? "成" : ""
        return "\(player.label) \(squareNotation(from)) \(piece.displaySymbol) \(action) \(squareNotation(to))\(promoteText)"
    }

    private static func formatDropRecord(
        player: ShogiPlayer,
        type: ShogiPieceType,
        to: BoardSquare
    ) -> String {
        "\(player.label) \(type.symbol) 打 \(squareNotation(to))"
    }

    private static func parseDateString(_ s: String) -> Date? {
        let formats = [
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "yyyy年M月d日 HH:mm:ss",
            "yyyy年M月d日 H:mm:ss",
            "yyyy年M月d日 HH:mm",
            "yyyy年M月d日 H:mm",
            "yyyy年M月d日"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        for fmt in formats {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}

// MARK: - ParsedKifMove (内部DTO)

private struct ParsedKifMove {
    let toRow: Int
    let toCol: Int
    let fromRow: Int?
    let fromCol: Int?
    let isDrop: Bool
    let promote: Bool
    let parsedPieceType: ShogiPieceType
    let parsedIsPromoted: Bool
}
