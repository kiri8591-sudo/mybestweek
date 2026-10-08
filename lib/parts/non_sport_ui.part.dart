// V12.4.13 — Vue dédiée aux activités non-Sport (équivalent Semaine Sport)
part of '../main.dart';

extension _NonSportWeekNavigationPart on _MaBelleSemaineAppState {
  void openNonSportWeekOverview() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _NonSportWeekPage(
          dayNames: dayNames,
          getActivities: () => activities.where((a) => !_isSportActivity(a) && !a.isSportProgram).toList(),
          getPlan: () => List<PlanItem>.from(plan),
          getLogs: () => List<ActivityLog>.from(logs),
          onOpenActivity: (activity) => addOrEditActivity(original: activity),
          onToggleDate: toggleNonSportActivityOnDate,
          onEditMinutes: editNonSportMinutesOnDate,
          onEditLog: editHistoryLogMinutes,
        ),
      ),
    );
  }
  void toggleNonSportActivityOnDate(Activity activity, DateTime date) {
    if (_isSportActivity(activity)) return;
    final day = date.weekday - 1;
    final monday = _startOfCurrentWeek();
    final currentWeek = _sameDateOnlyNonSport(date, _addDays(monday, day));
    if (currentWeek) {
      final items = plan.where((p) => p.activityId == activity.id && p.day == day).toList();
      if (items.isNotEmpty) {
        togglePlanItemDone(items.first, !items.first.done);
        return;
      }
    }
    final existing = logs.indexWhere((log) => _sameDateOnlyNonSport(log.date, date) && (log.activityId == activity.id || (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())));
    _prepareUndoSnapshot();
    setState(() {
      if (existing >= 0) {
        logs.removeAt(existing);
      } else {
        final now = DateTime.now();
        logs.add(ActivityLog(
          date: DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second),
          title: activity.name,
          emoji: activity.emoji,
          category: activity.category,
          period: _periodForActivity(activity, day),
          day: day,
          plannedMinutes: activity.duration,
          realisedMinutes: activity.duration,
          feeling: 'Bien',
          unplanned: true,
          activityId: activity.id,
        ));
      }
    });
    _queueLocalStatePersist();
  }

  /// Semaine Activités : saisir ou corriger le temps vécu d'une activité un jour donné.
  Future<void> editNonSportMinutesOnDate(Activity activity, DateTime date) async {
    if (_isSportActivity(activity) || !mounted) return;
    final day = date.weekday - 1;
    final currentWeek = _sameDateOnlyNonSport(date, _addDays(_startOfCurrentWeek(), day));
    if (currentWeek) {
      final items = plan.where((p) => p.activityId == activity.id && p.day == day).toList();
      if (items.isNotEmpty) {
        await editItemRealisedMinutes(items.first);
        return;
      }
    }
    final index = logs.indexWhere((log) =>
        _sameDateOnlyNonSport(log.date, date) &&
        (log.activityId == activity.id || (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())));
    if (index >= 0) {
      await editHistoryLogMinutes(logs[index]);
      return;
    }
    // Aucune réalisation ce jour-là : on en crée une avec le temps saisi.
    final minutes = await _askMinutes(name: activity.name, planned: activity.duration);
    if (minutes == null || !mounted) return;
    final actual = max(1, minutes);
    _prepareUndoSnapshot();
    setState(() {
      logs.add(ActivityLog(
        date: DateTime(date.year, date.month, date.day, 12),
        title: activity.name,
        emoji: activity.emoji,
        category: activity.category,
        period: _periodForActivity(activity, day),
        day: day,
        plannedMinutes: activity.duration,
        realisedMinutes: actual,
        feeling: 'Bien',
        unplanned: true,
        activityId: activity.id,
      ));
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ ${activity.name} : $actual min enregistrées.');
  }

  bool _sameDateOnlyNonSport(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

}

class _NonSportWeekPage extends StatefulWidget {
  final List<String> dayNames;
  final List<Activity> Function() getActivities;
  final List<PlanItem> Function() getPlan;
  final List<ActivityLog> Function() getLogs;
  final ValueChanged<Activity> onOpenActivity;
  final void Function(Activity activity, DateTime date) onToggleDate;
  final Future<void> Function(Activity activity, DateTime date) onEditMinutes;
  final Future<void> Function(ActivityLog log) onEditLog;

  const _NonSportWeekPage({
    required this.dayNames,
    required this.getActivities,
    required this.getPlan,
    required this.getLogs,
    required this.onOpenActivity,
    required this.onToggleDate,
    required this.onEditMinutes,
    required this.onEditLog,
  });

  @override
  State<_NonSportWeekPage> createState() => _NonSportWeekPageState();
}

class _NonSportWeekPageState extends State<_NonSportWeekPage> {
  String _activityFilter = 'Toutes';
  String _stateFilter = 'Tous';
  String _sort = 'Nom';
  String _view = 'Semaine';
  int? _selectedDay;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _weekStart;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return _addDays(day, -(day.weekday - 1));
  }

  DateTime _dayDate(int day) => _addDays(_weekStart, day);

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfCurrentWeek();
  }

  bool _isCurrentWeek() {
    final current = _startOfCurrentWeek();
    return _sameDate(_weekStart, current);
  }

  void _shiftWeek(int delta) {
    setState(() => _weekStart = _addDays(_weekStart, 7 * delta));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  List<Activity> _allActivities() => widget.getActivities();

  List<ActivityLog> _logsForRange(DateTime start, DateTime endExclusive) {
    return widget.getLogs().where((l) => !l.date.isBefore(start) && l.date.isBefore(endExclusive)).toList();
  }

  bool _isNonSportLog(ActivityLog log) {
    if (log.activityId != null) {
      Activity? activity;
      for (final a in _allActivities()) { if (a.id == log.activityId) { activity = a; break; } }
      return activity != null;
    }
    return log.category != 'Sport';
  }

  List<ActivityLog> _nonSportLogs() => widget.getLogs().where(_isNonSportLog).toList();

  int _plannedCount(Activity activity) => widget.getPlan().where((p) => p.activityId == activity.id).length;
  int _doneCount(Activity activity) => widget.getPlan().where((p) => p.activityId == activity.id && p.done).length;

  bool _missingFromWeek(Activity activity) => _plannedCount(activity) == 0;

  bool _passesFilters(Activity activity) {
    if (_activityFilter != 'Toutes' && activity.name != _activityFilter) return false;
    final planned = _plannedCount(activity);
    final done = _doneCount(activity);
    switch (_stateFilter) {
      case 'Réalisées':
        return done > 0;
      case 'À faire':
        return planned > 0 && done < planned;
      case 'Non prises en compte':
        return _missingFromWeek(activity);
      default:
        return true;
    }
  }

  List<Activity> _visibleActivities() {
    final visible = _allActivities().where(_passesFilters).toList();
    visible.sort((a, b) {
      switch (_sort) {
        case 'Réalisées':
          final d = _doneCount(b).compareTo(_doneCount(a));
          if (d != 0) return d;
          break;
        case 'À faire':
          final d = (_plannedCount(b) - _doneCount(b)).compareTo(_plannedCount(a) - _doneCount(a));
          if (d != 0) return d;
          break;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return visible;
  }

  String _duration(int minutes) => _minutesLabel(minutes);

  Widget _summary() {
    final start7 = _startOfCurrentWeek();
    final end7 = _addDays(start7, 7);
    final now = DateTime.now();
    final start30 = _addDays(DateTime(now.year, now.month, now.day), -29);
    final end30 = _addDays(DateTime(now.year, now.month, now.day), 1);
    final logs7 = _logsForRange(start7, end7).where(_isNonSportLog).toList();
    final logs30 = _logsForRange(start30, end30).where(_isNonSportLog).toList();
    final activeDays = logs7.map((l) => '${l.date.year}-${l.date.month}-${l.date.day}').toSet().length;
    final plan = widget.getPlan().where((p) => p.activityId != null && _allActivities().any((a) => a.id == p.activityId)).toList();
    final planDone = plan.where((p) => p.done).length;
    final rate = plan.isEmpty ? 0 : (planDone * 100 / plan.length).round();
    return _WeekHero(
      title: 'Cette semaine',
      iconKey: 'sportWeek',
      fallbackIcon: Icons.view_week_outlined,
      rangeLabel: '${_dateShort(start7)} – ${_dateShort(_addDays(start7, 6))}',
      ratePercent: rate,
      caption: plan.isEmpty ? 'Aucun moment prévu' : '$planDone sur ${plan.length} moments réalisés',
      tiles: [
        _StatTile(label: 'moments · 7 j', value: '${logs7.length}', iconKey: 'review', icon: Icons.check_circle_outline),
        _StatTile(label: 'temps · 7 j', value: _duration(logs7.fold<int>(0, (s, l) => s + l.realisedMinutes)), iconKey: 'review', icon: Icons.timer_outlined),
        _StatTile(label: 'jours actifs', value: '$activeDays/7', iconKey: 'review', icon: Icons.calendar_month_outlined),
      ],
      footnote: 'Sur 30 jours : ${logs30.length} moments · ${_duration(logs30.fold<int>(0, (s, l) => s + l.realisedMinutes))}.',
    );
  }

  String _dateShort(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Widget _filters() {
    final names = _allActivities().map((a) => a.name).toSet().toList()..sort();
    return _WeekFilterBar(
      activityNames: names,
      activityFilter: _activityFilter,
      stateFilter: _stateFilter,
      sort: _sort,
      sortOptions: const {'Nom': 'Nom', 'Réalisées': 'Réalisées', 'À faire': 'À faire'},
      view: _view,
      onActivity: (v) => setState(() => _activityFilter = v),
      onState: (v) => setState(() => _stateFilter = v),
      onSort: (v) => setState(() => _sort = v),
      onView: (v) => setState(() => _view = v),
      onReset: () => setState(() {
        _activityFilter = 'Toutes';
        _stateFilter = 'Tous';
        _sort = 'Nom';
      }),
    );
  }

  Widget _dayHeader() {
    return Row(children: [
      const SizedBox(width: 105),
      ...List.generate(7, (day) {
        final date = _dayDate(day);
        return Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.dayNames[day].substring(0, 1), style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textWarm)),
          Text('${date.day}', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted)),
        ])));
      }),
    ]);
  }

  Widget _dayCell(Activity activity, int day) {
    final date = _dayDate(day);
    final currentWeek = _isCurrentWeek();
    final items = currentWeek ? widget.getPlan().where((p) => p.activityId == activity.id && p.day == day).toList() : <PlanItem>[];
    final logged = widget.getLogs().any((log) => _sameDate(log.date, date) && (log.activityId == activity.id || (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())));
    final done = currentWeek ? (items.any((p) => p.done) || logged) : logged;
    final planned = currentWeek && items.isNotEmpty;
    return Expanded(child: Center(child: InkWell(
      onTap: () => widget.onToggleDate(activity, date),
      onLongPress: () async {
        await widget.onEditMinutes(activity, date);
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? _colors.accentFill : planned ? _colors.tintStrong : _colors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: done ? _colors.accentFillBorder : planned ? _colors.accentSoftBorder : _colors.border, width: .8),
        ),
        child: done ? Icon(Icons.check_rounded, size: 15, color: _colors.card) : planned ? Text('•', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.accentText)) : null,
      ),
    )));
  }

  Widget _activityRow(Activity activity) {
    final currentWeek = _isCurrentWeek();
    final planned = currentWeek ? _plannedCount(activity) : 0;
    final done = currentWeek
        ? _doneCount(activity)
        : widget.getLogs().where((log) => !log.date.isBefore(_weekStart) && log.date.isBefore(_addDays(_weekStart, 7)) && (log.activityId == activity.id || (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase()))).length;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.m), border: Border.all(color: _colors.border)),
      child: Row(children: [
        SizedBox(
          width: 105,
          child: Row(children: [
            _activityIconWidget(activity.emoji, size: 18),
            const SizedBox(width: 4),
            Expanded(child: InkWell(onTap: () => widget.onOpenActivity(activity), child: Text(activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textStrong)))),
            const SizedBox(width: 3),
            Text(currentWeek ? '$done/$planned' : '$done', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textWarm)),
          ]),
        ),
        Expanded(child: Row(children: List.generate(7, (day) => _dayCell(activity, day)))),
      ]),
    );
  }

  String _monthLabelFr() {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return months[_month.month - 1];
  }

  Widget _monthView() {
    final visible = _visibleActivities();
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final logs = _nonSportLogs();
    bool doneOn(Activity activity, DateTime date) => logs.any((log) => _sameDate(log.date, date) && (log.activityId == activity.id || (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())));
    Widget cell(Activity activity, bool done, int day) {
      final date = DateTime(_month.year, _month.month, day);
      return InkWell(
        onTap: () => widget.onToggleDate(activity, date),
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(width: 14, height: 16, child: Center(child: done
            ? Container(width: 12, height: 12, decoration: BoxDecoration(color: _colors.accentFill, borderRadius: BorderRadius.circular(3)), child: const Icon(Icons.check, size: 8, color: Colors.white))
            : Text('$day', style: TextStyle(fontSize: AppType.micro, color: _colors.textWarm)))),
      );
    }
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() > 250) _shiftMonth(v < 0 ? 1 : -1);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), onPressed: () => _shiftMonth(-1), icon: _uiIcon('sportBack', Icons.chevron_left_rounded, size: 20)),
          Expanded(child: Text('${_monthLabelFr()} ${_month.year}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), onPressed: () => _shiftMonth(1), icon: _uiIcon('sportNext', Icons.chevron_right_rounded, size: 20)),
        ]),
        Text('Réalisations enregistrées sur le mois · toucher une case pour cocher/décocher.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
        const SizedBox(height: 6),
        if (visible.isEmpty) const Text('Aucune activité non-Sport.')
        else ...visible.map((activity) => Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.m), border: Border.all(color: _colors.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 92, child: Row(children: [_activityIconWidget(activity.emoji, size: 17), const SizedBox(width: 4), Expanded(child: Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textStrong)))])),
            Expanded(child: Wrap(spacing: 1, runSpacing: 1, children: [for (var day = 1; day <= days; day++) cell(activity, doneOn(activity, DateTime(_month.year, _month.month, day)), day)])),
          ]),
        )),
      ]),
    );
  }


  String _activityEmojiForItem(PlanItem item) {
    if (item.activityId != null) {
      for (final a in _allActivities()) {
        if (a.id == item.activityId) return a.emoji;
      }
    }
    return item.customEmoji ?? '📍';
  }

  String _weekLabel() {
    final end = _addDays(_weekStart, 6);
    String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${f(_weekStart)} – ${f(end)}';
  }

  Widget _weekView() {
    final visible = _visibleActivities();
    final selected = _selectedDay ?? (_isCurrentWeek() ? DateTime.now().weekday - 1 : 0);
    final selectedDate = _dayDate(selected);
    final selectedItems = _isCurrentWeek()
        ? widget.getPlan().where((p) => p.day == selected && p.activityId != null && _allActivities().any((a) => a.id == p.activityId)).toList()
        : <PlanItem>[];
    final selectedLogs = _isCurrentWeek()
        ? <ActivityLog>[]
        : widget.getLogs().where((l) => _sameDate(l.date, selectedDate) && _isNonSportLog(l)).toList();
    final historyRows = <Widget>[
      if (selectedLogs.isEmpty)
        Text('Aucune réalisation ce jour. Toucher une case pour en ajouter une, appui long pour saisir un temps.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
      for (final log in selectedLogs)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            _activityIconWidget(log.emoji, size: 19),
            const SizedBox(width: 5),
            Expanded(child: Text(log.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong))),
            InkWell(
              onTap: () async {
                await widget.onEditLog(log);
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 15, color: _colors.textMuted),
                  const SizedBox(width: 3),
                  Text('${log.realisedMinutes} min', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.accentText)),
                ]),
              ),
            ),
          ]),
        ),
    ];
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() > 250) _shiftWeek(v < 0 ? 1 : -1);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Semaine précédente', onPressed: () => _shiftWeek(-1), icon: _uiIcon('sportBack', Icons.chevron_left_rounded, size: 20)),
          Expanded(child: Text('Semaine du ${_weekLabel()}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.bodyL, color: _colors.textStrong))),
          if (!_isCurrentWeek())
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => setState(() {
                _weekStart = _startOfCurrentWeek();
                _selectedDay = null;
              }),
              child: const Text('Aujourd’hui'),
            ),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Semaine suivante', onPressed: () => _shiftWeek(1), icon: _uiIcon('sportNext', Icons.chevron_right_rounded, size: 20)),
        ]),
        const SizedBox(height: 6),
        SizedBox(height: 48, child: Row(children: List.generate(7, (day) {
          final date = _dayDate(day);
          final active = day == selected;
          final done = widget.getLogs().where((log) => _sameDate(log.date, date) && _isNonSportLog(log)).length;
          final items = _isCurrentWeek() ? widget.getPlan().where((p) => p.day == day && p.activityId != null && _allActivities().any((a) => a.id == p.activityId)).toList() : <PlanItem>[];
          final count = _isCurrentWeek() ? items.where((p) => p.done).length : done;
          return Expanded(child: Padding(padding: EdgeInsets.only(right: day == 6 ? 0 : 5), child: GestureDetector(onTap: () => setState(() => _selectedDay = day), child: AnimatedContainer(duration: const Duration(milliseconds: 140), width: 42, padding: const EdgeInsets.symmetric(vertical: 3), decoration: BoxDecoration(color: active ? _colors.tintStrong : _colors.surfaceSoft, borderRadius: BorderRadius.circular(AppRadius.m), border: Border.all(color: active ? _colors.accentFill : _colors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.dayNames[day].substring(0,3).toUpperCase(), style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted)), Text('${date.day}', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: active ? _colors.accentText : _colors.textStrong)), Text(count == 0 ? '·' : '$count', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textWarm))])))));
        }))),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), decoration: BoxDecoration(color: _colors.tintSoft, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.borderTint)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_uiIcon('calendar', Icons.calendar_today_outlined, size: 18, color: _colors.accentIcon), const SizedBox(width: 6), Expanded(child: Text('Activités du ${widget.dayNames[selected]} · ${selectedDate.day}/${selectedDate.month}', style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textStrong)))]),
          const SizedBox(height: 5),
          if (!_isCurrentWeek()) ...historyRows
          else if (selectedItems.isEmpty)
            Text('Aucune activité non-Sport prévue ce jour.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted))
          else
            ...selectedItems.map((item) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              _activityIconWidget(_activityEmojiForItem(item), size: 19), const SizedBox(width: 5), Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong))),
              InkWell(
                onTap: () async {
                  final activity = _allActivities().firstWhere((a) => a.id == item.activityId);
                  await widget.onEditMinutes(activity, selectedDate);
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_outlined, size: 15, color: _colors.textMuted),
                    const SizedBox(width: 3),
                    Text(item.done ? '✓ ${item.realisedMinutes ?? item.duration} min' : '${item.duration} min', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: item.done ? _colors.accentText : _colors.textWarm)),
                  ]),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(onTap: () => widget.onToggleDate(_allActivities().firstWhere((a) => a.id == item.activityId), selectedDate), borderRadius: BorderRadius.circular(AppRadius.s), child: Container(width: 23, height: 23, alignment: Alignment.center, decoration: BoxDecoration(color: item.done ? _colors.accentFill : _colors.surfaceSoft, borderRadius: BorderRadius.circular(AppRadius.s), border: Border.all(color: item.done ? _colors.accentFillBorder : _colors.borderStrong)), child: item.done ? const Icon(Icons.check, size: 14, color: Colors.white) : null)),
            ]))),
        ])),
        const SizedBox(height: 8),
        _dayHeader(),
        ...visible.map(_activityRow),
        if (visible.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Toucher une case pour cocher · appui long pour saisir le temps passé.', style: _hintStyle()),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleActivities();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semaine Activités'),
        actions: [IconButton(tooltip: 'Accueil', onPressed: () => Navigator.pop(context), icon: _uiIcon('navHome', Icons.home_outlined, size: 20))],
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _summary(),
        const SizedBox(height: AppSpace.m),
        _filters(),
        const SizedBox(height: AppSpace.m),
        _AppCard(padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), child: _view == 'Semaine' ? _weekView() : _monthView()),
        const SizedBox(height: 14),
        if (visible.isEmpty) Text('Aucune activité ne correspond aux filtres.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
      ])),
    );
  }
}
