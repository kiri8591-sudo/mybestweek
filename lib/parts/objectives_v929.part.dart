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
  bool isMaximum; // false = au moins ; true = au plus
  final Set<String> rewardedPeriodKeys;

  RealizationGoal({
    required this.id,
    required this.activityId,
    required this.cadence,
    required this.target,
    required this.rewardText,
    required this.createdAt,
    this.isMaximum = false,
    Set<String>? rewardedPeriodKeys,
  }) : rewardedPeriodKeys = rewardedPeriodKeys == null ? <String>{} : {...rewardedPeriodKeys};
}

class _GoalDraft {
  final String activityId;
  final String cadence;
  final int target;
  final String rewardText;
  final bool isMaximum;
  final bool delete;

  const _GoalDraft({
    required this.activityId,
    required this.cadence,
    required this.target,
    required this.rewardText,
    this.isMaximum = false,
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
  late bool isMaximum;
  late final TextEditingController targetController;
  late final TextEditingController rewardController;

  @override
  void initState() {
    super.initState();
    final firstSelectable = widget.activities.where((a) => !a.isFrozen).cast<Activity?>().firstWhere((a) => a != null, orElse: () => null);
    activityId = widget.existing?.activityId ?? firstSelectable?.id ?? widget.activities.first.id;
    cadence = widget.existing?.cadence ?? 'semaine';
    target = widget.existing?.target ?? (cadence == 'jour' ? 1 : cadence == 'mois' ? 8 : 3);
    isMaximum = widget.existing?.isMaximum ?? false;
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
        isMaximum: isMaximum,
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
          AppSpace.l,
          AppSpace.s,
          AppSpace.l,
          MediaQuery.of(context).viewInsets.bottom + AppSpace.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(
              leading: _activityIconWidget('pack://target', size: 26),
              title: widget.existing == null ? 'Nouvel objectif' : 'Modifier l’objectif',
              subtitle: 'Une habitude concrète et une cible simple.',
            ),
            const SizedBox(height: AppSpace.l),
            Text('Activité', style: _sectionTitleStyle(context)),
            const SizedBox(height: AppSpace.s),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.activities.length,
                itemBuilder: (context, index) {
                  final activity = widget.activities[index];
                  final selected = activity.id == activityId;
                  final frozen = activity.isFrozen;
                  final frozenLinkedToExisting = frozen && widget.existing != null && widget.existing!.activityId == activity.id;
                  final selectable = !frozen || frozenLinkedToExisting;
                  return _SheetPickRow(
                    leading: _activityIconWidget(activity.emoji, size: 24),
                    title: activity.name,
                    subtitle: frozen
                        ? (frozenLinkedToExisting ? 'Gelée · liée à cet objectif' : 'Gelée · non sélectionnable pour un nouvel objectif')
                        : '${activity.category} · ${_durationOrCount(activity)}',
                    selected: selected,
                    enabled: selectable,
                    badge: frozen ? const _Pill('Gelée') : null,
                    onTap: () => setState(() => activityId = activity.id),
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Objectif plafond'),
              subtitle: Text(isMaximum ? 'Ne pas dépasser cette fréquence' : 'Atteindre au moins cette fréquence'),
              value: isMaximum,
              onChanged: (value) => setState(() => isMaximum = value),
            ),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isMaximum ? 'Maximum de réalisations' : 'Nombre minimal de réalisations',
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
            const SizedBox(height: AppSpace.s),
            _InfoNote(
              leading: _activityIconWidget('pack://bulb', size: 22),
              text: 'La récompense est gagnée une fois par période lorsque la cible est atteinte. Elle reste cumulée.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: _uiIcon('objectiveSave', Icons.check_rounded, size: 18, color: _colors.onPrimary),
                label: const Text('Enregistrer'),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: _uiIcon('objectiveDelete', Icons.delete_outline_rounded, size: 18, color: _colors.danger),
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
      final goalActivity = findActivity(goal.activityId);
      final isCountOnlyActivity = goalActivity?.countOnly ?? false;
      final activityName = goalActivity?.name.trim().toLowerCase() ?? '';
      for (final log in logs) {
        final matchesActivity = log.activityId == goal.activityId ||
            (log.activityId == null && activityName.isNotEmpty &&
                log.title.trim().toLowerCase() == activityName);
        if (!matchesActivity) continue;
        if (log.realisedMinutes <= 0 && !isCountOnlyActivity && (log.reps ?? 0) <= 0) continue;
        // Les objectifs hebdomadaires portent sur la semaine calendaire
        // entière : une réalisation faite avant la création de l'objectif,
        // mais dans cette même semaine, doit compter. Sinon le compteur peut
        // afficher « encore 1 » alors que l'activité a déjà été réalisée.
        // Pour les objectifs quotidiens, la période est déjà limitée au jour ;
        // les objectifs mensuels sont également évalués sur le mois complet.
        final logDay = _goalDateOnly(log.date);
        if (goal.cadence == 'jour' && logDay.isBefore(_goalDateOnly(goal.createdAt))) continue;
        if (logDay.isBefore(_goalDateOnly(start)) ||
            !logDay.isBefore(_goalDateOnly(end))) continue;
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

  bool _goalIsSatisfied(RealizationGoal goal) => goal.isMaximum
      ? _goalProgress(goal) <= goal.target
      : _goalProgress(goal) >= goal.target;

  int _goalRewardCount(RealizationGoal goal) => goal.rewardedPeriodKeys.length;

  void _refreshGoalsAfterRealization() {
    if (!mounted || _realizationGoals.isEmpty) return;

    final now = _clockNow;
    var changed = false;
    var newlyWon = 0;

    for (final goal in _realizationGoals) {
      if (goal.isMaximum) continue; // un plafond ne déclenche pas de récompense automatique
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

  Future<void> _addOrEditGoal({required BuildContext context, RealizationGoal? existing}) async {
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
      // Utiliser le contexte descendant du Navigator fourni par l'écran,
      // et non State.context (qui se trouve au-dessus du MaterialApp).
      context: context,
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
          isMaximum: draft.isMaximum,
        );

    setState(() {
      if (existing == null) {
        _realizationGoals.add(goal);
      } else {
        existing.activityId = draft.activityId;
        existing.cadence = draft.cadence;
        existing.target = safeTarget;
        existing.rewardText = draft.rewardText;
        existing.isMaximum = draft.isMaximum;
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

  Widget _goalCard(BuildContext context, RealizationGoal goal) {
    final activity = findActivity(goal.activityId);
    if (activity == null) return const SizedBox.shrink();

    final progress = _goalProgress(goal);
    final ratio = _goalProgressRatio(goal);
    final complete = _goalIsSatisfied(goal);
    final exceeded = goal.isMaximum && progress > goal.target;
    final rewardCount = _goalRewardCount(goal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AppCard(
        onTap: () => _addOrEditGoal(context: context, existing: goal),
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
                    child: _uiIcon('objectiveDetail', Icons.track_changes_rounded, size: 22, color: _colors.accentIcon),
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
                          '${goal.isMaximum ? 'Au plus' : 'Au moins'} ${goal.target} ${_goalCadenceLabel(goal.cadence)}',
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
                      ? _uiIcon('objectiveState', Icons.emoji_events_outlined, size: 21, color: _colors.goldText)
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
                    '${goal.isMaximum ? '$progress/${goal.target} max' : '$progress/${goal.target}'}',
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
                      goal.isMaximum ? (exceeded ? '⚠️ Plafond dépassé · repartir sereinement' : '✓ Dans la limite fixée') : (complete ? '🎁 Récompense gagnée · ${goal.rewardText}' : '🎁 ${goal.rewardText}'),
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


  String _weightDateLabel(DateTime? d) => d == null ? 'À définir' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  double get _latestWeightKg {
    final validEntries = _weightEntries
        .where((entry) => entry['kg'] is num && DateTime.tryParse('${entry['date']}') != null)
        .toList()
      ..sort((a, b) => DateTime.parse('${a['date']}').compareTo(DateTime.parse('${b['date']}')));
    if (validEntries.isEmpty) return _weightStartKg;
    return (validEntries.last['kg'] as num).toDouble();
  }

  Widget _weightTrackingCard(BuildContext context) {
    final latest = _latestWeightKg;
    final lost = _weightStartKg - latest;
    final remaining = latest - _weightTargetKg;
    final sorted = _weightEntries
        .where((entry) => entry['kg'] is num && DateTime.tryParse('${entry['date']}') != null)
        .toList()
      ..sort((a, b) => DateTime.parse('${a['date']}').compareTo(DateTime.parse('${b['date']}')));
    final lastRecordedDate = sorted.isEmpty ? null : DateTime.tryParse('${sorted.last['date']}');
    final weeklyReference = sorted.where((entry) {
      final date = DateTime.tryParse('${entry['date']}');
      return date != null && lastRecordedDate != null && lastRecordedDate.difference(date).inDays >= 6;
    }).toList();
    final weeklyDelta = weeklyReference.isEmpty ? null : latest - (weeklyReference.last['kg'] as num).toDouble();
    final firstDate = sorted.isEmpty ? null : DateTime.tryParse('${sorted.first['date']}');
    final lastDate = sorted.isEmpty ? null : DateTime.tryParse('${sorted.last['date']}');
    final weeklyRate = (firstDate == null || lastDate == null || lastDate.difference(firstDate).inDays < 7) ? null : (latest - (sorted.first['kg'] as num).toDouble()) / (lastDate.difference(firstDate).inDays / 7);
    final projectedDate = weeklyRate != null && weeklyRate < -.03 && remaining > 0 ? DateTime.now().add(Duration(days: (remaining / -weeklyRate * 7).round())) : null;
    return _AppCard(tone: _CardTone.tint, padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('⚖️', style: TextStyle(fontSize: 24)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Suivi du poids', style: _sectionTitleStyle(context)), Text('Une tendance, pas un jugement', style: TextStyle(color: _colors.textMuted, fontSize: AppType.small))])), TextButton(onPressed: () => _editWeightSettings(context), child: const Text('Réglages'))]),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(latest.toStringAsFixed(1).replaceAll('.', ',') + ' kg', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _colors.textStrong)), const SizedBox(width: 12), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('${lost >= 0 ? '−' : '+'}${lost.abs().toStringAsFixed(1).replaceAll('.', ',')} kg depuis le départ', style: TextStyle(color: _colors.textMuted, fontWeight: FontWeight.w600)))]),
      const SizedBox(height: 4), Text('Départ ${_weightStartKg.toStringAsFixed(1)} kg  ·  Cible ${_weightTargetKg.toStringAsFixed(1)} kg  ·  ${_weightTargetDate == null ? 'Date à définir' : _weightDateLabel(_weightTargetDate)}', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
      const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: ((_weightStartKg - latest) / max(.1, _weightStartKg - _weightTargetKg)).clamp(0.0, 1.0).toDouble(), minHeight: 9)),
      const SizedBox(height: 5), Text(remaining <= 0 ? 'Objectif atteint : bravo !' : '${remaining.toStringAsFixed(1).replaceAll('.', ',')} kg restant${remaining > 1 ? 's' : ''} · avancez à votre rythme', style: TextStyle(color: _colors.textMuted, fontSize: AppType.small)),
      if (sorted.length >= 2) ...[const SizedBox(height: 12), SizedBox(height: 62, width: double.infinity, child: CustomPaint(painter: _WeightSparkline(sorted.map((e)=>(e['kg'] as num).toDouble()).toList(), _colors.accentFill)))],
      if (weeklyDelta != null) Text('Évolution sur environ une semaine : ${weeklyDelta <= 0 ? '−' : '+'}${weeklyDelta.abs().toStringAsFixed(1).replaceAll('.', ',')} kg', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
      if (projectedDate != null) Text('Projection indicative au rythme observé : ${_weightDateLabel(projectedDate)}', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
      if (sorted.isNotEmpty) Text('${sorted.length} pesée${sorted.length>1?'s':''} enregistrée${sorted.length>1?'s':''} · dernière le ${_weightDateLabel(DateTime.tryParse('${sorted.last['date']}'))}', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
      const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(onPressed: () => _addWeightEntry(context), icon: const Icon(Icons.add), label: const Text('Ajouter une pesée'))),
    ]));
  }

  Future<void> _editWeightSettings(BuildContext context) async {
    final startController = TextEditingController(
      text: _weightStartKg.toStringAsFixed(1).replaceAll('.', ','),
    );
    final targetController = TextEditingController(
      text: _weightTargetKg.toStringAsFixed(1).replaceAll('.', ','),
    );
    DateTime? targetDate = _weightTargetDate;
    final today = DateUtils.dateOnly(DateTime.now());
    final minDate = today.subtract(const Duration(days: 365));
    final maxDate = DateTime(2035, 12, 31);

    try {
      // Utiliser explicitement la route permet d'attendre la fin de son
      // animation de fermeture avant de reconstruire MaterialApp/Navigator.
      final navigator = Navigator.of(context);
      final dialogRoute = DialogRoute<Map<String, Object?>>(
        context: context,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refreshDialog) => AlertDialog(
            title: const Text('Réglages du suivi du poids'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: startController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Poids de départ (kg)',
                      hintText: 'Ex. 95,6',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Poids cible (kg)',
                      hintText: 'Ex. 90',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Date visée'),
                    subtitle: Text(_weightDateLabel(targetDate)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final proposed = targetDate ?? DateTime(2027, 3, 1);
                      final initial = proposed.isBefore(minDate)
                          ? minDate
                          : proposed.isAfter(maxDate)
                              ? maxDate
                              : proposed;
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateUtils.dateOnly(initial),
                        firstDate: minDate,
                        lastDate: maxDate,
                      );
                      if (picked != null) {
                        refreshDialog(() => targetDate = DateUtils.dateOnly(picked));
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ces réglages ne modifient pas l’historique de vos pesées.',
                    style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final startValue = double.tryParse(
                    startController.text.trim().replaceAll(',', '.'),
                  );
                  final targetValue = double.tryParse(
                    targetController.text.trim().replaceAll(',', '.'),
                  );
                  if (startValue == null || targetValue == null ||
                      !startValue.isFinite || !targetValue.isFinite ||
                      startValue < 30 || startValue > 300 ||
                      targetValue < 30 || targetValue > 300) {
                    _showFeedback('Saisissez deux poids valides, entre 30 et 300 kg.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(<String, Object?>{
                    'start': startValue,
                    'target': targetValue,
                    'date': targetDate,
                  });
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );

      final resultFuture = navigator.push(dialogRoute);
      final result = await resultFuture;
      await dialogRoute.completed;
      if (result == null || !mounted) return;

      final startValue = result['start'];
      final targetValue = result['target'];
      final savedTargetDate = result['date'];
      if (startValue is! double || targetValue is! double ||
          (savedTargetDate != null && savedTargetDate is! DateTime)) {
        return;
      }

      // La mutation globale intervient seulement une fois le dialogue retiré
      // de l'Overlay : le Navigator n'est jamais reconstruit pendant son pop.
      setState(() {
        _weightStartKg = startValue;
        _weightTargetKg = targetValue;
        _weightTargetDate = savedTargetDate as DateTime?;
      });
      _queueLocalStatePersist();
      _showFeedback('Réglages du poids enregistrés.');
    } finally {
      startController.dispose();
      targetController.dispose();
    }
  }

  Future<void> _addWeightEntry(BuildContext context) async {
    final controller = TextEditingController(
      text: _latestWeightKg.toStringAsFixed(1).replaceAll('.', ','),
    );
    DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

    try {
      final navigator = Navigator.of(context);
      final dialogRoute = DialogRoute<Map<String, Object?>>(
        context: context,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refreshDialog) => AlertDialog(
            title: const Text('Enregistrer une pesée'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Poids mesuré (kg)',
                      hintText: 'Ex. 95,2',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Date de la pesée'),
                    subtitle: Text(_weightDateLabel(selectedDate)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final today = DateUtils.dateOnly(DateTime.now());
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate.isAfter(today) ? today : selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: today,
                      );
                      if (picked != null) {
                        refreshDialog(() => selectedDate = DateUtils.dateOnly(picked));
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final value = double.tryParse(
                    controller.text.trim().replaceAll(',', '.'),
                  );
                  if (value == null || !value.isFinite || value < 30 || value > 300) {
                    _showFeedback('Saisissez un poids valide, entre 30 et 300 kg.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(<String, Object?>{
                    'kg': value,
                    'date': DateUtils.dateOnly(selectedDate),
                  });
                },
                icon: const Icon(Icons.check),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );

      final resultFuture = navigator.push(dialogRoute);
      final result = await resultFuture;
      await dialogRoute.completed;
      if (result == null || !mounted) return;

      final value = result['kg'];
      final recordedDate = result['date'];
      if (value is! double || recordedDate is! DateTime) return;

      // Une seule pesée par date : une nouvelle saisie remplace proprement
      // celle déjà enregistrée pour cette journée. Le dialogue est déjà fermé.
      setState(() {
        _weightEntries.removeWhere((entry) {
          final parsed = DateTime.tryParse('${entry['date']}');
          return parsed != null &&
              parsed.year == recordedDate.year &&
              parsed.month == recordedDate.month &&
              parsed.day == recordedDate.day;
        });
        _weightEntries.add({
          'date': recordedDate.toIso8601String(),
          'kg': value,
        });
        _weightEntries.sort((a, b) {
          final da = DateTime.tryParse('${a['date']}') ?? DateTime(2000);
          final db = DateTime.tryParse('${b['date']}') ?? DateTime(2000);
          return da.compareTo(db);
        });
      });
      _queueLocalStatePersist();
      _showFeedback('Pesée du ${_weightDateLabel(recordedDate)} enregistrée.');
    } finally {
      controller.dispose();
    }
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

    final completedGoals = goals.where(_goalIsSatisfied).length;
    final totalRewards = goals.fold<int>(0, (sum, goal) => sum + _goalRewardCount(goal));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: pageTitle('Objectifs', goals.isEmpty ? 'Une habitude concrète, une cible simple.' : '$completedGoals sur ${goals.length} atteint${goals.length > 1 ? 's' : ''} sur la période.')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Builder(
              // Le contexte du Builder est bien sous le Navigator de MaterialApp.
              builder: (screenContext) => _weightTrackingCard(screenContext),
            ),
          ),
        ),
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
            child: Builder(
              builder: (screenContext) => Row(
                children: [
                  Expanded(
                    child: Text(
                      goals.isEmpty ? 'Objectifs' : 'Objectifs · ${goals.length} actif${goals.length > 1 ? 's' : ''}',
                      style: _sectionTitleStyle(screenContext),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addOrEditGoal(context: screenContext),
                    icon: _uiIcon('add', Icons.add_circle_outline, size: 18),
                    label: const Text('Nouvel objectif'),
                  ),
                ],
              ),
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
                (context, index) => _goalCard(context, goals[index]),
                childCount: goals.length,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
            child: Row(
              children: [
                _uiIcon('streak', Icons.local_fire_department_outlined, size: 21, color: _colors.goldText),
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


class _WeightSparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  _WeightSparkline(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(min); final maxV = values.reduce(max);
    final range = max(.2, maxV - minV);
    final path = Path();
    for (var i=0;i<values.length;i++) {
      final x = size.width * i / (values.length - 1);
      final smooth = i == 0 ? values[i] : i == values.length-1 ? values[i] : (values[i-1]+values[i]+values[i+1])/3;
      final y = size.height - 5 - ((smooth-minV)/range) * (size.height-10);
      if (i==0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    canvas.drawPath(path, Paint()..color=color..strokeWidth=2.5..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
  }
  @override
  bool shouldRepaint(covariant _WeightSparkline old) => old.values != values || old.color != color;
}
