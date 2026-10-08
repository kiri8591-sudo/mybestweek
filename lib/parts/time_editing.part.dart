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
          // Une réalisation ajoutée depuis l’Historique peut avoir créé une
          // occurrence dédiée dans le jour (id "history_..."). À 0 min,
          // cette occurrence ne doit pas rester affichée comme « non réalisée » :
          // elle doit disparaître complètement du planning du jour.
          final linked = plan.where((p) => p.id == planId).toList();
          if (linked.isNotEmpty) {
            final item = linked.first;
            final wasAddedFromHistory = item.id.startsWith('history_') &&
                item.userAdded && item.manualPlacement;
            if (wasAddedFromHistory) {
              plan.removeWhere((p) => p.id == planId);
            } else if (item.done) {
              // Pour une occurrence planifiée existante, on conserve le
              // créneau mais on annule uniquement sa réalisation.
              item.done = false;
              item.realisedMinutes = null;
              item.feeling = null;
            }
          }
        }
      });
      _queueLocalStatePersist();
      _refreshGoalsAfterRealization();
      _showFeedback('« ${log.title} » supprimée de l’historique et du jour.');
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
    final selectedDay = date.weekday - 1;
    String? linkedPlanItemId;

    setState(() {
      // L'ajout depuis l'Historique doit aussi mettre à jour le jour choisi.
      // Le planning est hebdomadaire : on rattache donc la réalisation au
      // créneau correspondant (jour de semaine + activité).
      final candidatesForDay = plan
          .where((item) => item.day == selectedDay && item.activityId == picked.id)
          .toList();

      PlanItem? item;
      for (final candidate in candidatesForDay) {
        if (!candidate.done) {
          item = candidate;
          break;
        }
      }
      item ??= candidatesForDay.isNotEmpty ? candidatesForDay.first : null;

      if (item == null) {
        item = PlanItem(
          id: 'history_${picked.id}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}_${DateTime.now().microsecondsSinceEpoch}',
          day: selectedDay,
          period: picked.period,
          title: picked.name,
          duration: picked.duration,
          activityId: picked.id,
          userAdded: true,
          manualPlacement: true,
          done: true,
          realisedMinutes: actual,
          feeling: 'Bien',
        );
        plan.add(item);
      } else {
        item.done = true;
        item.realisedMinutes = actual;
        item.feeling = 'Bien';
      }
      linkedPlanItemId = item.id;

      // Évite une double réalisation pour le même item : l'entrée ajoutée
      // depuis l'Historique devient la trace de référence.
      logs.removeWhere((log) => log.planItemId == linkedPlanItemId);
      logs.add(ActivityLog(
        date: DateTime(date.year, date.month, date.day, 12),
        title: picked.name,
        emoji: picked.emoji,
        category: picked.category,
        period: item.period,
        day: selectedDay,
        plannedMinutes: item.duration,
        realisedMinutes: actual,
        feeling: 'Bien',
        unplanned: false,
        planItemId: linkedPlanItemId,
        activityId: picked.id,
      ));
      _sortPlan();
    });
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      _upsertTodayDailySummary(persist: false);
    }
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ « ${picked.name} » ajouté au ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} et marqué réalisé : $actual min.');
  }
}
