// V12.4.6 — Polices embarquées (assets/fonts) : plus aucun téléchargement au lancement.
// Nunito Sans (400/500/600/700/800 + italiques) et Lora (400/500/600/700 + italiques), sous-ensemble latin.
// Régénération : voir tools/make_fonts.py

part of '../main.dart';

abstract final class AppFonts {
  static const String sans = 'NunitoSans';
  static const String serif = 'Lora';

  static TextStyle _style(
    String family, {
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: family,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  static TextStyle nunito({
    TextStyle? textStyle, Color? color, Color? backgroundColor, double? fontSize, FontWeight? fontWeight,
    FontStyle? fontStyle, double? letterSpacing, double? wordSpacing, TextBaseline? textBaseline, double? height,
    Paint? foreground, Paint? background, List<Shadow>? shadows, List<FontFeature>? fontFeatures,
    TextDecoration? decoration, Color? decorationColor, TextDecorationStyle? decorationStyle, double? decorationThickness,
  }) => _style(sans, textStyle: textStyle, color: color, backgroundColor: backgroundColor, fontSize: fontSize,
      fontWeight: fontWeight, fontStyle: fontStyle, letterSpacing: letterSpacing, wordSpacing: wordSpacing,
      textBaseline: textBaseline, height: height, foreground: foreground, background: background, shadows: shadows,
      fontFeatures: fontFeatures, decoration: decoration, decorationColor: decorationColor,
      decorationStyle: decorationStyle, decorationThickness: decorationThickness);

  static TextStyle lora({
    TextStyle? textStyle, Color? color, Color? backgroundColor, double? fontSize, FontWeight? fontWeight,
    FontStyle? fontStyle, double? letterSpacing, double? wordSpacing, TextBaseline? textBaseline, double? height,
    Paint? foreground, Paint? background, List<Shadow>? shadows, List<FontFeature>? fontFeatures,
    TextDecoration? decoration, Color? decorationColor, TextDecorationStyle? decorationStyle, double? decorationThickness,
  }) => _style(serif, textStyle: textStyle, color: color, backgroundColor: backgroundColor, fontSize: fontSize,
      fontWeight: fontWeight, fontStyle: fontStyle, letterSpacing: letterSpacing, wordSpacing: wordSpacing,
      textBaseline: textBaseline, height: height, foreground: foreground, background: background, shadows: shadows,
      fontFeatures: fontFeatures, decoration: decoration, decorationColor: decorationColor,
      decorationStyle: decorationStyle, decorationThickness: decorationThickness);

  static TextTheme nunitoTextTheme([TextTheme? base]) => (base ?? ThemeData.light().textTheme).apply(fontFamily: sans);
  static TextTheme loraTextTheme([TextTheme? base]) => (base ?? ThemeData.light().textTheme).apply(fontFamily: serif);
}
