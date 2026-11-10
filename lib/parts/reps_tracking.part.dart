// V12.18.0 — Suivi en répétitions : chaque réalisation enregistre un nombre de répétitions,
// comparé à un objectif ; le Coach affiche la dernière réalisation et l'objectif.

part of '../main.dart';

class _RepsSheet extends StatefulWidget {
  final String name;
  final int? target;
  final int? last;
  final int? current;
  final bool allowDelete;

  const _RepsSheet({required this.name, this.target, this.last, this.current, this.allowDelete = false});

  @override
  State<_RepsSheet> createState() => _RepsSheetState();
}

class _RepsSheetState extends State<_RepsSheet> {
  late final TextEditingController controller;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final start = widget.current ?? widget.last;
    controller = TextEditingController(text: start == null ? '' : '$start');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _close(int? value) {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(controller.text.trim());
    final quick = <int>{
      if (widget.last != null && widget.last! > 0) widget.last!,
      if (widget.last != null && widget.last! > 0) widget.last! + 5,
      if (widget.last != null && widget.last! > 0) widget.last! + 10,
      if (widget.target != null) widget.target!,
    }.toList()
      ..sort();
    final canSave = value != null && (value > 0 || (widget.allowDelete && value == 0));
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.l, AppSpace.s, AppSpace.l, MediaQuery.of(context).viewInsets.bottom + AppSpace.l),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SheetHeader(
            leading: _uiIcon('repeat', Icons.repeat_rounded, size: 24, color: _colors.accentIcon),
            title: 'Combien de répétitions ?',
            subtitle: widget.name,
          ),
          const SizedBox(height: AppSpace.m),
          Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
            if (widget.last != null) _Pill('Dernière : ${widget.last} rép.'),
            if (widget.target != null) _Pill('Objectif : ${widget.target} rép.', background: _colors.peachBg, foreground: _colors.goldText),
          ]),
          const SizedBox(height: AppSpace.m),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canSave) _close(value);
            },
            decoration: const InputDecoration(labelText: 'Répétitions réalisées'),
          ),
          if (quick.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final v in quick)
                ActionChip(
                  label: Text('$v', style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => controller.text = '$v'),
                ),
            ]),
          ],
          if (widget.allowDelete) ...[
            const SizedBox(height: 6),
            Text('0 répétition = supprimer cette réalisation de l’historique.', style: _hintStyle()),
          ],
          const SizedBox(height: AppSpace.m),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _closing ? null : () => _close(null), child: const Text('Passer'))),
            const SizedBox(width: AppSpace.s),
            Expanded(child: FilledButton(onPressed: (!canSave || _closing) ? null : () => _close(value), child: const Text('Enregistrer'))),
          ]),
        ]),
      ),
    );
  }
}

extension _RepsPart on _MaBelleSemaineAppState {
  Future<int?> _askReps({required Activity activity, int? current, bool allowDelete = false}) {
    return showModalBottomSheet<int>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RepsSheet(
        name: activity.name,
        target: activity.repsTarget,
        last: _lastRepsLog(activity)?.reps,
        current: current,
        allowDelete: allowDelete,
      ),
    );
  }

  ActivityLog _logWithReps(ActivityLog log, int reps) => ActivityLog(
        date: log.date,
        title: log.title,
        emoji: log.emoji,
        category: log.category,
        period: log.period,
        day: log.day,
        plannedMinutes: log.plannedMinutes,
        realisedMinutes: log.realisedMinutes,
        feeling: log.feeling,
        unplanned: log.unplanned,
        planItemId: log.planItemId,
        activityId: log.activityId,
        reps: reps,
      );

  void _setLogReps(ActivityLog log, int reps) {
    final index = logs.indexOf(log);
    if (index < 0) return;
    setState(() => logs[index] = _logWithReps(log, reps));
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    final a = _registeredActivity(id: log.activityId, title: log.activityId == null ? log.title : null);
    final target = a?.repsTarget;
    _showFeedback(target == null
        ? '✓ $reps répétitions enregistrées.'
        : reps >= target
            ? '🎉 $reps répétitions : objectif de $target atteint !'
            : '✓ $reps / $target répétitions.');
  }

  /// Après validation d'un moment suivi en répétitions : demande le nombre (ignorable).
  Future<void> _promptRepsForItem(PlanItem item) async {
    if (!mounted || item.activityId == null) return;
    final a = findActivity(item.activityId!);
    if (a == null || !_isRepsActivity(a)) return;
    final linked = logs.where((l) => l.planItemId == item.id).toList();
    if (linked.isEmpty || linked.any((l) => l.reps != null)) return;
    final reps = await _askReps(activity: a);
    if (reps == null || reps < 1 || !mounted) return;
    final log = logs.where((l) => l.planItemId == item.id).toList();
    if (log.isNotEmpty) _setLogReps(log.first, reps);
  }

  Future<void> _promptRepsForDate(Activity activity, DateTime date) async {
    if (!mounted || !_isRepsActivity(activity)) return;
    final candidates = logs.where((l) => _sameDateOnlyNonSport(l.date, date) && _logIsOfActivity(l, activity) && l.reps == null).toList();
    if (candidates.isEmpty) return;
    final reps = await _askReps(activity: activity);
    if (reps == null || reps < 1 || !mounted) return;
    _setLogReps(candidates.last, reps);
  }

  /// Saisir ou corriger les répétitions d'un moment (le valide s'il ne l'est pas encore).
  Future<void> editItemReps(PlanItem item) async {
    if (!mounted || item.activityId == null) return;
    final a = findActivity(item.activityId!);
    if (a == null || !_isRepsActivity(a)) return;
    final existing = logs.where((l) => l.planItemId == item.id && l.reps != null).toList();
    final reps = await _askReps(activity: a, current: existing.isEmpty ? null : existing.first.reps);
    if (reps == null || reps < 1 || !mounted) return;
    if (!item.done) {
      togglePlanItemDone(item, true);
      if (!item.done) return;
    }
    final log = logs.where((l) => l.planItemId == item.id).toList();
    if (log.isNotEmpty) _setLogReps(log.first, reps);
  }

  /// Priorités, accueil : répétitions du jour d'une activité.
  Future<void> editActivityRepsToday(Activity activity) async {
    if (!mounted) return;
    final now = DateTime.now();
    await editActivityRepsOnDate(activity, DateTime(now.year, now.month, now.day));
  }

  /// Un jour donné : corrige les répétitions, ou crée la réalisation si elle n'existe pas.
  Future<void> editActivityRepsOnDate(Activity activity, DateTime date) async {
    if (!mounted || !_isRepsActivity(activity)) return;
    final day = date.weekday - 1;
    final currentWeek = _sameDateOnlyNonSport(date, _addDays(_startOfCurrentWeek(), day));
    if (currentWeek) {
      final items = plan.where((p) => p.activityId == activity.id && p.day == day).toList();
      if (items.isNotEmpty) {
        await editItemReps(items.first);
        return;
      }
    }
    final mine = logs.where((l) => _sameDateOnlyNonSport(l.date, date) && _logIsOfActivity(l, activity)).toList();
    if (mine.isNotEmpty) {
      final reps = await _askReps(activity: activity, current: mine.last.reps);
      if (reps == null || reps < 1 || !mounted) return;
      _setLogReps(mine.last, reps);
      return;
    }
    final reps = await _askReps(activity: activity);
    if (reps == null || reps < 1 || !mounted) return;
    _recordRealisationOnDate(activity, date, 1, reps: reps);
    _showFeedback('✓ ${activity.name} : $reps répétitions enregistrées.');
  }
}
