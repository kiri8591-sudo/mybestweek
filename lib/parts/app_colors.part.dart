// V12.4.0 — Palette sémantique (clair / sombre).
// Chaque écran lit ses couleurs via `_colors.<rôle>` au lieu de Color(0x…) en dur.
// Le mode clair reprend les valeurs historiques ; le mode sombre est défini ici, en un seul endroit.

part of '../main.dart';

class AppColors {
  const AppColors({
    required this.textStrong,
    required this.textMuted,
    required this.textWarm,
    required this.textFaint,
    required this.accentText,
    required this.accentIcon,
    required this.accentFill,
    required this.accentFillBorder,
    required this.accentStrongText,
    required this.accentOutline,
    required this.accentSoftBorder,
    required this.danger,
    required this.warnText,
    required this.warnBg,
    required this.warnBorder,
    required this.goldText,
    required this.goldBg,
    required this.goldBorder,
    required this.card,
    required this.surfaceSoft,
    required this.surfaceSunken,
    required this.tintSoft,
    required this.tintStrong,
    required this.peachBg,
    required this.peachBorder,
    required this.border,
    required this.borderStrong,
    required this.borderTint,
    required this.shadow,
    required this.shadowSoft,
    required this.scaffold,
    required this.appBar,
    required this.inputFill,
    required this.chipBg,
    required this.navIndicator,
    required this.primary,
    required this.onPrimary,
  });

  // Textes
  final Color textStrong;      // titres, valeurs
  final Color textMuted;       // texte secondaire, icônes discrètes
  final Color textWarm;        // légendes (gris chaud)
  final Color textFaint;       // éléments désactivés
  // Accent vert/ardoise
  final Color accentText;      // texte ardoise (sélection, liens)
  final Color accentIcon;      // icônes d'action
  final Color accentFill;      // pastille « fait »
  final Color accentFillBorder;
  final Color accentStrongText;
  final Color accentOutline;
  final Color accentSoftBorder;
  // États
  final Color danger;
  final Color warnText;
  final Color warnBg;
  final Color warnBorder;
  final Color goldText;
  final Color goldBg;
  final Color goldBorder;
  // Surfaces
  final Color card;
  final Color surfaceSoft;
  final Color surfaceSunken;
  final Color tintSoft;
  final Color tintStrong;
  final Color peachBg;
  final Color peachBorder;
  // Bordures et ombres
  final Color border;
  final Color borderStrong;
  final Color borderTint;
  final Color shadow;
  final Color shadowSoft;
  // Structure (thème Material : fond d'écran, barres, boutons)
  final Color scaffold;        // fond des pages
  final Color appBar;          // barre de titre
  final Color inputFill;       // champs de saisie
  final Color chipBg;          // puces non sélectionnées
  final Color navIndicator;    // pastille de l'onglet actif
  final Color primary;         // boutons principaux
  final Color onPrimary;       // texte sur boutons principaux

  static const AppColors light = AppColors(
    textStrong: Color(0xFF3F4B45),
    textMuted: Color(0xFF656C6C),
    textWarm: Color(0xFF6F6D66),
    textFaint: Color(0xFF928D85),
    accentText: Color(0xFF526B78),
    accentIcon: Color(0xFF6F8E80),
    accentFill: Color(0xFF7D988D),
    accentFillBorder: Color(0xFF6C887A),
    accentStrongText: Color(0xFF587163),
    accentOutline: Color(0xFF8EAA9D),
    accentSoftBorder: Color(0xFFB8CCC1),
    danger: Color(0xFFC27D68),
    warnText: Color(0xFF826356),
    warnBg: Color(0xFFF8E7DF),
    warnBorder: Color(0xFFE3AA95),
    goldText: Color(0xFF8C642B),
    goldBg: Color(0xFFFFEBC8),
    goldBorder: Color(0xFFE8C98B),
    card: Color(0xFFFFFDF9),
    surfaceSoft: Color(0xFFF7F5EF),
    surfaceSunken: Color(0xFFF1F0EC),
    tintSoft: Color(0xFFEAF2ED),
    tintStrong: Color(0xFFE5EEE9),
    peachBg: Color(0xFFFFF4EA),
    peachBorder: Color(0xFFE7D4C6),
    border: Color(0xFFE0DDD5),
    borderStrong: Color(0xFFD3D0C8),
    borderTint: Color(0xFFD0DED7),
    shadow: Color(0x12000000),
    shadowSoft: Color(0x09000000),
    scaffold: Color(0xFFEEF2EE),
    appBar: Color(0xFFF9F5ED),
    inputFill: Color(0xFFFFFEFA),
    chipBg: Color(0xFFFAF8F3),
    navIndicator: Color(0xFFCFE3D5),
    primary: Color(0xFF456B57),
    onPrimary: Color(0xFFFFFFFF),
  );

  static const AppColors night = AppColors(
    textStrong: Color(0xFFE2E9E4),
    textMuted: Color(0xFFA5B2AB),
    textWarm: Color(0xFFA9ADA6),
    textFaint: Color(0xFF6C766F),
    accentText: Color(0xFFA7C4D3),
    accentIcon: Color(0xFF8FB8A3),
    accentFill: Color(0xFF5E8774),
    accentFillBorder: Color(0xFF86AE98),
    accentStrongText: Color(0xFFBDD9C8),
    accentOutline: Color(0xFF6F9482),
    accentSoftBorder: Color(0xFF4E6B5C),
    danger: Color(0xFFE39A85),
    warnText: Color(0xFFD4A595),
    warnBg: Color(0xFF3A2A25),
    warnBorder: Color(0xFF8A5848),
    goldText: Color(0xFFE2B66A),
    goldBg: Color(0xFF3E3220),
    goldBorder: Color(0xFF7A6232),
    card: Color(0xFF202B25),
    surfaceSoft: Color(0xFF1B2420),
    surfaceSunken: Color(0xFF171E1B),
    tintSoft: Color(0xFF24332B),
    tintStrong: Color(0xFF2C3F34),
    peachBg: Color(0xFF3A2F28),
    peachBorder: Color(0xFF5E4A3E),
    border: Color(0xFF38443E),
    borderStrong: Color(0xFF4A574F),
    borderTint: Color(0xFF3E5246),
    shadow: Color(0x66000000),
    shadowSoft: Color(0x4D000000),
    scaffold: Color(0xFF121614),
    appBar: Color(0xFF1A201D),
    inputFill: Color(0xFF252D29),
    chipBg: Color(0xFF28312C),
    navIndicator: Color(0xFF385346),
    primary: Color(0xFFA9C8B6),
    onPrimary: Color(0xFF173123),
  );
}

// Palette active. Mise à jour à chaque reconstruction de l'application
// (voir _buildAppShell) selon _darkMode.
AppColors _colors = AppColors.light;
