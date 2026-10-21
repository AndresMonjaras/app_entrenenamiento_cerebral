import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF172C34);
  static const muted = Color(0xFF74817E);
  static const green = Color(0xFF287C61);
  static const mint = Color(0xFFDEF3E8);
  static const background = Color(0xFFF6F7F4);
  static const line = Color(0xFFE4E8E2);
  static const amber = Color(0xFFC98931);
  static const purple = Color(0xFF8472B6);
  static const coral = Color(0xFFD47D65);
}

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'FiraSans',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.green,
    primary: AppColors.green,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
    outline: AppColors.line,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 40,
      height: 1.12,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -.8,
    ),
    titleLarge: TextStyle(
      fontSize: 23,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -.5,
    ),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      minimumSize: const Size(48, 50),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: AppColors.mint,
  ),
);

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );
}

class SmallTag extends StatelessWidget {
  const SmallTag(
    this.text, {
    super.key,
    this.color = AppColors.green,
    this.background = AppColors.mint,
  });
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: .2,
      ),
    ),
  );
}

bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

Route<T> appRoute<T>(Widget child) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => child,
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (reduceMotion(context)) return child;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .025), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  },
);
