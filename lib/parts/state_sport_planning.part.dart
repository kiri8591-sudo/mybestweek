// V8.91 — Gestion runtime Sport
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _SportRuntimePart on _MaBelleSemaineAppState {

  void _applyEditedSportActivityOccurrences(Activity activity) {
    if (!_isSportActivity(activity) || !activity.activeInSportRotation) return;

    final sportDays = _sportDays();
    if (sportDays.isEmpty) return;

    final desiredDaysCount = _sportTargetFrequency(activity).clamp(1, 7).toInt();
    final dailyTarget = _sportDailyOccurrenceLimit(activity);

    // Les jours préférés sont prioritaires. On complète ensuite avec les
    // autres jours Sport nécessaires pour atteindre la fréquence hebdomadaire.
    final preferredSportDays = activity.preferredDays
        .where((day) => sportDays.contains(day))
        .toList();
    final orderedDays = <int>[...
      preferredSportDays,
      ...sportDays.where((day) => !preferredSportDays.contains(day)),
    ];

    final targetDays = orderedDays.take(desiredDaysCount).toSet();

    // Si plusieurs occurrences/jour est désactivé, on ramène les occurrences
    // non réalisées à une seule. Une occurrence déjà réalisée est conservée.
    for (final day in sportDays) {
      final sameDay = _sportItemsForDayMutable(day)
          .where((item) => item.activityId == activity.id)
          .toList();
      if (!targetDays.contains(day) && sameDay.isEmpty) continue;
      if (targetDays.contains(day)) continue;
      final removable = [...sameDay]
        ..sort((a, b) => a.id.compareTo(b.id));
      while (removable.length > 1) {
        final candidate = removable.lastWhere(
          (item) => !item.done,
          orElse: () => removable.first,
        );
        if (candidate.done) break;
        plan.removeWhere((item) => item.id == candidate.id);
        removable.remove(candidate);
      }
    }

    for (final day in orderedDays) {
      if (!targetDays.contains(day)) continue;
      final budget = _sportBudgetForDay(day);
      if (budget <= 0) continue;

      var sameDay = _sportItemsForDayMutable(day)
          .where((item) => item.activityId == activity.id)
          .toList();

      // Une activité explicitement réglée plusieurs fois par jour doit être
      // visible autant de fois que demandé. La limite est quotidienne, sans
      // modifier la fréquence des jours.
      final wanted = dailyTarget;
      var needed = wanted - sameDay.length;
      if (needed <= 0) {
        if (!activity.allowMultiplePerDay && sameDay.length > 1) {
          for (final extra in sameDay.skip(1)) {
            if (!extra.done) plan.removeWhere((item) => item.id == extra.id);
          }
        }
        continue;
      }

      var used = _sportItemsForDayMutable(day)
          .fold<int>(0, (sum, item) => sum + item.duration);

      // On libère d'abord de la place dans les séances Sport non réalisées,
      // sans jamais supprimer une séance déjà validée ni une occurrence de
      // l'activité en cours d'édition.
      final removable = _sportItemsForDayMutable(day)
          .where((item) => !item.done && item.activityId != activity.id)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      for (final item in removable) {
        if (used + needed * activity.duration <= budget) break;
        plan.removeWhere((p) => p.id == item.id);
        used -= item.duration;
      }

      var seq = 0;
      while (needed > 0 && used + activity.duration <= budget) {
        plan.add(PlanItem(
          id: 'sport_edit_${activity.id}_${day}_${DateTime.now().microsecondsSinceEpoch}_$seq',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · occurrence configurée dans la fiche activité.',
          duration: activity.duration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        used += activity.duration;
        needed--;
        seq++;
      }
    }

    _sortPlan();
    setState(() {});
  }

  List<int> _futureSportDays() {
    return _sportDays().where((d) => d > today).toList()..sort();
  }

  int? _nextSportDay() {
    final future = _futureSportDays();
    if (future.isNotEmpty) return future.first;
    final all = _sportDays()..sort();
    for (final d in all) {
      if (d >= 0 && d < today) return d;
    }
    return null;
  }

  List<PlanItem> _sportItemsForDayMutable(int day) => plan.where((item) {
    if (item.day != day || item.activityId == null) return false;
    final activity = findActivity(item.activityId!);
    return activity != null && _isSportActivity(activity);
  }).toList();

  void _ensureReactivatedSportActivityInWeek(Activity activity) {
    if (!_isSportActivity(activity) || !activity.activeInSportRotation) return;

    final days = _sportDays().toSet().toList()..sort((a, b) {
      int distance(int day) => (day - today + 7) % 7;
      return distance(a).compareTo(distance(b));
    });
    if (days.isEmpty) return;

    if (plan.any((item) => item.activityId == activity.id && days.contains(item.day))) return;

    PlanItem? bestRemovalForDay(int day, List<PlanItem> items, int budget) {
      final removable = items.where((item) {
        if (item.done) return false;
        final other = item.activityId == null ? null : findActivity(item.activityId!);
        if (other == null || !_isSportActivity(other)) return false;
        return true;
      }).toList();
      if (removable.isEmpty) return null;
      removable.sort((a, b) {
        final aa = a.activityId == null ? null : findActivity(a.activityId!);
        final bb = b.activityId == null ? null : findActivity(b.activityId!);
        final sa = aa == null ? 0.0 : _sportRotationScore(aa, day, <String>{}, <String, int>{});
        final sb = bb == null ? 0.0 : _sportRotationScore(bb, day, <String>{}, <String, int>{});
        return sa.compareTo(sb);
      });
      return removable.first;
    }

    for (final day in days) {
      final budget = _sportBudgetForDay(day);
      if (budget <= 0) continue;

      final items = _sportItemsForDayMutable(day);
      final List<PlanItem> sameGroup = activity.sportGroup == null
          ? <PlanItem>[]
          : items.where((item) {
              if (item.activityId == null) return false;
              final other = findActivity(item.activityId!);
              return other != null && _isSportActivity(other) && other.sportGroup == activity.sportGroup;
            }).toList();

      // Une séance du même groupe est remplaçable uniquement si elle n'est pas réalisée.
      if (sameGroup.isNotEmpty && sameGroup.any((item) => item.done)) continue;
      if (sameGroup.isNotEmpty) {
        final replace = sameGroup.first;
        final usedWithoutReplace = items.fold<int>(0, (sum, item) => sum + (item.id == replace.id ? 0 : item.duration));
        if (usedWithoutReplace + activity.duration <= budget) {
          plan.removeWhere((item) => item.id == replace.id);
          plan.add(PlanItem(
            id: 'sport_reactivated_${DateTime.now().microsecondsSinceEpoch}_$day',
            day: day,
            period: _periodForActivity(activity, day),
            timeLabel: null,
            activityId: activity.id,
            title: activity.name,
            details: 'Sport · activité réactivée cette semaine.',
            duration: activity.duration,
            optional: false,
            userAdded: false,
            fixedInWeeklyTemplate: false,
          ));
          return;
        }
      }

      var used = items.fold<int>(0, (sum, item) => sum + item.duration);
      while (used + activity.duration > budget) {
        final removable = bestRemovalForDay(day, _sportItemsForDayMutable(day), budget);
        if (removable == null) break;
        used -= removable.duration;
        plan.removeWhere((item) => item.id == removable.id);
      }

      final nowItems = _sportItemsForDayMutable(day);
      final finalUsed = nowItems.fold<int>(0, (sum, item) => sum + item.duration);
      final groupConflict = activity.sportGroup != null && nowItems.any((item) {
        if (item.activityId == null) return false;
        final other = findActivity(item.activityId!);
        return other != null && _isSportActivity(other) && other.sportGroup == activity.sportGroup;
      });
      if (finalUsed + activity.duration <= budget && !groupConflict) {
        plan.add(PlanItem(
          id: 'sport_reactivated_${DateTime.now().microsecondsSinceEpoch}_$day',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · activité réactivée cette semaine.',
          duration: activity.duration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        return;
      }
    }
  }


  void _setSportDailyBudget(int day, int minutes) {
    final program = _sportProgram;
    if (program == null || day < 0 || day > 6) return;
    final safeMinutes = (minutes.clamp(0, 240) ~/ 5) * 5;
    final durations = <int, int>{...program.sportDailyDurations, day: safeMinutes};
    final updated = Activity(
      id: program.id,
      name: program.name,
      emoji: program.emoji,
      category: program.category,
      duration: program.duration,
      frequency: program.frequency,
      priority: program.priority,
      preferredDays: [...program.preferredDays],
      sportWeight: program.sportWeight,
      sportGroup: program.sportGroup,
      sportGroupFrequency: program.sportGroupFrequency,
      activeInSportRotation: program.activeInSportRotation,
      isSportProgram: true,
      sportDailyDurations: durations,
    );
    final index = activities.indexWhere((a) => a.id == program.id);
    if (index < 0) return;
    setState(() {
      activities[index] = updated;
      _refreshSportDay(day);
      _sortPlan();
    });
    _queueLocalStatePersist();
  }

  void _forceSportActivityOnPreferredDays(Activity activity) {
    if (!_isSportActivity(activity) || !activity.activeInSportRotation) return;
    if (!activity.allowMultiplePerDay) return;

    final sportDays = _sportDays().toSet();
    final targetDays = _sportTargetFrequency(activity).clamp(1, 7).toInt();
    final preferredDays = activity.preferredDays.where(sportDays.contains).toList()
      ..sort();
    final alreadyScheduledDays = plan
        .where((item) => item.activityId == activity.id && sportDays.contains(item.day))
        .map((item) => item.day)
        .toSet();

    final candidateDays = <int>[
      ...preferredDays.where((day) => !alreadyScheduledDays.contains(day)),
      ...sportDays.where((day) => !alreadyScheduledDays.contains(day)).toList()..sort(),
    ];

    var scheduledDays = alreadyScheduledDays.length;
    for (final day in candidateDays) {
      if (scheduledDays >= targetDays) break;

      final budget = _sportBudgetForDay(day);
      if (budget <= 0) continue;

      final targetOccurrences = _sportDailyOccurrenceLimit(activity);
      final existing = _sportItemsForDayMutable(day)
          .where((item) => item.activityId == activity.id)
          .toList();
      if (existing.length >= targetOccurrences) {
        scheduledDays++;
        continue;
      }

      var used = _sportItemsForDayMutable(day)
          .fold<int>(0, (sum, item) => sum + item.duration);
      var needed = targetOccurrences - existing.length;

      final removable = _sportItemsForDayMutable(day)
          .where((item) => !item.done && item.activityId != activity.id)
          .toList()
        ..sort((a, b) {
          final aa = a.activityId == null ? null : findActivity(a.activityId!);
          final bb = b.activityId == null ? null : findActivity(b.activityId!);
          final sa = aa == null ? 0.0 : _sportRotationScore(aa, day, <String>{}, <String, int>{});
          final sb = bb == null ? 0.0 : _sportRotationScore(bb, day, <String>{}, <String, int>{});
          return sa.compareTo(sb);
        });

      for (final item in removable) {
        if (used + needed * activity.duration <= budget) break;
        plan.removeWhere((p) => p.id == item.id);
        used -= item.duration;
      }

      var seq = 0;
      while (needed > 0 && used + activity.duration <= budget) {
        plan.add(PlanItem(
          id: 'sport_config_${activity.id}_${day}_${DateTime.now().microsecondsSinceEpoch}_$seq',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · occurrence configurée dans la fiche activité.',
          duration: activity.duration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        used += activity.duration;
        needed--;
        seq++;
      }

      final finalCount = _sportItemsForDayMutable(day)
          .where((item) => item.activityId == activity.id)
          .length;
      if (finalCount >= targetOccurrences) scheduledDays++;
    }
  }

  void _refreshSportDay(int day) {
    final budget = _sportBudgetForDay(day);
    final existing = _sportItemsForDayMutable(day);
    final completed = existing.where((item) => item.done).toList();
    plan.removeWhere((item) {
      if (item.day != day || item.activityId == null || item.done) return false;
      final activity = findActivity(item.activityId!);
      return activity != null && _isSportActivity(activity);
    });

    if (budget <= 0) return;
    final reserved = completed.fold<int>(0, (sum, item) => sum + item.duration);
    final availableBudget = max(0, budget - reserved);
    if (availableBudget <= 0) return;

    final candidates = activities.where((a) => _isSportActivity(a) && a.activeInSportRotation && !_manualDayBlocked(a, day)).toList();
    final generatedCount = <String, int>{};
    final remaining = <String, int>{};
    for (final a in candidates) {
      final key = _sportRotationKey(a);
      final existingCount = plan.where((p) {
        if (p.activityId == null) return false;
        final other = findActivity(p.activityId!);
        return other != null && _isSportActivity(other) && _sportRotationKey(other) == key;
      }).length;
      remaining[key] = max(0, _sportTargetFrequency(a) - existingCount);
      generatedCount[a.id] = 0;
    }

    final previousDayIds = completed.map((item) => item.activityId).whereType<String>().toSet();
    final selected = _chooseSportActivitiesForDay(
      day,
      availableBudget,
      candidates,
      remaining,
      generatedCount,
      previousDayIds,
    );
    var seq = 0;
    for (final activity in selected) {
      final used = _sportItemsForDayMutable(day).fold<int>(0, (sum, item) => sum + item.duration);
      if (used + activity.duration > budget) continue;
      plan.add(PlanItem(
        id: 'sport_${DateTime.now().microsecondsSinceEpoch}_${day}_$seq',
        day: day,
        period: 'Matin',
        timeLabel: null,
        activityId: activity.id,
        title: activity.name,
        details: 'Sport · budget ${budget} min ce jour · rotation selon historique.',
        duration: activity.duration,
        optional: false,
        userAdded: false,
        fixedInWeeklyTemplate: false,
      ));
      seq++;
    }
    _ensureSportMultipleOccurrencesForDay(day);
    _sortPlan();
  }

  int _sportDayTotalMinutes(int day) {
    return _sportItemsForDayMutable(day)
        .fold<int>(0, (sum, item) => sum + max(0, item.duration));
  }

  int _acceptedSportOverrunForDay(int day) {
    if (!_manualSportBudgetOverrideDays.contains(day)) return 0;
    final baseBudget = _sportBaseBudgetForDay(day);
    final total = _sportDayTotalMinutes(day);
    return max(0, total - baseBudget);
  }

  void _refreshSportBudgetCoachSuggestion() {
    final pending = <int, int>{};
    final overrideDays = _manualSportBudgetOverrideDays.toList()..sort();
    if (overrideDays.isEmpty) {
      sportCoachSuggestion = '';
      sportCoachSuggestionDelta = 0;
      _pendingSportCoachSuggestionDeltas = {};
      return;
    }

    // On mesure d'abord le déséquilibre encore non compensé par les budgets
    // déjà ajustés par le coach. Cela évite de reproposer deux fois la même
    // compensation après son application.
    var remainingIncrease = 0;
    for (final day in overrideDays) {
      final total = _sportDayTotalMinutes(day);
      final effectiveBudget = _sportBudgetForDay(day);
      final gap = max(0, total - effectiveBudget);
      if (gap > 0) {
        pending[day] = gap;
        remainingIncrease += gap;
      }
    }

    if (remainingIncrease <= 0) {
      sportCoachSuggestion = '';
      sportCoachSuggestionDelta = 0;
      _pendingSportCoachSuggestionDeltas = {};
      return;
    }

    // Les jours futurs sont privilégiés pour absorber la compensation. On
    // ne propose pas de réduire un jour lui-même dépassé manuellement.
    final candidates = <int>[..._sportDays().where((d) => !overrideDays.contains(d) && d > today)];
    for (final d in _sportDays().where((d) => !overrideDays.contains(d) && d <= today)) {
      if (!candidates.contains(d)) candidates.add(d);
    }

    var remainingReduction = remainingIncrease;
    for (final day in candidates) {
      if (remainingReduction <= 0) break;
      final currentBudget = _sportBudgetForDay(day);
      // Conserver au moins 10 min de budget sur un jour Sport lorsque cela
      // est possible. Les ajustements restent sur des pas de 5 minutes.
      final capacity = max(0, ((currentBudget - 10) ~/ 5) * 5);
      if (capacity <= 0) continue;
      final reduction = min(capacity, (remainingReduction ~/ 5) * 5);
      if (reduction <= 0) continue;
      pending[day] = (pending[day] ?? 0) - reduction;
      remainingReduction -= reduction;
    }

    _pendingSportCoachSuggestionDeltas = pending;
    sportCoachSuggestionDelta = remainingIncrease;

    final positiveLines = <String>[];
    final negativeLines = <String>[];
    for (final entry in pending.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      if (entry.value > 0) {
        positiveLines.add('${dayNames[entry.key]} +${entry.value} min');
      } else if (entry.value < 0) {
        negativeLines.add('${dayNames[entry.key]} ${entry.value} min');
      }
    }

    final parts = <String>[];
    if (positiveLines.isNotEmpty) parts.add('augmenter ${positiveLines.join(' · ')}');
    if (negativeLines.isNotEmpty) parts.add('réduire ${negativeLines.join(' · ')}');
    if (remainingReduction > 0) {
      parts.add('il reste $remainingReduction min non compensés faute de marge suffisante sur les autres jours');
    }
    sportCoachSuggestion = parts.isEmpty
        ? 'Le budget Sport reste dépassé de $remainingIncrease min.'
        : 'Dépassement Sport accepté : ${parts.join(' ; ')}.';
  }

  void _fitSportDayToBudget(int day) {
    final budget = _sportBudgetForDay(day);
    var items = _sportItemsForDayMutable(day)
        .where((item) => !item.manualPlacement && !item.fixedInWeeklyTemplate)
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    var total = _sportDayTotalMinutes(day);
    while (total > budget && items.isNotEmpty) {
      final removable = items.firstWhere((i) => !i.done, orElse: () => items.last);
      if (removable.done) break;
      total -= removable.duration;
      plan.removeWhere((p) => p.id == removable.id);
      items = _sportItemsForDayMutable(day)
          .where((item) => !item.manualPlacement && !item.fixedInWeeklyTemplate)
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
    }
  }

  void analyzeSportSession(PlanItem item, Activity activity) {
    if (!_isSportActivity(activity)) return;

    String message;
    String? adjustmentLabel;
    var delta = 0;

    if (item.feeling == 'Difficile') {
      delta = -10;
      message = 'J’ai analysé « ${activity.name} ». Le ressenti difficile justifie un peu plus de récupération.';
      adjustmentLabel = '−10 min sur le prochain jour Sport';
    } else if (item.feeling == 'Très bien') {
      message = 'J’ai analysé « ${activity.name} ». Le ressenti est très bon : je conserve le rythme prévu.';
    } else {
      message = 'J’ai analysé « ${activity.name} ». Rien ne justifie de changer le planning.';
    }

    final now = DateTime.now();
    setState(() {
      sportCoachLastAnalysis = message;
      sportCoachLastAnalysisAt = now;
      sportCoachSuggestion = adjustmentLabel ?? '';
      sportCoachSuggestionDelta = delta;
      sportCoachLogs.insert(0, SportCoachLog(
        date: now,
        activityName: activity.name,
        message: message,
        adjustment: adjustmentLabel,
      ));
      if (sportCoachLogs.length > 30) {
        sportCoachLogs = sportCoachLogs.take(30).toList();
      }
    });
    _refreshSportBudgetCoachSuggestion();
    _queueLocalStatePersist();
  }

  void applySportCoachSuggestion() {
    if (sportCoachSuggestion.isEmpty || _pendingSportCoachSuggestionDeltas.isEmpty) return;

    final deltas = Map<int, int>.from(_pendingSportCoachSuggestionDeltas);
    final applied = <String>[];
    setState(() {
      for (final entry in deltas.entries) {
        final day = entry.key;
        final delta = entry.value;
        if (delta == 0) continue;
        final baseAdjustment = sportCoachDailyAdjustments[day] ?? 0;
        sportCoachDailyAdjustments[day] = baseAdjustment + delta;
        _fitSportDayToBudget(day);
        applied.add('${dayNames[day]} ${delta > 0 ? '+' : ''}$delta min');
      }
      _pendingSportCoachSuggestionDeltas = {};
      sportCoachSuggestion = '';
      sportCoachSuggestionDelta = 0;
      _refreshSportBudgetCoachSuggestion();
      sportCoachLogs.insert(0, SportCoachLog(
        date: DateTime.now(),
        activityName: 'Ajustement du planning',
        message: 'Le coach Sport a rééquilibré la durée entre plusieurs jours.',
        adjustment: applied.join(' · '),
      ));
    });
    _queueLocalStatePersist();
    _showFeedback(applied.isEmpty ? 'Aucun ajustement appliqué.' : 'Coach Sport appliqué : ${applied.join(' · ')}.');
  }

  void openSportCoachJournal() {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SportCoachJournalSheet(logs: sportCoachLogs, dayNames: dayNames),
    );
  }

  String coachMessage() {
    if (logs.isEmpty) {
      return 'Pas encore assez de retours pour ajuster la semaine. Le planning reste simple et respirable.';
    }
    final recent = logs.where((l) => DateTime.now().difference(l.date).inDays < 7).toList();
    if (recent.isEmpty) {
      return 'Cette semaine repart tranquillement. Je garde le rythme prévu en attendant de nouveaux retours.';
    }
    final easy = recent.where((l) => l.feeling == 'Très bien' || l.feeling == 'Bien').length;
    final difficult = recent.where((l) => l.feeling == 'Difficile').length;
    if (difficult >= 2) {
      return 'J’ai repéré plusieurs moments difficiles. La prochaine semaine pourra être un peu plus légère et mieux espacée.';
    }
    if (easy >= 3) {
      return 'Le rythme semble bien passer. Je peux conserver les temps forts et garder de vraies plages de respiration.';
    }
    return 'J’ai regardé les derniers retours. Rien ne justifie pour l’instant de bouleverser la semaine.';
  }
}
