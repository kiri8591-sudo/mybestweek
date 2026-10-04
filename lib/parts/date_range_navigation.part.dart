// V9.05 — Navigation et activités sur plusieurs jours
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _DateRangeNavigationPart on _MaBelleSemaineAppState {
  bool _isDateRangePlanItem(PlanItem item) {
    if (item.activityId == null) return false;
    final activity = findActivity(item.activityId!);
    return activity?.isDateRange == true;
  }

  Future<void> _removeDateRangeOccurrence(PlanItem item) async {
    if (!_isDateRangePlanItem(item)) return;
    final removed = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce jour ?'),
        content: Text('« ${item.title} » restera présente les autres jours de sa période.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer ce jour')),
        ],
      ),
    );
    if (removed != true || !mounted) return;
    setState(() {
      if (item.activityId != null) _recordManualDayRemoval(item.activityId!, item.day);
      plan.removeWhere((p) => p.id == item.id);
    });
    _queueLocalStatePersist();
    _showFeedback('« ${item.title} » retirée de ${dayNames[item.day]}.');
  }

  Widget _multiDaySection(List<PlanItem> items, {required int day}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 9, 9, 8),
        decoration: BoxDecoration(
          color: _colors.border,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _colors.goldBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('🗓️', style: TextStyle(fontSize: 19)),
            SizedBox(width: 7),
            Expanded(child: Text('Activités sur plusieurs jours', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _colors.textWarm))),
          ]),
          const SizedBox(height: 3),
          Text('Présentes pendant toute la période. Elles ne se valident pas.', style: TextStyle(fontSize: 10.5, color: _colors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          ...items.map((item) {
            final activity = findActivity(item.activityId!);
            return Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.fromLTRB(7, 7, 5, 7),
              decoration: BoxDecoration(
                color: _colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _colors.borderStrong),
              ),
              child: Row(children: [
                _activityIconWidget(_planItemIconValue(item, activities), size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: activity == null ? null : () => addOrEditActivity(original: activity),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                        const SizedBox(height: 2),
                        Text(activity == null ? 'Période' : _dateRangeLabel(activity), style: TextStyle(fontSize: 10.2, color: _colors.textMuted, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier l’activité',
                  visualDensity: VisualDensity.compact,
                  onPressed: activity == null ? null : () => addOrEditActivity(original: activity),
                  icon: _uiIcon('edit', Icons.edit_outlined, size: 18, color: _colors.textWarm),
                ),
                IconButton(
                  tooltip: 'Retirer ce jour',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeDateRangeOccurrence(item),
                  icon: _uiIcon('remove', Icons.remove_circle_outline, size: 18, color: _colors.danger),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  void openPlanItem(PlanItem item) {
    togglePlanItemDone(item, !item.done);
  }

  bool _isGenericActivityItem(PlanItem item) {
    if (item.activityId == null) return false;
    final activity = findActivity(item.activityId!);
    return activity != null && !_isSportActivity(activity) && !activity.isDateRange;
  }

  void _openGenericActivity(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    if (activity != null) {
      addOrEditActivity(original: activity);
    }
  }

  void _recordActivityMove(PlanItem item, {required int fromDay, required String fromPeriod, required int toDay, required String toPeriod}) {
    if (fromDay == toDay && fromPeriod == toPeriod) return;
    activityMoveLogs.add(ActivityMoveLog(
      date: DateTime.now(),
      activityName: item.title,
      activityId: item.activityId,
      fromDay: fromDay,
      toDay: toDay,
      fromPeriod: fromPeriod == 'Midi' ? 'Après-midi' : fromPeriod,
      toPeriod: toPeriod == 'Midi' ? 'Après-midi' : toPeriod,
    ));
    if (activityMoveLogs.length > 100) {
      activityMoveLogs.removeRange(0, activityMoveLogs.length - 100);
    }
  }

  void openWeeklyReview() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => _WeeklyReviewPage(
        plan: plan,
        // Le Bilan 4 semaines doit recevoir l'historique complet.
        // La page filtre elle-même chaque semaine pour ses indicateurs.
        logs: logs,
        moveLogs: activityMoveLogs,
        activities: activities,
        weeklyNote: weeklyNote,
        onSaveNote: (value) {
          setState(() => weeklyNote = value);
          _queueLocalStatePersist();
        },
        onOpenHistory: openHistory,
        onReplan: () {
          openGenerationCriteria();
        },
        coachSummary: _coachWeeklySummary(),
        coachInsights: _coachWeeklyInsights(),
        onOpenCoachDecisions: openPlanningCoachDecisions,
        referenceNow: _clockNow,
      )),
    );
  }

  void openHistory() {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _HistorySheet(logs: logs, activities: activities, dayNames: dayNames, onOpenGenerationCriteria: openGenerationCriteria),
    );
  }

}
