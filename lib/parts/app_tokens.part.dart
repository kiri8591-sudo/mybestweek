// V12.4.2 — Échelles typographiques et rayons communs (harmonisation visuelle).
// 65 tailles de police et 22 rayons différents ont été ramenés à 12 + 7 valeurs.
// Pour un nouvel écran : utiliser ces constantes plutôt que des nombres libres.

part of '../main.dart';

abstract final class AppType {
  static const double micro = 10;     // minuscules repères (lettres de jours)
  static const double caption = 10.5; // légendes denses
  static const double small = 11;     // sous-titres, métadonnées (minimum recommandé iOS)
  static const double label = 11.5;   // libellés, chips, texte courant compact
  static const double body = 12.5;    // texte courant
  static const double bodyL = 13.5;   // texte courant confortable
  static const double title = 15;     // titres de cartes
  static const double titleL = 17;    // titres de feuilles
  static const double h2 = 19;
  static const double h1 = 21;
  static const double display = 24;
  static const double hero = 28;
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 99;
}
