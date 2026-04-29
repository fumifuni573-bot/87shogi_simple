import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/timer/presentation/timer_page.dart';

void main() {
  testWidgets('timer page renders both player panels and center controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TimerPage(showInitialSettingsSheet: false),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
  });
}