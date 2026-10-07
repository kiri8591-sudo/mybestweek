// V12.7.0 — « Mes réalisations » (rapport par année) et « Revue des semaines »
// (grille activités × 7 jours). Inspiré des écrans My Achievement Report et Review d'iHour.
// Données : uniquement l'historique existant (ActivityLog), aucune nouvelle sauvegarde.

part of '../main.dart';

/// Écart en jours calendaires, insensible au changement d'heure.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String _longDate(DateTime d) => '${d.day} ${_frMonthsLong[d.month - 1]} ${d.year}';

/// Lundi (minuit) de la semaine de [d], sans dérive due à l'heure d'été.
DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Numéro de semaine ISO et année ISO.
(int week, int year) _isoWeek(DateTime d) {
  final thursday = DateTime(d.year, d.month, d.day + 4 - d.weekday);
  final t = DateTime.utc(thursday.year, thursday.month, thursday.day);
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  return ((t.difference(jan1).inDays ~/ 7) + 1, thursday.year);
}

Activity _resolveActivity(ActivityLog log, List<Activity> activities) {
  for (final a in activities) {
    if (_logMatchesActivity(log, a)) return a;
  }
  return Activity(
    id: 'stats_${log.title.trim().toLowerCase().hashCode}',
    name: log.title,
    emoji: log.emoji,
    category: log.category,
    period: log.period,
    duration: log.plannedMinutes,
    frequency: 1,
    priority: 1,
  );
}

/// Plus longue suite de jours consécutifs avec au moins une réalisation.
int _longestStreak(Iterable<ActivityLog> logs) {
  final days = logs.map((l) => DateTime.utc(l.date.year, l.date.month, l.date.day)).toSet().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final d in days) {
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

Map<int, int> _minutesPerDay(Iterable<ActivityLog> logs) {
  final map = <int, int>{};
  for (final l in logs) {
    map[_dayKey(l.date)] = (map[_dayKey(l.date)] ?? 0) + l.realisedMinutes;
  }
  return map;
}

/// Une ligne de frise : un mois, une case par jour (colorée si réalisé).
Widget _heatMonthRow(DateTime month, Map<int, int> perDay) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  return Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(children: [
      SizedBox(width: 44, child: Text(_frMonthsShort[month.month - 1], style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted))),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final size = max(4.0, min(14.0, (c.maxWidth - 31 * 2) / 31));
          return Row(children: [
            for (var d = 1; d <= days; d++)
              Container(
                width: size,
                height: size,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: (perDay[_dayKey(DateTime(month.year, month.month, d))] ?? 0) > 0 ? _colors.accentFill : _colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ]);
        }),
      ),
    ]),
  );
}

