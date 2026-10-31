import 'package:flutter/material.dart';

/// Tema central de la app (Material 3), con variantes clara y oscura.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1B6B5A);

  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
