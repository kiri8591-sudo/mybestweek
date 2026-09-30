// V9.29.4 — Objectifs de réalisation + récompenses + streak Sport.
// Reconstruction sur la base V9.28.1 avec réintégration V9.29.
// Création d'objectif volontairement simple :
// 1) le formulaire ne modifie jamais l'état principal ;
// 2) après fermeture, une seule setState ajoute/modifie l'objectif ;
// 3) la sauvegarde et le retour visuel sont exécutés séparément ;
// 4) aucun moteur de planning n'est appelé lors de la création.

part of '../main.dart';

class RealizationGoal {
  final String id;
  String activityId;
  String cadence; // jour | semaine | mois
  int target;
  String rewardText;
  DateTime createdAt;
  final Set<String> rewardedPeriodKeys;

  RealizationGoal({
    required this.id,
    required this.activityId,
    required this.cadence,
    required this.target,
    required this.rewardText,
    required this.createdAt,
    Set<String>? rewardedPeriodKeys,
  }) : rewardedPeriodKeys = rewardedPeriodKeys == null ? <String>{} : {...rewardedPeriodKeys};
}

class _GoalDraft {
  final String activityId;
  final String cadence;
  final int target;
  final String rewardText;
  final bool delete;

  const _GoalDraft({
    required this.activityId,
    required this.cadence,
    required this.target,
    required this.rewardText,
    this.delete = false,
  });
}

class _GoalEditorSheet extends StatefulWidget {
  final List<Activity> activities;
  final RealizationGoal? existing;

  const _GoalEditorSheet({
    required this.activities,
    this.existing,
  });

