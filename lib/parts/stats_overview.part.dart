// V12.6.0 — Statistiques : vue d'ensemble (anneau « Total investi ») et fiche par activité
// (total en heures, jours depuis le début, rythme hebdomadaire, prochain palier,
// frise des 3 derniers mois et calendrier du mois avec les minutes de chaque jour).
// Inspiré des écrans de statistiques d'iHour ; toutes les données viennent de l'historique existant.

part of '../main.dart';

bool _logIsOfActivity(ActivityLog log, Activity activity) =>
    (log.activityId != null && log.activityId == activity.id) ||
    (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());

/// 0,6 · 4,6 · 43 · 758 (une décimale sous 10 h).
String _hoursLabel(int minutes) {
  final h = minutes / 60.0;
  if (h < 10) return h.toStringAsFixed(1).replaceAll('.', ',');
  return h.round().toString();
}

/// Une réalisation compte dans les statistiques : du temps, des répétitions ou une occurrence.
/// (Une occurrence est enregistrée avec 1 minute de pure convention : ne jamais l'additionner aux heures.)
bool _logIsRealised(ActivityLog l) => l.realisedMinutes > 0 || (l.reps ?? 0) > 0 || _logIsCount(l);

/// Rang d'affichage d'une activité : 0 = temps, 1 = occurrences, 2 = répétitions seules.
int _activityKindRank(Activity a) => !a.countOnly ? 0 : (_isRepsOnly(a) ? 2 : 1);

const List<int> _milestonesHours = [5, 10, 25, 50, 100, 250, 500, 750, 1000, 2500, 5000, 10000];

int? _nextMilestoneMinutes(int minutes) {
  for (final h in _milestonesHours) {
    if (h * 60 > minutes) return h * 60;
  }
  return null;
}