Widget _kpiCell(String value, String label, {Color? color}) {
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

class _ActivityGroup {
  final Activity activity;
  final List<ActivityLog> logs = [];
  int minutes = 0;
  _ActivityGroup(this.activity);
}

// ---------------------------------------------------------------------------
// Mes réalisations
// ---------------------------------------------------------------------------

class _AchievementReportPage extends StatefulWidget {
  final List<ActivityLog> logs;
  final List<Activity> activities;

  const _AchievementReportPage({required this.logs, required this.activities});

  @override
  State<_AchievementReportPage> createState() => _AchievementReportPageState();
}

class _AchievementReportPageState extends State<_AchievementReportPage> {
  String _scope = 'Tout';

  Widget _summaryLine(String label, String value, [String? unit]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(TextSpan(
        style: TextStyle(fontSize: AppType.bodyL, color: _colors.textMuted, height: 1.25),
        children: [
          TextSpan(text: '$label '),
          TextSpan(text: value, style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _colors.textStrong)),
          if (unit != null) TextSpan(text: ' $unit'),
        ],
      )),
    );
  }

  Widget _groupCard(_ActivityGroup g) {
    final sorted = [...g.logs]..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first.date;
    final last = sorted.last.date;
    final days = g.logs.map((l) => _dayKey(l.date)).toSet().length;
    final span = _daysBetween(first, last) + 1;
    final perWeek = (g.minutes / max(1.0, span / 7.0)).round();
    final longestRecord = g.logs.fold<int>(0, (m, l) => max(m, l.realisedMinutes));
    final perDay = _minutesPerDay(g.logs);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: _AppCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _ActivityStatsPage(activity: g.activity, logs: widget.logs)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 24, backgroundColor: _colors.tintStrong, child: _activityIconWidget(g.activity.emoji, size: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _sectionTitleStyle(context)),
                const SizedBox(height: 3),
                Text('${_longDate(first)} ~ ${_longDate(last)}', style: _hintStyle()),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(_hoursLabel(g.minutes), style: TextStyle(fontSize: AppType.display + 2, fontWeight: FontWeight.w800, color: _colors.goldText, height: 1)),
              Text('heures', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.goldText)),
            ]),
          ]),
          const SizedBox(height: AppSpace.l),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kpiCell('$days', days > 1 ? 'Jours' : 'Jour'),
            _kpiCell('${_hoursLabel(perWeek)} h', 'Chaque semaine'),
            _kpiCell('${_longestStreak(g.logs)}', 'Plus longue série (j)'),
            _kpiCell(_minutesLabel(longestRecord), 'Plus long record'),
          ]),
          const SizedBox(height: AppSpace.s),
          for (var i = 2; i >= 0; i--) _heatMonthRow(DateTime(last.year, last.month - i), perDay),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.logs.where((l) => l.realisedMinutes > 0).toList();
    final years = (all.map((l) => l.date.year).toSet().toList()..sort((a, b) => b.compareTo(a)));
    final scopes = ['Tout', ...years.map((y) => '$y')];
    if (!scopes.contains(_scope)) _scope = 'Tout';
    final logs = _scope == 'Tout' ? all : all.where((l) => '${l.date.year}' == _scope).toList();

    final total = logs.fold<int>(0, (s, l) => s + l.realisedMinutes);
    final recordedDays = logs.map((l) => _dayKey(l.date)).toSet().length;

    final groups = <String, _ActivityGroup>{};
    for (final l in logs) {
      final a = _resolveActivity(l, widget.activities);
      final g = groups.putIfAbsent(a.id, () => _ActivityGroup(a));
      g.logs.add(l);
      g.minutes += l.realisedMinutes;
    }
    final ordered = groups.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));

    final heatYear = _scope == 'Tout' ? DateTime.now().year : (int.tryParse(_scope) ?? DateTime.now().year);
    final yearPerDay = _minutesPerDay(all.where((l) => l.date.year == heatYear));

    return Scaffold(
      appBar: AppBar(title: const Text('Mes réalisations'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.s, AppSpace.l, 28),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final s in scopes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700)),
                      selected: _scope == s,
                      onSelected: (_) => setState(() => _scope = s),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.m),
            if (logs.isEmpty)
              _AppCard(
                tone: _CardTone.soft,
                child: Center(child: Text('Aucune réalisation enregistrée sur cette période.', style: TextStyle(color: _colors.textMuted))),
              )
            else ...[
              _AppCard(
                tone: _CardTone.tint,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: _colors.card, shape: BoxShape.circle, border: Border.all(color: _colors.borderTint)),
                      alignment: Alignment.center,
                      child: _uiIcon('insights', Icons.emoji_events_outlined, size: 34, color: _colors.goldText),
                    ),
                    const SizedBox(width: AppSpace.l),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _summaryLine('Jours enregistrés', '$recordedDays'),
                        _summaryLine('Total investi', _hoursLabel(total), 'h'),
                        if (ordered.isNotEmpty) _summaryLine('Le plus investi', ordered.first.activity.name, '${_hoursLabel(ordered.first.minutes)} h'),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: AppSpace.m),
                  Divider(height: 1, color: _colors.borderTint),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s),
                    child: Text('Année $heatYear', style: _hintStyle()),
                  ),
                  for (var m = 1; m <= 12; m++) _heatMonthRow(DateTime(heatYear, m), yearPerDay),
                ]),
              ),
              const SizedBox(height: AppSpace.m),
              for (final g in ordered) _groupCard(g),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Revue des semaines
// ---------------------------------------------------------------------------

class _WeeksReviewPage extends StatelessWidget {
  final List<ActivityLog> logs;
  final List<Activity> activities;

  const _WeeksReviewPage({required this.logs, required this.activities});

