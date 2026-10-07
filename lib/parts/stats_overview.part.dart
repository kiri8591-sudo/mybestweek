// V12.6.0 — Statistiques : vue d'ensemble (anneau « Total investi ») et fiche par activité
// (total en heures, jours depuis le début, rythme hebdomadaire, prochain palier,
// frise des 3 derniers mois et calendrier du mois avec les minutes de chaque jour).
// Inspiré des écrans de statistiques d'iHour ; toutes les données viennent de l'historique existant.

part of '../main.dart';

bool _logMatchesActivity(ActivityLog log, Activity activity) =>
    (log.activityId != null && log.activityId == activity.id) ||
    (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());

/// 0,6 · 4,6 · 43 · 758 (une décimale sous 10 h).
String _hoursLabel(int minutes) {
  final h = minutes / 60.0;
  if (h < 10) return h.toStringAsFixed(1).replaceAll('.', ',');
  return h.round().toString();
}

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
  final int minutes;
  const _ActivityTotal(this.activity, this.minutes);
}

// ---------------------------------------------------------------------------
// Vue d'ensemble
// ---------------------------------------------------------------------------

class _StatsOverviewPage extends StatefulWidget {
  final List<ActivityLog> logs;
  final List<Activity> activities;

  const _StatsOverviewPage({required this.logs, required this.activities});

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
    return widget.logs.where((l) => l.realisedMinutes > 0 && (cutoff == null || !l.date.isBefore(cutoff))).toList();
  }

  Activity _activityFor(ActivityLog log) => _resolveActivity(log, widget.activities);

  List<_ActivityTotal> _activityTotals(List<ActivityLog> logs) {
    final minutes = <String, int>{};
    final activities = <String, Activity>{};
    for (final log in logs) {
      final a = _activityFor(log);
      minutes[a.id] = (minutes[a.id] ?? 0) + log.realisedMinutes;
      activities[a.id] = a;
    }
    final result = [for (final e in minutes.entries) _ActivityTotal(activities[e.key]!, e.value)];
    result.sort((a, b) => b.minutes.compareTo(a.minutes));
    return result;
  }

  void _openActivity(Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _ActivityStatsPage(activity: activity, logs: widget.logs)),
    );
  }

  Widget _legendRow(String name, int minutes, int total, Color color) {
    final share = total <= 0 ? 0.0 : minutes / total;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
          Text('${_hoursLabel(minutes)} h', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text('${(share * 100).round()} %', textAlign: TextAlign.right, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted))),
        ]),
        const SizedBox(height: 5),
        _MeterBar(value: share, color: color, height: 6),
      ]),
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
          Expanded(child: Text(item.activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(_hoursLabel(item.minutes), style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.accentText, height: 1.05)),
            Text('heures', style: TextStyle(fontSize: AppType.micro, color: _colors.textMuted)),
          ]),
          const SizedBox(width: 4),
          _uiIcon('planOpen', Icons.chevron_right, size: 19, color: _colors.textMuted),
        ]),
      ),
    );
  }

  Widget _calendarCard(Map<int, int> perDay) {
    var monthMinutes = 0;
    perDay.forEach((key, value) {
      if (key ~/ 100 == _calMonth.year * 100 + _calMonth.month) monthMinutes += value;
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
              Text(monthMinutes == 0 ? 'Aucune réalisation' : '${_minutesLabel(monthMinutes)} vécues, toutes activités', style: _hintStyle()),
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
        _monthCalendarGrid(_calMonth, perDay),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _periodLogs();
    final totalMinutes = logs.fold<int>(0, (s, l) => s + l.realisedMinutes);

    final byCategory = <String, int>{};
    for (final l in logs) {
      final c = l.category.trim().isEmpty ? 'Autre' : l.category.trim();
      byCategory[c] = (byCategory[c] ?? 0) + l.realisedMinutes;
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final slices = <MapEntry<String, int>>[];
    var other = 0;
    for (var i = 0; i < sorted.length; i++) {
      if (i < 6) {
        slices.add(sorted[i]);
      } else {
        other += sorted[i].value;
      }
    }
    if (other > 0) slices.add(MapEntry('Autres', other));

    DateTime? first;
    for (final l in widget.logs) {
      if (l.realisedMinutes <= 0) continue;
      if (first == null || l.date.isBefore(first)) first = l.date;
    }
    final today = DateTime.now();
    final dayNumber = first == null
        ? 0
        : _daysBetween(first, today) + 1;

    final totals = _activityTotals(logs);

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
                    MaterialPageRoute<void>(builder: (_) => _AchievementReportPage(logs: widget.logs, activities: widget.activities)),
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
            const SizedBox(height: AppSpace.m),
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const SizedBox(height: AppSpace.l),
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _DonutPainter(
                          values: [for (final s in slices) s.value.toDouble()],
                          colors: _palette,
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
                if (slices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.l),
                    child: Center(child: Text('Aucune réalisation sur cette période.', style: TextStyle(color: _colors.textMuted))),
                  )
                else
                  for (var i = 0; i < slices.length; i++)
                    _legendRow(slices[i].key, slices[i].value, totalMinutes, _palette[i % _palette.length]),
              ]),
            ),
            const SizedBox(height: AppSpace.m),
            _calendarCard(_minutesPerDay(widget.logs.where((l) => l.realisedMinutes > 0))),
            if (totals.isNotEmpty) ...[
              const SizedBox(height: AppSpace.m),
              _AppCard(
                padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.l, AppSpace.l, AppSpace.s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _SectionHeader(
                    iconKey: 'insights',
                    fallbackIcon: Icons.auto_graph_outlined,
                    title: 'Par activité',
                    subtitle: 'Touche une activité pour voir son détail.',
                  ),
                  const SizedBox(height: AppSpace.s),
                  for (var i = 0; i < totals.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: _colors.border),
                    _activityRow(totals[i]),
                  ],
                ]),
              ),
            ],
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

  const _ActivityStatsPage({required this.activity, required this.logs});

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

  Widget _calendar(Map<int, int> perDay) => _monthCalendarGrid(_month, perDay);

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final logs = widget.logs.where((l) => l.realisedMinutes > 0 && _logMatchesActivity(l, activity)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = logs.fold<int>(0, (s, l) => s + l.realisedMinutes);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final firstDate = logs.isEmpty ? null : logs.last.date;
    final days = firstDate == null ? 0 : _daysBetween(firstDate, todayDate) + 1;
    final perWeek = days <= 0 ? 0 : (total / max(1.0, days / 7.0)).round();
    final last7 = logs.where((l) => !l.date.isBefore(_addDays(todayDate, -6))).fold<int>(0, (s, l) => s + l.realisedMinutes);
    final nextMilestone = _nextMilestoneMinutes(total);
    final toMilestone = nextMilestone == null ? 0 : nextMilestone - total;

    final perDay = <int, int>{};
    for (final l in logs) {
      perDay[_dayKey(l.date)] = (perDay[_dayKey(l.date)] ?? 0) + l.realisedMinutes;
    }
    final monthMinutes = logs.where((l) => l.date.year == _month.year && l.date.month == _month.month).fold<int>(0, (s, l) => s + l.realisedMinutes);

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
                      Text(firstDate == null ? 'Pas encore de réalisation' : 'Depuis le ${_fullDate(firstDate)}', style: _hintStyle()),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(_hoursLabel(total), style: TextStyle(fontSize: AppType.display + 6, fontWeight: FontWeight.w800, color: _colors.goldText, height: 1)),
                    Text('heures', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.goldText)),
                  ]),
                ]),
                const SizedBox(height: AppSpace.l),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kpi('$days', days > 1 ? 'Jours' : 'Jour'),
                  _kpi('${_hoursLabel(perWeek)} h', 'Chaque semaine'),
                  _kpi('${_hoursLabel(last7)} h', '7 derniers jours'),
                  _kpi(nextMilestone == null ? '—' : '${_hoursLabel(toMilestone)} h', nextMilestone == null ? 'Palier max' : 'Avant ${nextMilestone ~/ 60} h'),
                ]),
                const SizedBox(height: AppSpace.m),
                Divider(height: 1, color: _colors.borderTint),
                for (var i = 2; i >= 0; i--) _heatRow(DateTime(now.year, now.month - i), perDay),
              ]),
            ),
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
                      Text(monthMinutes == 0 ? 'Aucune réalisation' : _minutesLabel(monthMinutes), style: _hintStyle()),
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
                _calendar(perDay),
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
                        Text(_minutesLabel(l.realisedMinutes), style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textMuted)),
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
