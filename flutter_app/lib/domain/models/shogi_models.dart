enum ShogiPlayer {
  sente,
  gote;

  String get label => this == ShogiPlayer.sente ? '先手' : '後手';

  int get forward => this == ShogiPlayer.sente ? -1 : 1;

  ShogiPlayer get opposite => this == ShogiPlayer.sente ? ShogiPlayer.gote : ShogiPlayer.sente;

  static ShogiPlayer fromJson(String value) => ShogiPlayer.values.byName(value);
}

enum ShogiPieceType {
  king,
  gold,
  silver,
  knight,
  lance,
  bishop,
  rook,
  pawn;

  String get symbol {
    switch (this) {
      case ShogiPieceType.king:
        return '王';
      case ShogiPieceType.gold:
        return '金';
      case ShogiPieceType.silver:
        return '銀';
      case ShogiPieceType.knight:
        return '桂';
      case ShogiPieceType.lance:
        return '香';
      case ShogiPieceType.bishop:
        return '角';
      case ShogiPieceType.rook:
        return '飛';
      case ShogiPieceType.pawn:
        return '歩';
    }
  }

  String get pieceName {
    switch (this) {
      case ShogiPieceType.king:
        return '王将';
      case ShogiPieceType.gold:
        return '金将';
      case ShogiPieceType.silver:
        return '銀将';
      case ShogiPieceType.knight:
        return '桂馬';
      case ShogiPieceType.lance:
        return '香車';
      case ShogiPieceType.bishop:
        return '角行';
      case ShogiPieceType.rook:
        return '飛車';
      case ShogiPieceType.pawn:
        return '歩兵';
    }
  }

  String get promotedSymbol {
    switch (this) {
      case ShogiPieceType.silver:
        return '全';
      case ShogiPieceType.knight:
        return '圭';
      case ShogiPieceType.lance:
        return '杏';
      case ShogiPieceType.pawn:
        return 'と';
      case ShogiPieceType.bishop:
        return '馬';
      case ShogiPieceType.rook:
        return '龍';
      case ShogiPieceType.king:
      case ShogiPieceType.gold:
        return symbol;
    }
  }

  bool get canPromote => this != ShogiPieceType.king && this != ShogiPieceType.gold;

  static const handOrder = <ShogiPieceType>[
    ShogiPieceType.rook,
    ShogiPieceType.bishop,
    ShogiPieceType.gold,
    ShogiPieceType.silver,
    ShogiPieceType.knight,
    ShogiPieceType.lance,
    ShogiPieceType.pawn,
  ];

  static ShogiPieceType fromJson(String value) => ShogiPieceType.values.byName(value);
}

enum GameHandicap {
  none,
  lance,
  bishop,
  rook,
  twoPieces,
  fourPieces,
  sixPieces;
}

enum KifuSourceProvider {
  shogiWars,
  dojo81,
  shogiDB2,
  other;

  String get label {
    switch (this) {
      case KifuSourceProvider.shogiWars:
        return 'ウォーズ';
      case KifuSourceProvider.dojo81:
        return '81道場';
      case KifuSourceProvider.shogiDB2:
        return 'ShogiDB2';
      case KifuSourceProvider.other:
        return 'その他';
    }
  }

  static KifuSourceProvider detect(String urlString) {
    final host = Uri.tryParse(urlString)?.host.toLowerCase() ?? '';
    if (host.contains('wars') || host.contains('shogiwars')) {
      return KifuSourceProvider.shogiWars;
    }
    if (host.contains('81dojo')) {
      return KifuSourceProvider.dojo81;
    }
    if (host.contains('shogidb2') || host.contains('shogidb')) {
      return KifuSourceProvider.shogiDB2;
    }
    return KifuSourceProvider.other;
  }
}

class RegisteredKifuSource {
  const RegisteredKifuSource({
    required this.id,
    required this.urlString,
    required this.createdAt,
  });

  final String id;
  final String urlString;
  final DateTime createdAt;

  String get hostLabel => Uri.tryParse(urlString)?.host ?? 'URL';

  KifuSourceProvider get provider => KifuSourceProvider.detect(urlString);

