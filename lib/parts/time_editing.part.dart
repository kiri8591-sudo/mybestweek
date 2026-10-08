// V12.11.0 — Saisie du temps réellement vécu (activités non-Sport) :
// depuis la semaine (« Temps réalisé ») et depuis l'Historique (modifier / ajouter),
// pour que les statistiques de durée reflètent le réel et non la durée prévue.

part of '../main.dart';

extension _TimeEditingPart on _MaBelleSemaineAppState {
  Future<int?> _askMinutes({required String name, required int planned, int? current}) {
    return showModalBottomSheet<int>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SportRealisedMinutesSheet(
        activityName: name,
        plannedMinutes: max(1, planned),
        currentMinutes: current,
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

  /// Historique : corriger la durée d'une réalisation.
  Future<void> editHistoryLogMinutes(ActivityLog log) async {
    if (!mounted || logs.indexOf(log) < 0) return;
    final minutes = await _askMinutes(
      name: log.title,
      planned: log.plannedMinutes > 0 ? log.plannedMinutes : max(1, log.realisedMinutes),
      current: log.realisedMinutes > 0 ? log.realisedMinutes : null,
    );
    if (minutes == null || !mounted) return;
    final index = logs.indexOf(log);
    if (index < 0) return;

    // Dans l’Historique, 0 min signifie explicitement : supprimer cette réalisation.
    if (minutes == 0) {
      setState(() {
        logs.removeAt(index);
        final planId = log.planItemId;
        if (planId != null) {
          for (final p in plan) {
            if (p.id == planId && p.done) {
              p.done = false;
              p.realisedMinutes = null;
              p.feeling = null;
            }
          }
        }
      });
      _queueLocalStatePersist();
      _refreshGoalsAfterRealization();
      _showFeedback('« ${log.title} » supprimée de l’historique.');
      return;
    }

    final actual = max(1, minutes);
    setState(() {
      logs[index] = _logWithMinutes(log, actual);
      final planId = log.planItemId;
      if (planId != null) {
        for (final p in plan) {
          if (p.id == planId && p.done) p.realisedMinutes = actual;
        }
      }
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ Temps mis à jour : $actual min.');
  }

  /// Historique : ajouter après coup une réalisation (activité, jour, durée).
  Future<void> addHistoryLog() async {
    if (!mounted) return;
    // L’ajout depuis l’Historique doit proposer toutes les activités, y compris Sport.
    final candidates = activities.toList()
      ..sort((a, b) {
        final typeCompare = (_isSportActivity(a) ? 0 : 1).compareTo(_isSportActivity(b) ? 0 : 1);
        if (typeCompare != 0) return typeCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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
                padding: const EdgeInsets.only(bottom: AppSpace.s),
                child: Text('Quelle activité ?', style: _sheetTitleStyle(sheetContext)),
              ),
              for (final a in candidates)
                ListTile(
                  leading: _activityIconWidget(a.emoji, size: 26),
                  title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${a.duration} min prévues · ${_isSportActivity(a) ? 'Sport' : 'Activité'}'),
                  onTap: () => Navigator.pop(sheetContext, a),
                ),
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
    setState(() {
      logs.add(ActivityLog(
        date: DateTime(date.year, date.month, date.day, 12),
        title: picked.name,
        emoji: picked.emoji,
        category: picked.category,
        period: picked.period,
        day: date.weekday - 1,
        plannedMinutes: picked.duration,
        realisedMinutes: actual,
        feeling: 'Bien',
        unplanned: true,
        planItemId: null,
        activityId: picked.id,
      ));
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ « ${picked.name} » ajouté à l’historique : $actual min.');
  }
}
