import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../shared/theme/app_theme.dart';

class ShogiApp extends StatelessWidget {
  const ShogiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '87 Shogi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}