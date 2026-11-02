import 'package:flutter/material.dart';

const kFont = 'BeVietnamPro';

const kBg = Color(0xFFFBF5FA);
const kInk = Color(0xFF33263F);
const kMuted = Color(0xFF75688A);
const kFaint = Color(0xFFB9AEC6);
const kLine = Color(0xFFEEDDEB);
const kWell = Color(0xFFF7EEF6); // nền ô nhập / rãnh lõm
const kTrack = Color(0xFFF1E6F1);
const kPrimary = Color(0xFFC2417A);
const kPrimarySoft = Color(0xFFFFE3EE);
const kViolet = Color(0xFF7A4FD6);
const kVioletSoft = Color(0xFFECE3FF);
const kGreen = Color(0xFF2BA36B);
const kDanger = Color(0xFFB83A6E);

/// Màu pastel: nền khối, chữ/viền đậm, chấm nhỏ đậm vừa.
class Pastel {
  const Pastel(this.name, this.bg, this.fg, this.dot);
  final String name;
  final Color bg;
  final Color fg;
  final Color dot;
}

const palette = <String, Pastel>{
  'pink': Pastel('Hồng', Color(0xFFFFD3E4), Color(0xFF8E2457), Color(0xFFC2417A)),
  'peach': Pastel('Cam đào', Color(0xFFFFE0C7), Color(0xFF8A4510), Color(0xFFE07A2E)),
  'yellow': Pastel('Vàng bơ', Color(0xFFFFF1B8), Color(0xFF6E5A0C), Color(0xFFE0A21E)),
  'mint': Pastel('Bạc hà', Color(0xFFC8F0DB), Color(0xFF23704C), Color(0xFF2BA36B)),
  'sky': Pastel('Xanh trời', Color(0xFFCFE6FF), Color(0xFF2B5F96), Color(0xFF2B8FD6)),
  'lavender': Pastel('Oải hương', Color(0xFFE6DAFF), Color(0xFF5B3FA6), Color(0xFF7A4FD6)),
};

Pastel pastel(String key) => palette[key] ?? palette['pink']!;

const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const weekdayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

/// Bóng đổ "đất sét" cho khối nổi.
List<BoxShadow> clayShadow(Color tint, {double depth = 1}) => [
  BoxShadow(
    color: tint.withValues(alpha: 0.30 * depth),
    blurRadius: 26 * depth,
    spreadRadius: -10,
    offset: Offset(0, 16 * depth),
  ),
  BoxShadow(
    color: tint.withValues(alpha: 0.10 * depth),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

const kShadowTint = Color(0xFF784A8A);

TextStyle ts(double size, {FontWeight w = FontWeight.w600, Color c = kInk, double? h, double? ls, TextDecoration? deco}) => TextStyle(
  fontFamily: kFont,
  fontSize: size,
  fontWeight: w,
  color: c,
  height: h,
  letterSpacing: ls,
  decoration: deco,
  decorationColor: c,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: Brightness.light,
    primary: kPrimary,
    onPrimary: Colors.white,
    secondary: kViolet,
    surface: kBg,
    onSurface: kInk,
  );
  final base = ThemeData(useMaterial3: true, fontFamily: kFont, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    textTheme: base.textTheme.apply(bodyColor: kInk, displayColor: kInk, fontFamily: kFont),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(backgroundColor: kBg, foregroundColor: kInk, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kWell,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      hintStyle: ts(15, c: kMuted, w: FontWeight.w500),
      labelStyle: ts(14, c: kMuted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      headerBackgroundColor: kPrimary,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kInk,
      contentTextStyle: ts(14, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()}),
  );
}
