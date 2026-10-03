// V9.24 — Validation et complétion des activités
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _PlanCompletionPart on _MaBelleSemaineAppState {
  void togglePlanItemDone(PlanItem item, bool checked) {
    if (_isDateRangePlanItem(item)) {
      _showFeedback('Une activité sur plusieurs jours ne se valide pas.');
      return;
    }
    _prepareUndoSnapshot();
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    if (checked && activity != null && _isSportActivity(activity)) {
      _validateSportItemQuick(item, activity);
      return;
    }
    if (!checked) {
      setState(() {
        item.done = false;
        item.realisedMinutes = null;
        item.feeling = null;
        logs.removeWhere((log) => log.planItemId == item.id);
        if (item.day == today) dailySummaries.removeWhere((summary) => summary.dateKey == _todayDateKey());
      });
      _queueLocalStatePersist();
      _showFeedback('Validation annulée pour « ${item.title} ».');
      return;
    }

    final now = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() {
      item.done = true;
      item.realisedMinutes = item.duration;
      item.feeling = 'Bien';
      logs.removeWhere((log) => log.planItemId == item.id);
      logs.add(ActivityLog(
        date: now,
        title: item.title,
        emoji: activity?.emoji ?? item.customEmoji ?? '📍',
        category: activity?.category ?? item.customCategory ?? 'Autre',
        period: item.period,
        day: item.day,
        plannedMinutes: item.duration,
        realisedMinutes: item.duration,
        feeling: 'Bien',
        unplanned: item.activityId == null,
        planItemId: item.id,
        activityId: item.activityId,
      ));
    });
    if (activity != null && _isSportActivity(activity)) analyzeSportSession(item, activity);
    if (_todayIsCompleted()) _upsertTodayDailySummary(persist: false);
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _maybeAwardDailyPriorityBonus();
    _showFeedback('✓ « ${item.title} » validé.');
  }

  Future<int?> _askSportRealisedMinutes(PlanItem item, Activity activity) async {
    return showModalBottomSheet<int>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SportRealisedMinutesSheet(
        activityName: activity.name,
        plannedMinutes: max(1, item.duration),
      ),
    );
  }

  Future<void> _validateSportItemQuick(PlanItem item, Activity activity) async {
    if (!mounted || item.done) return;
    if (_sportValidationInProgress.contains(item.id)) return;
    _sportValidationInProgress.add(item.id);
    try {
      // Geste principal iPhone : une simple coche signifie « réalisé comme prévu ».
      // Un léger retour haptique rend le geste perceptible sur iPhone sans
      // ajouter une étape d’interface.
      await HapticFeedback.selectionClick();
      _completePlanItem(item, activity, item.duration);
    } catch (_) {
      if (mounted) _showFeedback('Impossible d’enregistrer cette validation.');
    } finally {
      _sportValidationInProgress.remove(item.id);
    }
  }

  Future<void> _editSportRealisedMinutes(PlanItem item, Activity activity) async {
    if (!mounted) return;
    if (_sportValidationInProgress.contains(item.id)) return;
    _sportValidationInProgress.add(item.id);
    try {
      final realised = await _askSportRealisedMinutes(item, activity);
      if (realised == null || !mounted) return;
      final actual = max(1, realised);
      if (!item.done) {
        _completePlanItem(item, activity, actual);
        return;
      }
      setState(() {
        item.realisedMinutes = actual;
        final matchingLogs = logs.where((log) => log.planItemId == item.id).toList();
        if (matchingLogs.isEmpty) {
          logs.add(ActivityLog(
            date: DateTime.now(),
            title: item.title,
            emoji: activity.emoji,
            category: activity.category,
            period: item.period,
            day: item.day,
            plannedMinutes: item.duration,
            realisedMinutes: actual,
            feeling: item.feeling ?? 'Bien',
            unplanned: false,
            planItemId: item.id,
            activityId: activity.id,
          ));
        } else {
          for (final log in matchingLogs) {
            final index = logs.indexOf(log);
            if (index < 0) continue;
            logs[index] = ActivityLog(
              date: log.date,
              title: log.title,
              emoji: log.emoji,
              category: log.category,
              period: log.period,
              day: log.day,
              plannedMinutes: item.duration,
              realisedMinutes: actual,
              feeling: log.feeling,
              unplanned: log.unplanned,
              planItemId: log.planItemId,
              activityId: log.activityId,
            );
          }
        }
      });
      if (item.day == today) _upsertTodayDailySummary(persist: false);
      _queueLocalStatePersist();
      _refreshGoalsAfterRealization();
      _showFeedback('✓ Temps réalisé mis à jour : $actual min.');
    } catch (_) {
      if (mounted) _showFeedback('Impossible d’enregistrer cette durée.');
    } finally {
      _sportValidationInProgress.remove(item.id);
    }
  }

  void _completePlanItem(PlanItem item, Activity activity, [int? realisedMinutes]) {
    if (!mounted || item.done) return;
    final now = DateTime.now();
    final actual = max(1, realisedMinutes ?? item.duration);

    // Une seule mise à jour d’état pour la validation Sport : on évite un
    // second setState immédiat dans le coach, qui pouvait provoquer un écran
    // d’erreur dans certaines séquences de fermeture du bottom-sheet iPhone.
    String coachMessage = 'J’ai analysé « ${activity.name} ». Rien ne justifie de changer le planning.';
    String coachAdjustment = '';
    var coachDelta = 0;
    if (_isSportActivity(activity)) {
      // La validation rapide utilise volontairement le ressenti « Bien ».
      // Le réglage du coach reste neutre ; un ressenti différent pourra être
      // renseigné ensuite depuis la fiche de l’activité.
      coachMessage = 'J’ai analysé « ${activity.name} ». Rien ne justifie de changer le planning.';
    }

    setState(() {
      item.done = true;
      item.realisedMinutes = actual;
      item.feeling = 'Bien';
      logs.removeWhere((log) => log.planItemId == item.id);
      logs.add(ActivityLog(
        date: now,
        title: item.title,
        emoji: activity.emoji,
        category: activity.category,
        period: item.period,
        day: item.day,
        plannedMinutes: item.duration,
        realisedMinutes: actual,
        feeling: 'Bien',
        unplanned: false,
        planItemId: item.id,
        activityId: item.activityId,
      ));
      if (_isSportActivity(activity)) {
        sportCoachLastAnalysis = coachMessage;
        sportCoachLastAnalysisAt = now;
        sportCoachSuggestion = coachAdjustment;
        sportCoachSuggestionDelta = coachDelta;
        sportCoachLogs.insert(0, SportCoachLog(
          date: now,
          activityName: activity.name,
          message: coachMessage,
          adjustment: coachAdjustment.isEmpty ? null : coachAdjustment,
        ));
        if (sportCoachLogs.length > 30) {
          sportCoachLogs = sportCoachLogs.take(30).toList();
        }
      }
    });

    if (_todayIsCompleted()) _upsertTodayDailySummary(persist: false);
    _persistLocalState();
    _refreshGoalsAfterRealization();
    _maybeAwardDailyPriorityBonus();
    _showFeedback('✓ « ${item.title} » validé · $actual min réalisés.');
  }

}
