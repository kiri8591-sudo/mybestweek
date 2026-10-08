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
    final firstSelectable = widget.activities.where((a) => !a.isFrozen).cast<Activity?>().firstWhere((a) => a != null, orElse: () => null);
    activityId = widget.existing?.activityId ?? firstSelectable?.id ?? widget.activities.first.id;
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
                    color: _colors.tintStrong,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                  alignment: Alignment.center,
                  child: _activityIconWidget('pack://target', size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.existing == null ? 'Nouvel objectif' : 'Modifier l’objectif',
                    style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Activité',
              style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: _colors.card,
                borderRadius: BorderRadius.circular(AppRadius.l),
                border: Border.all(color: _colors.borderStrong),
              ),
              constraints: const BoxConstraints(maxHeight: 255),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: widget.activities.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 52, endIndent: 10),
                itemBuilder: (context, index) {
                  final activity = widget.activities[index];
                  final selected = activity.id == activityId;
                  final frozen = activity.isFrozen;
                  final frozenLinkedToExisting = frozen &&
                      widget.existing != null &&
                      widget.existing!.activityId == activity.id;
                  final selectable = !frozen || frozenLinkedToExisting;
                  return ListTile(
                    dense: true,
                    enabled: selectable,
                    selected: selected,
                    selectedTileColor: _colors.tintStrong,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _activityIconWidget(activity.emoji, size: 26),
                        if (frozen)
                          Positioned(
                            right: -7,
                            bottom: -4,
                            child: _activityIconWidget('pack://water', size: 18),
                          ),
                      ],
                    ),
                    title: Text(
                      activity.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w700,
                        color: frozen ? _colors.textFaint : _colors.textStrong,
                      ),
                    ),
                    subtitle: frozen
                        ? Text(
                            frozenLinkedToExisting
                                ? 'Activité gelée · liée à cet objectif · sélection conservée'
                                : 'Activité gelée · non sélectionnable pour un nouvel objectif',
                            style: TextStyle(fontSize: AppType.small, color: _colors.textFaint, fontWeight: FontWeight.w700),
                          )
                        : null,
                    trailing: selected
                        ? Icon(Icons.check_circle_rounded, color: _colors.textMuted, size: 20)
                        : frozen
                            ? Text('GELÉE', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.textMuted))
                            : Icon(Icons.radio_button_unchecked_rounded, color: _colors.textFaint, size: 19),
                    onTap: selectable ? () => setState(() => activityId = activity.id) : null,
                  );
                },
              ),
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
                color: _colors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.l),
                border: Border.all(color: _colors.borderTint),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _activityIconWidget('pack://bulb', size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La récompense est gagnée une fois par période lorsque la cible est atteinte. Elle reste cumulée.',
                      style: TextStyle(fontSize: AppType.small, height: 1.32, color: _colors.accentText, fontWeight: FontWeight.w700),
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
    return _addDays(day, -(day.weekday - 1));
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
        return _addDays(start, 1);
      case 'mois':
        return DateTime(start.year, start.month + 1, 1);
      case 'semaine':
      default:
        return _addDays(start, 7);
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

    // Un objectif peut être créé pour toute activité réellement présente
    // dans Mes activités, y compris Sport, activités gelées et activités
    // multi-jours. Le gel agit sur le Coach, pas sur le suivi des objectifs.
    // Pour un nouvel objectif, toutes les activités non gelées sont proposées.
    // Une activité gelée reste visible dans Mes activités et peut être ajoutée
    // manuellement à une journée, mais elle n’est pas sélectionnable lors de
    // la création d’un nouvel objectif.
    // Lors de la modification d'un objectif existant, l'activité actuellement
    // liée reste visible même si elle est désormais gelée, afin de pouvoir
    // consulter ou modifier l'objectif sans perdre son lien.
    final byId = <String, Activity>{};
    for (final activity in activities) {
      byId.putIfAbsent(activity.id, () => activity);
    }
    final editableActivities = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selectableForNewGoal = editableActivities.where((a) => !a.isFrozen).toList();
    // Pour un nouvel objectif, on affiche aussi les activités gelées : elles
    // doivent rester visibles dans le sélecteur, grisées et non sélectionnables.
    // La vraie sélection reste limitée aux activités actives dans _GoalEditorSheet.
    final availableForEditor = editableActivities;

    if (existing == null && selectableForNewGoal.isEmpty) {
      _showFeedback('Aucune activité disponible pour créer un objectif : toutes les activités sont gelées.');
      return;
    }
    if (availableForEditor.isEmpty) {
      _showFeedback('Aucune activité disponible.');
      return;
    }

    final draft = await showModalBottomSheet<_GoalDraft>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditorSheet(
        activities: availableForEditor,
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
    if (selectedActivity == null) {
      _showFeedback('Activité introuvable.');
      return;
    }
    if (existing == null && selectedActivity.isFrozen) {
      _showFeedback('Une activité gelée ne peut pas être sélectionnée pour un nouvel objectif.');
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

    // Vérifie immédiatement si le nouvel objectif est déjà atteint avec
    // les réalisations présentes dans sa période. C'est particulièrement
    // important pour un objectif mensuel créé après plusieurs réalisations.
    _refreshGoalsAfterRealization();
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
        : _addDays(today, -1);
    var streak = 0;

    while (true) {
      final key = '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (!keys.contains(key)) break;
      streak++;
      cursor = _addDays(cursor, -1);
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
      padding: const EdgeInsets.only(bottom: 8),
      child: _AppCard(
        onTap: () => _addOrEditGoal(existing: goal),
        tone: complete ? _CardTone.tint : _CardTone.plain,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: complete ? _colors.tintStrong : _colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                    alignment: Alignment.center,
                    child: _activityIconWidget(_uiIconValue('objectiveDetail', ''), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppType.bodyL,
                                  fontWeight: FontWeight.w700,
                                  color: complete ? _colors.accentIcon : _colors.textStrong,
                                ),
                              ),
                            ),
                            if (activity.isFrozen) ...[
                              const SizedBox(width: 5),
                              _activityIconWidget(_uiIconValue('frozen', '🧊'), size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${goal.target} ${_goalCadenceLabel(goal.cadence)}',
                          style: TextStyle(
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w700,
                            color: _colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  complete
                      ? _activityIconWidget(_uiIconValue('objectiveState', ''), size: 21)
                      : _uiIcon('planOpen', Icons.chevron_right_rounded, size: 21, color: _colors.textFaint),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MeterBar(value: ratio, color: complete ? _colors.accentFill : _colors.accentOutline),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progress/${goal.target}',
                    style: TextStyle(
                      fontSize: AppType.label,
                      fontWeight: FontWeight.w700,
                      color: _colors.textMuted,
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
                        fontSize: AppType.small,
                        fontWeight: FontWeight.w700,
                        color: complete ? _colors.accentIcon : _colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🎁 $rewardCount',
                    style: TextStyle(
                      fontSize: AppType.small,
                      fontWeight: FontWeight.w700,
                      color: _colors.textWarm,
                    ),
                  ),
                ],
              ),
            ],
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
      child: _AppCard(
        tone: streak > 0 ? _CardTone.tint : _CardTone.plain,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _colors.tintStrong,
                borderRadius: BorderRadius.circular(AppRadius.l),
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
                    style: TextStyle(
                      fontSize: AppType.body,
                      fontWeight: FontWeight.w700,
                      color: _colors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak == 0
                        ? 'Pas de série en cours${doneToday ? '' : ' · à toi de jouer aujourd’hui'}'
                        : '$streak jour${streak > 1 ? 's' : ''} consécutif${streak > 1 ? 's' : ''}${doneToday ? ' · aujourd’hui fait' : ' · jusqu’à hier'}',
                    style: TextStyle(
                      fontSize: AppType.small,
                      fontWeight: FontWeight.w700,
                      color: _colors.textMuted,
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
                  style: TextStyle(
                    fontSize: AppType.h1,
                    fontWeight: FontWeight.w800,
                    color: _colors.accentIcon,
                  ),
                ),
                Text(
                  'record $best',
                  style: TextStyle(
                    fontSize: AppType.micro,
                    fontWeight: FontWeight.w700,
                    color: _colors.textMuted,
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
        SliverToBoxAdapter(child: pageTitle('Objectifs', goals.isEmpty ? 'Une habitude concrète, une cible simple.' : '$completedGoals sur ${goals.length} atteint${goals.length > 1 ? 's' : ''} sur la période.')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _AppCard(
              tone: _CardTone.tint,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _colors.card,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                    alignment: Alignment.center,
                    child: _activityIconWidget('pack://target', size: 32),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mes objectifs de réalisation',
                          style: _sectionTitleStyle(context),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          goals.isEmpty
                              ? 'Choisis une habitude concrète et une cible simple.'
                              : '$completedGoals/${goals.length} atteint${goals.length > 1 ? 's' : ''} sur la période actuelle · $totalRewards récompense${totalRewards > 1 ? 's' : ''} cumulée${totalRewards > 1 ? 's' : ''}.',
                          style: TextStyle(
                            fontSize: AppType.small,
                            height: 1.3,
                            color: _colors.accentText,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    goals.isEmpty ? 'Objectifs' : 'Objectifs · ${goals.length} actif${goals.length > 1 ? 's' : ''}',
                    style: _sectionTitleStyle(context),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addOrEditGoal(),
                  icon: _uiIcon('add', Icons.add_circle_outline, size: 18),
                  label: const Text('Nouvel objectif'),
                ),
              ],
            ),
          ),
        ),
        if (goals.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activityIconWidget('pack://sprout', size: 24),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Aucun objectif pour le moment. Commence par une cible simple, par exemple 3 réalisations par semaine.',
                        style: TextStyle(
                          fontSize: AppType.label,
                          height: 1.34,
                          color: _colors.textMuted,
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
                Expanded(
                  child: Text(
                    'Streak Sport par activité',
                    style: _sectionTitleStyle(context),
                  ),
                ),
                Text(
                  'jours consécutifs',
                  style: TextStyle(
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w700,
                    color: _colors.textMuted,
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
              child: _AppCard(
                child: Text(
                  'Ajoute ou réactive une activité Sport pour suivre une série.',
                  style: TextStyle(
                    fontSize: AppType.label,
                    color: _colors.textMuted,
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
