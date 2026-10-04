// V9.28 — Activités gelées + priorités du jour + bonus quotidien.
// Les priorités sont choisies par l'utilisateur (maximum 5) et cochées depuis
// un écran dédié. Le bonus quotidien est accordé une seule fois par jour si
// toutes les priorités choisies ont été réalisées.

part of '../main.dart';

const List<String> _automaticPriorityRewards = [
  'un bon café tranquille',
  'un épisode de ta série préférée',
  'une balade sans objectif',
  'un bon livre au calme',
  'un morceau de musique juste pour le plaisir',
  'un petit dessert plaisir',
  'un moment de détente rien qu’à toi',
  'une sortie improvisée',
  'un bon repas que tu aimes',
  'une sieste ou une vraie pause',
  'un film choisi sur un coup de cœur',
  'un après-midi sans contrainte',
];

String _randomPriorityReward() => _automaticPriorityRewards[Random().nextInt(_automaticPriorityRewards.length)];

extension _PrioritiesV928Part on _MaBelleSemaineAppState {
  String _priorityDateKey() {
    final d = _clockNow;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isDailyPriorityActivityId(String? activityId) =>
      activityId != null && _dailyPriorityActivityIds.contains(activityId);

  bool _planContainsPriorityToday(String activityId) => plan.any(
        (item) => item.day == today && item.activityId == activityId,
      );

  void _ensureDailyPrioritiesInTodayPlan() {
    if (!mounted) return;
    final selected = _dailyPriorityActivities();
    final missing = selected
        .where((activity) => !_planContainsPriorityToday(activity.id))
        .toList();
    if (missing.isEmpty) return;

    var seq = 0;
    setState(() {
      for (final activity in missing) {
        final done = _priorityActivityDoneToday(activity);
        plan.add(PlanItem(
          id: 'priority_${DateTime.now().microsecondsSinceEpoch}_$seq',
          day: today,
          period: activity.period,
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Priorité du jour — ajoutée automatiquement car elle n’était pas présente dans le planning.',
          duration: _isSportActivity(activity)
              ? _sportGenerationDuration(activity)
              : _learnedDurationForGeneration(activity),
          optional: false,
          userAdded: true,
          fixedInWeeklyTemplate: false,
          manualPlacement: true,
          done: done,
          realisedMinutes: done ? max(1, activity.duration) : null,
        ));
        seq++;
      }
      _sortPlan();
    });
    _queueLocalStatePersist();
    _showFeedback(
      missing.length == 1
          ? '⭐ Priorité ajoutée aux activités du jour.'
          : '⭐ ${missing.length} priorités ajoutées aux activités du jour.',
    );
  }

  List<Activity> _dailyPriorityActivities() {
    final selected = <Activity>[];
    for (final id in _dailyPriorityActivityIds) {
      final activity = findActivity(id);
      if (activity == null || activity.isFrozen || activity.isDateRange || activity.isSportProgram) continue;
      selected.add(activity);
    }
    selected.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return selected;
  }

  bool _priorityActivityDoneToday(Activity activity) {
    final key = _priorityDateKey();
    for (final log in logs) {
      final date = log.date;
      final logKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (logKey == key && log.activityId == activity.id && log.realisedMinutes > 0) return true;
    }
    for (final item in plan) {
      if (item.day != today || item.activityId != activity.id || !item.done) continue;
      return true;
    }
    return false;
  }

  bool get _priorityBonusWonToday =>
      _priorityBonusAwarded && _priorityBonusAwardedDateKey == _priorityDateKey();

  bool _priorityAllDoneToday(List<Activity> selected) =>
      selected.isNotEmpty && selected.every(_priorityActivityDoneToday);

  void _maybeAwardDailyPriorityBonus() {
    if (!mounted || _dailyPriorityActivityIds.isEmpty || _undoInProgress) return;
    final selected = _dailyPriorityActivities();
    if (!_priorityAllDoneToday(selected) || _priorityBonusWonToday) return;

    final dateKey = _priorityDateKey();
    final rewardBefore = _priorityBonusTotal ~/ 5;
    var generatedReward = '';
    setState(() {
      _priorityBonusAwardedDateKey = dateKey;
      _priorityBonusAwarded = true;
      _priorityBonusTotal += 1;
      final rewardAfterNow = _priorityBonusTotal ~/ 5;
      if (rewardAfterNow > rewardBefore) {
        generatedReward = _randomPriorityReward();
        _priorityRewardText = generatedReward;
      }
    });
    _persistLocalState(recordUndo: false);

    final rewardAfter = _priorityBonusTotal ~/ 5;
    if (rewardAfter > rewardBefore) {
      HapticFeedback.heavyImpact();
      _showFeedback('🎁 Récompense surprise : $generatedReward.');
    } else {
      HapticFeedback.mediumImpact();
      _showFeedback('⭐ Bonus du jour gagné !');
    }
  }

  Future<void> _togglePriorityToday(Activity activity) async {
    if (!mounted || activity.isFrozen) return;
    if (_priorityActivityDoneToday(activity)) {
      await _uncompletePriorityToday(activity);
      return;
    }

    _prepareUndoSnapshot();

    final todayItem = plan.where((item) =>
        item.day == today &&
        item.activityId == activity.id &&
        !item.done &&
        !_isDateRangePlanItem(item)).toList();

    if (todayItem.isNotEmpty) {
      final item = todayItem.first;
      if (_isSportActivity(activity)) {
        await _validateSportItemQuick(item, activity);
      } else {
        togglePlanItemDone(item, true);
      }
    } else if (_isSportActivity(activity)) {
      await _toggleSportActivityOnDayQuick(activity, today);
    } else {
      final now = DateTime.now();
      setState(() {
        logs.add(ActivityLog(
          date: now,
          title: activity.name,
          emoji: activity.emoji,
          category: activity.category,
          period: activity.period,
          day: today,
          plannedMinutes: max(1, activity.duration),
          realisedMinutes: max(1, activity.duration),
          feeling: 'Bien',
          unplanned: true,
          planItemId: null,
          activityId: activity.id,
        ));
      });
      _queueLocalStatePersist();
      _refreshGoalsAfterRealization();
      _showFeedback('✓ « ${activity.name} » comptée comme réalisée aujourd’hui.');
    }

    if (mounted) _maybeAwardDailyPriorityBonus();
  }

  Future<void> _uncompletePriorityToday(Activity activity) async {
    ActivityLog? latestLog;
    for (final log in logs) {
      if (log.activityId != activity.id) continue;
      final d = log.date;
      final current = DateTime.now();
      if (d.year != current.year || d.month != current.month || d.day != current.day) continue;
      if (latestLog == null || log.date.isAfter(latestLog.date)) latestLog = log;
    }

    if (latestLog?.planItemId != null) {
      final itemIndex = plan.indexWhere((item) => item.id == latestLog!.planItemId);
      if (itemIndex >= 0) {
        togglePlanItemDone(plan[itemIndex], false);
        return;
      }
    }

    if (latestLog != null && mounted) {
      _prepareUndoSnapshot();
      setState(() => logs.remove(latestLog));
      _queueLocalStatePersist();
      _showFeedback('Validation annulée pour « ${activity.name} ».');
    }
  }

  Future<void> _editDailyPriorities() async {
    if (!mounted) return;
    final currentIds = <String>{
      ..._dailyPriorityActivityIds.where((id) {
        final activity = findActivity(id);
        return activity != null && !activity.isFrozen && !activity.isDateRange && !activity.isSportProgram;
      }),
    };

    final candidates = activities
        .where((a) => !a.isFrozen && !a.isDateRange && !a.isSportProgram)
        .toList()
      ..sort((a, b) {
        final selectedCompare = (currentIds.contains(b.id) ? 0 : 1).compareTo(currentIds.contains(a.id) ? 0 : 1);
        if (selectedCompare != 0) return selectedCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final picked = await showModalBottomSheet<Set<String>>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final working = <String>{...currentIds};
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mes priorités du jour', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                  const SizedBox(height: 4),
                  Text('${working.length}/5 choisies · sélectionne les activités qui comptent particulièrement pour toi.', style: TextStyle(fontSize: 11.5, color: _colors.textMuted, height: 1.3)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: min(MediaQuery.of(context).size.height * .58, 520.0),
                    child: ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (_, index) {
                        final activity = candidates[index];
                        final selected = working.contains(activity.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(17),
                            onTap: () {
                              if (!selected && working.length >= 5) {
                                _showFeedback('Maximum 5 priorités pour garder la journée lisible.');
                                return;
                              }
                              setSheetState(() {
                                if (selected) {
                                  working.remove(activity.id);
                                } else {
                                  working.add(activity.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
                              decoration: BoxDecoration(
                                color: selected ? _colors.tintStrong : _colors.surfaceSoft,
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(color: selected ? _colors.borderTint : _colors.border),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(13)),
                                  alignment: Alignment.center,
                                  child: _activityIconWidget(activity.emoji, size: 24),
                                ),
                                const SizedBox(width: 9),
                                Expanded(child: Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _colors.textStrong))),
                                Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? _colors.accentIcon : _colors.textFaint, size: 22),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, working),
                      icon: _uiIcon('confirm', Icons.check_rounded, size: 18),
                      label: const Text('Enregistrer mes priorités'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) return;

    final previousIds = <String>{..._dailyPriorityActivityIds};
    final nextIds = <String>{...picked.take(5)};
    final changed = previousIds.length != nextIds.length || !previousIds.containsAll(nextIds);
    if (!changed) return;

    _prepareUndoSnapshot();
    setState(() {
      _dailyPriorityActivityIds
        ..clear()
        ..addAll(nextIds);

      // Si une priorité avait nécessité l'insertion automatique d'une
      // occurrence dans la journée, cette occurrence doit disparaître lorsque
      // la priorité est retirée. Les activités déjà présentes dans le
      // planning (manuel ou généré) ne sont jamais touchées.
      final removedPriorityIds = previousIds.difference(nextIds);
      if (removedPriorityIds.isNotEmpty) {
        plan.removeWhere((item) =>
            item.day == today &&
            removedPriorityIds.contains(item.activityId) &&
            item.id.startsWith('priority_'));
        _sortPlan();
      }
    });
    _queueLocalStatePersist();
    _ensureDailyPrioritiesInTodayPlan();
    _maybeAwardDailyPriorityBonus();
  }

  void _toggleActivityFrozen(Activity activity) {
    if (!mounted) return;
    _prepareUndoSnapshot();
    final freezing = !activity.isFrozen;
    var removedToday = 0;
    var removedFuture = 0;

    setState(() {
      activity.isFrozen = freezing;
      if (freezing) {
        _dailyPriorityActivityIds.remove(activity.id);

        final toRemove = plan.where((item) =>
            item.activityId == activity.id &&
            item.day >= today &&
            !item.done &&
            !_isDateRangePlanItem(item)).toList();
        removedToday = toRemove.where((item) => item.day == today).length;
        removedFuture = toRemove.where((item) => item.day > today).length;
        final removedIds = toRemove.map((item) => item.id).toSet();
        plan.removeWhere((item) => removedIds.contains(item.id));

        // Le gel est une décision du Coach à prendre en compte immédiatement :
        // on conserve une trace visible de l'ajustement, sans le traiter comme
        // un simple retrait manuel de planning.
        if (removedToday > 0) {
          final detail =
              '🧊 Aujourd’hui · ${activity.name} — activité gelée : $removedToday occurrence(s) prévue(s) retirée(s) du planning du jour. Le Coach n’en proposera pas de nouvelle tant qu’elle restera gelée.';
          _lastPlanningDecisionDetails = [
            detail,
            ..._lastPlanningDecisionDetails,
          ].take(30).toList();
          _lastPlanningCoachExplanation =
              'J’ai pris en compte le gel de « ${activity.name} » : $removedToday occurrence(s) prévue(s) aujourd’hui ont été retirée(s), sans remplacement automatique.';
        }
      }
      _sortPlan();
    });

    _queueLocalStatePersist();
    if (freezing) {
      final detail = removedToday > 0
          ? '🧊 « ${activity.name} » est gelée. $removedToday occurrence(s) d’aujourd’hui retirée(s) ; $removedFuture pour les jours suivants. Le Coach en tient compte.'
          : removedFuture > 0
              ? '🧊 « ${activity.name} » est gelée. $removedFuture occurrence(s) future(s) retirée(s). Le Coach en tient compte.'
              : '🧊 « ${activity.name} » est gelée. Elle reste disponible pour une reprise ultérieure.';
      _showFeedback(detail);
    } else {
      _showFeedback('🌱 « ${activity.name} » est de nouveau active. Elle pourra revenir lors d’une prochaine régénération.');
    }
  }

  void _applyFreezeTransitionFromEditor(Activity updated, Activity original) {
    if (!mounted || original.isFrozen == updated.isFrozen || !updated.isFrozen) return;
    var removedToday = 0;
    var removedFuture = 0;
    setState(() {
      final toRemove = plan.where((item) =>
          item.activityId == updated.id &&
          item.day >= today &&
          !item.done &&
          !_isDateRangePlanItem(item)).toList();
      removedToday = toRemove.where((item) => item.day == today).length;
      removedFuture = toRemove.where((item) => item.day > today).length;
      final removedIds = toRemove.map((item) => item.id).toSet();
      plan.removeWhere((item) => removedIds.contains(item.id));
      _dailyPriorityActivityIds.remove(updated.id);
      if (removedToday > 0) {
        final detail =
            '🧊 Aujourd’hui · ${updated.name} — activité gelée : $removedToday occurrence(s) prévue(s) retirée(s) du planning du jour. Le Coach n’en proposera pas de nouvelle tant qu’elle restera gelée.';
        _lastPlanningDecisionDetails = [detail, ..._lastPlanningDecisionDetails].take(30).toList();
        _lastPlanningCoachExplanation =
            'J’ai pris en compte le gel de « ${updated.name} » : $removedToday occurrence(s) prévue(s) aujourd’hui ont été retirée(s), sans remplacement automatique.';
      }
      _sortPlan();
    });
    if (removedToday > 0 || removedFuture > 0) {
      _showFeedback('🧊 « ${updated.name} » gelée : $removedToday aujourd’hui · $removedFuture à venir. Le Coach en tient compte.');
    }
  }

  Widget _priorityHeroCard(List<Activity> selected) {
    final doneCount = selected.where(_priorityActivityDoneToday).length;
    final allDone = _priorityAllDoneToday(selected);
    final progress = selected.isEmpty ? 0.0 : doneCount / selected.length;
    final remainingForReward = 5 - (_priorityBonusTotal % 5);
    final rewardLabel = _priorityBonusTotal > 0 && _priorityBonusTotal % 5 == 0
        ? 'Palier atteint · prochaine récompense dans 5 bonus'
        : 'Encore $remainingForReward bonus pour la prochaine récompense';

    return softCard(
      color: allDone ? _colors.tintStrong : _colors.peachBg,
      borderColor: allDone ? _colors.borderTint : _colors.goldBorder,
      radius: 25,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(17)),
            alignment: Alignment.center,
            child: Text(allDone ? '🎉' : '⭐', style: const TextStyle(fontSize: 27)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mes priorités du jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _colors.textStrong)),
            const SizedBox(height: 3),
            Text(
              selected.isEmpty
                  ? 'Choisis jusqu’à 5 activités importantes pour donner un petit fil conducteur à la journée.'
                  : _priorityBonusWonToday
                      ? 'Bravo : toutes tes priorités ont été réalisées aujourd’hui. Le bonus est gagné. ⭐'
                      : '$doneCount/${selected.length} réalisées aujourd’hui${allDone ? ' · bonus prêt' : ''}.',
              style: TextStyle(fontSize: 11.2, height: 1.32, color: _colors.accentIcon, fontWeight: FontWeight.w700),
            ),
          ])),
        ]),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: _colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(allDone ? const Color(0xFF79A989) : const Color(0xFFD7A564)),
            ),
          ),
        ],
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: Text('⭐ $_priorityBonusTotal bonus cumulés', style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.w900, color: _colors.accentIcon))),
          Text('🎁 $rewardLabel', style: TextStyle(fontSize: 9.8, fontWeight: FontWeight.w800, color: _colors.danger)),
        ]),
      ]),
    );
  }

  Widget _priorityActivityCard(Activity activity) {
    final done = _priorityActivityDoneToday(activity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _togglePriorityToday(activity),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
          decoration: BoxDecoration(
            color: done ? _colors.tintStrong : _colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: done ? _colors.borderTint : _colors.border),
            boxShadow: [BoxShadow(color: _colors.shadowSoft, blurRadius: 7, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: done ? _colors.tintStrong : _colors.surfaceSunken,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: _activityIconWidget(activity.emoji, size: 28),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w900, color: done ? _colors.accentIcon : _colors.textStrong, decoration: done ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 3),
              Text(done ? 'Réalisée aujourd’hui' : '${activity.category} · ${activity.duration} min', style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.w700, color: _colors.textMuted)),
            ])),
            const SizedBox(width: 7),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: done ? _colors.tintStrong : _colors.surfaceSunken, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(done ? Icons.check_rounded : Icons.circle_outlined, size: 25, color: done ? _colors.accentIcon : _colors.textFaint),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _frozenInfoCard() {
    final frozen = activities.where((a) => a.isFrozen).toList();
    if (frozen.isEmpty) return const SizedBox.shrink();
    return softCard(
      color: _colors.surfaceSunken,
      borderColor: _colors.borderStrong,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🧊', style: TextStyle(fontSize: 19)),
          const SizedBox(width: 7),
          Expanded(child: Text('Activités gelées', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _colors.textMuted))),
          Text('${frozen.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _colors.textMuted)),
        ]),
        const SizedBox(height: 5),
        Text('Elles restent dans ta bibliothèque, mais le coach ne les propose plus. Reprends-les depuis « Activités » quand le moment sera venu.', style: TextStyle(fontSize: 10.8, height: 1.3, color: _colors.textMuted)),
      ]),
    );
  }

  Widget buildPriorities() {
    final selected = _dailyPriorityActivities();
    if (_priorityAllDoneToday(selected) && !_priorityBonusWonToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAwardDailyPriorityBonus());
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Priorités', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                const SizedBox(height: 2),
                Text(dayNames[today], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _colors.textMuted)),
              ])),
              IconButton(
                tooltip: 'Choisir mes priorités',
                onPressed: _editDailyPriorities,
                icon: _uiIcon('insights', Icons.tune_rounded, size: 19),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          sliver: SliverToBoxAdapter(child: _priorityHeroCard(selected)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(child: Text('Ton petit défi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _colors.textStrong))),
              TextButton.icon(onPressed: _editDailyPriorities, icon: _uiIcon('edit', Icons.edit_rounded, size: 15), label: const Text('Choisir')),
            ]),
          ),
        ),
        if (selected.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            sliver: SliverToBoxAdapter(
              child: softCard(
                color: _colors.tintStrong,
                borderColor: _colors.borderTint,
                radius: 20,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🌱 Commence par 1 à 5 activités', style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w900, color: _colors.accentIcon)),
                  const SizedBox(height: 4),
                  Text('Ici, tu ne gères pas toute la semaine : tu choisis simplement ce qui compte le plus aujourd’hui.', style: TextStyle(fontSize: 10.8, height: 1.3, color: _colors.accentIcon)),
                  const SizedBox(height: 9),
                  FilledButton.icon(onPressed: _editDailyPriorities, icon: _uiIcon('priority', Icons.star_rounded, size: 17), label: const Text('Choisir mes priorités')),
                ]),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((_, index) => _priorityActivityCard(selected[index]), childCount: selected.length)),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          sliver: SliverToBoxAdapter(child: _frozenInfoCard()),
        ),
      ],
    );
  }
}
