// V8.98 — Interactions avec les éléments du planning
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _PlanInteractionPart on _MaBelleSemaineAppState {
  int _manualRemovalCount(String activityId, int day) {
    if (_manualDayRemovalsWeekKey != _currentWeekKey()) return 0;
    return _manualDayRemovals[activityId]?[day] ?? 0;
  }

  void _recordManualDayRemoval(String activityId, int day) {
    final weekKey = _currentWeekKey();
    if (_manualDayRemovalsWeekKey != weekKey) {
      _manualDayRemovals = {};
      _manualDayRemovalsWeekKey = weekKey;
    }
    final byDay = _manualDayRemovals.putIfAbsent(activityId, () => <int, int>{});
    byDay[day] = (byDay[day] ?? 0) + 1;
  }

  void _clearManualDayRemoval(String activityId, int day) {
    final byDay = _manualDayRemovals[activityId];
    if (byDay == null) return;
    final count = byDay[day] ?? 0;
    if (count <= 1) {
      byDay.remove(day);
    } else {
      byDay[day] = count - 1;
    }
    if (byDay.isEmpty) _manualDayRemovals.remove(activityId);
  }

  bool _manualDayBlocked(Activity activity, int day) {
    final weekKey = _currentWeekKey();
    if (_manualDayRemovalsWeekKey.isNotEmpty && _manualDayRemovalsWeekKey != weekKey) return false;
    final removed = _manualRemovalCount(activity.id, day);
    if (removed <= 0) return false;
    final dailyTarget = activity.allowMultiplePerDay ? activity.maxDailyOccurrences.clamp(2, 3).toInt() : 1;
    return removed >= dailyTarget;
  }

  Future<void> _removePlanOccurrence(PlanItem item) async {
    if (_isDateRangePlanItem(item)) {
      await _removeDateRangeOccurrence(item);
      return;
    }
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final confirmed = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du jour ?'),
        content: Text('« ${item.title} » sera retirée de ${dayNames[item.day]}. L’activité reste disponible dans ta liste et le coach tiendra compte de ce retrait.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      if (activity != null) _recordManualDayRemoval(activity.id, item.day);
      plan.removeWhere((p) => p.id == item.id);
    });
    _queueLocalStatePersist();
    _showFeedback('« ${item.title} » retirée de ${dayNames[item.day]}. Le coach en tiendra compte.');
  }

  Future<void> _movePlanItemDay(PlanItem item) async {
    if (!_isGenericActivityItem(item)) return;
    var selectedDay = item.day;
    var selectedPeriod = item.period == 'Midi' ? 'Après-midi' : item.period;
    final result = await showDialog<Map<String, dynamic>>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Déplacer l’activité'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: selectedDay,
              decoration: const InputDecoration(labelText: 'Jour'),
              items: List.generate(7, (day) => DropdownMenuItem<int>(value: day, child: Text(dayNames[day]))),
              onChanged: (value) { if (value != null) setDialogState(() => selectedDay = value); },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedPeriod,
              decoration: const InputDecoration(labelText: 'Moment'),
              items: const ['Matin', 'Après-midi', 'Soir'].map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
              onChanged: (value) { if (value != null) setDialogState(() => selectedPeriod = value); },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {'day': selectedDay, 'period': selectedPeriod}), child: const Text('Déplacer')),
          ],
        ),
      ),
    );
    if (result == null) return;
    final target = result['day'] as int;
    final targetPeriod = result['period'] as String;
    if (target == item.day && targetPeriod == item.period) return;
    final targetActivity = item.activityId == null ? null : findActivity(item.activityId!);
    final sameDayCount = item.activityId == null
        ? 0
        : plan.where((p) => p.id != item.id && p.activityId == item.activityId && p.day == target).length;
    final maxDaily = targetActivity?.allowMultiplePerDay == true
        ? targetActivity!.maxDailyOccurrences.clamp(2, 3).toInt()
        : 1;
    if (sameDayCount >= maxDaily) {
      _showFeedback('Le maximum quotidien de cette activité est atteint.');
      return;
    }
    final fromDay = item.day;
    final fromPeriod = item.period == 'Midi' ? 'Après-midi' : item.period;
    final activity = findActivity(item.activityId!);
    final replacement = PlanItem(
      id: item.id,
      day: target,
      period: targetPeriod,
      timeLabel: item.timeLabel,
      title: item.title,
      duration: item.duration,
      activityId: item.activityId,
      details: item.details,
      customEmoji: item.customEmoji,
      customCategory: item.customCategory,
      optional: item.optional,
      userAdded: item.userAdded,
      fixedInWeeklyTemplate: item.fixedInWeeklyTemplate,
      manualPlacement: true,
      done: item.done,
      realisedMinutes: item.realisedMinutes,
      feeling: item.feeling,
    );
    setState(() {
      final index = plan.indexWhere((p) => p.id == item.id);
      if (index >= 0) plan[index] = replacement;
      if (item.activityId != null && fromDay != target) {
        _recordManualDayRemoval(item.activityId!, fromDay);
        _clearManualDayRemoval(item.activityId!, target);
      }
      _recordActivityMove(item, fromDay: fromDay, fromPeriod: fromPeriod, toDay: target, toPeriod: targetPeriod);
      _sortPlan();
    });
    _queueLocalStatePersist();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('« ${item.title} » déplacée à ${dayNames[target]} · $targetPeriod.')),
    );
  }


  bool _canDropGenericInWeeklyPeriod(PlanItem item, int targetDay, String targetPeriod) {
    if (!_isGenericActivityItem(item)) return false;
    if (item.day == targetDay && item.period == targetPeriod) return false;
    final activity = findActivity(item.activityId!);
    if (activity == null) return false;
    final sameDayCount = plan.where((p) =>
        p.id != item.id && p.activityId == item.activityId && p.day == targetDay).length;
    final maxDaily = activity.allowMultiplePerDay
        ? activity.maxDailyOccurrences.clamp(2, 3).toInt()
        : 1;
    // Le déplacement ne change pas le nombre total d'occurrences du jour
    // lorsque l'on déplace une occurrence existante. On vérifie donc la
    // limite quotidienne en excluant l'occurrence déplacée elle-même.
    return sameDayCount < maxDaily;
  }

  void _moveGenericActivityWeekly(PlanItem item, int targetDay, String targetPeriod) {
    if (!_canDropGenericInWeeklyPeriod(item, targetDay, targetPeriod)) return;
    final fromDay = item.day;
    final fromPeriod = item.period == 'Midi' ? 'Après-midi' : item.period;
    final replacement = PlanItem(
      id: item.id, day: targetDay, period: targetPeriod, timeLabel: item.timeLabel,
      title: item.title, duration: item.duration, activityId: item.activityId,
      details: item.details, customEmoji: item.customEmoji, customCategory: item.customCategory,
      optional: item.optional, userAdded: item.userAdded, fixedInWeeklyTemplate: item.fixedInWeeklyTemplate,
      manualPlacement: true, done: item.done, realisedMinutes: item.realisedMinutes, feeling: item.feeling,
    );
    setState(() {
      final index = plan.indexWhere((p) => p.id == item.id);
      if (index >= 0) plan[index] = replacement;
      if (item.activityId != null && fromDay != targetDay) {
        _recordManualDayRemoval(item.activityId!, fromDay);
        _clearManualDayRemoval(item.activityId!, targetDay);
      }
      _recordActivityMove(item, fromDay: fromDay, fromPeriod: fromPeriod, toDay: targetDay, toPeriod: targetPeriod);
      _sortPlan();
    });
    _queueLocalStatePersist();
    _showFeedback('« ${item.title} » déplacée vers ${dayNames[targetDay]} · $targetPeriod.');
  }


  int _activityRealisationCountOnDate(Activity activity, DateTime date) {
    return logs.where((log) =>
        _logMatchesActivity(log, activity) &&
        log.date.year == date.year &&
        log.date.month == date.month &&
        log.date.day == date.day).length;
  }

  bool _canRecordAdditionalRealisation(Activity activity) {
    if (_isSportActivity(activity) || activity.isSportProgram || activity.isDateRange) return false;
    if (!activity.allowMultiplePerDay) return false;
    final count = _activityRealisationCountOnDate(activity, DateTime.now());
    return count < activity.maxDailyOccurrences.clamp(2, 3).toInt();
  }

  void _recordAdditionalRealisation(Activity activity) {
    if (!_canRecordAdditionalRealisation(activity)) {
      _showFeedback('Active « plusieurs réalisations par jour » et vérifie la limite quotidienne de « ${activity.name} ».');
      return;
    }
    final now = DateTime.now();
    final occurrence = _activityRealisationCountOnDate(activity, now) + 1;
    final item = PlanItem(
      id: 'extra_${activity.id}_${now.microsecondsSinceEpoch}',
      day: today,
      period: _generationPeriod(activity, today),
      timeLabel: null,
      title: activity.name,
      details: 'Réalisation supplémentaire enregistrée aujourd’hui · occurrence $occurrence/${activity.maxDailyOccurrences.clamp(2, 3)}.',
      activityId: activity.id,
      duration: max(1, activity.duration),
      optional: false,
      userAdded: true,
      fixedInWeeklyTemplate: false,
      manualPlacement: true,
      done: true,
      realisedMinutes: max(1, activity.duration),
      feeling: 'Bien',
    );
    setState(() {
      plan.add(item);
      logs.add(ActivityLog(
        date: now,
        title: activity.name,
        emoji: activity.emoji,
        category: activity.category,
        period: item.period,
        day: today,
        plannedMinutes: 0,
        realisedMinutes: item.duration,
        feeling: 'Bien',
        unplanned: true,
        planItemId: item.id,
        activityId: activity.id,
      ));
      _sortPlan();
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ « ${activity.name} » réalisée une nouvelle fois aujourd’hui ($occurrence/${activity.maxDailyOccurrences.clamp(2, 3)}).');
  }

  void openItemActions(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    // Les occurrences Sport n'ouvrent jamais le menu « Valider / Modifier / Supprimer ce moment ».
    // Le libellé mène à la fiche activité et la validation se fait par la coche.
    if (activity != null && _isSportActivity(activity)) {
      addOrEditActivity(original: activity);
      return;
    }
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (item.activityId == null || (findActivity(item.activityId!)?.category == 'Sport')) Text('${item.duration} min', style: _detailMetaStyle()),
                ],
              ),
              const SizedBox(height: 6),
              Text('${item.period}${item.userAdded ? (item.activityId != null ? ' · ajouté au planning' : ' · ajout personnel') : ''}'),
              if (item.done) ...[
                const SizedBox(height: 8),
                const Text('✓ Ce moment est déjà validé.', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6F8E80))),
                if (activity != null && _canRecordAdditionalRealisation(activity) && item.day == today) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Aujourd’hui : ${_activityRealisationCountOnDate(activity, DateTime.now())}/${activity.maxDailyOccurrences.clamp(2, 3).toInt()} réalisations enregistrées.',
                    style: _detailMetaStyle().copyWith(color: const Color(0xFF6F7777)),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    togglePlanItemDone(item, !item.done);
                  },
                  icon: Icon(item.done ? Icons.undo : Icons.check_circle_outline),
                  label: Text(item.done ? 'Annuler la validation' : 'Valider ce moment'),
                ),
              ),
              if (item.done && activity != null && item.day == today && _canRecordAdditionalRealisation(activity)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _recordAdditionalRealisation(activity);
                    },
                    icon: _uiIcon('add', Icons.add_task_outlined, size: 18),
                    label: const Text('Réaliser encore aujourd’hui'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    editPlanItem(item);
                  },
                  icon: _uiIcon('edit', Icons.edit_outlined, size: 18),
                  label: const Text('Modifier ce moment'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() => plan.removeWhere((p) => p.id == item.id));
                    _queueLocalStatePersist();
                    _scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text('« ${item.title} » retiré de la semaine.')),
                    );
                  },
                  icon: _uiIcon('delete', Icons.delete_outline, size: 18, color: const Color(0xFFC27D68)),
                  label: const Text('Retirer de la semaine'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void editPlanItem(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    if (activity != null && _isSportActivity(activity)) {
      addOrEditActivity(original: activity);
      return;
    }
    final title = TextEditingController(text: item.title);
    final details = TextEditingController(text: item.details ?? '');
    final duration = TextEditingController(text: '${item.duration}');
    var day = item.day;
    var period = item.period == 'Midi' ? 'Après-midi' : item.period;
    var feeling = _normalizeFeeling(item.feeling);

    showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Modifier le moment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: details,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Détail / note'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: day,
                  decoration: const InputDecoration(labelText: 'Jour'),
                  items: List.generate(dayNames.length, (index) => DropdownMenuItem<int>(value: index, child: Text(dayNames[index]))),
                  onChanged: (v) => setDialogState(() => day = v ?? day),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: 'Moment de la journée'),
                  items: const ['Matin', 'Après-midi', 'Soir']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => period = v ?? period),
                ),
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: Text('Tu peux déplacer cette activité vers un autre jour et choisir Matin, Après-midi ou Soir.', style: TextStyle(fontSize: 12, color: Color(0xFF6F7777)))),
                const SizedBox(height: 10),
                if (item.activityId == null || (findActivity(item.activityId!)?.category == 'Sport')) ...[
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Durée (min)'),
                  ),
                ],
                if (item.done) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: feeling.isEmpty ? 'Bien' : feeling,
                    decoration: const InputDecoration(labelText: 'Ressenti'),
                    items: const [
                      DropdownMenuItem(value: 'Très bien', child: Text('Très bien')),
                      DropdownMenuItem(value: 'Bien', child: Text('Bien')),
                      DropdownMenuItem(value: 'Difficile', child: Text('Difficile')),
                    ],
                    onChanged: (v) => setDialogState(() => feeling = v ?? feeling),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final newTitle = title.text.trim();
                if (newTitle.isEmpty) return;
                final newDuration = int.tryParse(duration.text) ?? item.duration;
                final safeDuration = newDuration < 1 ? 1 : newDuration;
                final activity = item.activityId == null ? null : findActivity(item.activityId!);
                if (activity != null && _isSportActivity(activity)) {
                  final budget = _sportBudgetForDay(day);
                  final otherSport = _sportItemsForDay(day)
                      .where((p) => p.id != item.id)
                      .fold<int>(0, (sum, p) => sum + p.duration);
                  if (otherSport + safeDuration > budget) {
                    _showFeedback('Cette modification dépasserait le plafond Sport de ${dayNames[day]} (${budget} min).');
                    return;
                  }
                }
                setState(() {
                  item.period = period;
                  item.title = newTitle;
                  item.details = details.text.trim().isEmpty ? null : details.text.trim();
                  item.duration = safeDuration;
                  if (item.done) item.feeling = feeling.isEmpty ? 'Bien' : feeling;
                  _syncCompletedValidationDuration(item);
                });
                _queueLocalStatePersist();
                Navigator.pop(dialogContext);
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(content: Text('« ${item.title} » modifié.')),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      title.dispose();
      details.dispose();
      duration.dispose();
    });
  }

  Future<void> addUnplannedToDay(int day) async {
    final result = await _navigatorKey.currentState?.push<_NewMomentResult>(
      MaterialPageRoute(
        builder: (_) => _AddMomentPage(
          dayName: dayNames[day],
          activities: List<Activity>.from(activities),
          onEditActivityIcon: _editActivityIcon,
          onPickActivityIcon: ({required String name, required String category, required String current}) =>
              _chooseActivityIconValue(name: name, category: category, current: current),
        ),
      ),
    );

    if (!mounted || result == null) return;

    Activity? linkedActivity;
    if (result.activityId != null) {
      linkedActivity = findActivity(result.activityId!);
    }

    // « Créer » crée réellement l'activité dans la bibliothèque, puis la place
    // immédiatement dans le jour choisi.
    if (result.createActivity) {
      final newId = 'activity_${DateTime.now().microsecondsSinceEpoch}';
      linkedActivity = Activity(
        id: newId,
        name: result.title,
        emoji: result.emoji,
        category: result.category,
        period: result.period,
        duration: result.duration,
        frequency: 1,
        priority: 3,
        preferredDays: [day],
        allowMultiplePerDay: false,
        maxDailyOccurrences: 2,
      );
      setState(() => activities.add(linkedActivity!));
    }

    // Lorsque l’on ajoute une activité existante directement à une journée,
    // on doit respecter sa configuration d’occurrences du jour : une activité
    // réglée sur 2 ou 3 occurrences est donc ajoutée autant de fois que
    // nécessaire pour compléter les occurrences manquantes, au lieu de n’en
    // créer qu’une seule. Les occurrences déjà présentes sont conservées.
    final isLinkedActivity = linkedActivity != null && !linkedActivity!.isDateRange;
    final dailyTarget = isLinkedActivity && linkedActivity!.allowMultiplePerDay
        ? linkedActivity!.maxDailyOccurrences.clamp(2, 3).toInt()
        : 1;
    final sameDayCount = isLinkedActivity
        ? plan.where((p) => p.activityId == linkedActivity!.id && p.day == day).length
        : 0;
    final occurrencesToAdd = isLinkedActivity
        ? (dailyTarget - sameDayCount).clamp(0, dailyTarget).toInt()
        : 1;

    if (isLinkedActivity && occurrencesToAdd <= 0) {
      _showFeedback('Le maximum quotidien de « ${linkedActivity!.name} » est déjà atteint.');
      return;
    }

    final activityDuration = linkedActivity?.duration ?? result.duration;
    final isSport = (linkedActivity != null && _isSportActivity(linkedActivity)) || result.category == 'Sport';
    var acceptedBudgetOverride = false;
    if (isSport) {
      final budget = _sportBudgetForDay(day);
      final currentSport = _sportDayTotalMinutes(day);
      final addedMinutes = activityDuration * occurrencesToAdd;
      final nextTotal = currentSport + addedMinutes;
      if (budget <= 0) {
        if (result.createActivity && linkedActivity != null) {
          setState(() => activities.removeWhere((a) => a.id == linkedActivity!.id));
        }
        _showFeedback('Aucun budget Sport n’est disponible ce jour.');
        return;
      }
      if (nextTotal > budget) {
        final overrun = nextTotal - budget;
        final accepted = await showDialog<bool>(
          context: _navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: Text('Dépassement Sport · ${dayNames[day]}'),
            content: Text(
              'Le budget prévu est de $budget min.\n\n'
              'Cet ajout porterait le Sport à $nextTotal min, soit $overrun min au-delà de la limite.\n\n'
              'Peux-tu confirmer ce dépassement ? Le coach conservera ce choix et pourra ensuite proposer une compensation : une hausse de durée sur ce jour et une baisse sur un ou plusieurs autres jours.'
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accepter le dépassement')),
            ],
          ),
        ) ?? false;
        if (!accepted) {
          if (result.createActivity && linkedActivity != null) {
            setState(() => activities.removeWhere((a) => a.id == linkedActivity!.id));
          }
          return;
        }
        acceptedBudgetOverride = true;
      }
    }

    final itemsToAdd = <PlanItem>[];
    for (var occurrence = 0; occurrence < occurrencesToAdd; occurrence++) {
      itemsToAdd.add(PlanItem(
        id: 'extra_${DateTime.now().microsecondsSinceEpoch}_${day}_$occurrence',
        day: day,
        period: isLinkedActivity
            ? _generationPeriodForOccurrence(
                linkedActivity!,
                day,
                sameDayCount + occurrence,
                dailyTarget,
                _periodForActivity(linkedActivity!, day),
              )
            : result.period,
        title: linkedActivity?.name ?? result.title,
        duration: activityDuration,
        activityId: linkedActivity?.id,
        customEmoji: linkedActivity == null ? result.emoji : null,
        customCategory: linkedActivity == null ? result.category : null,
        optional: false,
        userAdded: true,
        manualPlacement: true,
      ));
    }

    setState(() {
      if (linkedActivity != null) _clearManualDayRemoval(linkedActivity.id, day);
      if (acceptedBudgetOverride) _manualSportBudgetOverrideDays.add(day);
      plan.addAll(itemsToAdd);
      _refreshSportBudgetCoachSuggestion();
      _sortPlan();
    });
    _queueLocalStatePersist();

    _showFeedback(
      itemsToAdd.length > 1
          ? '« ${itemsToAdd.first.title} » ajouté à ${dayNames[day]} avec ${itemsToAdd.length} occurrences.'
          : '« ${itemsToAdd.first.title} » ajouté à ${dayNames[day]}.',
    );
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return monday;
  }

}
