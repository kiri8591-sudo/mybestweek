// V8.97 — Interface Sport
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

class _SportRealisedMinutesSheet extends StatefulWidget {
  final String activityName;
  final int plannedMinutes;

  const _SportRealisedMinutesSheet({
    required this.activityName,
    required this.plannedMinutes,
  });

  @override
  State<_SportRealisedMinutesSheet> createState() => _SportRealisedMinutesSheetState();
}

class _SportRealisedMinutesSheetState extends State<_SportRealisedMinutesSheet> {
  late final TextEditingController controller;
  late final List<int> quickValues;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final planned = max(1, widget.plannedMinutes);
    // Cinq choix proches suffisent : l’écran reste très léger sur iPhone.
    final nearby = <int>{
      max(5, planned - 10),
      max(5, planned - 5),
      planned,
      planned + 5,
      planned + 10,
    };
    quickValues = nearby.where((v) => v > 0).toList()..sort();
    controller = TextEditingController(text: '$planned');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _close([int? value]) {
    if (_closing || !mounted) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final planned = max(1, widget.plannedMinutes);
    final current = int.tryParse(controller.text.trim());
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 6, 18, 14 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _colors.tintSoft,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  alignment: Alignment.center,
                  child: _activityIconWidget(_uiIconValue('sportTimer', ''), size: 21),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Combien de temps ?', style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      const SizedBox(height: 1),
                      Text(widget.activityName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _closing ? null : () => _close(planned),
                child: Text('✓ ${planned} min · comme prévu', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Ou choisis rapidement une autre durée', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textMuted)),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: quickValues.map((value) => SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: _closing ? null : () => _close(value),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                    side: BorderSide(color: value == planned ? _colors.accentOutline : _colors.border),
                  ),
                  child: Text('$value', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: value == planned ? _colors.accentStrongText : _colors.textMuted)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: false,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Autre durée',
                      suffixText: 'min',
                      isDense: true,
                    ),
                    onChanged: (_) { if (mounted) setState(() {}); },
                    onSubmitted: (_) {
                      if (current != null && current > 0) _close(current);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Valider cette durée',
                  onPressed: (_closing || current == null || current < 1) ? null : () => _close(current),
                  icon: _uiIcon('confirm', Icons.check_circle_rounded, size: 23, color: _colors.accentIcon),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _SportWeekPage extends StatefulWidget {
  final List<String> dayNames;
  final List<Activity> Function() getActivities;
  final Activity? Function() getSportProgram;
  final List<PlanItem> Function() getPlan;
  final List<ActivityLog> Function() getLogs;
  final Set<int> Function() getSportDays;
  final Map<int, int> Function() getSportBudgets;
  final ValueChanged<Activity> onReactivate;
  final ValueChanged<Activity> onPostpone;
  final ValueChanged<Activity> onOpenActivity;
  final void Function(Activity activity, int day) onToggleDay;
  final Future<void> Function(PlanItem item) onRemoveItem;
  final Future<void> Function(int day) onAddSportActivity;
  final void Function(int day, int minutes) onSetBudget;
  final DateTime Function() getNow;
  final bool Function(String?) isDailyPriority;
  final VoidCallback onOpenCoachJournal;

  const _SportWeekPage({
    required this.dayNames,
    required this.getActivities,
    required this.getSportProgram,
    required this.getPlan,
    required this.getLogs,
    required this.getSportDays,
    required this.getSportBudgets,
    required this.onReactivate,
    required this.onPostpone,
    required this.onOpenActivity,
    required this.onToggleDay,
    required this.onRemoveItem,
    required this.onAddSportActivity,
    required this.onSetBudget,
    required this.getNow,
    required this.isDailyPriority,
    required this.onOpenCoachJournal,
  });

  @override
  State<_SportWeekPage> createState() => _SportWeekPageState();
}

class _SportWeekPageState extends State<_SportWeekPage> {
  late Map<int, int> budgets;
  String _activityFilter = 'Toutes';
  String _stateFilter = 'Tous';
  String _sort = 'Nom';
  String _view = 'Semaine';
  int? _selectedActivityId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _selectedDate;
  late DateTime _dateStripStart;

  @override
  void initState() {
    super.initState();
    budgets = {...widget.getSportBudgets()};
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _dateStripStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
  }

  List<Activity> _allSportActivities() => widget.getActivities();

  Widget _sportProgramIcon({double size = 22}) {
    return _activityIconWidget(widget.getSportProgram()?.emoji ?? '🏃', size: size);
  }

  /// Indicateur 7 jours utilisé dans la page Sport.
  /// La version précédente appelait le helper de l'état principal, qui
  /// n'est pas accessible depuis _SportWeekPageState. Cette copie s'appuie
  /// uniquement sur les données exposées par widget.getPlan().
  Widget _sportWeeklyIndicator(Activity activity) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final currentPlan = widget.getPlan();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (day) {
        PlanItem? item;
        for (final candidate in currentPlan) {
          if (candidate.day == day && candidate.activityId == activity.id) {
            item = candidate;
            break;
          }
        }
        final active = item?.done == true;
        final planned = item != null && !item!.done;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels[day],
                style: TextStyle(
                  fontSize: AppType.micro,
                  fontWeight: FontWeight.w800,
                  color: _colors.textMuted,
                ),
              ),
              const SizedBox(height: 1),
              InkWell(
                onTap: () => widget.onToggleDay(activity, day),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? _colors.accentFill
                        : planned
                            ? _colors.tintStrong
                            : _colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: active
                          ? _colors.accentFillBorder
                          : _colors.accentSoftBorder,
                    ),
                  ),
                  child: active
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : planned
                          ? Text(
                              '•',
                              style: TextStyle(
                                fontSize: AppType.bodyL,
                                fontWeight: FontWeight.w800,
                                color: _colors.accentText,
                              ),
                            )
                          : null,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<PlanItem> _itemsFor(Activity activity, int day) {
    return widget.getPlan().where((item) {
      if (item.day != day || item.activityId != activity.id) return false;
      return true;
    }).toList();
  }

  int _plannedCount(Activity activity) =>
      widget.getPlan().where((item) => item.activityId == activity.id).length;

  int _doneCount(Activity activity) => widget.getPlan().where((item) =>
      item.activityId == activity.id && item.done).length;

  int _target(Activity activity) => activity.sportGroupFrequency ?? activity.frequency;

  bool _isMissingFromWeek(Activity activity) {
    if (!activity.activeInSportRotation) return false;
    return _plannedCount(activity) == 0;
  }

  int _logDoneCountInMonth(Activity activity) {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 1);
    // The page cannot receive logs directly without widening its contract;
    // current-month completed plan items are included below, while historical
    // monthly activity is represented by the persisted plan/log-compatible state.
    return widget.getPlan().where((item) {
      return item.activityId == activity.id && item.done &&
          item.day >= 0 && item.day < 7 &&
          DateTime.now().weekday - 1 == item.day &&
          DateTime.now().isAfter(start.subtract(const Duration(seconds: 1))) &&
          DateTime.now().isBefore(end);
    }).length;
  }

  Widget _dayCell(Activity activity, int day) {
    final items = _itemsFor(activity, day);
    final planned = items.isNotEmpty;
    final done = items.any((item) => item.done);
    final label = done ? '✓' : (planned ? '•' : '—');

    Color background;
    Color border;
    Color foreground;
    if (done) {
      background = _colors.accentFill;
      border = _colors.accentFillBorder;
      foreground = Colors.white;
    } else if (planned) {
      background = _colors.tintStrong;
      border = _colors.accentSoftBorder;
      foreground = _colors.accentText;
    } else if (widget.getSportDays().contains(day)) {
      background = _colors.surfaceSoft;
      border = _colors.borderStrong;
      foreground = _colors.textFaint;
    } else {
      background = _colors.surfaceSunken;
      border = _colors.border;
      foreground = _colors.textFaint;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.dayNames[day].substring(0, 3),
            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textMuted)),
        const SizedBox(height: 3),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.s),
          onTap: () => widget.onToggleDay(activity, day),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.s),
              border: Border.all(color: border),
            ),
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.bodyL, color: foreground)),
          ),
        ),
      ],
    );
  }

  bool _passesFilters(Activity activity) {
    if (_activityFilter != 'Toutes' && activity.name != _activityFilter) return false;
    final planned = _plannedCount(activity);
    final done = _doneCount(activity);
    switch (_stateFilter) {
      case 'Réalisées':
        if (done == 0) return false;
        break;
      case 'À faire':
        if (planned == 0 || done >= planned) return false;
        break;
      case 'Non prises en compte':
        if (!_isMissingFromWeek(activity)) return false;
        break;
    }
    return true;
  }

  List<Activity> _visibleActivities() {
    final list = _allSportActivities().where(_passesFilters).toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'Réalisées':
          final dc = _doneCount(b).compareTo(_doneCount(a));
          if (dc != 0) return dc;
          break;
        case 'À faire':
          final ac = (_plannedCount(a) - _doneCount(a));
          final bc = (_plannedCount(b) - _doneCount(b));
          final rc = bc.compareTo(ac);
          if (rc != 0) return rc;
          break;
        case 'Cible':
          final rc = _target(b).compareTo(_target(a));
          if (rc != 0) return rc;
          break;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Widget _summary() {
    final all = _allSportActivities();
    final active = all.where((a) => a.activeInSportRotation).toList();
    final planned = widget.getPlan().where((p) =>
        p.activityId != null &&
        all.any((a) => a.id == p.activityId)).toList();
    final done = planned.where((p) => p.done).toList();
    final missing = active.where(_isMissingFromWeek).length;
    final plannedMinutes = planned.fold<int>(0, (s, p) => s + p.duration);
    final doneMinutes = done.fold<int>(0, (s, p) => s + p.duration);
    final rate = plannedMinutes == 0 ? 0 : (doneMinutes * 100 / plannedMinutes).round();

    Widget stat(String value, String label, String iconKey, IconData icon) => Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _colors.border),
      ),
      child: Column(children: [
        _uiIcon(iconKey, icon, size: 18, color: _colors.accentIcon),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.titleL, color: _colors.textStrong)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted)),
      ]),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final stats = [
          stat('${active.length}', 'actives', 'sportActive', Icons.directions_run_outlined),
          stat('$doneMinutes / $plannedMinutes', 'min réalisées / prévues', 'sportMinutes', Icons.timelapse_outlined),
          stat('$rate %', 'taux de réalisation', 'sportRate', Icons.check_circle_outline),
          stat('$missing', 'non prises en compte', 'sportMissing', Icons.warning_amber_rounded),
        ];
        if (wide) {
          return Row(children: [
            Expanded(child: stats[0]), const SizedBox(width: 7),
            Expanded(child: stats[1]), const SizedBox(width: 7),
            Expanded(child: stats[2]), const SizedBox(width: 7),
            Expanded(child: stats[3]),
          ]);
        }
        final itemWidth = max(0.0, (constraints.maxWidth - 7) / 2);
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: stats.map((item) => SizedBox(width: itemWidth, child: item)).toList(),
        );
      },
    );
  }

  Widget _filters() {
    final names = _allSportActivities().map((a) => a.name).toList()..sort();
    final selected = _activityFilter == 'Toutes' || names.contains(_activityFilter)
        ? _activityFilter
        : 'Toutes';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: _colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _colors.border),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activité', isDense: true),
              items: ['Toutes', ...names].map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _activityFilter = v ?? 'Toutes'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _stateFilter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'État', isDense: true),
              items: const [
                DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                DropdownMenuItem(value: 'Réalisées', child: Text('Réalisées')),
                DropdownMenuItem(value: 'À faire', child: Text('À faire')),
                DropdownMenuItem(value: 'Non prises en compte', child: Text('Non prises en compte')),
              ],
              onChanged: (v) => setState(() => _stateFilter = v ?? 'Tous'),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Que signifie « non prise en compte » ?',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Non prise en compte'),
                content: const Text('Cela signifie qu’une activité Sport active dans la rotation n’a actuellement aucune occurrence prévue dans cette semaine. Elle n’est donc ni réalisée ni simplement « à faire » : elle n’a pas trouvé de place dans le planning de la semaine.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris'))],
              ),
            ),
            icon: _uiIcon('help', Icons.info_outline, size: 18),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Réinitialiser les filtres',
            onPressed: () => setState(() {
              _activityFilter = 'Toutes';
              _stateFilter = 'Tous';
              _sort = 'Nom';
              _view = 'Semaine';
            }),
            icon: _uiIcon('sportFilter', Icons.filter_alt_off_outlined, size: 18),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sort,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trier par', isDense: true),
              items: const [
                DropdownMenuItem(value: 'Nom', child: Text('Nom')),
                DropdownMenuItem(value: 'Réalisées', child: Text('Réalisées')),
                DropdownMenuItem(value: 'À faire', child: Text('À faire')),
                DropdownMenuItem(value: 'Cible', child: Text('Cible / semaine')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? 'Nom'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Semaine', label: Text('7 jours')),
                  ButtonSegment(value: 'Mois', label: Text('1 mois')),
                ],
                selected: {_view},
                onSelectionChanged: (value) => setState(() => _view = value.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
                ),
              ),
          ),
        ]),
      ]),
    );
  }

  String _dateLabel(DateTime d) {
    const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${d.day} ${months[d.month - 1]}';
  }

  int _planDayIndex(DateTime d) => d.weekday - 1;

  Widget _dailyDateNavigator() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '7 jours précédents',
          onPressed: () => setState(() {
            _dateStripStart = _dateStripStart.subtract(const Duration(days: 7));
            _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          }),
          icon: _activityIconWidget(_uiIconValue('sportBack', ''), size: 20),
        ),
        Expanded(
          child: Text(
            'Vue journalière · ${_dateLabel(_selectedDate)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.bodyL),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '7 jours suivants',
          onPressed: () => setState(() {
            _dateStripStart = _dateStripStart.add(const Duration(days: 7));
            _selectedDate = _selectedDate.add(const Duration(days: 7));
          }),
          icon: _activityIconWidget(_uiIconValue('sportNext', ''), size: 20),
        ),
      ]),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (_, i) {
                  final d = _dateStripStart.add(Duration(days: i));
                  final selected = _sameDate(d, _selectedDate);
                  final dayIndex = _planDayIndex(d);
                  final items = _itemsForDayForDate(dayIndex, d);
                  final done = items.where((x) => x.done).length;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = d;
                              }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 39,
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                      decoration: BoxDecoration(
                        color: selected ? _colors.tintStrong : _colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(
                          color: selected ? _colors.accentFill : _colors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.dayNames[dayIndex].substring(0, 3).toUpperCase(),
                            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textMuted),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: AppType.bodyL,
                              fontWeight: FontWeight.w800,
                              color: selected ? _colors.accentText : _colors.textStrong,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            items.isEmpty ? '·' : '$done/${items.length}',
                            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textWarm),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<PlanItem> _itemsForDayForDate(int day, DateTime date) {
    // Le planning courant est hebdomadaire : on affiche les éléments du jour
    // correspondant au jour de semaine de la date sélectionnée.
    return _allSportActivities().isEmpty ? <PlanItem>[] : widget.getPlan().where((p) => p.day == day && p.activityId != null && _allSportActivities().any((a) => a.id == p.activityId)).toList();
  }

  Widget _selectedDaySportDetail() {
    final day = _planDayIndex(_selectedDate);
    final items = _itemsForDayForDate(day, _selectedDate);
    final target = widget.getSportDays().contains(day) ? (budgets[day] ?? 0) : 0;
    final planned = items.fold<int>(0, (s, p) => s + p.duration);
    final done = items.where((p) => p.done).fold<int>(0, (s, p) => s + (p.realisedMinutes ?? p.duration));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(color: _colors.tintSoft, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.borderTint)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sportProgramIcon(size: 22),
          const SizedBox(width: 7),
          Expanded(child: Text('Activités du jour · ${widget.dayNames[day]} ${_dateLabel(_selectedDate)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.bodyL))),
          IconButton(
            tooltip: 'Ajouter une activité Sport',
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.onAddSportActivity(day),
            icon: _uiIcon('add', Icons.add_circle_outline, size: 18, color: _colors.accentIcon),
          ),
          Text('$done / $planned min', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textMuted)),
        ]),
        const SizedBox(height: 3),
        Text(target > 0 ? 'Budget Sport : $target min' : 'Pas de budget Sport prévu ce jour', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('Aucune activité Sport prévue ce jour.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted))
        else
          ...items.map((item) {
            final activity = item.activityId == null ? null : _allSportActivities().firstWhere((a) => a.id == item.activityId, orElse: () => _allSportActivities().first);
            final titleStyle = _detailMetaStyle().copyWith(fontWeight: FontWeight.w800, color: _colors.textStrong);
            return Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _activityIconWidget(_planItemIconValue(item, widget.getActivities()), size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      onTap: activity == null ? null : () => widget.onOpenActivity(activity),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle.copyWith(decoration: item.done ? TextDecoration.lineThrough : null),
                              ),
                            ),
                            if (item.day == _planDayIndex(widget.getNow()) && widget.isDailyPriority(item.activityId)) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _colors.goldBg,
                                  borderRadius: BorderRadius.circular(AppRadius.s),
                                  border: Border.all(color: _colors.goldBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _uiIcon('priority', Icons.star_rounded, size: 11, color: _colors.goldText),
                                    const SizedBox(width: 2),
                                    Text('Priorité', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, letterSpacing: 0.05, color: _colors.goldText)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirer du jour',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () => widget.onRemoveItem(item),
                    icon: _uiIcon('remove', Icons.remove_circle_outline, size: 17, color: _colors.danger),
                  ),
                ]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item.done ? '${item.realisedMinutes ?? item.duration} / ${item.duration} min' : '${item.duration} min',
                      style: _detailMetaStyle(),
                    ),
                    const SizedBox(width: 5),
                    if (activity != null) ...[
                      _sportWeeklyIndicator(activity),
                      const SizedBox(width: 4),
                    ],
                    InkWell(
                      onTap: () {
                        if (activity == null) return;
                        setState(() => widget.onToggleDay(activity, day));
                      },
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      child: Container(
                        width: 23,
                        height: 23,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: item.done ? _colors.accentFill : _colors.surfaceSoft,
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: item.done ? _colors.accentFillBorder : _colors.borderStrong),
                        ),
                        child: item.done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                    ),
                  ],
                ),
              ]),
            );
          }),
      ]),
    );
  }

  // Le tableau garde toujours ses 7 colonnes, quel que soit le mode.
  // En mode 1 jour, le jour sélectionné est seulement mis en évidence ;
  // toutes les colonnes restent affichées et toutes les cases restent cliquables.
  List<int> _trackingDayIndices() => List<int>.generate(7, (i) => i);

  Widget _weekDayHeader() {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final selectedDay = _planDayIndex(_selectedDate);
    final days = _trackingDayIndices();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          const SizedBox(width: 115),
          ...days.map((day) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: day == selectedDay ? _colors.tintSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Center(
                    child: Text(
                      labels[day],
                      style: TextStyle(
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.w800,
                        color: day == selectedDay ? _colors.accentText : _colors.textWarm,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _compactDayCell(Activity activity, int day) {
    final items = _itemsFor(activity, day);
    final planned = items.isNotEmpty;
    final done = items.any((item) => item.done);
    final selectedDay = _planDayIndex(_selectedDate);
    final selected = day == selectedDay;
    final label = done ? '✓' : (planned ? '•' : '');

    final background = done
        ? _colors.accentFill
        : planned
            ? _colors.tintStrong
            : _colors.surfaceSoft;
    final border = done
        ? _colors.accentFillBorder
        : planned
            ? _colors.accentSoftBorder
            : _colors.border;
    final foreground = done ? Colors.white : _colors.accentText;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: selected ? _colors.tintSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        child: Center(
          child: InkWell(
            onTap: () => widget.onToggleDay(activity, day),
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: Border.all(color: selected ? _colors.accentFill : border, width: selected ? 1.2 : 1),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppType.bodyL,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityRow(Activity activity) {
    final missing = _isMissingFromWeek(activity);
    final planned = _plannedCount(activity);
    final done = _doneCount(activity);
    final target = _target(activity);
    final labelStyle = _detailMetaStyle().copyWith(fontWeight: FontWeight.w800, color: _colors.textStrong);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 5),
      decoration: BoxDecoration(
        color: missing ? _colors.warnBg : _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: missing ? _colors.warnBorder : _colors.border,
          width: activity.category == 'Sport' ? (missing ? 1.2 : 1.0) : (missing ? 0.8 : 0.55),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _activityIconWidget(activity.emoji, size: 23),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.s),
              onTap: () => widget.onOpenActivity(activity),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      activity.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  if (missing) Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: _activityIconWidget(_uiIconValue('sportWarning', ''), size: 13),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          SizedBox(
            width: 115,
            child: Text(
              '$done/$planned · cible ${target}×',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _detailMetaStyle().copyWith(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textWarm),
            ),
          ),
          ..._trackingDayIndices().map((day) => _compactDayCell(activity, day)),
        ]),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  int _daysInMonth() => DateTime(_month.year, _month.month + 1, 0).day;

  String _monthLabel() {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  Widget _monthView() {
    final visible = _visibleActivities();
    final days = _daysInMonth();
    final logs = widget.getLogs();

    bool doneOn(Activity activity, DateTime date) {
      return logs.any((log) {
        if (!_sameDay(log.date, date)) return false;
        if (log.activityId == activity.id) return true;
        return log.activityId == null &&
            log.title.trim().toLowerCase() == activity.name.trim().toLowerCase();
      });
    }

    // Calendrier mensuel volontairement très compact : même logique que la vue
    // 7 jours, mais avec une petite case par jour. Les 30/31 cases se répartissent
    // automatiquement sur 1 ou 2 lignes à droite du nom de l'activité.
    Widget check(bool done) {
      return SizedBox(
        width: 11,
        height: 11,
        child: Container(
          decoration: BoxDecoration(
            color: done ? _colors.accentFill : _colors.card,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: done ? _colors.accentFill : _colors.borderStrong,
              width: 0.9,
            ),
          ),
          child: done ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
        ),
      );
    }

    Widget dayNumber(int day) {
      return SizedBox(
        width: 11,
        height: 11,
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textWarm),
          ),
        ),
      );
    }

    Widget compactCells(Activity activity, {required bool header}) {
      return Expanded(
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (var day = 1; day <= days; day++)
              header
                  ? dayNumber(day)
                  : check(doneOn(activity, DateTime(_month.year, _month.month, day))),
          ],
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
          icon: _activityIconWidget(_uiIconValue('sportBack', ''), size: 20),
        ),
        Expanded(
          child: Text(
            _monthLabel(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.title),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
          icon: _activityIconWidget(_uiIconValue('sportNext', ''), size: 20),
        ),
      ]),
      const SizedBox(height: 3),
      if (visible.isEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Aucune activité ne correspond aux filtres.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
        )
      else ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text('ACTIVITÉ', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textWarm)),
              ),
            ),
            compactCells(visible.first, header: true),
          ],
        ),
        const SizedBox(height: 4),
        ...visible.map((activity) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1, right: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _activityIconWidget(activity.emoji, size: 16),
                          const SizedBox(width: 3),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.s),
                              onTap: () => widget.onOpenActivity(activity),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: Text(
                              activity.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, height: 1.05),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  compactCells(activity, header: false),
                ],
              ),
            )),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.getActivities().where((a) => a.activeInSportRotation).toList();
    final inactive = widget.getActivities().where((a) => !a.activeInSportRotation).toList();
    final visible = _visibleActivities();
    // La vue journalière au-dessus affiche déjà le détail du jour sélectionné.
    // Le tableau de suivi est donc dédié aux 7 jours : il n'y a pas de second
    // mode « 1 jour » qui répéterait le même contenu.
    final trackingActivities = visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semaine Sport'),
        actions: [
          IconButton(
            tooltip: 'Journal du coach Sport',
            onPressed: widget.onOpenCoachJournal,
            icon: _uiIcon('history', Icons.menu_book_rounded, size: 20),
          ),
          IconButton(tooltip: 'Accueil', onPressed: () => Navigator.pop(context), icon: _uiIcon('navHome', Icons.home_outlined, size: 20)),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            decoration: BoxDecoration(color: _colors.tintStrong, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: _colors.borderTint)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [mascotAvatarInline(size: 40), const SizedBox(width: 10), Expanded(child: Text('Bilan Sport', style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _colors.textStrong)))]),
              const SizedBox(height: 8),
              Text('Une vue synthétique de la semaine, avec filtre par activité, état, tri et historique mensuel.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted, height: 1.35)),
              const SizedBox(height: 12),
              _summary(),
            ]),
          ),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: _colors.border)),
            child: _view == 'Semaine'
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _dailyDateNavigator(),
                    const SizedBox(height: 8),
                    _selectedDaySportDetail(),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                      decoration: BoxDecoration(
                        color: _colors.tintSoft,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                        border: Border.all(color: _colors.borderTint),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _uiIcon('sportWeek', Icons.view_week_outlined, size: 17, color: _colors.accentIcon),
                          const SizedBox(width: 6),
                          const Expanded(child: Text('Suivi des activités · 7 jours', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.bodyL))),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          'Les 7 jours restent visibles et les cases restent cliquables ; le jour sélectionné est mis en évidence.',
                          style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        _weekDayHeader(),
                        if (trackingActivities.isEmpty)
                          const Text('Aucune activité Sport n’est prévue pour ce jour.')
                        else
                          ...trackingActivities.map(_activityRow),
                      ]),
                    ),
                  ])
                : _monthView(),
          ),
          if (inactive.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('MISES EN ATTENTE', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, letterSpacing: .7, color: _colors.textWarm)),
            const SizedBox(height: 7),
            ...inactive.map((activity) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              decoration: BoxDecoration(color: _colors.surfaceSunken, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.border)),
              child: Row(children: [
                _activityIconWidget(activity.emoji, size: 28),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(activity.name, style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textWarm)),
                  const SizedBox(height: 2),
                  Text('${activity.duration} min · ⏸ PLUS TARD', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.warnText)),
                ])),
                OutlinedButton.icon(onPressed: () { widget.onReactivate(activity); Navigator.pop(context); }, icon: _uiIcon('sportReactivate', Icons.refresh_rounded, size: 16), label: const Text('Réactiver')),
              ]),
            )),
          ],
        ],
        ),
      ),
    );
  }
}