  @override
  State<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<_GoalEditorSheet> {
  late String activityId;
  late String cadence;
  late int target;
  late final TextEditingController targetController;
  late final TextEditingController rewardController;

  @override
  void initState() {
    super.initState();
    activityId = widget.existing?.activityId ?? widget.activities.first.id;
    cadence = widget.existing?.cadence ?? 'semaine';
    target = widget.existing?.target ?? (cadence == 'jour' ? 1 : cadence == 'mois' ? 8 : 3);
    targetController = TextEditingController(text: '$target');
    rewardController = TextEditingController(
      text: widget.existing?.rewardText ?? 'un petit plaisir',
    );
  }

  @override
  void dispose() {
    targetController.dispose();
    rewardController.dispose();
    super.dispose();
  }

  int _maxTarget(String value) => value == 'jour' ? 7 : value == 'semaine' ? 31 : 99;

  int _defaultTarget(String value) => value == 'jour' ? 1 : value == 'semaine' ? 3 : 8;

  String _cadenceLabel(String value) {
    switch (value) {
      case 'jour':
        return 'par jour';
      case 'mois':
        return 'par mois';
      default:
        return 'par semaine';
    }
  }

  void _save() {
    final parsed = int.tryParse(targetController.text.trim());
    final safeTarget = max(1, min(_maxTarget(cadence), parsed ?? target));
    Navigator.of(context).pop(
      _GoalDraft(
        activityId: activityId,
        cadence: cadence,
        target: safeTarget,
        rewardText: rewardController.text.trim().isEmpty
            ? 'un petit plaisir'
            : rewardController.text.trim(),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(
      _GoalDraft(
        activityId: activityId,
        cadence: cadence,
        target: target,
        rewardText: rewardController.text.trim(),
        delete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🎯', style: TextStyle(fontSize: 25)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.existing == null ? 'Nouvel objectif' : 'Modifier l’objectif',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: activityId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activité'),
              items: widget.activities
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text('${a.emoji} ${a.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => activityId = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: cadence,
              decoration: const InputDecoration(labelText: 'Rythme de l’objectif'),
              items: const [
                DropdownMenuItem(value: 'jour', child: Text('Par jour')),
                DropdownMenuItem(value: 'semaine', child: Text('Par semaine')),
                DropdownMenuItem(value: 'mois', child: Text('Par mois')),
              ],
              onChanged: (value) {
                if (value == null) return;
                final newMax = _maxTarget(value);
                final newDefault = _defaultTarget(value);
                final parsed = int.tryParse(targetController.text.trim());
                var newTarget = (parsed ?? target).clamp(1, newMax).toInt();
                if (newTarget <= 0) newTarget = newDefault;
                setState(() {
                  cadence = value;
                  target = newTarget;
                  targetController.text = '$target';
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre de réalisations',
                suffixText: _cadenceLabel(cadence),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) target = parsed;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rewardController,
              maxLength: 70,
              decoration: const InputDecoration(
                labelText: 'Récompense',
                hintText: 'Ex. un film, une sortie, un après-midi libre…',
              ),
            ),
            const SizedBox(height: 2),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCE5F0)),
              ),
              padding: const EdgeInsets.all(11),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡', style: TextStyle(fontSize: 17)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La récompense est gagnée une fois par période lorsque la cible est atteinte. Elle reste cumulée.',
                      style: TextStyle(fontSize: 10.9, height: 1.32, color: Color(0xFF64707B), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: _activityIconWidget(_uiIconValue('objectiveSave', ''), size: 18),
                label: const Text('Enregistrer'),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: _activityIconWidget(_uiIconValue('objectiveDelete', ''), size: 18),
                  label: const Text('Supprimer cet objectif'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _ObjectivesV929Part on _MaBelleSemaineAppState {
  DateTime _goalDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _goalWeekStart(DateTime d) {
    final day = _goalDateOnly(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime _goalPeriodStart(RealizationGoal goal, DateTime reference) {
    switch (goal.cadence) {
      case 'jour':
        return _goalDateOnly(reference);
      case 'mois':
        return DateTime(reference.year, reference.month, 1);
      case 'semaine':
      default:
        return _goalWeekStart(reference);
    }
  }

  DateTime _goalPeriodEnd(RealizationGoal goal, DateTime reference) {
    final start = _goalPeriodStart(goal, reference);
    switch (goal.cadence) {
      case 'jour':
        return start.add(const Duration(days: 1));
      case 'mois':
        return DateTime(start.year, start.month + 1, 1);
      case 'semaine':
      default:
        return start.add(const Duration(days: 7));
    }
  }

  String _goalPeriodKey(RealizationGoal goal, DateTime reference) {
    final start = _goalPeriodStart(goal, reference);
    final prefix = goal.cadence == 'jour'
        ? 'D'
        : goal.cadence == 'mois'
            ? 'M'
            : 'W';
    return '$prefix-${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }

  String _goalCadenceLabel(String cadence) {
    switch (cadence) {
      case 'jour':
        return 'par jour';
      case 'mois':
        return 'par mois';
      case 'semaine':
      default:
        return 'par semaine';
    }
  }

  int _goalProgress(RealizationGoal goal, [DateTime? reference]) {
    try {
      final ref = reference ?? _clockNow;
      final start = _goalPeriodStart(goal, ref);
      final end = _goalPeriodEnd(goal, ref);
      var count = 0;
      for (final log in logs) {
        if (log.activityId != goal.activityId) continue;
        if (log.realisedMinutes <= 0) continue;
        // Un objectif mensuel porte sur le mois en cours : les réalisations
        // déjà faites avant la création de l'objectif restent comptabilisées.
        // Pour jour/semaine, on conserve le point de départ à la création.
        if (goal.cadence != 'mois' && log.date.isBefore(goal.createdAt)) continue;
        if (log.date.isBefore(start) || !log.date.isBefore(end)) continue;
        count++;
      }
      return count;
    } catch (_) {
      // Un objectif mal formé ne doit jamais faire tomber l'écran Objectifs.
      return 0;
    }
  }

  double _goalProgressRatio(RealizationGoal goal) =>
      (_goalProgress(goal) / max(1, goal.target)).clamp(0.0, 1.0).toDouble();

  int _goalRewardCount(RealizationGoal goal) => goal.rewardedPeriodKeys.length;

  void _refreshGoalsAfterRealization() {
    if (!mounted || _realizationGoals.isEmpty) return;

    final now = _clockNow;
    var changed = false;
    var newlyWon = 0;

    for (final goal in _realizationGoals) {
      final key = _goalPeriodKey(goal, now);
      if (_goalProgress(goal, now) >= goal.target &&
          !goal.rewardedPeriodKeys.contains(key)) {
        goal.rewardedPeriodKeys.add(key);
        changed = true;
        newlyWon++;
      }
    }

    if (!changed) return;

    setState(() {});
    _persistLocalState(recordUndo: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showFeedback(
        newlyWon == 1
            ? '🎁 Objectif atteint · récompense gagnée !'
            : '🎁 $newlyWon objectifs atteints · récompenses gagnées !',
      );
    });
  }

  void _captureGoalUndoSnapshot() {
    if (_undoInProgress || !mounted || _isHydratingLocalState) return;
    try {
      final root = jsonDecode(_backupJson()) as Map<String, dynamic>;
      root['weekKey'] = _currentWeekKey();
      root['savedAt'] = DateTime.now().toIso8601String();
      _undoSnapshotJson = const JsonEncoder.withIndent('  ').convert(root);
      _undoActionDescription = 'la dernière modification d’objectif';
      _undoActionPrepared = true;
    } catch (_) {
      // L'objectif reste créable même si le snapshot d'annulation échoue.
    }
  }

  Future<void> _addOrEditGoal({RealizationGoal? existing}) async {
    if (!mounted) return;

    final editableActivities = activities
        .where((a) =>
            !a.isSportProgram &&
            !a.isDateRange &&
            (!a.isFrozen || (existing != null && a.id == existing.activityId)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (editableActivities.isEmpty) {
      _showFeedback('Aucune activité disponible pour créer un objectif.');
      return;
    }

    final draft = await showModalBottomSheet<_GoalDraft>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditorSheet(
        activities: editableActivities,
        existing: existing,
      ),
    );

    if (!mounted || draft == null) return;

    if (draft.delete) {
      if (existing == null) return;
      _captureGoalUndoSnapshot();
      _undoActionDescription = 'la suppression de l’objectif lié à « ${findActivity(existing.activityId)?.name ?? 'l’activité'} »';
      setState(() {
        _realizationGoals.removeWhere((goal) => goal.id == existing.id);
      });
      _queueLocalStatePersist();
      _showFeedback('Objectif supprimé.');
      return;
    }

    final selectedActivity = findActivity(draft.activityId);
    if (selectedActivity == null || selectedActivity.isSportProgram || selectedActivity.isDateRange) {
      _showFeedback('Cette activité ne peut pas recevoir cet objectif.');
      return;
    }

    final safeTarget = max(
      1,
      min(
        draft.cadence == 'jour'
            ? 7
            : draft.cadence == 'semaine'
                ? 31
                : 99,
        draft.target,
      ),
    );

    final duplicate = _realizationGoals.any(
      (goal) =>
          goal.id != existing?.id &&
          goal.activityId == draft.activityId &&
          goal.cadence == draft.cadence,
    );
    if (duplicate) {
      _showFeedback('Cet objectif existe déjà pour cette activité et ce rythme.');
      return;
    }

    _captureGoalUndoSnapshot();
    final cadenceLabel = draft.cadence == 'jour'
        ? 'par jour'
        : draft.cadence == 'mois'
            ? 'par mois'
            : 'par semaine';
    _undoActionDescription = existing == null
        ? 'la création de l’objectif « ${selectedActivity.name} · $cadenceLabel »'
        : 'la modification de l’objectif « ${selectedActivity.name} · $cadenceLabel »';

    final now = DateTime.now();
    final goal = existing ??
        RealizationGoal(
          id: 'goal_${now.microsecondsSinceEpoch}',
          activityId: draft.activityId,
          cadence: draft.cadence,
          target: safeTarget,
          rewardText: draft.rewardText,
          createdAt: now,
        );

    setState(() {
      if (existing == null) {
        _realizationGoals.add(goal);
      } else {
        existing.activityId = draft.activityId;
        existing.cadence = draft.cadence;
        existing.target = safeTarget;
        existing.rewardText = draft.rewardText;
      }
    });

    _queueLocalStatePersist();
    _showFeedback(existing == null ? '🎯 Objectif créé.' : '🎯 Objectif modifié.');
  }

  Set<String> _sportActivityDayKeys(Activity activity) {
    return logs
        .where((log) => log.activityId == activity.id && log.realisedMinutes > 0)
        .map((log) {
      final d = log.date;
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }).toSet();
  }

  int _sportCurrentStreak(Activity activity) {
    final keys = _sportActivityDayKeys(activity);
    if (keys.isEmpty) return 0;

    final today = _goalDateOnly(_clockNow);
    final todayKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    var cursor = keys.contains(todayKey)
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;

    while (true) {
      final key = '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (!keys.contains(key)) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _sportBestStreak(Activity activity) {
    final dates = _sportActivityDayKeys(activity)
        .map((key) {
          final p = key.split('-').map(int.parse).toList();
          return DateTime(p[0], p[1], p[2]);
        })
        .toList()
      ..sort();

    if (dates.isEmpty) return 0;

    var best = 1;
    var run = 1;
    for (var i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        run++;
        best = max(best, run);
      } else {
        run = 1;
      }
    }
    return best;
  }

  Widget _goalCard(RealizationGoal goal) {
    final activity = findActivity(goal.activityId);
    if (activity == null) return const SizedBox.shrink();

    final progress = _goalProgress(goal);
    final ratio = _goalProgressRatio(goal);
    final complete = progress >= goal.target;
    final rewardCount = _goalRewardCount(goal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _addOrEditGoal(existing: goal),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 11, 10),
          decoration: BoxDecoration(
            color: complete ? const Color(0xFFF1F7F0) : const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: complete ? const Color(0xFFD7E7D5) : const Color(0xFFE5DED4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: complete ? const Color(0xFFDDEFE2) : const Color(0xFFF1F0F7),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: _activityIconWidget(_uiIconValue('objectiveDetail', ''), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w900,
                            color: complete ? const Color(0xFF53725E) : const Color(0xFF4D5A54),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${goal.target} ${_goalCadenceLabel(goal.cadence)}',
                          style: const TextStyle(
                            fontSize: 10.3,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7A827E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  complete
                      ? _activityIconWidget(_uiIconValue('objectiveState', ''), size: 21)
                      : _uiIcon('planOpen', Icons.chevron_right_rounded, size: 21, color: const Color(0xFFA3AAA6)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE7E1D8),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          complete ? const Color(0xFF76A581) : const Color(0xFF8097AE),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progress/${goal.target}',
                    style: const TextStyle(
                      fontSize: 11.1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF59645F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      complete ? '🎁 Récompense gagnée · ${goal.rewardText}' : '🎁 ${goal.rewardText}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.3,
                        fontWeight: FontWeight.w800,
                        color: complete ? const Color(0xFF5B7A63) : const Color(0xFF7B746B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🎁 $rewardCount',
                    style: const TextStyle(
                      fontSize: 10.1,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8A7968),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sportStreakCard(Activity activity) {
    final streak = _sportCurrentStreak(activity);
    final best = _sportBestStreak(activity);
    final keys = _sportActivityDayKeys(activity);
    final today = _goalDateOnly(_clockNow);
    final todayKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doneToday = keys.contains(todayKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 11, 10),
        decoration: BoxDecoration(
          color: streak > 0 ? const Color(0xFFF1F7F0) : const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: streak > 0 ? const Color(0xFFD7E7D5) : const Color(0xFFE5DED4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2E9),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: _activityIconWidget(activity.emoji, size: 23),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.3,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4D5A54),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak == 0
                        ? 'Pas de série en cours${doneToday ? '' : ' · à toi de jouer aujourd’hui'}'
                        : '$streak jour${streak > 1 ? 's' : ''} consécutif${streak > 1 ? 's' : ''}${doneToday ? ' · aujourd’hui fait' : ' · jusqu’à hier'}',
                    style: const TextStyle(
                      fontSize: 10.1,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF78817C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6A8D6D),
                  ),
                ),
                Text(
                  'record $best',
                  style: const TextStyle(
                    fontSize: 9.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8A918D),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildObjectives() {
    final goals = [..._realizationGoals]
      ..sort((a, b) {
        const order = {'jour': 0, 'semaine': 1, 'mois': 2};
        final cadenceCompare = (order[a.cadence] ?? 9).compareTo(order[b.cadence] ?? 9);
        if (cadenceCompare != 0) return cadenceCompare;
        final aa = findActivity(a.activityId)?.name.toLowerCase() ?? '';
        final bb = findActivity(b.activityId)?.name.toLowerCase() ?? '';
        return aa.compareTo(bb);
      });

    final sportActivities = activities
        .where((a) =>
            a.category.toLowerCase() == 'sport' &&
            !a.isSportProgram &&
            !a.isDateRange &&
            !a.isFrozen)
        .toList()
      ..sort((a, b) {
        final streakCompare = _sportCurrentStreak(b).compareTo(_sportCurrentStreak(a));
        if (streakCompare != 0) return streakCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final completedGoals = goals.where((g) => _goalProgress(g) >= g.target).length;
    final totalRewards = goals.fold<int>(0, (sum, goal) => sum + _goalRewardCount(goal));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFFFFF8EF),
          surfaceTintColor: Colors.transparent,
          title: Row(children: [
            _activityIconWidget(_uiIconValue('objective', ''), size: 22),
            const SizedBox(width: 8),
            const Text('Objectifs'),
          ]),
          actions: [
            IconButton(
              tooltip: 'Nouvel objectif',
              onPressed: () => _addOrEditGoal(),
              icon: _activityIconWidget(_uiIconValue('add', ''), size: 22),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: softCard(
              color: const Color(0xFFEAF0FA),
              borderColor: const Color(0xFFD9E3F1),
              radius: 23,
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎯', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mes objectifs de réalisation',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF48576A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          goals.isEmpty
                              ? 'Choisis une habitude concrète et une cible simple.'
                              : '$completedGoals/${goals.length} atteint${goals.length > 1 ? 's' : ''} sur la période actuelle · $totalRewards récompense${totalRewards > 1 ? 's' : ''} cumulée${totalRewards > 1 ? 's' : ''}.',
                          style: const TextStyle(
                            fontSize: 10.9,
                            height: 1.3,
                            color: Color(0xFF677382),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 7),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Objectifs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF46544D),
                    ),
                  ),
                ),
                if (goals.isNotEmpty)
                  Text(
                    '${goals.length} actif${goals.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 10.4,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A827D),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (goals.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: softCard(
                color: const Color(0xFFFFFCF7),
                borderColor: const Color(0xFFE5DED4),
                radius: 19,
                padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🌱', style: TextStyle(fontSize: 21)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Aucun objectif pour le moment. Commence par une cible simple, par exemple 3 réalisations par semaine.',
                        style: TextStyle(
                          fontSize: 11.3,
                          height: 1.34,
                          color: Color(0xFF68736F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (goals.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _goalCard(goals[index]),
                childCount: goals.length,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
            child: Row(
              children: [
                _activityIconWidget(_uiIconValue('streak', ''), size: 21),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Streak Sport par activité',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF46544D),
                    ),
                  ),
                ),
                Text(
                  'jours consécutifs',
                  style: TextStyle(
                    fontSize: 9.4,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8A918D),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (sportActivities.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: softCard(
                color: const Color(0xFFFFFCF7),
                borderColor: const Color(0xFFE5DED4),
                radius: 19,
                padding: const EdgeInsets.all(13),
                child: const Text(
                  'Ajoute ou réactive une activité Sport pour suivre une série.',
                  style: TextStyle(
                    fontSize: 11.2,
                    color: Color(0xFF68736F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        if (sportActivities.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _sportStreakCard(sportActivities[index]),
                childCount: sportActivities.length,
              ),
            ),
          ),
      ],
    );
  }
}
