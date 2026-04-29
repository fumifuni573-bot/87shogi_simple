import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/app/app_launch_splash.dart';
import 'package:flutter_app/app/shogi_app.dart';

void main() {
  testWidgets('app shows splash then home actions', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShogiApp()));
    await tester.pump();

    expect(find.byType(AppLaunchSplash), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();

    expect(find.text('対局'), findsOneWidget);
    expect(find.text('棋譜'), findsOneWidget);
    expect(find.text('URL登録'), findsOneWidget);
  });

  testWidgets('timer action opens standalone timer screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShogiApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('タイマー'));
    await tester.tap(find.text('タイマー'));
    await tester.pumpAndSettle();

    expect(find.text('タイマー設定'), findsOneWidget);
    expect(find.text('Player 1'), findsWidgets);
    expect(find.text('Player 2'), findsWidgets);
  });
}