class _SportCoachJournalSheet extends StatelessWidget {
  final List<SportCoachLog> logs;
  final List<String> dayNames;

  const _SportCoachJournalSheet({required this.logs, required this.dayNames});

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Journal du coach Sport', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sorted.isEmpty ? 'Aucune analyse Sport pour le moment.' : 'Les analyses et ajustements du coach.'),
          const SizedBox(height: 14),
          SizedBox(
            height: min(MediaQuery.sizeOf(context).height * .62, 520),
            child: sorted.isEmpty
                ? const Center(child: Text('Le journal se remplira après les premières séances.'))
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final log = sorted[index];
                      final d = log.date.toLocal();
                      final dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: _colors.surfaceSunken, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.border)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          mascotAvatarInline(size: 34),
                          const SizedBox(width: 9),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(log.activityName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(dateLabel, style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
                            const SizedBox(height: 5),
                            Text(log.message, style: const TextStyle(height: 1.3)),
                            if (log.adjustment != null) ...[
                              const SizedBox(height: 5),
                              Text('⚙️ ${log.adjustment}', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.accentText)),
                            ],
                          ])),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

Widget mascotChoiceAvatar({double size = 34}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: _colors.peachBg,
    shape: BoxShape.circle,
    border: Border.all(color: _colors.peachBorder, width: 1.2),
    boxShadow: [BoxShadow(color: _colors.shadow, blurRadius: 4, offset: Offset(0, 1))],
  ),
  clipBehavior: Clip.antiAlias,
  child: Padding(
    padding: EdgeInsets.all(size * .02),
    child: Image.memory(_bearHeadBytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
  ),
);

Widget mascotAvatarInline({double size = 34}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(color: _colors.peachBg, shape: BoxShape.circle, border: Border.all(color: _colors.peachBorder)),
  clipBehavior: Clip.antiAlias,
  child: Padding(
    padding: EdgeInsets.all(size * .02),
    child: Image.memory(_bearHeadBytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
  ),
);

class _SportChoice {
  final int minutes;
  final double score;
  final List<Activity> activities;

  const _SportChoice({required this.minutes, required this.score, required this.activities});
}

class _SportDailySlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SportDailySlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(0, 240);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _colors.tintStrong, borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Text('$safe min', style: TextStyle(fontWeight: FontWeight.w800, color: _colors.accentText)),
          ),
        ]),
        Slider(
          value: safe.toDouble(),
          min: 0,
          max: 240,
          divisions: 48,
          label: '$safe min',
          onChanged: (v) => onChanged((v / 5).round() * 5),
        ),
      ]),
    );
  }
}

class _StepperLine extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _StepperLine({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: _uiIcon('remove', Icons.remove_circle_outline, size: 18, color: _colors.danger)),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: _uiIcon('add', Icons.add_circle_outline, size: 18)),
      ]);
}