  Widget _cell(bool on) {
    return Container(
      height: 32,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: on ? _colors.accentFill : _colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
      ),
      child: on ? Icon(Icons.check_rounded, size: 18, color: _colors.card) : null,
    );
  }

  Widget _weekCard(BuildContext context, DateTime monday, List<ActivityLog> weekLogs, bool current) {
    final (week, isoYear) = _isoWeek(monday);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    final groups = <String, _ActivityGroup>{};
    for (final l in weekLogs) {
      final a = _resolveActivity(l, activities);
      final g = groups.putIfAbsent(a.id, () => _ActivityGroup(a));
      g.logs.add(l);
      g.minutes += l.realisedMinutes;
    }
    final ordered = groups.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: _AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text.rich(TextSpan(
              style: TextStyle(fontFamily: AppFonts.serif, fontSize: AppType.title, fontWeight: FontWeight.w700, color: _colors.textMuted),
              children: [
                TextSpan(text: '$isoYear  Semaine '),
                TextSpan(text: '$week', style: TextStyle(fontSize: AppType.titleL + 3, color: _colors.textStrong)),
              ],
            )),
            if (current) ...[
              const SizedBox(width: 8),
              _Pill('En cours', background: _colors.warnBg, foreground: _colors.goldText),
            ],
            const Spacer(),
            Text('${dm(monday)} – ${dm(sunday)}', style: _hintStyle()),
          ]),
          const SizedBox(height: AppSpace.s),
          Divider(height: 1, color: _colors.border),
          const SizedBox(height: AppSpace.s),
          Row(children: [
            const SizedBox(width: 112),
            for (final l in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
              Expanded(child: Center(child: Text(l, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textFaint)))),
          ]),
          if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
              child: Text('Aucune réalisation pour l’instant cette semaine.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
            )
          else
            for (final g in ordered)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  SizedBox(
                    width: 112,
                    child: Row(children: [
                      _activityIconWidget(g.activity.emoji, size: 26),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g.activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textStrong, height: 1.2))),
                    ]),
                  ),
                  for (var d = 1; d <= 7; d++) Expanded(child: _cell(g.logs.any((l) => l.date.weekday == d))),
                ]),
              ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = logs.where((l) => l.realisedMinutes > 0).toList();
    final now = DateTime.now();
    final currentMonday = _mondayOf(now);
    DateTime? firstMonday;
    for (final l in done) {
      final m = _mondayOf(l.date);
      if (firstMonday == null || m.isBefore(firstMonday)) firstMonday = m;
    }
    final first = firstMonday ?? currentMonday;
    final weeksCount = (_daysBetween(first, currentMonday) ~/ 7) + 1;
    final byWeek = <int, List<ActivityLog>>{};
    for (final l in done) {
      byWeek.putIfAbsent(_daysBetween(first, _mondayOf(l.date)) ~/ 7, () => []).add(l);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Revue des semaines'), leading: const BackButton()),
      body: SafeArea(
        child: done.isEmpty
            ? Center(child: Text('Aucune réalisation enregistrée pour le moment.', style: TextStyle(color: _colors.textMuted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 28),
                itemCount: weeksCount,
                itemBuilder: (context, i) {
                  final idx = weeksCount - 1 - i;
                  final weekLogs = byWeek[idx] ?? const <ActivityLog>[];
                  final isCurrent = idx == weeksCount - 1;
                  if (weekLogs.isEmpty && !isCurrent) return const SizedBox.shrink();
                  final monday = DateTime(first.year, first.month, first.day + idx * 7);
                  return _weekCard(context, monday, weekLogs, isCurrent);
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendrier d'un mois (partagé : vue d'ensemble et fiche d'activité)
// ---------------------------------------------------------------------------

String _cellMinutes(int minutes) => minutes < 60 ? '${minutes}m' : '${_hoursLabel(minutes)}h';

Widget _calendarDayCell(int day, int minutes, bool isToday) {
  final active = minutes > 0;
  return AspectRatio(
    aspectRatio: .95,
    child: Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: active ? _colors.accentFill : _colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: isToday ? Border.all(color: _colors.accentText, width: 1.5) : null,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$day', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: active ? _colors.card : _colors.textMuted, height: 1.1)),
            if (active) Text(_cellMinutes(minutes), style: TextStyle(fontSize: AppType.micro, color: _colors.card, height: 1.1)),
          ]),
        ),
      ),
    ),
  );
}

/// Grille du mois (lundi en premier) : jour + minutes vécues les jours actifs.
Widget _monthCalendarGrid(DateTime month, Map<int, int> perDay) {
  final first = DateTime(month.year, month.month, 1);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final lead = first.weekday - 1;
  final todayKey = _dayKey(DateTime.now());
  final cells = <Widget>[
    for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    for (var d = 1; d <= days; d++)
      _calendarDayCell(d, perDay[_dayKey(DateTime(month.year, month.month, d))] ?? 0, todayKey == _dayKey(DateTime(month.year, month.month, d))),
  ];
  while (cells.length % 7 != 0) {
    cells.add(const SizedBox.shrink());
  }
  return Column(children: [
    Row(children: [
      for (final l in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
        Expanded(child: Center(child: Text(l, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted)))),
    ]),
    const SizedBox(height: 4),
    for (var r = 0; r < cells.length ~/ 7; r++)
      Row(children: [for (var c = 0; c < 7; c++) Expanded(child: cells[r * 7 + c])]),
  ]);
}
