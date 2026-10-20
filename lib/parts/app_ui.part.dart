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
  final Color? fill; // fond personnalisé (ex. teinte par catégorie)
  final Color? borderColor;

  const _AppCard({
    required this.child,
    this.tone = _CardTone.plain,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.onTap,
    this.fill,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      _CardTone.plain => _colors.card,
      _CardTone.soft => _colors.surfaceSunken,
      _CardTone.tint => _colors.tintStrong,
    };
    final line = borderColor ?? (tone == _CardTone.tint ? _colors.borderTint : _colors.border);
    final radius = BorderRadius.circular(AppRadius.xl);
    return Material(
      color: this.fill ?? fill,
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

/// Ajoute des jours calendaires en gardant l'heure affichée : contrairement à
/// `add(Duration(days: n))`, ne dérive pas d'une heure lors du changement d'heure.
DateTime _addDays(DateTime d, int days) => d.isUtc
    ? DateTime.utc(d.year, d.month, d.day + days, d.hour, d.minute, d.second, d.millisecond)
    : DateTime(d.year, d.month, d.day + days, d.hour, d.minute, d.second, d.millisecond);

// ---------------------------------------------------------------------------
// Écrans « Semaine » (Sport et Activités) : composants partagés
// ---------------------------------------------------------------------------

/// En-tête de semaine : titre + dates, pourcentage, barre et tuiles chiffrées.
class _WeekHero extends StatelessWidget {
  final String title;
  final String iconKey;
  final IconData fallbackIcon;
  final String rangeLabel;
  final int ratePercent;
  final String caption;
  final List<Widget> tiles;
  final String? footnote;

  const _WeekHero({
    required this.title,
    required this.iconKey,
    required this.fallbackIcon,
    required this.rangeLabel,
    required this.ratePercent,
    required this.caption,
    required this.tiles,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return _AppCard(
      tone: _CardTone.tint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader(
          iconKey: iconKey,
          fallbackIcon: fallbackIcon,
          title: title,
          trailing: _Pill(rangeLabel, background: _colors.card, foreground: _colors.textMuted),
        ),
        const SizedBox(height: AppSpace.l),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$ratePercent %', style: TextStyle(fontFamily: AppFonts.serif, fontSize: AppType.hero, fontWeight: FontWeight.w700, color: _colors.textStrong, height: 1)),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(caption, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textMuted)),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.m),
        _MeterBar(value: ratePercent / 100.0, height: 10),
        const SizedBox(height: AppSpace.l),
        _statTiles(tiles),
        if (footnote != null) ...[
          const SizedBox(height: AppSpace.m),
          Text(footnote!, style: _hintStyle()),
        ],
      ]),
    );
  }
}

/// Barre de filtres commune : vue 7 jours / 1 mois, état en puces, filtres avancés repliables.
class _WeekFilterBar extends StatefulWidget {
  final List<String> activityNames;
  final String activityFilter;
  final String stateFilter;
  final String sort;
  final Map<String, String> sortOptions; // valeur -> libellé
  final String view;
  final ValueChanged<String> onActivity;
  final ValueChanged<String> onState;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onView;
  final VoidCallback onReset;
  final VoidCallback? onHelp;

  const _WeekFilterBar({
    required this.activityNames,
    required this.activityFilter,
    required this.stateFilter,
    required this.sort,
    required this.sortOptions,
    required this.view,
    required this.onActivity,
    required this.onState,
    required this.onSort,
    required this.onView,
    required this.onReset,
    this.onHelp,
  });

  @override
  State<_WeekFilterBar> createState() => _WeekFilterBarState();
}

class _WeekFilterBarState extends State<_WeekFilterBar> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final advancedActive = widget.activityFilter != 'Toutes' || widget.sort != 'Nom';
    final anyActive = advancedActive || widget.stateFilter != 'Tous';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'Semaine', label: Text('7 jours')),
            ButtonSegment<String>(value: 'Mois', label: Text('1 mois')),
          ],
          selected: <String>{widget.view},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) widget.onView(s.first);
          },
        ),
      ),
      const SizedBox(height: AppSpace.s),
      Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final value in const ['Tous', 'À faire', 'Réalisées', 'Non prises en compte'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(value, style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
                    selected: widget.stateFilter == value,
                    onSelected: (_) => widget.onState(value),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
          ),
        ),
        if (widget.onHelp != null)
          IconButton(
            tooltip: 'Que signifie « non prise en compte » ?',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onHelp,
            icon: _uiIcon('help', Icons.info_outline, size: 18),
          ),
      ]),
      Row(children: [
        TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 6)),
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less_rounded : Icons.tune_rounded, size: 18),
          label: Text(advancedActive ? 'Filtres · actifs' : 'Filtres et tri'),
        ),
        const Spacer(),
        if (anyActive)
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 6)),
            onPressed: widget.onReset,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Réinitialiser'),
          ),
      ]),
      if (_open)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xs),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('act_${widget.activityFilter}'),
                initialValue: widget.activityNames.contains(widget.activityFilter) ? widget.activityFilter : 'Toutes',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Activité', isDense: true),
                items: ['Toutes', ...widget.activityNames].map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => widget.onActivity(v ?? 'Toutes'),
              ),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('sort_${widget.sort}'),
                initialValue: widget.sortOptions.containsKey(widget.sort) ? widget.sort : 'Nom',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trier par', isDense: true),
                items: widget.sortOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => widget.onSort(v ?? 'Nom'),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Icônes système : une seule apparence par défaut (Material), partout.
