import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The bundled emoji font, as the last resort for a character the text font
/// has no glyph for.
///
/// It has to be bundled. The system's own Apple Color Emoji is present and
/// resolvable on iOS, but Impeller draws nothing for it — every emoji came out
/// an empty box, including in text the assistant wrote and the app cannot
/// edit. Noto's vector colour glyphs draw correctly, measured on the simulator
/// 2026-09-22.
///
/// Only ever a fallback: the primary family stays unset, so Latin and Thai are
/// still the platform's own font and nothing about the app's typography moves.
const _emojiFont = 'NotoColorEmoji';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.screen,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      // Both, because a Text with no style of its own inherits from whichever
      // one the surrounding Material made the default.
      textTheme: base.textTheme.apply(fontFamilyFallback: const [_emojiFont]),
      primaryTextTheme:
          base.primaryTextTheme.apply(fontFamilyFallback: const [_emojiFont]),
      scaffoldBackgroundColor: AppColors.softScreen,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.softScreen,
        foregroundColor: AppColors.foreground,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.screen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
