import Foundation

enum GameEngine {
    static func isInside(_ row: Int, _ col: Int) -> Bool {
        (0..<9).contains(row) && (0..<9).contains(col)
    }

    static func initializePositionCountsIfNeeded(
        counts: [String: Int],
        boardState: [[ContentView.Piece?]],
        senteHandState: [ContentView.PieceType: Int],
        goteHandState: [ContentView.PieceType: Int],
        sideToMove: ContentView.Player
    ) -> [String: Int] {
        guard counts.isEmpty else { return counts }
        var updated = counts
        let key = positionKey(
            boardState: boardState,
            senteHandState: senteHandState,
            goteHandState: goteHandState,
            sideToMove: sideToMove
        )
        updated[key] = 1
        return updated
    }

    static func registerPositionAndDetectSennichite(
        counts: [String: Int],
        boardState: [[ContentView.Piece?]],
        senteHandState: [ContentView.PieceType: Int],
        goteHandState: [ContentView.PieceType: Int],
        sideToMove: ContentView.Player
    ) -> (counts: [String: Int], isSennichite: Bool) {
        var updated = counts
        let key = positionKey(
            boardState: boardState,
            senteHandState: senteHandState,
            goteHandState: goteHandState,
            sideToMove: sideToMove
        )
        let newCount = updated[key, default: 0] + 1
        updated[key] = newCount
        return (updated, newCount >= 4)
    }

    static func isGoldLikeMove(dr: Int, dc: Int, forward: Int) -> Bool {
        let moves = [(forward, -1), (forward, 0), (forward, 1), (0, -1), (0, 1), (-forward, 0)]
        return moves.contains { $0.0 == dr && $0.1 == dc }
    }

    static func isPromotionZone(row: Int, owner: ContentView.Player) -> Bool {
        owner == .sente ? (0...2).contains(row) : (6...8).contains(row)
    }

    static func isDeadEndRow(_ row: Int, owner: ContentView.Player) -> Bool {
        owner == .sente ? row == 0 : row == 8
    }

    static func isDeadEndKnightRow(_ row: Int, owner: ContentView.Player) -> Bool {
        owner == .sente ? row <= 1 : row >= 7
    }

    static func isPathClear(
        on boardState: [[ContentView.Piece?]],
        from: ContentView.Square,
        to: ContentView.Square
    ) -> Bool {
        let dr = (to.row - from.row).signum()
        let dc = (to.col - from.col).signum()

        var r = from.row + dr
        var c = from.col + dc

        while r != to.row || c != to.col {
            if boardState[r][c] != nil {
                return false
            }
            r += dr
            c += dc
        }
        return true
    }

    static func squareNotation(_ square: ContentView.Square) -> String {
        let rankText = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
        return "\(9 - square.col)\(rankText[square.row])"
    }

    static func formatMoveRecord(
        player: ContentView.Player,
        piece: ContentView.Piece,
        from: ContentView.Square,
        to: ContentView.Square,
        captured: ContentView.Piece?,
        promote: Bool
    ) -> String {
        let action = captured == nil ? "→" : "×"
        let promoteText = promote && piece.type.canPromote ? "成" : ""
        return "\(player.label) \(squareNotation(from)) \(piece.displaySymbol) \(action) \(squareNotation(to))\(promoteText)"
    }

    static func formatDropRecord(
        player: ContentView.Player,
        type: ContentView.PieceType,
        to: ContentView.Square
    ) -> String {
        "\(player.label) \(type.symbol) 打 \(squareNotation(to))"
    }

    static func resultSummary(for snapshot: ContentView.GameSnapshot) -> String {
        if let winner = snapshot.winner {
            return "\(winner.label)の勝ち（\(snapshot.winReason)）"
        }
        if snapshot.isSennichite {
            return "千日手（引き分け）"
        }
        if snapshot.isInterrupted {
            return "対局中断"
        }
        return "対局中"
    }

    static func positionKey(
        boardState: [[ContentView.Piece?]],
        senteHandState: [ContentView.PieceType: Int],
        goteHandState: [ContentView.PieceType: Int],
        sideToMove: ContentView.Player
    ) -> String {
        var boardPart = ""
        boardPart.reserveCapacity(243)

        for row in 0..<9 {
            for col in 0..<9 {
                if let piece = boardState[row][col] {
                    let ownerCode = piece.owner == .sente ? "S" : "G"
                    let promoCode = piece.isPromoted ? "+" : "-"
                    boardPart += ownerCode + pieceCode(piece.type) + promoCode
                } else {
                    boardPart += "___"
                }
            }
        }

        let sentePart = handKey(for: senteHandState)
        let gotePart = handKey(for: goteHandState)
        let turnPart = sideToMove == .sente ? "S" : "G"

        return "\(turnPart)|\(boardPart)|\(sentePart)|\(gotePart)"
    }

    private static func handKey(for hand: [ContentView.PieceType: Int]) -> String {
        ContentView.PieceType.handOrder
            .map { "\(pieceCode($0))\(hand[$0, default: 0])" }
            .joined(separator: ",")
    }

    private static func pieceCode(_ type: ContentView.PieceType) -> String {
        switch type {
        case .king: return "K"
        case .gold: return "G"
        case .silver: return "S"
        case .knight: return "N"
        case .lance: return "L"
        case .bishop: return "B"
        case .rook: return "R"
        case .pawn: return "P"
        }
    }
}