// Une icône personnalisée par l'utilisateur (Système · personnaliser) reste prioritaire.
// ---------------------------------------------------------------------------

const Map<String, IconData> _kSystemIconDefaults = {
  'navHome': Icons.home_outlined,
  'navWeek': Icons.calendar_view_week_outlined,
  'navActivities': Icons.interests_outlined,
  'navPriorities': Icons.star_outline_rounded,
  'priority': Icons.star_rounded,
  'navObjectives': Icons.flag_outlined,
  'search': Icons.search_rounded,
  'challenge': Icons.emoji_events_outlined,
  'objective': Icons.track_changes_rounded,
  'objectiveDetail': Icons.track_changes_rounded,
  'objectiveSave': Icons.check_rounded,
  'objectiveDelete': Icons.delete_outline_rounded,
  'objectiveState': Icons.emoji_events_outlined,
  'streak': Icons.local_fire_department_outlined,
  'history': Icons.history_rounded,
  'reviewBack': Icons.arrow_back_ios_new_rounded,
  'undo': Icons.undo_rounded,
  'histTrend': Icons.trending_down_rounded,
  'histStable': Icons.check_circle_outline,
  'histSortUp': Icons.arrow_upward_rounded,
  'histSortDown': Icons.arrow_downward_rounded,
  'histEmpty': Icons.menu_book_outlined,
  'periodMorning': Icons.wb_twilight_rounded,
  'periodAfternoon': Icons.wb_sunny_outlined,
  'periodEvening': Icons.nights_stay_outlined,
  'sport': Icons.fitness_center_rounded,
  'sportWeek': Icons.view_week_outlined,
  'sportTimer': Icons.timer_outlined,
  'sportActive': Icons.directions_run_rounded,
  'sportMinutes': Icons.hourglass_bottom_rounded,
  'sportRate': Icons.check_circle_outline,
  'sportMissing': Icons.warning_amber_rounded,
  'sportFilter': Icons.filter_list_rounded,
  'sportBack': Icons.chevron_left_rounded,
  'sportNext': Icons.chevron_right_rounded,
  'sportReactivate': Icons.refresh_rounded,
  'sportWarning': Icons.warning_amber_rounded,
  'frozen': Icons.ac_unit_rounded,
  'backupDevice': Icons.smartphone_outlined,
  'backupCloud': Icons.cloud_outlined,
  'backupFile': Icons.description_outlined,
  'backupShield': Icons.shield_outlined,
  'backupDownload': Icons.download_rounded,
  'backupUpload': Icons.cloud_upload_outlined,
  'backupFolder': Icons.folder_open_outlined,
  'backupReset': Icons.restart_alt_rounded,
  'backupDue': Icons.schedule_rounded,
  'backupOk': Icons.check_circle_outline,
  'reviewMoments': Icons.check_circle_outline,
  'reviewRegularity': Icons.event_repeat_outlined,
  'reviewPlanned': Icons.event_note_outlined,
  'reviewRealized': Icons.play_circle_outline_rounded,
  'reviewRemaining': Icons.hourglass_empty_rounded,
  'reviewMoved': Icons.open_with_rounded,
  'reviewValidated': Icons.timer_outlined,
  'reviewUnexpected': Icons.auto_awesome_outlined,
  'reviewActiveDays': Icons.event_available_outlined,
  'reviewTime': Icons.timer_outlined,
  'reviewPiano': Icons.piano_outlined,
  'reviewDifficult': Icons.battery_alert_outlined,
  'reviewMood': Icons.sentiment_satisfied_alt_outlined,
  'nextWeekDirections': Icons.tune_rounded,
  'dragDown': Icons.expand_more_rounded,
  'expandMore': Icons.expand_more_rounded,
  'planOpen': Icons.chevron_right_rounded,
  'missionDone': Icons.check_circle_outline,
  'coach': Icons.psychology_outlined,
  'add': Icons.add_circle_outline,
  'edit': Icons.edit_outlined,
  'remove': Icons.remove_circle_outline,
  'delete': Icons.delete_outline_rounded,
  'confirm': Icons.check_circle_outline,
  'help': Icons.help_outline_rounded,
  'photo': Icons.image_outlined,
  'emoji': Icons.emoji_emotions_outlined,
  'manageIcons': Icons.palette_outlined,
  'save': Icons.save_outlined,
  'restore': Icons.settings_backup_restore_rounded,
  'calendar': Icons.calendar_month_outlined,
  'week': Icons.view_week_outlined,
  'duration': Icons.timer_outlined,
  'move': Icons.open_with_rounded,
  'repeat': Icons.repeat_rounded,
  'close': Icons.close_rounded,
  'apply': Icons.bolt_outlined,
  'settings': Icons.settings_outlined,
  'identity': Icons.person_outline_rounded,
  'location': Icons.place_outlined,
  'refresh': Icons.refresh_rounded,
  'insights': Icons.insights_outlined,
  'system': Icons.settings_outlined,
};

