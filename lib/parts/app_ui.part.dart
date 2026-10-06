// V12.5.0 — Composants d'interface communs.
// Tous les écrans (Bilan, Historique, …) assemblent leurs cartes avec ces briques
// pour garder les mêmes espacements, rayons, titres et pastilles.
// Pour un nouvel écran : _AppCard + _SectionHeader + _StatTile / _Pill / _MeterBar.

part of '../main.dart';

/// Espacements communs (multiples de 4).
abstract final class AppSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

/// Titre de section dans une carte (Lora, w700, 15 pt).
TextStyle _sectionTitleStyle(BuildContext context) =>
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontSize: AppType.title,
      fontWeight: FontWeight.w700,
      color: _colors.textStrong,
      height: 1.2,
    );

/// Titre d'une feuille ou d'un écran secondaire (Lora, w700, 19 pt).
TextStyle _sheetTitleStyle(BuildContext context) =>
    (Theme.of(context).textTheme.headlineSmall ?? const TextStyle()).copyWith(
      fontSize: AppType.h2,
      fontWeight: FontWeight.w700,
      color: _colors.textStrong,
      height: 1.15,
    );

/// Texte d'aide sous un titre (Nunito, 11,5 pt, gris).
TextStyle _hintStyle() => TextStyle(
      fontSize: AppType.label,
      height: 1.35,
      color: _colors.textMuted,
    );

enum _CardTone {
  /// Carte blanche cassée : contenu courant.
  plain,

  /// Fond neutre légèrement creusé : informations secondaires.
  soft,

  /// Fond vert très clair : messages du coach, éléments mis en avant.
  tint,
}

/// Carte standard : même rayon, même marge intérieure, même bordure partout.
class _AppCard extends StatelessWidget {
  final Widget child;
  final _CardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _AppCard({
    required this.child,
    this.tone = _CardTone.plain,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      _CardTone.plain => _colors.card,
      _CardTone.soft => _colors.surfaceSunken,
      _CardTone.tint => _colors.tintStrong,
    };
    final line = tone == _CardTone.tint ? _colors.borderTint : _colors.border;
    final radius = BorderRadius.circular(AppRadius.xl);
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: line, width: 1)),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// En-tête de section : icône (pack / personnalisée) + titre + élément à droite.
class _SectionHeader extends StatelessWidget {
  final String iconKey;
  final IconData fallbackIcon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.iconKey,
    required this.fallbackIcon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _colors.card.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: _colors.borderTint),
          ),
          alignment: Alignment.center,
          child: _uiIcon(iconKey, fallbackIcon, size: 20, color: _colors.accentIcon),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: _sectionTitleStyle(context))),
        if (trailing != null) trailing!,
      ]),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: _hintStyle()),
      ],
    ]);
  }
}

/// Pastille : état, compteur, ressenti.
class _Pill extends StatelessWidget {
  final String text;
  final Color? background;
  final Color? foreground;
  final Color? dot;

  const _Pill(this.text, {this.background, this.foreground, this.dot});

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? _colors.accentStrongText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? _colors.tintSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot != null) ...[
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ]),
    );
  }
}

/// Barre de progression arrondie, même épaisseur partout.
class _MeterBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const _MeterBar({required this.value, this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Stack(children: [
        Container(height: height, color: _colors.border),
        FractionallySizedBox(
          widthFactor: v,
          child: Container(height: height, color: color ?? _colors.accentFill),
        ),
      ]),
    );
  }
}

/// Tuile chiffre clé : icône, valeur, libellé. Colonne : tient à 2 ou 3 par ligne.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String iconKey;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.iconKey, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _uiIcon(iconKey, icon, size: 20, color: _colors.accentIcon),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong, height: 1.1)),
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted, height: 1.2)),
      ]),
    );
  }
}

/// Ligne de tuiles de même largeur (2 ou 3).
Widget _statTiles(List<Widget> tiles) {
  // IntrinsicHeight : sans hauteur bornée (liste défilante), un Row en « stretch » plante la page.
  return IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpace.s),
        Expanded(child: tiles[i]),
      ],
    ]),
  );
}

/// Durée lisible : 45 min, 2 h, 2 h 05.
String _minutesLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

const List<String> _frMonthsLong = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const List<String> _frWeekdaysLong = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

/// « Aujourd’hui », « Hier » ou « lundi 5 octobre ».
String _friendlyDayLabel(DateTime date, DateTime now) {
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Aujourd’hui';
  if (diff == 1) return 'Hier';
  final base = '${_frWeekdaysLong[d.weekday - 1]} ${d.day} ${_frMonthsLong[d.month - 1]}';
  return d.year == today.year ? base : '$base ${d.year}';
}

/// Couleurs des trois ressentis, identiques dans le Bilan et l'Historique.
Color _feelingColor(String feeling) {
  switch (feeling) {
    case 'Très bien':
      return _colors.accentFill;
    case 'Bien':
      return _colors.accentSoftBorder;
    case 'Difficile':
      return _colors.warnBorder;
    default:
      return _colors.border;
  }
}
