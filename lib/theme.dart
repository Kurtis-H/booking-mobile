import 'package:material_ui/material_ui.dart';

/// The website's palette, so the app and the site read as one product: ink and
/// indigo, a color band per event, and seat colors that match the web map.
abstract final class Palette {
  static const background = Color(0xFFF6F5FA);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1A2E);
  static const muted = Color(0xFF5B596E);
  static const line = Color(0xFFE3E1EC);
  static const accent = Color(0xFF4338CA);
  static const accentSoft = Color(0xFFECEAFD);
  static const ok = Color(0xFF157A3C);
  static const okSoft = Color(0xFFE4F4EA);
  static const bad = Color(0xFFB42318);
  static const badSoft = Color(0xFFFDECEA);
  // Seats: available is white with a clear outline, sold is a darker grey with
  // an X instead of its number, selected is solid indigo. Each differs in more
  // than color, so they read apart at a glance and in grayscale.
  static const seat = Color(0xFFFFFFFF);
  static const seatLine = Color(0xFF9EA5D6);
  static const sold = Color(0xFFCFCDD8);
  static const soldInk = Color(0xFF4A4858);

  /// One color per event, picked by id. White text passes WCAG AA on each.
  static const hues = [
    Color(0xFF4338CA),
    Color(0xFF0F766E),
    Color(0xFFBE185D),
    Color(0xFFB45309),
    Color(0xFF0369A1),
    Color(0xFF6D28D9),
  ];

  /// Section (price tier) colors, front to back. The same as the website.
  static const tiers = [
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF0369A1),
  ];

  static Color hueFor(int eventId) => hues[eventId % hues.length];
}

ThemeData bookingTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.accent,
    primary: Palette.accent,
    onPrimary: Colors.white,
    surface: Palette.card,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.muted,
    outlineVariant: Palette.line,
    error: Palette.bad,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: 'Inter');
  final text = base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.background,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.card,
      foregroundColor: Palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shape: Border(bottom: BorderSide(color: Palette.line)),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Palette.ink,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: Palette.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1),
  );
}
