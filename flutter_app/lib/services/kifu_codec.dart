import '../domain/models/shogi_models.dart';

class KifuCodec {
  static String encode(PersistedShogiGameRecord record) {
    final headers = record.kifExtendedData?.headers ?? const <String, String>{};
    final senteName = headers['先手'] ?? '先手';
    final goteName = headers['後手'] ?? '後手';
    final handicap = headers['手合割'] ?? '平手';
    final startedAt = headers['開始日時'] ?? _formatDate(record.savedAt);
    final lines = <String>[
      '開始日時：$startedAt',
      '手合割：$handicap',
      '先手：$senteName',
      '後手：$goteName',
      '結果：${record.snapshot.resultSummary}',
      '手数----指手---------',
    ];

    final standardMoves = record.snapshot.moveRecords.map(_standardKifMove).toList(growable: false);
    for (var index = 0; index < standardMoves.length; index++) {
      lines.add('${index + 1} ${standardMoves[index]}');
    }

    final terminal = _terminalMoveText(record.snapshot);
    if (terminal != null) {
      lines.add('${standardMoves.length + 1} $terminal');
    }

    return lines.join('\n');
  }

  static String fileName(PersistedShogiGameRecord record) {
    final timestamp = _formatFileDate(record.savedAt);
    return 'record_${timestamp}_${record.snapshot.moveRecords.length}手.kif';
  }

  static String _standardKifMove(String record) {
    final parts = record.split(' ');
    if (parts.length == 4 && parts[2] == '打') {
      return '${_toStandardDestination(parts[3])}${parts[1]}打';
    }
    if (parts.length == 5) {
      final from = _toSourceCoordinate(parts[1]);
      final piece = parts[2];
      final destinationPart = parts[4];
      final promoteSuffix = destinationPart.endsWith('成') ? '成' : '';
      final destinationBase = promoteSuffix.isEmpty
          ? destinationPart
          : destinationPart.substring(0, destinationPart.length - 1);
      return '${_toStandardDestination(destinationBase)}$piece($from)$promoteSuffix';
    }
    return record;
  }

  static String _toStandardDestination(String square) {
    if (square.isEmpty) {
      return square;
    }
    if (square.length == 1) {
      return _fullWidth(square[0]);
    }
    return '${_fullWidth(square[0])}${_rowKanji(square[1])}';
  }

  static String _toSourceCoordinate(String square) {
    if (square.isEmpty) {
      return square;
    }
    return '${square[0]}${_rowNumber(square.substring(1))}';
  }

  static String _rowNumber(String value) {
    switch (value) {
      case '一':
        return '1';
      case '二':
        return '2';
      case '三':
        return '3';
      case '四':
        return '4';
      case '五':
        return '5';
      case '六':
        return '6';
      case '七':
        return '7';
      case '八':
        return '8';
      case '九':
        return '9';
      default:
        return value;
    }
  }

  static String _rowKanji(String value) {
    switch (value) {
      case '1':
        return '一';
      case '2':
        return '二';
      case '3':
        return '三';
      case '4':
        return '四';
      case '5':
        return '五';
      case '6':
        return '六';
      case '7':
        return '七';
      case '8':
        return '八';
      case '9':
        return '九';
      default:
        return value;
    }
  }

  static String _fullWidth(String value) {
    switch (value) {
      case '1':
        return '１';
      case '2':
        return '２';
      case '3':
        return '３';
      case '4':
        return '４';
      case '5':
        return '５';
      case '6':
        return '６';
      case '7':
        return '７';
      case '8':
        return '８';
      case '9':
        return '９';
      default:
        return value;
    }
  }

  static String? _terminalMoveText(ShogiGameSnapshot snapshot) {
    if (snapshot.isSennichite) {
      return '千日手';
    }
    if (snapshot.isInterrupted) {
      return snapshot.winReason == '持将棋' ? '持将棋' : '中断';
    }
    if (snapshot.winner != null) {
      switch (snapshot.winReason) {
        case '投了':
          return '投了';
        case '詰み':
          return '詰み';
        case '時間切れ':
          return 'TIME_UP';
        case '王取り':
          return '王取り';
        default:
          return snapshot.winReason.isEmpty ? null : snapshot.winReason;
      }
    }
    return null;
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  static String _formatFileDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}${two(date.month)}${two(date.day)}_${two(date.hour)}${two(date.minute)}${two(date.second)}';
  }
}