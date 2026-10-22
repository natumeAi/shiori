import 'package:flutter/material.dart';

/// Material 3 light and dark themes generated from a single seed color.
abstract final class AppTheme {
  static const _seedColor = Colors.deepPurple;

  static final light = ThemeData(colorScheme: .fromSeed(seedColor: _seedColor));

  static final dark = ThemeData(
    colorScheme: .fromSeed(seedColor: _seedColor, brightness: .dark),
  );
}
