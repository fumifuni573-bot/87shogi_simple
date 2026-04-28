import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/logic/clock_logic.dart';

void main() {
  test('displaySeconds prefers main time while positive', () {
    expect(
      ClockLogic.displaySeconds(main: 15, byoYomiRemaining: 5, byoYomiSeconds: 30),
      15,
    );
  });

  test('preparedByoYomiRemaining starts only when main is exhausted', () {
    expect(ClockLogic.preparedByoYomiRemaining(main: 0, byoYomiSeconds: 30), 30);
    expect(ClockLogic.preparedByoYomiRemaining(main: 1, byoYomiSeconds: 30), isNull);
  });

  test('consumeByoYomi clamps at zero and reports death', () {
    final result = ClockLogic.consumeByoYomi(
      currentRemaining: 10,
      byoYomiSeconds: 30,
      elapsed: 12,
    );
    expect(result.remaining, 0);
    expect(result.alive, isFalse);
  });
}