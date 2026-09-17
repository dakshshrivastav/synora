import 'package:flutter/material.dart';

abstract final class FreonColors {
  static const primary = Color(0xff004f45);
  static const teal = Color(0xff00695c);
  static const secondary = Color(0xff006a62);
  static const mint = Color(0xff81f3e5);
  static const cyan = Color(0xff00667b);
  static const ice = Color(0xffb3ebff);
  static const canvas = Color(0xfff9f9ff);
  static const pale = Color(0xfff0f3ff);
  static const surface = Color(0xffe7eeff);
  static const ink = Color(0xff111c2d);
  static const muted = Color(0xff3e4946);
  static const outline = Color(0xffbec9c5);
}

TextStyle displayStyle(double size, {Color color = FreonColors.ink}) =>
    TextStyle(
      fontFamily: 'Outfit',
      fontSize: size,
      fontWeight: FontWeight.w200,
      height: 1.12,
      letterSpacing: -size * .025,
      color: color,
    );

const labelStyle = TextStyle(
  fontFamily: 'Hanken Grotesk',
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.4,
  height: 1.4,
);

ThemeData freonTheme() {
  const shape = RoundedRectangleBorder();
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Hanken Grotesk',
    scaffoldBackgroundColor: FreonColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: FreonColors.primary,
      secondary: FreonColors.mint,
      onSecondary: FreonColors.primary,
      surface: FreonColors.canvas,
      onSurface: FreonColors.ink,
      error: Color(0xffba1a1a),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          bodyMedium: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 14,
            height: 1.5,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Hanken Grotesk',
            fontSize: 16,
            height: 1.5,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: FreonColors.ink, displayColor: FreonColors.ink),
    dividerTheme: const DividerThemeData(
      color: FreonColors.outline,
      thickness: .5,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 44),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontWeight: FontWeight.w600,
          letterSpacing: .3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        minimumSize: const Size(0, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape),
    ),
    dialogTheme: const DialogThemeData(
      shape: shape,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: FreonColors.pale,
      contentPadding: EdgeInsets.all(14),
      border: UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: FreonColors.outline),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: FreonColors.teal, width: 2),
      ),
      labelStyle: TextStyle(fontSize: 12, letterSpacing: .6),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: FreonColors.surface,
      selectedColor: FreonColors.primary,
      labelStyle: labelStyle,
      showCheckmark: false,
    ),
  );
}
