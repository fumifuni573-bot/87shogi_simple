import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/shogi_models.dart';
import '../features/game/state/clock_controller.dart';
import '../features/game/state/game_session_controller.dart';
import '../logic/game_engine.dart';

final gameSnapshotProvider = Provider<ShogiGameSnapshot>((ref) {
  return GameEngine.initialSnapshot();
});

final gameSessionProvider = NotifierProvider<GameSessionController, GameSessionState>(
  GameSessionController.new,
);

final clockControllerProvider = NotifierProvider<ClockController, ClockState>(
  ClockController.new,
);