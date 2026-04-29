import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';

class AppLaunchSplash extends StatefulWidget {
  const AppLaunchSplash({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<AppLaunchSplash> createState() => _AppLaunchSplashState();
}

class _AppLaunchSplashState extends State<AppLaunchSplash> {
  static const _normalVisibleDuration = Duration(milliseconds: 2750);
  static const _normalFadeDuration = Duration(milliseconds: 520);
  static const _reducedVisibleDuration = Duration(milliseconds: 1350);
  static const _reducedFadeDuration = Duration(milliseconds: 360);

  double _markScale = 0.92;
  double _lineRevealOpacity = 0;
  double _lineGlowOpacity = 0;
  double _glowOpacity = 0;
  double _overlayOpacity = 1;
  double _lineGlowBlur = 14;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startAnimation();
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      setState(() {
        _markScale = 1;
        _lineRevealOpacity = 1;
        _lineGlowOpacity = 0.10;
        _lineGlowBlur = 8;
        _glowOpacity = 0.18;
      });
      _finishTimer = Timer(_reducedVisibleDuration, () {
        if (!mounted) {
          return;
        }
        setState(() {
          _overlayOpacity = 0;
        });
        Timer(_reducedFadeDuration, widget.onFinished);
      });
      return;
    }

    setState(() {
      _lineRevealOpacity = 1;
      _markScale = 1;
      _lineGlowOpacity = 0.26;
      _lineGlowBlur = 6;
      _glowOpacity = 0.24;
    });

    Timer(const Duration(milliseconds: 1240), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _lineGlowOpacity = 0.12;
        _lineGlowBlur = 9;
      });
    });

    _finishTimer = Timer(_normalVisibleDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _overlayOpacity = 0;
      });
      Timer(_normalFadeDuration, widget.onFinished);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _overlayOpacity,
        duration: (_overlayOpacity == 0)
            ? ((MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                ? _reducedFadeDuration
                : _normalFadeDuration)
            : Duration.zero,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: _markScale * 1.04,
                  duration: const Duration(milliseconds: 920),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _glowOpacity,
                    duration: const Duration(milliseconds: 900),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x38FFFFFF),
                      ),
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: _markScale,
                  duration: const Duration(milliseconds: 920),
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    width: 270,
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: _lineGlowOpacity,
                          duration: const Duration(milliseconds: 950),
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: _lineGlowBlur, sigmaY: _lineGlowBlur),
                            child: const _LaunchLogoMark(color: Colors.white),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _lineRevealOpacity,
                          duration: const Duration(milliseconds: 1900),
                          curve: Curves.easeOut,
                          child: const _LaunchLogoMark(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchLogoMark extends StatelessWidget {
  const _LaunchLogoMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(color: color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '87',
            style: TextStyle(
              fontSize: 164,
              fontWeight: FontWeight.w900,
              height: 0.9,
            ),
          ),
          Text(
            '吹棋',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              height: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}