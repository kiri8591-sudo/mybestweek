// V12.11.0 — Saisie du temps réellement vécu (activités non-Sport) :
// depuis la semaine (« Temps réalisé ») et depuis l'Historique (modifier / ajouter),
// pour que les statistiques de durée reflètent le réel et non la durée prévue.

part of '../main.dart';

extension _TimeEditingPart on _MaBelleSemaineAppState {
  Future<int?> _askMinutes({required String name, required int planned, int? current, bool allowDelete = false}) {
    return showModalBottomSheet<int>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SportRealisedMinutesSheet(
        activityName: name,
        plannedMinutes: max(1, planned),
        currentMinutes: current,
        allowDelete: allowDelete,
      ),
    );
  }

  ActivityLog _logWithMinutes(ActivityLog log, int actual) => ActivityLog(
        date: log.date,
        title: log.title,
        emoji: log.emoji,
        category: log.category,
        period: log.period,
        day: log.day,
        plannedMinutes: log.plannedMinutes,
        realisedMinutes: actual,
        feeling: log.feeling,
        unplanned: log.unplanned,
        planItemId: log.planItemId,
        activityId: log.activityId,
      );

  /// Applique un temps réalisé à un moment déjà validé (moment + ligne de journal).
  void _applyRealisedMinutes(PlanItem item, int actual) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    setState(() {
      item.realisedMinutes = actual;
      final matching = logs.where((l) => l.planItemId == item.id).toList();
      if (matching.isEmpty) {
        logs.add(ActivityLog(
          date: _historyDateForPlanItem(item, DateTime.now()),
          title: item.title,
          emoji: activity?.emoji ?? item.customEmoji ?? '📍',
          category: activity?.category ?? item.customCategory ?? 'Autre',
          period: item.period,
          day: item.day,
          plannedMinutes: item.duration,
          realisedMinutes: actual,
          feeling: item.feeling ?? 'Bien',
          unplanned: item.activityId == null,
          planItemId: item.id,
          activityId: item.activityId,
        ));
      } else {
        for (final log in matching) {
          final index = logs.indexOf(log);
          if (index >= 0) logs[index] = _logWithMinutes(log, actual);
        }
      }
    });
    if (item.day == today) _upsertTodayDailySummary(persist: false);
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
  }

  /// Semaine : saisir ou corriger le temps réellement passé sur un moment.
  /// Si le moment n'est pas encore validé, il l'est avec ce temps.
  Future<void> editItemRealisedMinutes(PlanItem item) async {
    if (!mounted) return;
    final current = item.done ? (item.realisedMinutes ?? item.duration) : null;
    final minutes = await _askMinutes(name: item.title, planned: item.duration, current: current);
    if (minutes == null || !mounted) return;
    final actual = max(1, minutes);
    if (!item.done) {
      togglePlanItemDone(item, true);
      if (!item.done) return;
    }
    _applyRealisedMinutes(item, actual);
    _showFeedback('✓ Temps réalisé : $actual min.');
  }

  /// Saisir ou corriger le temps vécu d'une activité (Sport ou non) un jour donné.
  Future<void> editActivityMinutesOnDate(Activity activity, DateTime date) async {
    if (!mounted) return;
    final day = date.weekday - 1;
    final isSport = _isSportActivity(activity) || activity.isSportProgram;
    final currentWeek = _sameDateOnlyNonSport(date, _addDays(_startOfCurrentWeek(), day));
    if (currentWeek) {
      final items = plan.where((p) => p.activityId == activity.id && p.day == day).toList();
      if (items.isNotEmpty) {
        if (isSport) {
          await _editSportRealisedMinutes(items.first, activity);
        } else {
          await editItemRealisedMinutes(items.first);
        }
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
    final minutes = await _askMinutes(name: activity.name, planned: activity.duration);
    if (minutes == null || !mounted) return;
    final actual = max(1, minutes);
    _recordRealisationOnDate(activity, date, actual);
    _showFeedback('✓ ${activity.name} : $actual min enregistrées.');
  }

  /// Priorités, accueil : temps du jour d'une activité (crée le moment si besoin).
  Future<void> editActivityMinutesToday(Activity activity) async {
    if (!mounted) return;
    var items = plan.where((p) => p.day == today && p.activityId == activity.id).toList();
    if (items.isEmpty) {
      _ensureDailyPrioritiesInTodayPlan();
      items = plan.where((p) => p.day == today && p.activityId == activity.id).toList();
    }
    final now = DateTime.now();
    if (items.isEmpty) {
      await editActivityMinutesOnDate(activity, DateTime(now.year, now.month, now.day));
      return;
    }
    if (_isSportActivity(activity) || activity.isSportProgram) {
      await _editSportRealisedMinutes(items.first, activity);
    } else {
      await editItemRealisedMinutes(items.first);
    }
  }

  /// Historique : corriger la durée d'une réalisation ; 0 minute la supprime.
  Future<void> editHistoryLogMinutes(ActivityLog log) async {
    if (!mounted || logs.indexOf(log) < 0) return;
    final minutes = await _askMinutes(
      name: log.title,
      planned: log.plannedMinutes > 0 ? log.plannedMinutes : max(1, log.realisedMinutes),
      current: log.realisedMinutes,
      allowDelete: true,
    );
    if (minutes == null || !mounted) return;
    if (minutes <= 0) {
      _deleteHistoryLog(log);
      return;
    }
    final index = logs.indexOf(log);
    if (index < 0) return;
    setState(() {
      logs[index] = _logWithMinutes(log, minutes);
      final planId = log.planItemId;
      if (planId != null) {
        for (final p in plan) {
          if (p.id == planId && p.done) p.realisedMinutes = minutes;
        }
      }
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ Temps mis à jour : $minutes min.');
  }

  /// Supprime une réalisation de l'historique et remet à jour le moment du planning lié.
  void _deleteHistoryLog(ActivityLog log) {
    _prepareUndoSnapshot();
    final day = log.date.weekday - 1;
    final inCurrentWeek = _sameDateOnlyNonSport(log.date, _addDays(_startOfCurrentWeek(), day));
    setState(() {
      logs.remove(log);
      PlanItem? linked;
      final planId = log.planItemId;
      if (planId != null) {
        for (final p in plan) {
          if (p.id == planId) linked = p;
        }
      }
      if (linked == null && inCurrentWeek && log.activityId != null) {
        // Anciennes validations sans lien : on retrouve le moment validé du même jour.
        for (final p in plan) {
          if (p.done && p.activityId == log.activityId && p.day == day && !logs.any((l) => l.planItemId == p.id)) {
            linked = p;
            break;
          }
        }
      }
      final target = linked;
      if (target != null) {
        if (target.id.startsWith('history_') || target.id.startsWith('extra_')) {
          plan.removeWhere((p) => p.id == target.id);
        } else {
          target.done = false;
          target.realisedMinutes = null;
          target.feeling = null;
        }
        _sortPlan();
      }
      if (inCurrentWeek && day == today) dailySummaries.removeWhere((summary) => summary.dateKey == _todayDateKey());
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('🗑️ Réalisation supprimée de l’historique : « ${log.title} ».');
  }

  /// Enregistre une réalisation à une date donnée et met à jour le planning de ce jour
  /// (semaine en cours : le moment prévu est validé, ou un moment validé est créé).
  void _recordRealisationOnDate(Activity activity, DateTime date, int actual) {
    final day = date.weekday - 1;
    final currentWeek = _sameDateOnlyNonSport(date, _addDays(_startOfCurrentWeek(), day));
    _prepareUndoSnapshot();
    setState(() {
      String? planItemId;
      var planned = 0;
      if (currentWeek) {
        PlanItem? target;
        for (final p in plan) {
          if (p.activityId == activity.id && p.day == day && !p.done && !_isDateRangePlanItem(p)) {
            target = p;
            break;
          }
        }
        if (target != null) {
          target.done = true;
          target.realisedMinutes = actual;
          target.feeling = 'Bien';
          planItemId = target.id;
          planned = target.duration;
        } else {
          final item = PlanItem(
            id: 'history_${activity.id}_${DateTime.now().microsecondsSinceEpoch}',
            day: day,
            period: _generationPeriod(activity, day),
            timeLabel: null,
            title: activity.name,
            details: 'Réalisation ajoutée depuis l’historique.',
            activityId: activity.id,
            duration: max(1, activity.duration),
            optional: false,
            userAdded: true,
            fixedInWeeklyTemplate: false,
            manualPlacement: true,
            done: true,
            realisedMinutes: actual,
            feeling: 'Bien',
          );
          plan.add(item);
          planItemId = item.id;
          _sortPlan();
        }
      }
      logs.add(ActivityLog(
        date: DateTime(date.year, date.month, date.day, 12),
        title: activity.name,
        emoji: activity.emoji,
        category: activity.category,
        period: _periodForActivity(activity, day),
        day: day,
        plannedMinutes: planned,
        realisedMinutes: actual,
        feeling: 'Bien',
        unplanned: planned == 0,
        planItemId: planItemId,
        activityId: activity.id,
      ));
    });
    if (currentWeek && day == today && _todayIsCompleted()) _upsertTodayDailySummary(persist: false);
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _maybeAwardDailyPriorityBonus();
  }

  /// Historique : ajouter après coup une réalisation (activité, jour, durée).
  Future<void> addHistoryLog() async {
    if (!mounted) return;
    final candidates = activities.where((a) => !a.isSportProgram && !a.isDateRange).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (candidates.isEmpty) {
      _showFeedback('Aucune activité disponible.');
      return;
    }
    final picked = await showModalBottomSheet<Activity>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .72),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: _SheetHeader(
                  leading: _uiIcon('add', Icons.add_circle_outline, size: 24, color: _colors.accentIcon),
                  title: 'Quelle activité ?',
                  subtitle: '${candidates.length} activités, Sport compris.',
                ),
              ),
              for (final group in [
                ('Sport', candidates.where((a) => _isSportActivity(a)).toList()),
                ('Autres activités', candidates.where((a) => !_isSportActivity(a)).toList()),
              ])
                if (group.$2.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text('${group.$1} · ${group.$2.length}', style: _sectionTitleStyle(sheetContext)),
                  ),
                  for (final a in group.$2)
                    _SheetPickRow(
                      leading: _activityIconWidget(a.emoji, size: 24),
                      title: a.name,
                      subtitle: '${a.category} · ${a.duration} min prévues${a.isFrozen ? ' · gelée' : ''}',
                      onTap: () => Navigator.pop(sheetContext, a),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: _navigatorKey.currentContext!,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Quel jour ?',
    );
    if (date == null || !mounted) return;
    final minutes = await _askMinutes(name: picked.name, planned: picked.duration);
    if (minutes == null || !mounted) return;
    final actual = max(1, minutes);
    _recordRealisationOnDate(picked, date, actual);
    _showFeedback('✓ « ${picked.name} » ajouté à l’historique : $actual min.');
  }
}
