// V12.26.0 — Tableau de bord Nutrition : objectifs de l'onglet Objectifs et suivi multi-périodes.

part of '../main.dart';

class _NutritionTrackingPage extends StatefulWidget {
  final List<Activity> activities;
  final List<ActivityLog> logs;
  final List<RealizationGoal> goals;
  final Future<void> Function(ActivityLog log) onEditLog;
  final Future<void> Function(Activity activity) onAddForActivity;

  const _NutritionTrackingPage({
    required this.activities,
    required this.logs,
    required this.goals,
    required this.onEditLog,
    required this.onAddForActivity,
  });

  @override
  State<_NutritionTrackingPage> createState() => _NutritionTrackingPageState();
}

class _NutritionTrackingPageState extends State<_NutritionTrackingPage> {
  static const List<String> _monthNames = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  String _period = 'Semaine';
  DateTime _anchor = DateTime.now();
  DateTime _rangeStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _rangeEnd = DateTime.now();
  bool _historyExpanded = false;

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTimeRange _bounds() {
    final anchor = _dateOnly(_anchor);
    switch (_period) {
      case 'Mois':
        return DateTimeRange(
          start: DateTime(anchor.year, anchor.month, 1),
          end: DateTime(anchor.year, anchor.month + 1, 0),
        );
      case 'Année':
        return DateTimeRange(
          start: DateTime(anchor.year, 1, 1),
          end: DateTime(anchor.year, 12, 31),
        );
      case 'Dates':
        final start = _dateOnly(_rangeStart);
        final end = _dateOnly(_rangeEnd);
        return DateTimeRange(start: start, end: end.isBefore(start) ? start : end);
      case 'Semaine':
      default:
        final start = anchor.subtract(Duration(days: anchor.weekday - DateTime.monday));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
    }
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _periodLabel(DateTimeRange range) {
    switch (_period) {
      case 'Mois':
        return '${_monthNames[range.start.month - 1]} ${range.start.year}';
      case 'Année':
        return '${range.start.year}';
      case 'Dates':
        return 'Du ${_dateLabel(range.start)} au ${_dateLabel(range.end)}';
      case 'Semaine':
      default:
        return 'Du ${_dateLabel(range.start)} au ${_dateLabel(range.end)}';
    }
  }

  void _shiftPeriod(int amount) {
    setState(() {
      if (_period == 'Semaine') {
        _anchor = _anchor.add(Duration(days: amount * 7));
      } else if (_period == 'Mois') {
        _anchor = DateTime(_anchor.year, _anchor.month + amount, 1);
      } else if (_period == 'Année') {
        _anchor = DateTime(_anchor.year + amount, _anchor.month, 1);
      }
      _historyExpanded = false;
    });
  }

  Future<void> _pickRangeStart() async {
    final now = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeStart.isAfter(now) ? now : _rangeStart,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Date de début',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rangeStart = _dateOnly(picked);
      if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = _rangeStart;
      _historyExpanded = false;
    });
  }

  Future<void> _pickRangeEnd() async {
    final now = _dateOnly(DateTime.now());
    final initial = _rangeEnd.isAfter(now) ? now : _rangeEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_rangeStart) ? _rangeStart : initial,
      firstDate: _rangeStart,
      lastDate: now,
      helpText: 'Date de fin',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rangeEnd = _dateOnly(picked);
      _historyExpanded = false;
    });
  }

  List<Activity> _nutritionActivities() {
    final result = widget.activities
        .where((activity) =>
            activity.category.trim().toLowerCase() == 'nutrition' &&
            !activity.isDateRange &&
            !activity.isSportProgram)
        .toList();
    result.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0 ? priority : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  bool _isInRange(ActivityLog log, DateTimeRange range) {
    final date = _dateOnly(log.date);
    return !date.isBefore(range.start) && !date.isAfter(range.end);
  }

  List<ActivityLog> _logsForActivity(Activity activity, DateTimeRange range) {
    final result = widget.logs.where((log) =>
        _isLogRealised(log) &&
        _isLogOfActivity(log, activity) &&
        _isInRange(log, range)).toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  bool _isLogRealised(ActivityLog log) {
    if (log.realisedMinutes > 0 || (log.reps ?? 0) > 0) return true;
    for (final activity in widget.activities) {
      final matches = (log.activityId != null && log.activityId == activity.id) ||
          (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());
      if (matches && activity.category.trim().toLowerCase() == 'nutrition' && activity.countOnly) return true;
    }
    return false;
  }

  bool _isLogOfActivity(ActivityLog log, Activity activity) =>
      (log.activityId != null && log.activityId == activity.id) ||
      (log.activityId == null &&
          log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());

  List<RealizationGoal> _goalsForActivity(Activity activity) => widget.goals
      .where((goal) => goal.activityId == activity.id)
      .toList()
    ..sort((a, b) {
      final cadenceOrder = const {'jour': 0, 'semaine': 1, 'mois': 2};
      final byCadence = (cadenceOrder[a.cadence] ?? 1).compareTo(cadenceOrder[b.cadence] ?? 1);
      return byCadence != 0 ? byCadence : a.isMaximum.toString().compareTo(b.isMaximum.toString());
    });

  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  int _expectedForGoal(RealizationGoal goal, DateTimeRange range) {
    var start = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    if (end.isBefore(start)) return 0;

    // Les objectifs jour/semaine commencent à compter à leur date de création.
    // L'objectif mensuel conserve la règle de l'onglet Objectifs : il vaut pour
    // le mois de création entier, y compris les réalisations du début du mois.
    if (goal.cadence == 'mois') {
      final firstGoalMonth = DateTime(goal.createdAt.year, goal.createdAt.month, 1);
      if (end.isBefore(firstGoalMonth)) return 0;
      start = _maxDate(start, firstGoalMonth);
    } else {
      start = _maxDate(start, _dateOnly(goal.createdAt));
      if (end.isBefore(start)) return 0;
    }

    final days = end.difference(start).inDays + 1;
    if (goal.cadence == 'jour') return goal.target * days;
    if (goal.cadence == 'semaine' && _period == 'Semaine') {
      // Dans la vue Semaine, on reprend exactement la cible hebdomadaire de
      // l'onglet Objectifs, même si l'objectif a été créé en cours de semaine.
      return goal.target;
    }
    if (goal.cadence == 'mois') {
      var cursor = DateTime(start.year, start.month, 1);
      var exact = 0.0;
      while (!cursor.isAfter(end)) {
        final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
        final monthEnd = nextMonth.subtract(const Duration(days: 1));
        final overlapStart = _maxDate(start, cursor);
        final overlapEnd = _minDate(end, monthEnd);
        final overlapDays = overlapEnd.difference(overlapStart).inDays + 1;
        if (overlapDays > 0) {
          final daysInMonth = nextMonth.difference(cursor).inDays;
          exact += goal.target * overlapDays / daysInMonth;
        }
        cursor = nextMonth;
      }
      return exact.ceil();
    }

    // Cadence hebdomadaire : prorata des jours couverts, ce qui permet une
    // comparaison cohérente pour les mois, années et périodes personnalisées.
    return (goal.target * days / 7.0).ceil();
  }

  int _actualForGoal(RealizationGoal goal, Activity activity, DateTimeRange range) {
    var count = 0;
    final isWholeWeekView = goal.cadence == 'semaine' && _period == 'Semaine';
    final firstGoalMonth = DateTime(goal.createdAt.year, goal.createdAt.month, 1);
    for (final log in widget.logs) {
      if (!_isLogRealised(log) || !_isLogOfActivity(log, activity) || !_isInRange(log, range)) continue;

      // Une cible « au moins N fois par semaine » se juge sur la semaine
      // calendaire entière. Une réalisation faite lundi/mardi doit donc être
      // comptée même si l'objectif a été créé plus tard dans la même semaine.
      // C'est cohérent avec _expectedForGoal, qui affiche déjà la cible
      // hebdomadaire complète dans cette vue.
      if (isWholeWeekView) {
        count++;
        continue;
      }

      if (goal.cadence == 'mois') {
        if (_dateOnly(log.date).isBefore(firstGoalMonth)) continue;
      } else {
        // Pour les périodes partielles/personnalisées, le suivi commence à la
        // date de création de l'objectif. Comparaison au jour, sans l'heure.
        if (_dateOnly(log.date).isBefore(_dateOnly(goal.createdAt))) continue;
      }
      count++;
    }
    return count;
  }

  bool _goalSatisfied(RealizationGoal goal, int actual, int expected) =>
      goal.isMaximum ? actual <= expected : actual >= expected;

  List<ActivityLog> _allNutritionLogs(DateTimeRange range, List<Activity> nutritionActivities) {
    final ids = nutritionActivities.map((a) => a.id).toSet();
    final names = nutritionActivities.map((a) => a.name.trim().toLowerCase()).toSet();
    final result = widget.logs.where((log) {
      final linkedNutrition = log.activityId != null && ids.contains(log.activityId);
      final legacyNutrition = log.activityId == null && names.contains(log.title.trim().toLowerCase());
      final nutritionCategory = log.category.trim().toLowerCase() == 'nutrition';
      return _isLogRealised(log) &&
          (linkedNutrition || legacyNutrition || nutritionCategory) &&
          _isInRange(log, range);
    }).toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> _addFor(Activity activity) async {
    await widget.onAddForActivity(activity);
    if (mounted) setState(() {});
  }

  Future<void> _editLog(ActivityLog log) async {
    await widget.onEditLog(log);
    if (mounted) setState(() {});
  }

  Widget _periodSelector() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'Semaine', label: Text('Semaine')),
            ButtonSegment<String>(value: 'Mois', label: Text('Mois')),
            ButtonSegment<String>(value: 'Année', label: Text('Année')),
            ButtonSegment<String>(value: 'Dates', label: Text('Dates')),
          ],
          selected: <String>{_period},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() {
              _period = selection.first;
              _historyExpanded = false;
            });
          },
          showSelectedIcon: false,
        ),
      );

  Widget _periodNavigation(DateTimeRange range) {
    if (_period == 'Dates') {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpace.s,
        runSpacing: AppSpace.s,
        children: [
          OutlinedButton.icon(
            onPressed: _pickRangeStart,
            icon: const Icon(Icons.event_outlined, size: 17),
            label: Text('Du ${_dateLabel(range.start)}'),
          ),
          OutlinedButton.icon(
            onPressed: _pickRangeEnd,
            icon: const Icon(Icons.event_available_outlined, size: 17),
            label: Text('Au ${_dateLabel(range.end)}'),
          ),
        ],
      );
    }
    return Row(children: [
      IconButton(
        tooltip: 'Période précédente',
        visualDensity: VisualDensity.compact,
        onPressed: () => _shiftPeriod(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text(
          _periodLabel(range),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong),
        ),
      ),
      IconButton(
        tooltip: 'Période suivante',
        visualDensity: VisualDensity.compact,
        onPressed: () => _shiftPeriod(1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ]);
  }

  Widget _goalProgressRow(Activity activity, RealizationGoal goal, DateTimeRange range) {
    final expected = _expectedForGoal(goal, range);
    final actual = _actualForGoal(goal, activity, range);
    final active = expected > 0;
    final satisfied = active && _goalSatisfied(goal, actual, expected);
    final ratio = !active
        ? 0.0
        : goal.isMaximum
            ? (actual / expected).clamp(0.0, 1.0).toDouble()
            : (actual / expected).clamp(0.0, 1.0).toDouble();
    final cadenceLabel = goal.cadence == 'jour'
        ? 'par jour'
        : goal.cadence == 'mois'
            ? 'par mois'
            : 'par semaine';
    final limitText = '${goal.isMaximum ? 'Au plus' : 'Au moins'} ${goal.target} $cadenceLabel';
    final status = !active
        ? 'Objectif non actif sur cette période'
        : goal.isMaximum
            ? (satisfied ? 'Dans la limite fixée' : 'Plafond dépassé de ${actual - expected}')
            : (satisfied ? 'Objectif atteint' : 'Encore ${expected - actual} à réaliser');
    final statusColor = !active
        ? _colors.textMuted
        : goal.isMaximum && !satisfied
            ? _colors.warnBorder
            : satisfied
                ? _colors.accentText
                : _colors.textMuted;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s),
        decoration: BoxDecoration(
          color: _colors.surfaceSunken.withOpacity(0.45),
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _colors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(limitText, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textStrong))),
            Text('$actual / $expected', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w900, color: statusColor)),
          ]),
          const SizedBox(height: 6),
          _MeterBar(value: ratio, height: 6, color: goal.isMaximum && !satisfied ? _colors.warnBorder : (satisfied ? _colors.accentFill : _colors.goldBorder)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: statusColor)),
        ]),
      ),
    );
  }

  Widget _activityProgressCard(Activity activity, DateTimeRange range) {
    final entries = _logsForActivity(activity, range);
    final actual = entries.length;
    final goals = _goalsForActivity(activity);

    return _AppCard(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _colors.tintStrong,
            child: _activityIconWidget(activity.emoji, size: 29),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
              Text('$actual réalisation${actual == 1 ? '' : 's'} sur la période', style: _hintStyle()),
            ]),
          ),
          TextButton.icon(
            onPressed: () => _addFor(activity),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Enregistrer'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ]),
        const SizedBox(height: AppSpace.s),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xs),
            child: Text('Aucun objectif défini pour cette activité dans l’onglet Objectifs.', style: _hintStyle()),
          )
        else
          for (final goal in goals) _goalProgressRow(activity, goal, range),
      ]),
    );
  }

  Widget _historyRow(ActivityLog log, List<Activity> activities) {
    final linked = activities.where((activity) => _isLogOfActivity(log, activity)).toList();
    final name = linked.isNotEmpty ? linked.first.name : log.title;
    final activity = linked.isEmpty ? null : linked.first;
    final amount = activity?.countOnly == true ? '1 fois' : (log.reps != null ? '${log.reps} rép.' : (log.realisedMinutes > 0 ? '${log.realisedMinutes} min' : '1 fois'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _colors.tintStrong,
          child: _activityIconWidget(activity?.emoji ?? log.emoji, size: 21),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong)),
            Text('${_friendlyDayLabel(log.date, DateTime.now())} · ${_dateLabel(log.date)}', style: _hintStyle()),
          ]),
        ),
        Text(amount, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textMuted)),
        IconButton(
          tooltip: 'Modifier cette entrée',
          visualDensity: VisualDensity.compact,
          onPressed: () => _editLog(log),
          icon: Icon(Icons.edit_outlined, size: 18, color: _colors.accentIcon),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _nutritionActivities();
    final range = _bounds();
    final nutritionLogs = _allNutritionLogs(range, activities);
    var activeGoalCount = 0;
    var satisfiedGoals = 0;
    for (final activity in activities) {
      for (final goal in _goalsForActivity(activity)) {
        final expected = _expectedForGoal(goal, range);
        if (expected <= 0) continue;
        activeGoalCount++;
        final actual = _actualForGoal(goal, activity, range);
        if (_goalSatisfied(goal, actual, expected)) satisfiedGoals++;
      }
    }
    final overallProgress = activeGoalCount == 0 ? 0.0 : satisfiedGoals / activeGoalCount;
    final shownLogs = _historyExpanded ? nutritionLogs : nutritionLogs.take(8).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          _activityIconWidget('pack://balanced_meal', size: 24),
          const SizedBox(width: 7),
          const Text('Suivi Nutrition'),
        ]),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 30),
          children: [
            _AppCard(
              tone: _CardTone.tint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _activityIconWidget('pack://balanced_meal', size: 35),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Tes habitudes alimentaires', style: _sheetTitleStyle(context))),
                ]),
                const SizedBox(height: AppSpace.s),
                Text('Les réalisations sont comparées aux objectifs enregistrés dans l’onglet Objectifs : minimums, plafonds et cadence quotidienne, hebdomadaire ou mensuelle.', style: _hintStyle()),
                const SizedBox(height: AppSpace.m),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${nutritionLogs.length}', style: TextStyle(fontSize: AppType.display, fontWeight: FontWeight.w900, color: _colors.textStrong, height: 1.0)),
                    const SizedBox(height: 2),
                    Text('réalisations enregistrées sur la période', style: _hintStyle()),
                  ])),
                  _Pill('${activities.length} activité${activities.length > 1 ? 's' : ''}', background: _colors.card, foreground: _colors.textStrong),
                ]),
                const SizedBox(height: AppSpace.m),
                if (activeGoalCount > 0) ...[
                  _MeterBar(value: overallProgress, height: 9, color: _colors.accentFill),
                  const SizedBox(height: AppSpace.xs),
                  Text('$satisfiedGoals / $activeGoalCount objectifs atteints ou respectés', style: _hintStyle()),
                ],
                const SizedBox(height: AppSpace.xs),
                Text(_periodLabel(range), style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted)),
              ]),
            ),
            const SizedBox(height: AppSpace.m),
            _AppCard(
              padding: const EdgeInsets.all(AppSpace.m),
              child: Column(children: [
                _periodSelector(),
                const SizedBox(height: AppSpace.s),
                _periodNavigation(range),
                if (_period == 'Dates') ...[
                  const SizedBox(height: AppSpace.xs),
                  Text('Choisis librement une période passée pour comparer les réalisations aux objectifs correspondants.', textAlign: TextAlign.center, style: _hintStyle()),
                ],
              ]),
            ),
            const SizedBox(height: AppSpace.l),
            _SectionHeader(
              iconKey: 'insights',
              fallbackIcon: Icons.track_changes_rounded,
              title: 'Objectifs par activité',
              subtitle: 'Comparaison avec les règles de l’onglet Objectifs, y compris les plafonds.',
            ),
            const SizedBox(height: AppSpace.s),
            if (activities.isEmpty)
              _AppCard(
                tone: _CardTone.soft,
                child: Text('Aucune activité dans la catégorie Nutrition. Ajoute d’abord tes habitudes dans Activités.', style: _hintStyle()),
              )
            else
              for (var i = 0; i < activities.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.s),
                _activityProgressCard(activities[i], range),
              ],
            const SizedBox(height: AppSpace.l),
            _SectionHeader(
              iconKey: 'history',
              fallbackIcon: Icons.history_rounded,
              title: 'Journal Nutrition',
              subtitle: '${nutritionLogs.length} réalisation${nutritionLogs.length > 1 ? 's' : ''} sur la période sélectionnée. Touchez le crayon pour modifier une entrée.',
              trailing: nutritionLogs.isNotEmpty
                  ? TextButton.icon(
                      onPressed: () => setState(() => _historyExpanded = !_historyExpanded),
                      icon: Icon(_historyExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 17),
                      label: Text(_historyExpanded ? 'Réduire' : 'Tout voir'),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 5)),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpace.s),
            _AppCard(
              padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.s, AppSpace.s, AppSpace.s),
              child: nutritionLogs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.l),
                      child: Center(child: Text('Aucune réalisation Nutrition sur cette période.', style: _hintStyle())),
                    )
                  : Column(children: [
                      for (var i = 0; i < shownLogs.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: _colors.border),
                        _historyRow(shownLogs[i], activities),
                      ],
                      if (!_historyExpanded && nutritionLogs.length > shownLogs.length)
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () => setState(() => _historyExpanded = true),
                            child: Text('Afficher les ${nutritionLogs.length - shownLogs.length} autres réalisations'),
                          ),
                        ),
                    ]),
            ),
            const SizedBox(height: AppSpace.m),
            Text('Une entrée ajoutée ou modifiée dans le journal est répercutée dans le bilan des activités et dans le suivi Nutrition.', textAlign: TextAlign.center, style: _hintStyle()),
          ],
        ),
      ),
    );
  }
}