const List<String> _frMonthsShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Anneau : une part par catégorie, séparées par un petit espace.
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;
  final double stroke;

  const _DonutPainter({required this.values, required this.colors, required this.track, this.stroke = 32});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 2 * pi, false, base);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const gap = 0.05;
    final many = values.length > 1;
    var start = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i % colors.length];
      final drawn = many ? max(sweep - gap, 0.02) : sweep;
      canvas.drawArc(rect, start + (many ? gap / 2 : 0), drawn, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

class _ActivityTotal {
  final Activity activity;
  final int minutes; // minutes (temps), fois (occurrences) ou répétitions (répétitions seules) selon [kind]
  final int sessions; // nombre de réalisations
  const _ActivityTotal(this.activity, this.minutes, {this.sessions = 0});
  bool get isCount => activity.countOnly;
  bool get isReps => _isRepsOnly(activity);
  /// 0 = temps, 1 = occurrences, 2 = répétitions seules.
  int get kind => _activityKindRank(activity);
}

// ---------------------------------------------------------------------------
// Vue d'ensemble
// ---------------------------------------------------------------------------

class _StatsOverviewPage extends StatefulWidget {
  final List<ActivityLog> logs;
  final List<Activity> activities;
  final List<RealizationGoal> goals;

  final Future<void> Function(ActivityLog log) onEditLog;
  final Future<void> Function(Activity activity) onAddForActivity;
  final Future<void> Function(Activity activity) onRecreate;
  final Future<void> Function(Activity activity) onRelink;

  const _StatsOverviewPage({required this.logs, required this.activities, required this.goals, required this.onEditLog, required this.onAddForActivity, required this.onRecreate, required this.onRelink});

  @override
  State<_StatsOverviewPage> createState() => _StatsOverviewPageState();
}

class _StatsOverviewPageState extends State<_StatsOverviewPage> {
  String _period = 'Tout';
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<Color> get _palette => [
        _colors.accentFill,
        _colors.goldBorder,
        _colors.warnBorder,
        _colors.accentOutline,
        _colors.accentSoftBorder,
        _colors.peachBorder,
        _colors.borderStrong,
      ];

  List<ActivityLog> _periodLogs() {
    final now = DateTime.now();
    DateTime? cutoff;
    if (_period == '30 jours') cutoff = now.subtract(const Duration(days: 30));
    if (_period == '1 an') cutoff = now.subtract(const Duration(days: 365));
    return widget.logs.where((l) => _logIsRealised(l) && (cutoff == null || !l.date.isBefore(cutoff))).toList();
  }

  Activity _activityFor(ActivityLog log) => _resolveActivity(log, widget.activities);

  /// Activités distinctes réalisées par jour, séparées entre suivi en durée et occurrences.
  /// Chaque icône n'apparaît qu'une fois par jour, même si l'activité a plusieurs entrées.
  Map<int, List<Activity>> _activitiesPerDay(Iterable<ActivityLog> source, {required bool count}) {
    final grouped = <int, Map<String, Activity>>{};
    for (final log in source) {
      final isCount = _logIsCount(log);
      if (isCount != count) continue;
      if (!isCount && log.realisedMinutes <= 0) continue;
      final activity = _activityFor(log);
      final key = _dayKey(log.date);
      grouped.putIfAbsent(key, () => <String, Activity>{})[activity.id] = activity;
    }
    return {
      for (final entry in grouped.entries)
        entry.key: (entry.value.values.toList()..sort((a, b) => a.name.compareTo(b.name))),
    };
  }

  List<_ActivityTotal> _activityTotals(List<ActivityLog> logs) {
    final minutes = <String, int>{};
    final sessions = <String, int>{};
    final activities = <String, Activity>{};
    for (final log in logs) {
      final a = _activityFor(log);
      minutes[a.id] = (minutes[a.id] ?? 0) + (_isRepsOnly(a) ? (log.reps ?? 0) : (a.countOnly ? 1 : log.realisedMinutes));
      sessions[a.id] = (sessions[a.id] ?? 0) + 1;
      activities[a.id] = a;
    }
    final result = [for (final e in minutes.entries) _ActivityTotal(activities[e.key]!, e.value, sessions: sessions[e.key] ?? 0)];
    // Temps, puis occurrences, puis répétitions : on ne classe jamais des unités différentes ensemble.
    result.sort((a, b) {
      if (a.kind != b.kind) return a.kind.compareTo(b.kind);
      return b.minutes.compareTo(a.minutes);
    });
    return result;
  }

  /// Ordre stable des catégories : de base, puis personnalisées, puis les autres par nom.
  /// La même catégorie garde ainsi la même couleur dans toutes les sections.
  List<String> _statCategoryOrder() {
    final known = <String>{
      for (final c in [...kBaseCategories, ..._customCategories]) c.trim().toLowerCase(),
    };
    final others = <String>{
      for (final a in widget.activities) a.category.trim().isEmpty ? 'autre' : a.category.trim().toLowerCase(),
      for (final l in widget.logs) l.category.trim().isEmpty ? 'autre' : l.category.trim().toLowerCase(),
    }..removeAll(known);
    return [...known, ...(others.toList()..sort())];
  }

  Color _categoryColor(String name, List<String> order) {
    final index = order.indexOf(name.trim().toLowerCase());
    return _palette[(index < 0 ? order.length : index) % _palette.length];
  }

  Widget _statsSectionHeader({required IconData icon, required String title, required String value, required String hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: _colors.accentIcon),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: _sectionTitleStyle(context))),
        Text(value, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
      ]),
      const SizedBox(height: 2),
      Text(hint, style: _hintStyle()),
    ]);
  }

  List<Widget> _activityRows(List<_ActivityTotal> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, color: _colors.border),
          _activityRow(items[i]),
        ],
      ];

  void _openActivity(Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _ActivityStatsPage(activity: activity, logs: widget.logs, onEditLog: widget.onEditLog, onAddForActivity: widget.onAddForActivity, onRecreate: widget.onRecreate, onRelink: widget.onRelink)),
    );
  }

  Widget _legendRow(String name, int minutes, int total, Color color, {VoidCallback? onTap}) {
    final share = total <= 0 ? 0.0 : minutes / total;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.s),
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.only(top: AppSpace.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
          Text('${_hoursLabel(minutes)} h', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text('${(share * 100).round()} %', textAlign: TextAlign.right, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted))),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: _colors.textMuted),
        ]),
        const SizedBox(height: 5),
        _MeterBar(value: share, color: color, height: 6),
      ]),
    ),
    );
  }

  Widget _countCategoryRow(String name, int count, int total, Color color, {VoidCallback? onTap}) {
    final share = total <= 0 ? 0.0 : count / total;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.s),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
            Text('$count fois', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
            const SizedBox(width: 8),
            SizedBox(width: 40, child: Text('${(share * 100).round()} %', textAlign: TextAlign.right, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted))),
            if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: _colors.textMuted),
          ]),
          const SizedBox(height: 5),
          _MeterBar(value: share, color: color, height: 6),
        ]),
      ),
    );
  }

  Widget _activityRow(_ActivityTotal item) {
    return InkWell(
      onTap: () => _openActivity(item.activity),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _colors.tintStrong, child: _activityIconWidget(item.activity.emoji, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong)),
              if (item.isReps && item.sessions > 0)
                Text('${item.sessions} ${_nutPlural(item.sessions, 'séance', 'séances')}', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
            ]),
          ),
          if (_activityIsDeleted(item.activity)) ...[
            const SizedBox(width: 6),
            _Pill('supprimée', background: _colors.surfaceSunken, foreground: _colors.textMuted),
          ],
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(item.isCount ? '${item.minutes}' : _hoursLabel(item.minutes), style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.accentText, height: 1.05)),
            Text(_amountUnit(item.activity), style: TextStyle(fontSize: AppType.micro, color: _colors.textMuted)),
          ]),
          const SizedBox(width: 4),
          _uiIcon('planOpen', Icons.chevron_right, size: 19, color: _colors.textMuted),
        ]),
      ),
    );
  }

  /// Toutes les réalisations d'un jour (calendrier de la vue d'ensemble).
  void _openDayDetail(DateTime date) {
    final dayLogs = widget.logs.where((l) => (l.realisedMinutes > 0 || _logIsCount(l) || (l.reps ?? 0) > 0) && _dayKey(l.date) == _dayKey(date)).toList();
    _showDayDetailSheet(
      context,
      date: date,
      dayLogs: dayLogs,
      onEditLog: (log) async {
        await widget.onEditLog(log);
        if (mounted) setState(() {});
      },
      onOpenLog: (log) => _openActivity(_activityFor(log)),
    );
  }

  Widget _calendarCard(
    Map<int, int> perDay,
    Map<int, int> perDayCount, {
    required Map<int, List<Activity>> perDayTimeActivities,
    required Map<int, List<Activity>> perDayCountActivities,
  }) {
    var monthMinutes = 0;
    var monthCount = 0;
    perDay.forEach((key, value) {
      if (key ~/ 100 == _calMonth.year * 100 + _calMonth.month) monthMinutes += value;
    });
    perDayCount.forEach((key, value) {
      if (key ~/ 100 == _calMonth.year * 100 + _calMonth.month) monthCount += value;
    });
    return _AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            tooltip: 'Mois précédent',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _calMonth = DateTime(_calMonth.year, _calMonth.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(children: [
              Text('${_frMonthsLong[_calMonth.month - 1]} ${_calMonth.year}', style: _sectionTitleStyle(context)),
              const SizedBox(height: 2),
              Text(monthMinutes == 0 && monthCount == 0 ? 'Aucune réalisation' : '${monthMinutes > 0 ? '${_minutesLabel(monthMinutes)} vécues' : ''}${monthMinutes > 0 && monthCount > 0 ? ' · ' : ''}${monthCount > 0 ? '$monthCount occurrence${monthCount > 1 ? 's' : ''}' : ''}', style: _hintStyle()),
            ]),
          ),
          IconButton(
            tooltip: 'Mois suivant',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _calMonth = DateTime(_calMonth.year, _calMonth.month + 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        const SizedBox(height: AppSpace.s),
        _monthCalendarGrid(
          _calMonth,
          perDay,
          perDayCount: perDayCount,
          perDayTimeActivities: perDayTimeActivities,
          perDayCountActivities: perDayCountActivities,
          onDayTap: _openDayDetail,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _periodLogs();
    final totalMinutes = _timeMinutesOf(logs);

    final countLogs = logs.where(_logIsCount).toList();
    // La répartition en heures conserve uniquement les activités suivies en temps.
    // Toutes les catégories sont affichées : aucune n'est masquée dans un groupe « Autres ».
    final byCategory = <String, int>{};
    // Amorcer les catégories depuis les activités elles-mêmes permet aussi
    // d'afficher Nutrition (et les autres catégories) lorsqu'aucune occurrence
    // n'a encore été enregistrée sur la période sélectionnée.
    for (final activity in widget.activities.where((a) => !a.countOnly)) {
      final category = activity.category.trim().isEmpty ? 'Autre' : activity.category.trim();
      byCategory.putIfAbsent(category, () => 0);
    }
    for (final l in logs.where((l) => !_logIsCount(l))) {
      final resolved = _activityFor(l);
      final rawCategory = l.category.trim().isEmpty ? resolved.category : l.category.trim();
      final c = rawCategory.trim().isEmpty ? 'Autre' : rawCategory.trim();
      byCategory[c] = (byCategory[c] ?? 0) + l.realisedMinutes;
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // Une tranche nulle est omise du dessin du donut, mais la catégorie reste
    // visible dans la légende et son total à 0 h.
    final slices = sorted.where((entry) => entry.value > 0).toList();

    // Les activités suivies en occurrences (notamment Nutrition) sont suivies
    // séparément des heures afin de ne pas mélanger des unités différentes.
    final byCountCategory = <String, int>{};
    for (final activity in widget.activities.where((a) => a.countOnly)) {
      final category = activity.category.trim().isEmpty ? 'Autre' : activity.category.trim();
      byCountCategory.putIfAbsent(category, () => 0);
    }
    for (final l in countLogs) {
      final resolved = _activityFor(l);
      final rawCategory = l.category.trim().isEmpty ? resolved.category : l.category.trim();
      final c = rawCategory.trim().isEmpty ? 'Autre' : rawCategory.trim();
      byCountCategory[c] = (byCountCategory[c] ?? 0) + 1;
    }
    final sortedCountCategories = byCountCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalCountOccurrences = countLogs.length;

    DateTime? first;
    for (final l in widget.logs) {
      if (l.realisedMinutes <= 0 && !_logIsCount(l) && (l.reps ?? 0) <= 0) continue;
      if (first == null || l.date.isBefore(first)) first = l.date;
    }
    final today = DateTime.now();
    final dayNumber = first == null
        ? 0
        : _daysBetween(first, today) + 1;

    final totals = _activityTotals(logs);
    final categoryOrder = _statCategoryOrder();
    final timeTotals = totals.where((t) => t.kind == 0).toList();
    final occTotals = totals.where((t) => t.kind == 1).toList();
    final repsTotals = totals.where((t) => t.kind == 2).toList();
    final totalReps = repsTotals.fold<int>(0, (s, t) => s + t.minutes);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 28),
          children: [
            if (dayNumber > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: Center(
                  child: Text.rich(TextSpan(
                    style: TextStyle(fontSize: AppType.bodyL, color: _colors.textMuted),
                    children: [
                      const TextSpan(text: 'Jour '),
                      TextSpan(text: '$dayNumber', style: TextStyle(fontSize: AppType.h1, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      const TextSpan(text: ' avec MyBestWeek'),
                    ],
                  )),
                ),
              ),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _AchievementReportPage(logs: widget.logs, activities: widget.activities, onEditLog: widget.onEditLog, onAddForActivity: widget.onAddForActivity, onRecreate: widget.onRecreate, onRelink: widget.onRelink)),
                  ),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Mes réalisations'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _WeeksReviewPage(logs: widget.logs, activities: widget.activities)),
                  ),
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: const Text('Revue des semaines'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ),
            ]),
            if (widget.activities.any((a) => a.category.trim().toLowerCase() == 'nutrition') || widget.logs.any((l) => l.category.trim().toLowerCase() == 'nutrition')) ...[
              const SizedBox(height: AppSpace.s),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _NutritionTrackingPage(
                        activities: widget.activities,
                        logs: widget.logs,
                        goals: widget.goals,
                        onEditLog: widget.onEditLog,
                        onAddForActivity: widget.onAddForActivity,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 19),
                  label: const Text('Ouvrir le suivi Nutrition'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.m),
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: '30 jours', label: Text('30 jours')),
                  ButtonSegment<String>(value: '1 an', label: Text('1 an')),
                  ButtonSegment<String>(value: 'Tout', label: Text('Tout')),
                ],
                selected: <String>{_period},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  setState(() => _period = s.first);
                },
              ),
            ),
            const SizedBox(height: AppSpace.m),
            // ---- Section Temps : tout ce qui se compte en heures ----
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _statsSectionHeader(
                  icon: Icons.schedule_rounded,
                  title: 'Temps',
                  value: '${_hoursLabel(totalMinutes)} h',
                  hint: 'Activités suivies en durée, comptées en heures.',
                ),
                const SizedBox(height: AppSpace.m),
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _DonutPainter(
                          values: [for (final s in slices) s.value.toDouble()],
                          colors: [for (final s in slices) _categoryColor(s.key, categoryOrder)],
                          track: _colors.border,
                        ),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Total investi', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                        Text(_hoursLabel(totalMinutes), style: TextStyle(fontFamily: AppFonts.serif, fontSize: 44, fontWeight: FontWeight.w700, color: _colors.textStrong, height: 1.1)),
                        const SizedBox(height: 2),
                        const _Pill('heures'),
                      ]),
                    ]),
                  ),
                ),
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.l),
                    child: Center(
                      child: Text(
                        countLogs.isEmpty
                            ? 'Aucune catégorie de durée enregistrée.'
                            : 'Aucune durée enregistrée ; les occurrences sont détaillées plus bas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _colors.textMuted),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < sorted.length; i++)
                    _legendRow(
                      sorted[i].key,
                      sorted[i].value,
                      totalMinutes,
                      _categoryColor(sorted[i].key, categoryOrder),
                      onTap: () => _openCategoryDetail(sorted[i].key, [sorted[i].key], logs, onlyCount: false),
                    ),
                if (sorted.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.m),
                    child: Text('Touche une catégorie pour voir le détail.', style: _hintStyle()),
                  ),
                if (timeTotals.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.l),
                  Divider(height: 1, color: _colors.border),
                  const SizedBox(height: AppSpace.m),
                  const _SectionHeader(
                    iconKey: 'insights',
                    fallbackIcon: Icons.auto_graph_outlined,
                    title: 'Par activité',
                    subtitle: 'Touche une activité pour voir son détail.',
                  ),
                  const SizedBox(height: AppSpace.s),
                  ..._activityRows(timeTotals),
                ],
              ]),
            ),
            // ---- Section Occurrences : tout ce qui se compte en fois (jamais ajouté aux heures) ----
            if (sortedCountCategories.isNotEmpty) ...[
              const SizedBox(height: AppSpace.m),
              _AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _statsSectionHeader(
                    icon: Icons.task_alt_rounded,
                    title: 'Occurrences',
                    value: '$totalCountOccurrences fois',
                    hint: 'Activités suivies en nombre de fois, comptées à part des heures.',
                  ),
                  for (var i = 0; i < sortedCountCategories.length; i++)
                    _countCategoryRow(
                      sortedCountCategories[i].key,
                      sortedCountCategories[i].value,
                      totalCountOccurrences,
                      _categoryColor(sortedCountCategories[i].key, categoryOrder),
                      onTap: () => _openCategoryDetail(sortedCountCategories[i].key, [sortedCountCategories[i].key], logs, onlyCount: true),
                    ),
                  if (occTotals.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.l),
                    Divider(height: 1, color: _colors.border),
                    const SizedBox(height: AppSpace.m),
                    const _SectionHeader(
                      iconKey: 'insights',
                      fallbackIcon: Icons.auto_graph_outlined,
                      title: 'Par activité',
                      subtitle: 'Touche une activité pour voir son détail.',
                    ),
                    const SizedBox(height: AppSpace.s),
                    ..._activityRows(occTotals),
                  ],
                  if (repsTotals.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.l),
                    Divider(height: 1, color: _colors.border),
                    const SizedBox(height: AppSpace.m),
                    _SectionHeader(
                      iconKey: 'insights',
                      fallbackIcon: Icons.repeat_rounded,
                      title: 'Répétitions',
                      subtitle: '$totalReps rép. au total, comptées à part des occurrences.',
                    ),
                    const SizedBox(height: AppSpace.s),
                    ..._activityRows(repsTotals),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: AppSpace.m),
            _calendarCard(
              _minutesPerDay(widget.logs.where((l) => l.realisedMinutes > 0 && !_logIsCount(l))),
              _countsPerDay(widget.logs.where(_logIsCount)),
              perDayTimeActivities: _activitiesPerDay(widget.logs, count: false),
              perDayCountActivities: _activitiesPerDay(widget.logs, count: true),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fiche d'une activité
// ---------------------------------------------------------------------------

class _ActivityStatsPage extends StatefulWidget {
  final Activity activity;
  final List<ActivityLog> logs;

  final Future<void> Function(ActivityLog log) onEditLog;
  final Future<void> Function(Activity activity) onAddForActivity;
  final Future<void> Function(Activity activity) onRecreate;
  final Future<void> Function(Activity activity) onRelink;

  const _ActivityStatsPage({required this.activity, required this.logs, required this.onEditLog, required this.onAddForActivity, required this.onRecreate, required this.onRelink});

  @override
  State<_ActivityStatsPage> createState() => _ActivityStatsPageState();
}

class _ActivityStatsPageState extends State<_ActivityStatsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String _fullDate(DateTime d) => '${d.day} ${_frMonthsLong[d.month - 1]} ${d.year}';

  Widget _kpi(String value, String label, {Color? color}) {
    return Expanded(
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: color ?? _colors.accentText, height: 1.1)),
        ),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted, height: 1.2)),
      ]),
    );
  }

  Widget _heatRow(DateTime month, Map<int, int> perDay) => _heatMonthRow(month, perDay);

  /// Réalisations de cette activité un jour donné.
  void _openDayDetail(DateTime date) {
    final dayLogs = widget.logs.where((l) => (l.realisedMinutes > 0 || widget.activity.countOnly || (l.reps ?? 0) > 0) && _dayKey(l.date) == _dayKey(date) && _logIsOfActivity(l, widget.activity)).toList();
    _showDayDetailSheet(
      context,
      date: date,
      dayLogs: dayLogs,
      activity: widget.activity,
      onEditLog: (log) async {
        await widget.onEditLog(log);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _calendar(Map<int, int> perDay, {bool count = false}) {
    final iconsByDay = <int, List<Activity>>{
      for (final key in perDay.keys) key: <Activity>[widget.activity],
    };
    return count
        ? _monthCalendarGrid(
            _month,
            const <int, int>{},
            perDayCount: perDay,
            perDayCountActivities: iconsByDay,
            onDayTap: _openDayDetail,
          )
        : _monthCalendarGrid(
            _month,
            perDay,
            perDayTimeActivities: iconsByDay,
            onDayTap: _openDayDetail,
          );
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final logs = widget.logs.where((l) => (l.realisedMinutes > 0 || activity.countOnly || (l.reps ?? 0) > 0) && _logIsOfActivity(l, activity)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final isCount = activity.countOnly;
    final isReps = _isRepsOnly(activity);
    final hasRepsExtra = _isRepsActivity(activity) && !activity.countOnly;
    int amount(ActivityLog l) => isCount ? 1 : l.realisedMinutes;
    final total = logs.fold<int>(0, (s, l) => s + amount(l));
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final firstDate = logs.isEmpty ? null : logs.last.date;
    final days = firstDate == null ? 0 : _daysBetween(firstDate, todayDate) + 1;
    final perWeek = days <= 0 ? 0 : (total / max(1.0, days / 7.0)).round();
    final perWeekCount = days <= 0 ? 0.0 : total / max(1.0, days / 7.0);
    final last7 = logs.where((l) => !l.date.isBefore(_addDays(todayDate, -6))).fold<int>(0, (s, l) => s + amount(l));
    final nextMilestone = isCount ? _nextCountMilestone(total) : _nextMilestoneMinutes(total);
    final toMilestone = nextMilestone == null ? 0 : nextMilestone - total;

    final repsLogs = logs.where((l) => l.reps != null).toList();
    final repsLast = repsLogs.isEmpty ? null : repsLogs.first.reps;
    final repsBest = repsLogs.fold<int>(0, (m, l) => max(m, l.reps ?? 0));
    final repsAvg = repsLogs.isEmpty ? 0 : (_repsTotal(repsLogs) / repsLogs.length).round();
    final perDay = <int, int>{};
    for (final l in logs) {
      perDay[_dayKey(l.date)] = (perDay[_dayKey(l.date)] ?? 0) + amount(l);
    }
    final monthMinutes = logs.where((l) => l.date.year == _month.year && l.date.month == _month.month).fold<int>(0, (s, l) => s + amount(l));
    final monthReps = _repsTotal(logs.where((l) => l.date.year == _month.year && l.date.month == _month.month));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de l’activité'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 28),
          children: [
            _AppCard(
              tone: _CardTone.tint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: _colors.card, child: _activityIconWidget(activity.emoji, size: 38)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _sheetTitleStyle(context)),
                      const SizedBox(height: 3),
                      Text(firstDate == null ? 'Pas encore de réalisation' : '${_activityIsDeleted(activity) ? 'Activité supprimée · ' : ''}Depuis le ${_fullDate(firstDate)}', style: _hintStyle()),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(isReps ? '${_repsTotal(logs)}' : (isCount ? '$total' : _hoursLabel(total)), style: TextStyle(fontSize: AppType.display + 6, fontWeight: FontWeight.w800, color: _colors.goldText, height: 1)),
                    Text(_amountUnit(activity), style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.goldText)),
                  ]),
                ]),
                const SizedBox(height: AppSpace.l),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ...(isReps
                      ? <Widget>[
                          _kpi(repsLast == null ? '—' : '$repsLast', 'Dernière'),
                          _kpi('$repsBest', 'Meilleure'),
                          _kpi('${activity.repsTarget}', 'Objectif'),
                          _kpi('$repsAvg', 'Moyenne'),
                        ]
                      : <Widget>[
                      _kpi('$days', days > 1 ? 'Jours' : 'Jour'),
                      _kpi(isCount ? '${perWeekCount.toStringAsFixed(1).replaceAll('.', ',')}×' : '${_hoursLabel(perWeek)} h', 'Chaque semaine'),
                      _kpi(isCount ? '$last7×' : '${_hoursLabel(last7)} h', '7 derniers jours'),
                      _kpi(nextMilestone == null ? '—' : (isCount ? '$toMilestone×' : '${_hoursLabel(toMilestone)} h'), nextMilestone == null ? 'Palier max' : (isCount ? 'Avant $nextMilestone fois' : 'Avant ${nextMilestone ~/ 60} h')),
                        ]),
                ]),
                if ((isReps || hasRepsExtra) && repsLast != null && (activity.repsTarget ?? 0) > 0) ...[
                  if (hasRepsExtra) ...[
                    const SizedBox(height: AppSpace.m),
                    Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
                      _Pill('Dernière : $repsLast rép.'),
                      _Pill('Meilleure : $repsBest rép.'),
                      _Pill('Objectif : ${activity.repsTarget} rép.', background: _colors.peachBg, foreground: _colors.goldText),
                    ]),
                  ],
                  const SizedBox(height: AppSpace.m),
                  _MeterBar(value: repsLast / activity.repsTarget!, height: 8, color: repsLast >= activity.repsTarget! ? _colors.accentFill : _colors.goldBorder),
                  const SizedBox(height: 4),
                  Text('${(repsLast * 100 / activity.repsTarget!).round()} % de l’objectif (${activity.repsTarget} rép.)', style: _hintStyle()),
                ],
                const SizedBox(height: AppSpace.m),
                Divider(height: 1, color: _colors.borderTint),
                for (var i = 2; i >= 0; i--) _heatRow(DateTime(now.year, now.month - i), perDay),
              ]),
            ),
            if (_activityIsDeleted(activity)) ...[
              const SizedBox(height: AppSpace.m),
              _AppCard(
                tone: _CardTone.soft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, size: 18, color: _colors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Cette activité a été supprimée. Son historique est conservé : tu peux la recréer ou relier ces réalisations à une activité existante.', style: _hintStyle())),
                  ]),
                  const SizedBox(height: AppSpace.m),
                  Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await widget.onRecreate(activity);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Recréer l’activité'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.onRelink(activity);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Relier à une activité'),
                    ),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: AppSpace.m),
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(
                    tooltip: 'Mois précédent',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text('${_frMonthsLong[_month.month - 1]} ${_month.year}', style: _sectionTitleStyle(context)),
                      const SizedBox(height: 2),
                      Text(monthMinutes == 0 ? 'Aucune réalisation' : (isReps ? '$monthMinutes ${_nutPlural(monthMinutes, 'séance', 'séances')} · $monthReps rép.' : (isCount ? '$monthMinutes fois' : _minutesLabel(monthMinutes))), style: _hintStyle()),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Mois suivant',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ]),
                const SizedBox(height: AppSpace.s),
                _calendar(perDay, count: isCount),
                if (!_activityIsDeleted(activity)) ...[
                  const SizedBox(height: AppSpace.s),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await widget.onAddForActivity(activity);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter une réalisation passée'),
                    ),
                  ),
                ],
              ]),
            ),
            if (logs.isNotEmpty) ...[
              const SizedBox(height: AppSpace.m),
              _AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionHeader(iconKey: 'history', fallbackIcon: Icons.history_outlined, title: 'Dernières réalisations'),
                  const SizedBox(height: AppSpace.s),
                  for (final l in logs.take(6))
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Row(children: [
                        Expanded(child: Text(_friendlyDayLabel(l.date, now), style: TextStyle(fontSize: AppType.body, color: _colors.textStrong))),
                        if (l.feeling.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(width: 9, height: 9, decoration: BoxDecoration(color: _feelingColor(_normalizeFeeling(l.feeling)), shape: BoxShape.circle)),
                          ),
                        InkWell(
                          onTap: () async {
                            await widget.onEditLog(l);
                            if (mounted) setState(() {});
                          },
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(isReps ? _logAmountLabel(l) : (isCount ? '1×' : _minutesLabel(l.realisedMinutes)), style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                              const SizedBox(width: 4),
                              Icon(Icons.edit_outlined, size: 14, color: _colors.textFaint),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
