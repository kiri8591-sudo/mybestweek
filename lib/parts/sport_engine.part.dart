// V9.09 — Moteur Sport
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _SportEnginePart on _MaBelleSemaineAppState {
  Activity? get _sportProgram {
    for (final a in activities) {
      if (a.isSportProgram) return a;
    }
    return null;
  }

  bool _isSportActivity(Activity activity) =>
      activity.category.toLowerCase() == 'sport' && !activity.isSportProgram;

  String _sportRotationKey(Activity activity) =>
      activity.sportGroup == null ? activity.id : 'group:${activity.sportGroup}';

  int _sportTargetFrequency(Activity activity) =>
      activity.sportGroupFrequency ?? activity.frequency;

  int _currentWeekSportKeyRealisedCount(String key, List<Activity> source) {
    final start = _startOfCurrentWeek();
    final end = start.add(const Duration(days: 7));
    final ids = source.where((a) => _sportRotationKey(a) == key).map((a) => a.id).toSet();
    return logs.where((log) =>
        !log.date.isBefore(start) &&
        log.date.isBefore(end) &&
        log.activityId != null &&
        ids.contains(log.activityId)).length;
  }

  int _preservedFutureSportKeyCount(String key, List<Activity> source) {
    final ids = source.where((a) => _sportRotationKey(a) == key).map((a) => a.id).toSet();
    return plan.where((item) =>
        item.day > today &&
        ids.contains(item.activityId) &&
        (item.activityId == null || item.manualPlacement || item.fixedInWeeklyTemplate)).length;
  }

  bool _logMatchesActivity(ActivityLog log, Activity activity) {
    if (log.activityId != null) return log.activityId == activity.id;
    return log.title.trim().toLowerCase() == activity.name.trim().toLowerCase();
  }

  void _syncCompletedValidationDuration(PlanItem item) {
    if (!item.done) return;
    // Une durée réellement réalisée doit rester mémorisée, notamment pour le Sport,
    // même si la durée prévue de l'activité est ensuite modifiée.
    final realised = item.realisedMinutes ?? item.duration;
    item.realisedMinutes = realised;
    final index = logs.indexWhere((log) => log.planItemId == item.id);
    if (index < 0) return;
    final old = logs[index];
    logs[index] = ActivityLog(
      date: old.date,
      title: item.title,
      emoji: (old.activityId != null ? findActivity(old.activityId!)?.emoji : null) ?? old.emoji,
      category: old.category,
      period: item.period,
      day: item.day,
      plannedMinutes: item.duration,
      realisedMinutes: realised,
      feeling: _normalizeFeeling(old.feeling),
      unplanned: old.unplanned,
      planItemId: old.planItemId,
      activityId: old.activityId,
    );
  }

  void _setSportActivityRotation(Activity activity, bool active) {
    final index = activities.indexWhere((a) => a.id == activity.id);
    if (index < 0) return;
    final current = activities[index];
    final updated = Activity(
      id: current.id,
      name: current.name,
      emoji: current.emoji,
      category: current.category,
      duration: current.duration,
      frequency: current.frequency,
      priority: current.priority,
      preferredDays: [...current.preferredDays],
      isDateRange: current.isDateRange,
      rangeStart: current.rangeStart,
      rangeEnd: current.rangeEnd,
      sportWeight: current.sportWeight,
      allowMultiplePerDay: current.allowMultiplePerDay,
      maxDailyOccurrences: current.maxDailyOccurrences,
      sportGroup: current.sportGroup,
      sportGroupFrequency: current.sportGroupFrequency,
      activeInSportRotation: active,
      isSportProgram: current.isSportProgram,
      sportDailyDurations: {...current.sportDailyDurations},
    );
    setState(() {
      activities[index] = updated;
      if (!active) {
        // « Plus tard » retire uniquement les occurrences non réalisées de
        // cette semaine. L'historique des séances déjà réalisées est conservé.
        plan.removeWhere((item) => item.activityId == activity.id && !item.done);
        _sortPlan();
      } else {
        // Réactivation : l'activité redevient éligible à la rotation ET on
        // tente immédiatement de lui réserver une occurrence dans la semaine
        // courante. Les séances déjà réalisées restent totalement inchangées.
        _ensureReactivatedSportActivityInWeek(updated);
        _sortPlan();
      }
    });
    _queueLocalStatePersist();
    _showFeedback(active
        ? '✓ « ${current.name} » réactivée dans la rotation Sport.'
        : '⏸ « ${current.name} » mise de côté pour plus tard.');
  }

  void reactivateSportActivity(Activity activity) => _setSportActivityRotation(activity, true);
  void postponeSportActivity(Activity activity) => _setSportActivityRotation(activity, false);

  void openSportWeekOverview() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _SportWeekPage(
          dayNames: dayNames,
          getActivities: () => activities.where(_isSportActivity).toList(),
          getSportProgram: () => _sportProgram,
          getPlan: () => List<PlanItem>.from(plan),
          getLogs: () => List<ActivityLog>.from(logs),
          getSportDays: () => {..._sportDays(), ..._regeneratedSportBudgets.keys}.toSet(),
          getSportBudgets: () => {
            for (var day = 0; day < 7; day++) day: _sportBaseBudgetForDay(day),
          },
          onReactivate: reactivateSportActivity,
          onPostpone: postponeSportActivity,
          onOpenActivity: (activity) => addOrEditActivity(original: activity),
          onToggleDay: toggleSportActivityOnDay,
          onRemoveItem: _removePlanOccurrence,
          onAddSportActivity: _addSportActivityToDay,
          onSetBudget: _setSportDailyBudget,
        ),
      ),
    );
  }

  double _sportRotationScore(Activity activity, int day, Set<String> selectedToday,
      Map<String, int> generatedCount) {
    final now = DateTime.now();
    final recent14 = logs.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 0 && age < 14 && _logMatchesActivity(log, activity);
    }).toList();
    final recent30 = logs.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 0 && age < 30 && _logMatchesActivity(log, activity);
    }).toList();

    final last = recent30.isEmpty
        ? null
        : (recent30..sort((a, b) => b.date.compareTo(a.date))).first;
    final daysSinceLast = last == null ? 60 : now.difference(last.date).inDays;

    if (_generationShouldAvoid(activity)) return -1000000.0;
    var score = activity.sportWeight * 5.0;
    if (_generationRespectPriorities) score += activity.priority * 1.5;
    switch (_generationActivityRule(activity.id)) {
      case 'prioritize': score += 30.0; break;
      case 'more': score += 8.0; break;
      case 'less': score -= 6.0; break;
    }
    if (_generationRespectPreferredDays && activity.preferredDays.contains(day)) score += 8.0;

    if (_generationUseHistory) {
      // Rotation historique : ce qui vient d’être fait descend, ce qui n’est
      // pas sorti depuis longtemps remonte.
      score += min(daysSinceLast, 14) * 1.15;
      score -= recent14.length * 4.0;
      score -= recent14.where((l) => l.feeling == 'Difficile').length * 3.0;
      score += recent14.where((l) => l.feeling == 'Très bien').length * 0.8;
    }

    // Apprentissage personnel du Sport : à partir de 3 réalisations, le coach
    // apprend les jours où cette activité est réellement pratiquée et utilise
    // ce signal pour départager les jours disponibles. Il tient aussi compte
    // d'une tendance répétée de ressenti difficile/Très bien.
    if (_generationLearnHabits) {
      final profile = _activityLearning(activity);
      if (profile.hasEnoughData) {
        score += profile.dayShare(day) * 7.0;
        if (day == profile.bestDay && profile.bestDayShare >= .55) score += 2.5;
        if (profile.difficultRate >= .50) score -= 1.8;
        if (profile.veryGoodRate >= .50) score += 1.0;
        if (profile.recent7Count >= 2) score -= .8;
      }
    }

    // Évite de remettre deux jours de suite exactement la même activité.
    if (_generationAlternateActivities && selectedToday.contains(activity.id)) score -= 100.0;

    // Respecte aussi la fréquence propre de l’activité dans la semaine.
    score -= (generatedCount[activity.id] ?? 0) * 2.5;
    return score;
  }

  List<Activity> _chooseSportActivitiesForDay(
      int day, int budget, List<Activity> candidates,
      Map<String, int> remaining, Map<String, int> generatedCount,
      Set<String> previousDayIds) {
    if (budget <= 0 || candidates.isEmpty) return [];

    final available = candidates.where((a) =>
        a.activeInSportRotation &&
        !_manualDayBlocked(a, day) &&
        (remaining[_sportRotationKey(a)] ?? 0) > 0 &&
        _sportGenerationDuration(a) <= budget).toList();
    if (available.isEmpty) return [];

    // IMPORTANT : lorsqu'une activité est configurée « plusieurs fois par
    // jour », ce réglage devient une vraie demande du planning et pas
    // seulement un plafond pour le moteur de rotation. On réserve donc en
    // premier lieu le nombre d'occurrences demandé, si le budget et la
    // fréquence restante le permettent.
    final repeatCandidates = available.where((a) {
      final dailyCount = a.allowMultiplePerDay
          ? a.maxDailyOccurrences.clamp(2, 3).toInt()
          : 1;
      final weeklyRemaining = remaining[_sportRotationKey(a)] ?? 0;
      return dailyCount >= 2 &&
          weeklyRemaining > 0 &&
          _sportGenerationDuration(a) * dailyCount <= budget;
    }).toList();

    if (repeatCandidates.isNotEmpty) {
      repeatCandidates.sort((a, b) => _sportRotationScore(
            b, day, previousDayIds, generatedCount,
          ).compareTo(_sportRotationScore(
            a, day, previousDayIds, generatedCount,
          )));

      final repeated = repeatCandidates.first;
      final count = repeated.maxDailyOccurrences.clamp(2, 3).toInt();
      final selected = List<Activity>.filled(count, repeated);
      var usedMinutes = _sportGenerationDuration(repeated) * count;

      // On peut ensuite compléter le budget avec d'autres activités, mais
      // jamais ajouter une troisième occurrence lorsque l'utilisateur a
      // choisi 2, ni dépasser la fréquence hebdomadaire restante.
      final tempRemaining = <String, int>{...remaining};
      final repeatKey = _sportRotationKey(repeated);
      tempRemaining[repeatKey] = max(0, (tempRemaining[repeatKey] ?? 0) - 1);

      final fillerCandidates = available.where((a) {
        if (_sportRotationKey(a) == repeatKey) return false;
        return (tempRemaining[_sportRotationKey(a)] ?? 0) > 0 &&
            usedMinutes + _sportGenerationDuration(a) <= budget;
      }).toList();

      // Petit remplissage glouton : la priorité reste la variété et le score
      // du coach, sans remettre en cause la répétition explicitement demandée.
      fillerCandidates.sort((a, b) => _sportRotationScore(
            b, day, previousDayIds, generatedCount,
          ).compareTo(_sportRotationScore(
            a, day, previousDayIds, generatedCount,
          )));

      for (final activity in fillerCandidates) {
        final key = _sportRotationKey(activity);
        final remainingForKey = tempRemaining[key] ?? 0;
        if (remainingForKey <= 0 || usedMinutes + _sportGenerationDuration(activity) > budget) continue;
        selected.add(activity);
        usedMinutes += _sportGenerationDuration(activity);
        tempRemaining[key] = remainingForKey - 1;
      }
      return selected;
    }

    // Cas normal : rotation classique avec sac à dos. Les copies multiples
    // restent autorisées pour les activités qui le permettent, mais ce bloc
    // n'est utilisé que lorsqu'aucune répétition explicite n'est réservable.
    final expanded = <Activity>[];
    for (final activity in available) {
      final weeklyRemaining = remaining[_sportRotationKey(activity)] ?? 0;
      final dailyLimit = activity.allowMultiplePerDay
          ? activity.maxDailyOccurrences.clamp(2, 3).toInt()
          : 1;
      final copies = min(dailyLimit, weeklyRemaining);
      for (var i = 0; i < copies; i++) {
        expanded.add(activity);
      }
    }

    final dp = <int, _SportChoice>{
      0: const _SportChoice(minutes: 0, score: 0, activities: []),
    };

    for (final activity in expanded) {
      final activityScore = _sportRotationScore(
        activity, day, previousDayIds, generatedCount,
      );
      final snapshot = Map<int, _SportChoice>.from(dp);
      for (final entry in snapshot.entries) {
        final newMinutes = entry.key + _sportGenerationDuration(activity);
        if (newMinutes > budget) continue;
        final sameKey = entry.value.activities
            .where((a) => _sportRotationKey(a) == _sportRotationKey(activity))
            .toList();
        if (sameKey.isNotEmpty) {
          final sameActivityCount = sameKey.where((a) => a.id == activity.id).length;
          final dailyLimit = activity.allowMultiplePerDay
              ? activity.maxDailyOccurrences.clamp(2, 3).toInt()
              : 1;
          final canRepeat = activity.allowMultiplePerDay &&
              sameActivityCount < dailyLimit;
          if (!canRepeat) continue;
        }
        final choice = _SportChoice(
          minutes: newMinutes,
          score: entry.value.score + activityScore,
          activities: [...entry.value.activities, activity],
        );
        final current = dp[newMinutes];
        if (current == null || choice.score > current.score) {
          dp[newMinutes] = choice;
        }
      }
    }

    final choices = dp.values.where((c) => c.activities.isNotEmpty).toList();
    choices.sort((a, b) {
      if (a.minutes != b.minutes) return b.minutes.compareTo(a.minutes);
      return b.score.compareTo(a.score);
    });
    if (choices.isEmpty) return [];

    final selected = choices.first.activities.toList();
    selected.sort((a, b) => _sportRotationScore(
          b, day, <String>{}, generatedCount,
        ).compareTo(_sportRotationScore(
          a, day, <String>{}, generatedCount,
        )));
    return selected;
  }

  void _completeGeneratedSportRepeats(List<PlanItem> generated, int day, int budget) {
    final candidates = activities.where((a) =>
        _isSportActivity(a) && a.activeInSportRotation && a.allowMultiplePerDay).toList();
    for (final activity in candidates) {
      final sameDay = generated.where((item) =>
          item.day == day && item.activityId == activity.id).toList();
      if (sameDay.isEmpty) continue;
      final targetDaily = max(0, _sportDailyOccurrenceLimit(activity) - _manualRemovalCount(activity.id, day));
      var needed = targetDaily - sameDay.length;
      if (needed <= 0) continue;

      // Les occurrences d'une même journée sont indépendantes de la
      // fréquence/semaine : une activité réglée 2×/jour peut donc être
      // complétée ici même si le groupe a déjà atteint son quota de séances
      // hebdomadaire en nombre d'occurrences.

      var used = generated.where((item) => item.day == day)
          .fold<int>(0, (sum, item) => sum + item.duration);
      var seq = 0;
      final generationDuration = _sportGenerationDuration(activity);
      while (needed > 0 && used + generationDuration <= budget) {
        generated.add(PlanItem(
          id: 'sport_repeat_${DateTime.now().microsecondsSinceEpoch}_${day}_$seq',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · ${budget} min disponibles ce jour · occurrence supplémentaire demandée par ta fiche.',
          duration: generationDuration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        used += generationDuration;
        needed--;
        seq++;
      }
    }
  }

  int _sportDayCount() {
    final program = _sportProgram;
    if (program == null) return 0;
    final customDays = program.sportDailyDurations.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();
    if (customDays.isNotEmpty) return customDays.length;
    return program.frequency.clamp(1, 7).toInt();
  }

  List<int> _sportDays() {
    final program = _sportProgram;
    if (program == null) return [];
    final customDays = program.sportDailyDurations.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList()..sort();
    if (customDays.isNotEmpty) return customDays;

    final target = _sportDayCount();
    final preferred = program.preferredDays.where((d) => d >= 0 && d < 7).toList()..sort();
    final result = <int>[];
    for (final day in preferred) {
      if (result.length >= target) break;
      if (!result.contains(day)) result.add(day);
    }
    for (var day = 0; day < 7 && result.length < target; day++) {
      if (!result.contains(day)) result.add(day);
    }
    return result;
  }

  int _configuredSportBaseBudgetForDay(int day) {
    final program = _sportProgram;
    if (program == null) return 0;
    return program.sportDailyDurations.containsKey(day)
        ? max(0, program.sportDailyDurations[day] ?? 0)
        : (_sportDays().contains(day) ? max(1, program.duration) : 0);
  }

  int _sportBaseBudgetForDay(int day) {
    final regenerated = _regeneratedSportBudgets[day];
    if (regenerated != null) return regenerated;
    return _configuredSportBaseBudgetForDay(day);
  }

  int _sportBudgetForDay(int day) {
    return max(0, _sportBaseBudgetForDay(day) + (sportCoachDailyAdjustments[day] ?? 0));
  }

  int _fallbackRegeneratedSportBudget() {
    final program = _sportProgram;
    if (program == null) return 0;
    final positive = program.sportDailyDurations.values.where((v) => v > 0).toList();
    if (positive.isEmpty) return max(1, program.duration);
    final average = (positive.reduce((a, b) => a + b) / positive.length).round();
    return max(5, (average / 5).round() * 5);
  }

  List<int> _futureSportGenerationDays() {
    final future = <int>{..._sportDays().where((d) => d > today)};
    final targetDays = _sportDayCount();

    // Un jour Sport passé ne « consomme » la fréquence hebdomadaire que s’il
    // a réellement été réalisé. Un jour simplement planifié mais non fait
    // doit donc pouvoir être reporté sur un jour futur lors d’une régénération.
    final realisedPastSportDays = <int>{};
    for (var day = 0; day <= today; day++) {
      if (_sportItemsForDay(day).any((item) => item.done && (item.realisedMinutes ?? 0) > 0)) {
        realisedPastSportDays.add(day);
      }
    }

    final preservedFutureManualSportDays = <int>{
      for (final item in plan)
        if (item.day > today && (item.activityId == null || item.manualPlacement || item.fixedInWeeklyTemplate))
          if (item.activityId != null && _isSportPlanItem(item)) item.day,
    };

    var fulfilledDays = realisedPastSportDays.length + preservedFutureManualSportDays.length;
    var remaining = max(0, targetDays - fulfilledDays);
    if (remaining <= future.length) {
      return future.toList()..sort();
    }

    final allFuture = List<int>.generate(7 - (today + 1), (i) => today + 1 + i);
    final fallbackBudget = _fallbackRegeneratedSportBudget();
    for (final day in allFuture) {
      if (remaining <= future.length) break;
      if (future.contains(day) || preservedFutureManualSportDays.contains(day)) continue;
      if (fallbackBudget <= 0) break;
      future.add(day);
      _regeneratedSportBudgets[day] = fallbackBudget;
      remaining--;
    }

    // Sécurité : s'il reste une séance à reporter et qu'aucun jour futur
    // n'était configuré, le prochain jour disponible devient un jour Sport
    // exceptionnel pour cette semaine uniquement.
    if (future.isEmpty && remaining > 0 && fallbackBudget > 0 && today < 6) {
      final nextDay = today + 1;
      future.add(nextDay);
      _regeneratedSportBudgets[nextDay] = fallbackBudget;
    }

    return future.toList()..sort();
  }

  int _sportDailyOccurrenceLimit(Activity activity) {
    if (!activity.allowMultiplePerDay) return 1;
    return activity.maxDailyOccurrences.clamp(2, 3).toInt();
  }

  void _ensureSportMultipleOccurrencesForDay(int day) {
    final budget = _sportBudgetForDay(day);
    if (budget <= 0) return;

    // Une occurrence déjà présente est le signal que cette activité a été
    // retenue pour ce jour. On complète alors jusqu'au nombre demandé dans
    // la fiche (« plusieurs fois par jour »), sans créer spontanément une
    // activité qui n'avait pas été choisie.
    final sportCandidates = activities.where((a) =>
        _isSportActivity(a) && a.activeInSportRotation && a.allowMultiplePerDay).toList();

    for (final activity in sportCandidates) {
      final sameDay = _sportItemsForDayMutable(day)
          .where((item) => item.activityId == activity.id)
          .toList();
      if (sameDay.isEmpty) continue;

      final targetDaily = max(0, _sportDailyOccurrenceLimit(activity) - _manualRemovalCount(activity.id, day));
      var needed = targetDaily - sameDay.length;
      if (needed <= 0) continue;

      // La fréquence/semaine représente les jours où l’activité peut être
      // proposée. Le nombre d’occurrences dans une journée est indépendant.
      // Une première occurrence déjà présente suffit donc pour compléter
      // jusqu’au nombre configuré, sans être bloqué par le compteur semaine.

      var used = _sportItemsForDayMutable(day)
          .fold<int>(0, (sum, item) => sum + item.duration);
      final generationDuration = _sportGenerationDuration(activity);
      var seq = 0;
      while (needed > 0 && used + generationDuration <= budget) {
        plan.add(PlanItem(
          id: 'sport_repeat_${DateTime.now().microsecondsSinceEpoch}_${day}_$seq',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · ${budget} min disponibles ce jour · occurrence supplémentaire demandée.',
          duration: generationDuration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        used += generationDuration;
        needed--;
        seq++;
      }
    }
  }

  void _normalizeSportDailyOccurrences() {
    // Met à niveau un planning déjà enregistré après changement de version
    // ou restauration, pour compléter les occurrences configurées par jour.
    for (final day in _sportDays()) {
      _ensureSportMultipleOccurrencesForDay(day);
    }
    _sortPlan();
  }

  void _generateSportPart(List<PlanItem> generated, int seqStart,
      {int startDay = 0, List<String>? decisionDetails}) {
    final sportActivities = activities
        .where((a) => _isSportActivity(a) && a.activeInSportRotation && !_generationShouldAvoid(a))
        .toList();
    if (sportActivities.isEmpty || _sportProgram == null) return;

    final days = _futureSportGenerationDays();
    final generatedCount = <String, int>{for (final a in sportActivities) a.id: 0};
    var seq = seqStart;
    Set<String> previousDayIds = {};

    final compositeActivities = sportActivities.toList();
    final remaining = <String, int>{};
    for (final activity in compositeActivities) {
      final key = _sportRotationKey(activity);
      if (remaining.containsKey(key)) continue;
      final group = compositeActivities.where((a) => _sportRotationKey(a) == key).toList();
      final target = group.map(_effectiveGenerationFrequency).reduce(max);
      final realised = _currentWeekSportKeyRealisedCount(key, group);
      final protectedFuture = _preservedFutureSportKeyCount(key, group);
      remaining[key] = max(0, target - realised - protectedFuture);
    }

    for (final day in days.where((d) => d >= startDay)) {
      final budget = _sportBudgetForDay(day);
      if (budget <= 0) continue;
      final manualSportIdsOnDay = plan.where((p) =>
          p.day == day && p.activityId != null && _isSportPlanItem(p) &&
          (p.manualPlacement || p.fixedInWeeklyTemplate)).map((p) => p.activityId!).toSet();
      final dayCandidates = compositeActivities.where((a) =>
          !_manualDayBlocked(a, day) && !manualSportIdsOnDay.contains(a.id)).toList();
      final selected = _chooseSportActivitiesForDay(
        day, budget, dayCandidates, remaining, generatedCount, previousDayIds,
      );
      final selectedIds = selected.map((a) => a.id).toSet();
      var usedMinutes = 0;
      for (final activity in selected) {
        final generationDuration = _sportGenerationDuration(activity);
        if (usedMinutes + generationDuration > budget) continue;
        final decisionReason = _sportDecisionReason(activity, day, budget, selectedIds);
        generated.add(PlanItem(
          id: 'sport_${DateTime.now().microsecondsSinceEpoch}_$seq',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Coach : $decisionReason',
          duration: generationDuration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        usedMinutes += generationDuration;
        generatedCount[activity.id] = (generatedCount[activity.id] ?? 0) + 1;
        if (decisionDetails != null && decisionDetails.length < 30) {
          decisionDetails.add(_sportDecisionReason(activity, day, budget, selectedIds));
        }
        seq++;
      }

      for (final activity in selected.toSet()) {
        final key = _sportRotationKey(activity);
        remaining[key] = max(0, (remaining[key] ?? 0) - 1);
      }

      _completeGeneratedSportRepeats(generated, day, budget);
      previousDayIds = selectedIds;
    }
  }

}
