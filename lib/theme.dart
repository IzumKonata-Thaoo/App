import 'package:flutter/material.dart';

const kBg = Color(0xFFFFF6FA);
const kInk = Color(0xFF5A4A6A);
const kMuted = Color(0xFFA596B3);
const kAccent = Color(0xFFFF8FBA);
const kAccentSoft = Color(0xFFFFE3EE);
const kLavender = Color(0xFFB79CED);
const kGrid = Color(0xFFF6E3EE);
const kOtherMonth = Color(0xFFFFF0F6);
const kDanger = Color(0xFFE5658B);

class Pastel {
  const Pastel(this.name, this.bg, this.fg);
  final String name;
  final Color bg;
  final Color fg;
}

const palette = <String, Pastel>{
  'pink': Pastel('Hồng', Color(0xFFFFD1E3), Color(0xFFB8446F)),
  'peach': Pastel('Cam đào', Color(0xFFFFE0C2), Color(0xFFB5651D)),
  'yellow': Pastel('Vàng', Color(0xFFFFF3B8), Color(0xFF8A7410)),
  'mint': Pastel('Bạc hà', Color(0xFFCFF5DC), Color(0xFF2E7D57)),
  'sky': Pastel('Xanh trời', Color(0xFFC9E6FF), Color(0xFF2F6FA3)),
  'lavender': Pastel('Tím oải hương', Color(0xFFE3D4FA), Color(0xFF6B4BA8)),
};

Pastel pastel(String key) => palette[key] ?? palette['pink']!;

const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const weekdayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.light,
    primary: kAccent,
    onPrimary: Colors.white,
    secondary: kLavender,
    surface: kBg,
    onSurface: kInk,
  );
  OutlineInputBorder border(Color c, [double w = 1.5]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    textTheme: ThemeData.light().textTheme.apply(bodyColor: kInk, displayColor: kInk),
    appBarTheme: const AppBarTheme(
        backgroundColor: kBg, foregroundColor: kInk, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kGrid)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(kGrid),
      enabledBorder: border(kGrid),
      focusedBorder: border(kAccent, 2),
      hintStyle: const TextStyle(color: kMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        side: const BorderSide(color: kGrid, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      elevation: 3,
      focusElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide.none),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kAccentSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: s.contains(WidgetState.selected) ? kAccent : kMuted)),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? kAccent : kMuted)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : kMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : kGrid),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: Color(0xFFE8C9DA), width: 2),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : Colors.white),
    ),
    sliderTheme: const SliderThemeData(
        activeTrackColor: kAccent, inactiveTrackColor: kGrid, thumbColor: kAccent, overlayColor: Color(0x33FF8FBA)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFFF9E8F1)),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : kMuted),
        side: const WidgetStatePropertyAll(BorderSide.none),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: kAccentSoft,
      side: const BorderSide(color: kGrid),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: kInk),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: kGrid, space: 1),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  );
}
