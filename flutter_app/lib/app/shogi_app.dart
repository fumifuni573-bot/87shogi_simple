import 'package:flutter/material.dart';

import 'app_launch_splash.dart';
import '../features/home/home_page.dart';
import '../shared/theme/app_theme.dart';

class ShogiApp extends StatefulWidget {
  const ShogiApp({super.key});

  @override
  State<ShogiApp> createState() => _ShogiAppState();
}

class _ShogiAppState extends State<ShogiApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '87 Shogi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Stack(
        fit: StackFit.expand,
        children: [
          const HomePage(),
          if (_showSplash)
            AppLaunchSplash(
              onFinished: () {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _showSplash = false;
                });
              },
            ),
        ],
      ),
    );
  }
}