  Map<String, dynamic> toJson() => {
        'id': id,
        'urlString': urlString,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RegisteredKifuSource.fromJson(Map<String, dynamic> json) {
    return RegisteredKifuSource(
      id: json['id'] as String,
      urlString: json['urlString'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class RegisteredShogiWarsUser {
  const RegisteredShogiWarsUser({
    required this.id,
    required this.username,
    required this.createdAt,
  });

  final String id;
  final String username;
  final DateTime createdAt;

  String get normalizedUsername => username.trim().toLowerCase();

  String get searchUrlString {
    final encoded = Uri.encodeQueryComponent(username);
    return 'https://www.shogi-extend.com/swars/search?query=$encoded&page=1';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RegisteredShogiWarsUser.fromJson(Map<String, dynamic> json) {
    return RegisteredShogiWarsUser(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ShogiPiece {
  const ShogiPiece({
    required this.owner,
    required this.type,
    this.isPromoted = false,
  });

  final ShogiPlayer owner;
  final ShogiPieceType type;
  final bool isPromoted;

  String get displaySymbol => isPromoted ? type.promotedSymbol : type.symbol;

  ShogiPiece copyWith({
    ShogiPlayer? owner,
    ShogiPieceType? type,
    bool? isPromoted,
  }) {
    return ShogiPiece(
      owner: owner ?? this.owner,
      type: type ?? this.type,
      isPromoted: isPromoted ?? this.isPromoted,
    );
  }

  Map<String, dynamic> toJson() => {
        'owner': owner.name,
        'type': type.name,
        'isPromoted': isPromoted,
      };

  factory ShogiPiece.fromJson(Map<String, dynamic> json) {
    return ShogiPiece(
      owner: ShogiPlayer.fromJson(json['owner'] as String),
      type: ShogiPieceType.fromJson(json['type'] as String),
      isPromoted: json['isPromoted'] as bool? ?? false,
    );
  }
}

class BoardSquare {
  const BoardSquare({required this.row, required this.col});

  final int row;
  final int col;

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory BoardSquare.fromJson(Map<String, dynamic> json) {
    return BoardSquare(
      row: json['row'] as int,
      col: json['col'] as int,
    );
  }
}

class PromotionPendingMove {
  const PromotionPendingMove({required this.from, required this.to});

  final BoardSquare from;
  final BoardSquare to;

  Map<String, dynamic> toJson() => {
        'from': from.toJson(),
        'to': to.toJson(),
      };

  factory PromotionPendingMove.fromJson(Map<String, dynamic> json) {
    return PromotionPendingMove(
      from: BoardSquare.fromJson(json['from'] as Map<String, dynamic>),
      to: BoardSquare.fromJson(json['to'] as Map<String, dynamic>),
    );
  }
}

class KifVariationBlock {
  const KifVariationBlock({required this.fromMove, required this.lines});

  final int fromMove;
  final List<String> lines;

  Map<String, dynamic> toJson() => {
        'fromMove': fromMove,
        'lines': lines,
      };

  factory KifVariationBlock.fromJson(Map<String, dynamic> json) {
    return KifVariationBlock(
      fromMove: json['fromMove'] as int,
      lines: List<String>.from(json['lines'] as List<dynamic>),
    );
  }
}

class KifExtendedData {
  const KifExtendedData({
    this.headers = const {},
    this.commentsByMove = const {},
    this.timeTextByMove = const {},
    this.variations = const [],
  });

  final Map<String, String> headers;
  final Map<int, List<String>> commentsByMove;
  final Map<int, String> timeTextByMove;
  final List<KifVariationBlock> variations;

  Map<String, dynamic> toJson() => {
        'headers': headers,
        'commentsByMove': commentsByMove.map((key, value) => MapEntry('$key', value)),
        'timeTextByMove': timeTextByMove.map((key, value) => MapEntry('$key', value)),
        'variations': variations.map((variation) => variation.toJson()).toList(),
      };

  factory KifExtendedData.fromJson(Map<String, dynamic> json) {
    return KifExtendedData(
      headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
      commentsByMove: (json['commentsByMove'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          int.parse(key as String),
          List<String>.from(value as List<dynamic>),
        ),
      ),
      timeTextByMove: (json['timeTextByMove'] as Map? ?? const {}).map(
        (key, value) => MapEntry(int.parse(key as String), value as String),
      ),
      variations: (json['variations'] as List<dynamic>? ?? const [])
          .map((variation) => KifVariationBlock.fromJson(variation as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ShogiGameSnapshot {
  const ShogiGameSnapshot({
    required this.board,
    required this.selected,
    required this.selectedDropType,
    required this.senteHand,
    required this.goteHand,
    required this.pendingPromotionMove,
    required this.turn,
    required this.winner,
    required this.winReason,
    required this.isSennichite,
    required this.isInterrupted,
    required this.positionCounts,
    required this.moveRecords,
  });

  final List<List<ShogiPiece?>> board;
  final BoardSquare? selected;
  final ShogiPieceType? selectedDropType;
  final Map<ShogiPieceType, int> senteHand;
  final Map<ShogiPieceType, int> goteHand;
  final PromotionPendingMove? pendingPromotionMove;
  final ShogiPlayer turn;
  final ShogiPlayer? winner;
  final String winReason;
  final bool isSennichite;
  final bool isInterrupted;
  final Map<String, int> positionCounts;
  final List<String> moveRecords;

  String get resultSummary {
    if (winner != null) {
      return '${winner!.label}の勝ち（$winReason）';
    }
    if (isSennichite) {
      return '千日手（引き分け）';
    }
    if (isInterrupted) {
      return '対局中断';
    }
    return '対局中';
  }

  Map<String, dynamic> toJson() => {
        'board': board
            .map(
            (row) => row.map((piece) => piece?.toJson()).toList(growable: false),
            )
            .toList(growable: false),
        'selected': selected?.toJson(),
        'selectedDropType': selectedDropType?.name,
        'senteHand': senteHand.map((key, value) => MapEntry(key.name, value)),
        'goteHand': goteHand.map((key, value) => MapEntry(key.name, value)),
        'pendingPromotionMove': pendingPromotionMove?.toJson(),
        'turn': turn.name,
        'winner': winner?.name,
        'winReason': winReason,
        'isSennichite': isSennichite,
        'isInterrupted': isInterrupted,
        'positionCounts': positionCounts,
        'moveRecords': moveRecords,
      };

  factory ShogiGameSnapshot.fromJson(Map<String, dynamic> json) {
    return ShogiGameSnapshot(
      board: (json['board'] as List<dynamic>)
          .map(
            (row) => (row as List<dynamic>)
                .map((piece) => piece == null ? null : ShogiPiece.fromJson(piece as Map<String, dynamic>))
                .toList(),
          )
          .toList(),
      selected: json['selected'] == null
          ? null
          : BoardSquare.fromJson(json['selected'] as Map<String, dynamic>),
      selectedDropType: json['selectedDropType'] == null
          ? null
          : ShogiPieceType.fromJson(json['selectedDropType'] as String),
      senteHand: (json['senteHand'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(ShogiPieceType.fromJson(key), value as int)),
      goteHand: (json['goteHand'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(ShogiPieceType.fromJson(key), value as int)),
      pendingPromotionMove: json['pendingPromotionMove'] == null
          ? null
          : PromotionPendingMove.fromJson(json['pendingPromotionMove'] as Map<String, dynamic>),
      turn: ShogiPlayer.fromJson(json['turn'] as String),
      winner: json['winner'] == null ? null : ShogiPlayer.fromJson(json['winner'] as String),
      winReason: json['winReason'] as String? ?? '',
      isSennichite: json['isSennichite'] as bool? ?? false,
      isInterrupted: json['isInterrupted'] as bool? ?? false,
      positionCounts: Map<String, int>.from(json['positionCounts'] as Map? ?? const {}),
      moveRecords: List<String>.from(json['moveRecords'] as List<dynamic>? ?? const []),
    );
  }
}

class PersistedShogiGameRecord {
  const PersistedShogiGameRecord({
    required this.snapshot,
    required this.moveHistory,
    required this.savedAt,
    required this.kifExtendedData,
  });

  final ShogiGameSnapshot snapshot;
  final List<ShogiGameSnapshot>? moveHistory;
  final DateTime savedAt;
  final KifExtendedData? kifExtendedData;

  Map<String, dynamic> toJson() => {
        'snapshot': snapshot.toJson(),
        'moveHistory': moveHistory?.map((entry) => entry.toJson()).toList(),
        'savedAt': savedAt.toIso8601String(),
        'kifExtendedData': kifExtendedData?.toJson(),
      };

  factory PersistedShogiGameRecord.fromJson(Map<String, dynamic> json) {
    return PersistedShogiGameRecord(
      snapshot: ShogiGameSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
      moveHistory: (json['moveHistory'] as List<dynamic>?)
          ?.map((entry) => ShogiGameSnapshot.fromJson(entry as Map<String, dynamic>))
          .toList(),
      savedAt: DateTime.parse(json['savedAt'] as String),
      kifExtendedData: json['kifExtendedData'] == null
          ? null
          : KifExtendedData.fromJson(json['kifExtendedData'] as Map<String, dynamic>),
    );
  }
}