// ---------------------------------------------------------------------------
// Feuilles et sélecteurs : composants communs
// ---------------------------------------------------------------------------

/// En-tête d'une feuille : pastille d'icône + titre + sous-titre.
class _SheetHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;

  const _SheetHeader({required this.leading, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: _colors.tintStrong, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.borderTint)),
        alignment: Alignment.center,
        child: leading,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _sheetTitleStyle(context)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: _hintStyle()),
          ],
        ]),
      ),
    ]);
  }
}

/// Ligne de choix (liste d'activités dans une feuille).
class _SheetPickRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final bool multi; // case à cocher (plusieurs choix) plutôt que bouton radio
  final Widget? badge;
  final VoidCallback? onTap;

  const _SheetPickRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.multi = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: _AppCard(
        tone: selected ? _CardTone.tint : _CardTone.soft,
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : .55,
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.m)),
              alignment: Alignment.center,
              child: leading,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: enabled ? _colors.textStrong : _colors.textFaint)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                ],
              ]),
            ),
            if (badge != null) ...[const SizedBox(width: 6), badge!],
            const SizedBox(width: 6),
            Icon(
              selected ? Icons.check_circle_rounded : (multi ? Icons.radio_button_unchecked_rounded : Icons.radio_button_unchecked_rounded),
              size: 22,
              color: selected ? _colors.accentIcon : _colors.textFaint,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Encart d'information (astuce, rappel) dans une feuille.
class _InfoNote extends StatelessWidget {
  final Widget leading;
  final String text;

  const _InfoNote({required this.leading, required this.text});

  @override
  Widget build(BuildContext context) {
    return _AppCard(
      tone: _CardTone.soft,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        leading,
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: AppType.small, height: 1.32, color: _colors.accentText, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Vue « 1 mois » des écrans Semaine Sport et Semaine Activités
// ---------------------------------------------------------------------------

/// Pour chaque activité : titre, bilan du mois et une case par jour
/// (toucher = cocher / décocher, appui long = saisir le temps).
class _MonthActivityGrid extends StatelessWidget {
  final DateTime month;
  final List<Activity> activities;
  final bool Function(Activity activity, DateTime date) doneOn;
  final int Function(Activity activity, DateTime date) minutesOn;
  final void Function(Activity activity, DateTime date) onToggle;
  final Future<void> Function(Activity activity, DateTime date) onEditMinutes;
  final ValueChanged<Activity> onOpenActivity;
  final String emptyText;

  const _MonthActivityGrid({
    required this.month,
    required this.activities,
    required this.doneOn,
    required this.minutesOn,
    required this.onToggle,
    required this.onEditMinutes,
    required this.onOpenActivity,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
        child: Text(emptyText, style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
      );
    }
    final days = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final todayKey = now.year * 10000 + now.month * 100 + now.day;

    Widget cell(Activity activity, int day) {
      final date = DateTime(month.year, month.month, day);
      final done = doneOn(activity, date);
      final isToday = date.year * 10000 + date.month * 100 + date.day == todayKey;
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        onTap: () => onToggle(activity, date),
        onLongPress: () => onEditMinutes(activity, date),
        child: Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? _colors.accentFill : _colors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: isToday ? Border.all(color: _colors.accentText, width: 1.5) : Border.all(color: _colors.border),
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: done ? _colors.card : _colors.textMuted,
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final activity in activities)
        Builder(builder: (context) {
          var doneDays = 0;
          var totalMinutes = 0;
          for (var d = 1; d <= days; d++) {
            final date = DateTime(month.year, month.month, d);
            if (doneOn(activity, date)) doneDays++;
            totalMinutes += minutesOn(activity, date);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: _AppCard(
              tone: _CardTone.soft,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  onTap: () => onOpenActivity(activity),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  child: Row(children: [
                    _activityIconWidget(activity.emoji, size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text(activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
                    _Pill(doneDays == 0 ? 'rien ce mois' : '$doneDays j${totalMinutes > 0 ? ' · ${_minutesLabel(totalMinutes)}' : ''}'),
                  ]),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 3, runSpacing: 3, children: [for (var d = 1; d <= days; d++) cell(activity, d)]),
              ]),
            ),
          );
        }),
    ]);
  }
}
