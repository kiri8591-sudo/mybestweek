// V12.25.1 — Carte Nutrition autonome sur l'écran d'accueil.
// Les activités de cette catégorie sont séparées des créneaux horaires,
// sur le même principe que la carte Sport.

part of '../main.dart';

extension _NutritionHomePart on _MaBelleSemaineAppState {
  String _nutritionCategoryKey(String? value) => (value ?? '')
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .trim()
      .toLowerCase();

  bool _isNutritionCategory(String? value) {
    final key = _nutritionCategoryKey(value);
    return key == 'alimentation' || key.contains('nutrition');
  }

  bool _isNutritionActivity(Activity activity) {
    if (_isNutritionCategory(activity.category)) return true;

    // Compatibilité avec les anciennes fiches rangées dans une catégorie
    // générique : leur nom ou leur icône Nutrition reste reconnaissable.
    final name = activity.name.trim().toLowerCase();
    final nutritionName = RegExp(
      r'poisson|saumon|thon|sardine|truite|l[ée]gumineuse|lentille|haricot|pois.?chiche|f[eè]ve|carnet.?calorique|journal.?alimentaire|noter.*repas|pes[eé]e|fromage|brocoli|carotte',
    ).hasMatch(name);
    final icon = activity.emoji.trim().toLowerCase();
    final nutritionIcon = <String>{
      'pack://balanced_meal',
      'pack://carrot',
      'pack://broccoli',
      'pack://fish',
      'pack://beans',
      'pack://apple',
      'pack://cheese',
      'pack://water_glass',
      'pack://scale',
    }.contains(icon);
    return nutritionName || nutritionIcon;
  }

  bool _isNutritionPlanItem(PlanItem item) {
    // Le customCategory reste prioritaire pour les anciennes entrées créées
    // avant que l'activité liée soit correctement catégorisée.
    if (_isNutritionCategory(item.customCategory)) return true;
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    return activity != null && _isNutritionActivity(activity);
  }

  bool _hasNutritionSection() =>
      _allCategoryNames().any(_isNutritionCategory) ||
      activities.any(_isNutritionActivity) ||
      plan.any(_isNutritionPlanItem) ||
      logs.any((log) => _isNutritionCategory(log.category));

  List<PlanItem> _nutritionItemsForDay(int day) => plan
      .where((item) => item.day == day && _isNutritionPlanItem(item))
      .toList();

  void _openNutritionTracking() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    Navigator.of(navigatorContext).push(
      MaterialPageRoute<void>(
        builder: (_) => _NutritionTrackingPage(
          activities: activities,
          logs: logs,
          goals: _realizationGoals,
          onEditLog: editHistoryLogMinutes,
          onAddForActivity: addHistoryLogFor,
        ),
      ),
    );
  }

  void _openNutritionWeeklyAnalysis() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    showModalBottomSheet<void>(
      context: navigatorContext,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _NutritionWeeklyAnalysisSheet(
        activities: List<Activity>.from(activities),
        logs: List<ActivityLog>.from(logs),
        goals: List<RealizationGoal>.from(_realizationGoals),
        nutritionActivities: List<Activity>.from(_nutritionActivitiesForChecklist()),
        tone: _nutritionCoachTone,
      ),
    );
  }

  List<Activity> _nutritionActivitiesForChecklist() {
    // Inclure toutes les activités Nutrition, même si une ancienne fiche a
    // conservé un indicateur dateRange / programme. Ces indicateurs ne doivent
    // jamais faire disparaître une habitude de la liste quotidienne.
    final linkedIds = <String>{};
    final legacyTitles = <String>{};

    for (final item in plan) {
      if (_isNutritionPlanItem(item) && item.activityId != null) {
        linkedIds.add(item.activityId!);
      }
    }
    for (final log in logs) {
      if (!_isNutritionCategory(log.category)) continue;
      if (log.activityId != null) {
        linkedIds.add(log.activityId!);
      } else if (log.title.trim().isNotEmpty) {
        legacyTitles.add(log.title.trim().toLowerCase());
      }
    }

    final result = activities.where((activity) =>
        _isNutritionActivity(activity) ||
        linkedIds.contains(activity.id) ||
        legacyTitles.contains(activity.name.trim().toLowerCase())).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  DateTime _nutritionDateForDay(int day) {
    final monday = _startOfCurrentWeek();
    final date = DateTime(monday.year, monday.month, monday.day + day);
    return DateTime(date.year, date.month, date.day);
  }

  bool _nutritionLogMatchesActivityDay(ActivityLog log, Activity activity, int day) {
    final date = _nutritionDateForDay(day);
    final sameDate = log.date.year == date.year &&
        log.date.month == date.month &&
        log.date.day == date.day;
    if (!sameDate) return false;
    if (log.activityId == activity.id) return true;
    return log.activityId == null &&
        log.title.trim().toLowerCase() == activity.name.trim().toLowerCase() &&
        (_isNutritionCategory(log.category) || _isNutritionActivity(activity));
  }

  bool _nutritionActivityDoneForDay(Activity activity, int day) {
    final plannedDone = plan.any((item) =>
        item.day == day && item.activityId == activity.id && item.done);
    if (plannedDone) return true;
    return logs.any((log) => _nutritionLogMatchesActivityDay(log, activity, day));
  }

  Widget _nutritionDayCard(int day, {bool compactHome = false}) {
    final items = _nutritionItemsForDay(day);
    final checklistActivities = _nutritionActivitiesForChecklist();
    // Sur l'écran Semaine, les habitudes restent visibles chaque jour, même
    // lorsqu'elles n'ont pas été préalablement placées dans le planning.
    // Sur l'accueil compact, on conserve la liste des seules activités planifiées.
    // Sur l'écran Semaine, le bloc Nutrition est une véritable grille
    // hebdomadaire : une ligne par activité et sept cases (lundi à dimanche).
    // Le compteur du bloc reflète donc les cases de toute la semaine, pas
    // uniquement le jour actuellement sélectionné.
    final weeklyChecklistDone = checklistActivities.fold<int>(
      0,
      (count, activity) => count + List<int>.generate(7, (d) => d)
          .where((d) => _nutritionActivityDoneForDay(activity, d))
          .length,
    );
    final done = compactHome
        ? items.where((item) => item.done).length
        : checklistActivities.isNotEmpty
            ? weeklyChecklistDone
            : items.where((item) => item.done).length;
    final total = compactHome
        ? items.length
        : checklistActivities.isNotEmpty
            ? checklistActivities.length * 7
            : items.length;
    final allDone = total > 0 && done >= total;
    final collapsed = compactHome && allDone && !_homeNutritionExpanded;
    final background = _darkMode
        ? const Color(0xFF30392C)
        : const Color(0xFFEAF0E2);
    final border = _darkMode
        ? const Color(0xFF526047)
        : const Color(0xFFD8E3CB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 7, 9, 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.m),
            onTap: collapsed
                ? () => setState(() => _homeNutritionExpanded = true)
                : null,
            child: Row(
              children: [
                _activityIconWidget('pack://balanced_meal', size: 25),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrition',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.bodyL,
                          fontWeight: FontWeight.w800,
                          color: _darkMode
                              ? const Color(0xFFE0EBD5)
                              : const Color(0xFF34462D),
                        ),
                      ),
                      Text(
                        total == 0
                            ? 'Aucune habitude Nutrition créée'
                            : compactHome
                                ? '$done/$total habitudes réalisées aujourd’hui'
                                : '$done/$total cases cochées cette semaine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.small,
                          fontWeight: FontWeight.w700,
                          color: _darkMode
                              ? const Color(0xFFB8C5AE)
                              : const Color(0xFF66765C),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Ouvrir le suivi Nutrition',
                  onPressed: _openNutritionTracking,
                  icon: Icon(
                    Icons.insights_outlined,
                    size: 19,
                    color: _darkMode
                        ? const Color(0xFFD3E1C8)
                        : const Color(0xFF536B46),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Lire l’analyse de ma semaine Nutrition',
                  onPressed: _openNutritionWeeklyAnalysis,
                  icon: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: _darkMode
                        ? const Color(0xFFE4D6A7)
                        : const Color(0xFF9A7833),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Ajouter une habitude Nutrition',
                  onPressed: () => _addNutritionActivityToDay(day),
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: _darkMode
                        ? const Color(0xFFD3E1C8)
                        : const Color(0xFF536B46),
                  ),
                ),
                if (compactHome && allDone && !collapsed)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
                    tooltip: 'Replier Nutrition',
                    onPressed: () => setState(() => _homeNutritionExpanded = false),
                    icon: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 19,
                      color: _colors.textMuted,
                    ),
                  )
                else if (collapsed)
                  Icon(
                    Icons.expand_more_rounded,
                    size: 19,
                    color: _darkMode
                        ? const Color(0xFFB8C5AE)
                        : const Color(0xFF66765C),
                  ),
              ],
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 3),
            if (compactHome && checklistActivities.isNotEmpty) _nutritionCoachCard(),
            if (!compactHome && checklistActivities.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 5),
                child: Text(
                  'Une ligne par habitude · coche le jour où tu l’as réalisée.',
                  style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted),
                ),
              ),
              _nutritionWeeklyMatrix(checklistActivities),
            ]
            else if (items.isNotEmpty)
              ...items.map(_nutritionItemRow)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 7, 4, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aucune habitude Nutrition détectée. Vérifie la catégorie de tes activités ou ajoute-en une.',
                      style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _createNutritionActivityFromWeek,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('Créer une habitude Nutrition'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Résout toujours l'élément depuis le planning courant avant de le valider.
  /// La carte Semaine est reconstruite lors des changements de jour ; retrouver
  /// l'élément par son identifiant évite d'utiliser une ancienne référence.
  void _setNutritionPlanItemDone(PlanItem displayedItem, bool checked) {
    if (!mounted) return;
    final index = plan.indexWhere((candidate) => candidate.id == displayedItem.id);
    if (index < 0) {
      _showFeedback('Cette habitude n’est plus présente dans le planning.');
      return;
    }
    final currentItem = plan[index];
    if (currentItem.done == checked) return;
    if (_isDateRangePlanItem(currentItem)) {
      _showFeedback('Une activité sur plusieurs jours ne se valide pas.');
      return;
    }
    HapticFeedback.selectionClick();
    togglePlanItemDone(currentItem, checked);
  }

  Widget _nutritionCheckControl({
    required bool checked,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Checkbox(
          value: checked,
          onChanged: (value) {
            if (value == null) return;
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          activeColor: _colors.accentFill,
          checkColor: Colors.white,
          side: BorderSide(color: _colors.accentIcon, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }

  /// Grille hebdomadaire Nutrition : une ligne par habitude et une case
  /// indépendante pour chacun des sept jours, sur le modèle de Semaine Sport.
  Widget _nutritionWeeklyMatrix(List<Activity> source) {
    const dayLabels = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 48;
        final dayWidth = ((availableWidth - 102) / 7)
            .clamp(23.0, 31.0)
            .toDouble();
        final activityWidth = availableWidth - (dayWidth * 7);

        Widget dayHeading(int index) {
          final isToday = index == today;
          return SizedBox(
            width: dayWidth,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                decoration: BoxDecoration(
                  color: isToday ? _colors.tintStrong : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dayLabels[index],
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                    color: isToday ? _colors.accentText : _colors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }

        Widget activityDayCheckbox(Activity activity, int index) {
          final checked = _nutritionActivityDoneForDay(activity, index);
          return SizedBox(
            width: dayWidth,
            height: 38,
            child: Center(
              child: Tooltip(
                message: '${activity.name} · ${dayNames[index]}',
                // FittedBox remplace Checkbox.constraints, absent des versions
                // Flutter utilisées par le projet. La case reste visuellement
                // compacte dans chaque colonne sans provoquer d'overflow.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Checkbox(
                    value: checked,
                    onChanged: (value) {
                      if (value == null) return;
                      _setNutritionActivityDoneForDay(activity, index, value);
                    },
                    semanticLabel: '${activity.name}, ${dayNames[index]}',
                    activeColor: _colors.accentFill,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: checked ? _colors.accentFillBorder : _colors.accentIcon,
                      width: 1.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: activityWidth,
                  child: Text(
                    'Habitude',
                    style: TextStyle(
                      fontSize: AppType.micro,
                      fontWeight: FontWeight.w800,
                      color: _colors.textMuted,
                    ),
                  ),
                ),
                ...List<Widget>.generate(7, dayHeading),
              ],
            ),
            Divider(height: 5, thickness: 0.8, color: borderForNutrition()),
            ...source.map((activity) {
              return Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        SizedBox(
                          width: activityWidth,
                          child: Row(
                            children: [
                              _activityIconWidget(activity.emoji, size: 22),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  activity.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppType.small,
                                    fontWeight: FontWeight.w700,
                                    color: _colors.textStrong,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...List<Widget>.generate(
                          7,
                          (index) => activityDayCheckbox(activity, index),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 0.6, color: borderForNutrition()),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  void _setNutritionActivityDoneForDay(Activity displayedActivity, int day, bool checked) {
    if (!mounted) return;
    final activity = findActivity(displayedActivity.id);
    if (activity == null || !_isNutritionActivity(activity)) return;
    final date = _nutritionDateForDay(day);
    final dayItems = plan.where((item) =>
        item.day == day && item.activityId == activity.id).toList();
    final hasMatchingLog = logs.any((log) => _nutritionLogMatchesActivityDay(log, activity, day));

    if (checked) {
      if (dayItems.any((item) => item.done) || hasMatchingLog) return;
      final pendingItems = dayItems.where((item) => !item.done).toList();
      if (pendingItems.isNotEmpty) {
        togglePlanItemDone(pendingItems.first, true);
        return;
      }

      _prepareUndoSnapshot();
      final now = DateTime.now();
      final duration = max(1, activity.duration);
      final item = PlanItem(
        id: 'nutrition_done_${activity.id}_${day}_${now.microsecondsSinceEpoch}',
        day: day,
        period: _periodForActivity(activity, day),
        timeLabel: null,
        activityId: activity.id,
        title: activity.name,
        details: 'Nutrition · réalisation enregistrée depuis l’écran Semaine.',
        duration: duration,
        optional: false,
        userAdded: true,
        fixedInWeeklyTemplate: false,
        manualPlacement: true,
        done: true,
        realisedMinutes: activity.countOnly ? 1 : duration,
        feeling: 'Bien',
      );
      setState(() {
        _clearManualDayRemoval(activity.id, day);
        plan.add(item);
        logs.removeWhere((log) => _nutritionLogMatchesActivityDay(log, activity, day));
        logs.add(ActivityLog(
          date: DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second),
          title: activity.name,
          emoji: activity.emoji,
          category: activity.category,
          period: item.period,
          day: day,
          plannedMinutes: duration,
          realisedMinutes: activity.countOnly ? 1 : duration,
          feeling: 'Bien',
          unplanned: false,
          planItemId: item.id,
          activityId: activity.id,
        ));
        _sortPlan();
      });
      if (day == today && _todayIsCompleted()) _upsertTodayDailySummary(persist: false);
      _queueLocalStatePersist();
      _refreshGoalsAfterRealization();
      _maybeAwardDailyPriorityBonus();
      _showFeedback('✓ « ${activity.name} » enregistré dans Nutrition.');
      return;
    }

    final completed = dayItems.where((item) => item.done).toList();
    if (completed.isEmpty && !hasMatchingLog) return;
    _prepareUndoSnapshot();
    setState(() {
      for (final item in completed) {
        item.done = false;
        item.realisedMinutes = null;
        item.feeling = null;
      }
      logs.removeWhere((log) => _nutritionLogMatchesActivityDay(log, activity, day));
      if (day == today) dailySummaries.removeWhere((summary) => summary.dateKey == _todayDateKey());
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('Réalisation de « ${activity.name} » annulée.');
  }

  Widget _nutritionItemRow(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final titleStyle = _detailTitleStyle(
      decoration: item.done ? TextDecoration.lineThrough : null,
    );
    final subtitle = _itemIsCount(item)
        ? (item.done ? '✓ Réalisé' : 'À cocher')
        : item.done
            ? '${item.realisedMinutes ?? item.duration} / ${item.duration} min · ✓'
            : '${item.duration} min';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(6, 4, 3, 4),
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF252D22) : _colors.card,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _darkMode ? const Color(0xFF46513F) : borderForNutrition()),
        ),
        child: Row(
          children: [
            _nutritionCheckControl(
              checked: item.done,
              onChanged: (value) => _setNutritionPlanItemDone(item, value),
            ),
            const SizedBox(width: 3),
            _activityIconWidget(_planItemIconValue(item, activities), size: 27),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.m),
                onTap: activity == null
                    ? () => openPlanItem(item)
                    : () => addOrEditActivity(original: activity),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 1),
                      Text(subtitle, style: _detailMetaStyle()),
                    ],
                  ),
                ),
              ),
            ),
            if (item.done) _feelingChip(item),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_horiz_rounded, size: 19, color: _colors.textMuted),
              onSelected: (value) {
                if (value == 'edit' && activity != null) {
                  addOrEditActivity(original: activity);
                } else if (value == 'remove') {
                  _removePlanOccurrence(item);
                }
              },
              itemBuilder: (context) => [
                if (activity != null)
                  const PopupMenuItem<String>(value: 'edit', child: Text('Voir / modifier')),
                const PopupMenuItem<String>(value: 'remove', child: Text('Retirer du jour')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color borderForNutrition() => _darkMode
      ? const Color(0xFF46513F)
      : const Color(0xFFDDE5D5);

  void _createNutritionActivityFromWeek() {
    final now = DateTime.now().microsecondsSinceEpoch;
    addOrEditActivity(
      prefill: Activity(
        id: 'nutrition_new_$now',
        name: '',
        emoji: '🥗',
        category: 'Nutrition',
        duration: 1,
        frequency: 1,
        priority: 3,
        countOnly: true,
      ),
    );
  }

  Future<void> _addNutritionActivityToDay(int day) async {
    final available = _nutritionActivitiesForChecklist();

    if (available.isEmpty) {
      _showFeedback('Crée d’abord une activité dans la catégorie « Nutrition » depuis Activités.');
      return;
    }

    final selected = await showModalBottomSheet<Activity>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter à Nutrition · ${dayNames[day]}',
                style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (_, index) {
                    final activity = available[index];
                    final count = _nutritionItemsForDay(day)
                        .where((item) => item.activityId == activity.id)
                        .length;
                    final maxDaily = activity.allowMultiplePerDay
                        ? activity.maxDailyOccurrences.clamp(2, 5).toInt()
                        : 1;
                    final canAdd = count < maxDaily;
                    final detail = _itemIsCountForActivity(activity)
                        ? 'Suivi par occurrence'
                        : '${activity.duration} min';
                    return ListTile(
                      enabled: canAdd,
                      leading: _activityIconWidget(activity.emoji, size: 29),
                      title: Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(canAdd ? detail : 'Déjà ajoutée au maximum aujourd’hui'),
                      trailing: Icon(
                        canAdd ? Icons.add_circle_outline : Icons.check_circle_outline,
                        color: canAdd ? _colors.accentIcon : _colors.textMuted,
                      ),
                      onTap: canAdd ? () => Navigator.pop(context, activity) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final already = _nutritionItemsForDay(day)
        .where((item) => item.activityId == selected.id)
        .length;
    final maxDaily = selected.allowMultiplePerDay
        ? selected.maxDailyOccurrences.clamp(2, 5).toInt()
        : 1;
    if (already >= maxDaily) {
      _showFeedback('« ${selected.name} » est déjà présente au maximum aujourd’hui.');
      return;
    }

    _prepareUndoSnapshot();
    final newItem = PlanItem(
      id: 'nutrition_manual_${selected.id}_${day}_${DateTime.now().microsecondsSinceEpoch}',
      day: day,
      period: _periodForActivity(selected, day),
      timeLabel: null,
      activityId: selected.id,
      title: selected.name,
      details: 'Nutrition · ajout manuel au planning.',
      duration: selected.duration,
      optional: false,
      userAdded: true,
      fixedInWeeklyTemplate: false,
      manualPlacement: true,
    );
    setState(() {
      _clearManualDayRemoval(selected.id, day);
      plan.add(newItem);
      _sortPlan();
      _homeNutritionExpanded = true;
    });
    _queueLocalStatePersist();
    _showFeedback('« ${selected.name} » ajoutée à Nutrition de ${dayNames[day]}.');
  }

  bool _itemIsCountForActivity(Activity activity) => activity.countOnly;
}


class _NutritionWeeklyGoalInsight {
  final Activity activity;
  final RealizationGoal goal;
  final int actual;
  final int target;
  final bool satisfied;

  const _NutritionWeeklyGoalInsight({
    required this.activity,
    required this.goal,
    required this.actual,
    required this.target,
    required this.satisfied,
  });
}

class _NutritionWeeklyAnalysisSheet extends StatelessWidget {
  final List<Activity> activities;
  final List<ActivityLog> logs;
  final List<RealizationGoal> goals;
  final List<Activity> nutritionActivities; // V12.28.0 — mêmes habitudes que la carte d'accueil
  final String tone;

  const _NutritionWeeklyAnalysisSheet({
    required this.activities,
    required this.logs,
    required this.goals,
    required this.nutritionActivities,
    required this.tone,
  });

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _matches(ActivityLog log, Activity activity) =>
      log.activityId == activity.id ||
      (log.activityId == null &&
          log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());

  bool _isRealised(ActivityLog log, Activity activity) =>
      activity.countOnly || log.realisedMinutes > 0 || (log.reps ?? 0) > 0;

  int _count(Activity activity, DateTime start, DateTime end) {
    return logs.where((log) {
      final date = _day(log.date);
      return _matches(log, activity) &&
          _isRealised(log, activity) &&
          !date.isBefore(start) &&
          !date.isAfter(end);
    }).length;
  }

  List<_NutritionWeeklyGoalInsight> _weeklyInsights(DateTime monday, DateTime today) {
    final result = <_NutritionWeeklyGoalInsight>[];
    for (final activity in activities.where((a) =>
        a.category.trim().toLowerCase() == 'nutrition' &&
        !a.isDateRange &&
        !a.isSportProgram)) {
      for (final goal in goals.where((g) => g.activityId == activity.id)) {
        // Les objectifs mensuels sont présentés comme repère distinct, car
        // ils ne constituent pas une fréquence hebdomadaire équivalente.
        if (goal.cadence == 'mois') continue;
        final createdDay = _day(goal.createdAt);
        if (today.isBefore(createdDay)) continue;
        // La fréquence hebdomadaire est évaluée sur toute la semaine en cours,
        // pas seulement depuis le jour où le réglage a été créé. Une habitude
        // déjà réalisée plus tôt dans la semaine reste donc acquise.
        final effectiveStart = goal.cadence == 'semaine'
            ? monday
            : (createdDay.isAfter(monday) ? createdDay : monday);
        final elapsedDays = today.difference(effectiveStart).inDays + 1;
        if (elapsedDays <= 0) continue;
        final target = goal.cadence == 'jour'
            ? goal.target * elapsedDays
            : goal.target;
        final actual = _count(activity, effectiveStart, today);
        final satisfied = goal.isMaximum ? actual <= target : actual >= target;
        result.add(_NutritionWeeklyGoalInsight(
          activity: activity,
          goal: goal,
          actual: actual,
          target: target,
          satisfied: satisfied,
        ));
      }
    }
    result.sort((a, b) {
      final byStatus = (a.satisfied ? 0 : 1).compareTo(b.satisfied ? 0 : 1);
      return byStatus != 0 ? byStatus : a.activity.name.toLowerCase().compareTo(b.activity.name.toLowerCase());
    });
    return result;
  }

  List<String> _monthlyReferences(DateTime today) {
    final lines = <String>[];
    final monthStart = DateTime(today.year, today.month, 1);
    for (final activity in activities.where((a) =>
        a.category.trim().toLowerCase() == 'nutrition' &&
        !a.isDateRange &&
        !a.isSportProgram)) {
      for (final goal in goals.where((g) => g.activityId == activity.id && g.cadence == 'mois')) {
        final goalStart = DateTime(goal.createdAt.year, goal.createdAt.month, 1);
        if (today.isBefore(goalStart)) continue;
        final start = goalStart.isAfter(monthStart) ? goalStart : monthStart;
        final actual = _count(activity, start, today);
        final rule = goal.isMaximum ? 'maximum' : 'minimum';
        lines.add('${activity.name} : $actual / ${goal.target} par mois ($rule).');
      }
    }
    return lines;
  }

  String _summary(int achieved, int total, int toDo, int exceeded) {
    if (total == 0) {
      return 'Aucun objectif quotidien ou hebdomadaire Nutrition n’est configuré pour le moment. Les objectifs mensuels, s’il y en a, restent consultables plus bas.';
    }
    if (toDo == 0 && exceeded == 0) {
      return 'Très bon début de semaine : les $total objectifs Nutrition suivis sont actuellement atteints ou respectés. Garde ce rythme régulier, sans chercher à compenser.';
    }
    if (achieved == 0) {
      return 'La semaine est encore en construction. Le plus utile est de programmer les habitudes manquantes dans les prochains repas, plutôt que d’attendre le dernier jour.';
    }
    return '$achieved objectif${achieved > 1 ? 's' : ''} déjà atteint${achieved > 1 ? 's' : ''} sur $total. Il reste $toDo habitude${toDo > 1 ? 's' : ''} à organiser et $exceeded plafond${exceeded > 1 ? 's' : ''} à rééquilibrer.';
  }

  Widget _insightLine({
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong)),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: AppType.small, height: 1.35, color: _colors.textMuted)),
        ])),
      ]),
    );
  }

  Widget _goalInsightCard(_NutritionWeeklyGoalInsight insight) {
    final goal = insight.goal;
    final activity = insight.activity;
    final isMaximum = goal.isMaximum;
    final exceeded = isMaximum && insight.actual > insight.target;
    final remaining = max(0, insight.target - insight.actual);
    final color = exceeded
        ? _colors.warnBorder
        : insight.satisfied
            ? _colors.accentText
            : _colors.textMuted;
    final status = isMaximum
        ? (exceeded
            ? 'Plafond dépassé de ${insight.actual - insight.target}'
            : 'Plafond respecté pour le moment')
        : (insight.satisfied
            ? 'Objectif atteint'
            : 'Encore $remaining à réaliser');
    final cadence = goal.cadence == 'jour' ? 'par jour' : 'par semaine';
    final targetLabel = isMaximum ? 'Au plus ${goal.target} $cadence' : 'Au moins ${goal.target} $cadence';
    final advice = isMaximum
        ? (exceeded
            ? 'Pour les prochains repas, varie les choix afin de revenir progressivement dans la limite prévue.'
            : 'Garde cette limite en tête pour les repas qui restent cette semaine.')
        : (insight.satisfied
            ? 'Habitude tenue : conserve cette régularité.'
            : 'Prévois ${remaining == 1 ? 'une occasion' : '$remaining occasions'} de « ${activity.name} » avant la fin de la semaine.');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: _AppCard(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _activityIconWidget(activity.emoji, size: 25),
            const SizedBox(width: 8),
            Expanded(child: Text(activity.name, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong))),
            Text('${insight.actual}/${insight.target}', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w900, color: color)),
          ]),
          const SizedBox(height: 3),
          Text('$targetLabel · $status', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: AppSpace.xs),
          Text(advice, style: _hintStyle()),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _day(now);
    final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final sunday = monday.add(const Duration(days: 6));
    final weekLabel = 'Du ${monday.day.toString().padLeft(2, '0')}/${monday.month.toString().padLeft(2, '0')} au ${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    final insights = _weeklyInsights(monday, today);
    final achieved = insights.where((i) => i.satisfied).length;
    final toDo = insights.where((i) => !i.satisfied && !i.goal.isMaximum).length;
    final exceeded = insights.where((i) => !i.satisfied && i.goal.isMaximum).length;
    final monthly = _monthlyReferences(today);
    final nutritionActivities = activities.where((a) =>
        a.category.trim().toLowerCase() == 'nutrition' &&
        !a.isDateRange &&
        !a.isSportProgram).toList();

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.s, AppSpace.l, AppSpace.m),
            child: Row(children: [
              _activityIconWidget('🥗', size: 31),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Analyse de ta semaine Nutrition', style: _sheetTitleStyle(context)),
                Text('$weekLabel · point au ${today.day}/${today.month}', style: _hintStyle()),
              ])),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.xl), children: [
            _NutritionCoachCard(
              engine: _NutritionCoachEngine(
                activities: nutritionActivities,
                logs: logs,
                goals: goals,
                now: now,
              ),
              tone: tone,
              compact: false,
            ),
            const SizedBox(height: AppSpace.s),
            _AppCard(
              tone: _CardTone.tint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Le point de la semaine', style: _sectionTitleStyle(context)),
                const SizedBox(height: AppSpace.xs),
                Text(_summary(achieved, insights.length, toDo, exceeded), style: TextStyle(fontSize: AppType.body, height: 1.4, color: _colors.textStrong)),
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s),
                  _MeterBar(value: achieved / insights.length, height: 8, color: _colors.accentFill),
                  const SizedBox(height: 4),
                  Text('$achieved / ${insights.length} objectifs atteints ou respectés à ce jour', style: _hintStyle()),
                ],
              ]),
            ),
            const SizedBox(height: AppSpace.l),
            _SectionHeader(
              iconKey: 'reviewRegularity',
              fallbackIcon: Icons.check_circle_outline_rounded,
              title: 'Les points positifs',
              subtitle: 'Les habitudes déjà réalisées ou les plafonds respectés.',
            ),
            const SizedBox(height: AppSpace.s),
            if (insights.isEmpty)
              _AppCard(tone: _CardTone.soft, child: Text('Aucun objectif quotidien ou hebdomadaire à évaluer. Tu peux les configurer dans l’onglet Objectifs.', style: _hintStyle()))
            else if (insights.where((i) => i.satisfied).isEmpty)
              _AppCard(tone: _CardTone.soft, child: Text('Aucun objectif minimum atteint pour le moment. La semaine est en cours : chaque occasion reste utile.', style: _hintStyle()))
            else
              for (final insight in insights.where((i) => i.satisfied))
                _goalInsightCard(insight),
            const SizedBox(height: AppSpace.l),
            _SectionHeader(
              iconKey: 'reviewDifficult',
              fallbackIcon: Icons.flag_outlined,
              title: 'Les habitudes à renforcer',
              subtitle: 'Les objectifs minimums qui ne sont pas encore atteints et les plafonds dépassés.',
            ),
            const SizedBox(height: AppSpace.s),
            if (insights.isEmpty)
              _AppCard(tone: _CardTone.soft, child: Text('Pas de point faible hebdomadaire à signaler : seuls les repères mensuels sont éventuellement listés plus bas.', style: _hintStyle()))
            else if (insights.where((i) => !i.satisfied).isEmpty)
              _AppCard(tone: _CardTone.soft, child: Text('Rien à corriger pour le moment. Continue simplement à suivre tes habitudes.', style: _hintStyle()))
            else
              for (final insight in insights.where((i) => !i.satisfied))
                _goalInsightCard(insight),
            if (monthly.isNotEmpty) ...[
              const SizedBox(height: AppSpace.l),
              _SectionHeader(
                iconKey: 'calendar',
                fallbackIcon: Icons.calendar_month_outlined,
                title: 'Repères mensuels',
                subtitle: 'Ces objectifs restent évalués sur le mois, pas sur la seule semaine.',
              ),
              const SizedBox(height: AppSpace.s),
              _AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final line in monthly) Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.xs),
                  child: Text(line, style: TextStyle(fontSize: AppType.small, color: _colors.textStrong)),
                ),
              ])),
            ],
            const SizedBox(height: AppSpace.l),
            _SectionHeader(
              iconKey: 'nextWeekDirections',
              fallbackIcon: Icons.lightbulb_outline_rounded,
              title: 'Orientations pour la suite',
            ),
            const SizedBox(height: AppSpace.s),
            _AppCard(
              tone: _CardTone.soft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (insights.isEmpty)
                  Text('Ajoute tes objectifs Nutrition dans l’onglet Objectifs pour obtenir une analyse personnalisée de tes habitudes.', style: _hintStyle())
                else if (toDo == 0 && exceeded == 0)
                  Text('Tes objectifs sont actuellement tenus. Garde les mêmes repères pour les repas restants et privilégie la régularité plutôt que la perfection.', style: _hintStyle())
                else ...[
                  if (toDo > 0)
                    _insightLine(
                      icon: Icons.event_available_outlined,
                      color: _colors.accentIcon,
                      title: 'Planifier les habitudes restantes',
                      detail: 'Choisis dès maintenant un ou plusieurs repas pour réaliser les ${toDo} habitude${toDo > 1 ? 's' : ''} encore à compléter.',
                    ),
                  if (exceeded > 0)
                    _insightLine(
                      icon: Icons.tune_rounded,
                      color: _colors.warnBorder,
                      title: 'Rééquilibrer sans culpabiliser',
                      detail: 'Un plafond est dépassé. Pour les repas restants, varie les choix et reviens simplement vers le cadre que tu as défini.',
                    ),
                  _insightLine(
                    icon: Icons.check_circle_outline_rounded,
                    color: _colors.accentIcon,
                    title: 'Conserver ce qui fonctionne',
                    detail: 'Les habitudes déjà réussies sont de bons points d’appui. Pas besoin de compenser : poursuis ton rythme habituel.',
                  ),
                ],
              ]),
            ),
            if (nutritionActivities.isEmpty) ...[
              const SizedBox(height: AppSpace.m),
              Text('Aucune activité Nutrition n’est encore créée.', style: _hintStyle()),
            ],
            const SizedBox(height: AppSpace.l),
            Text('Analyse fondée sur les réalisations enregistrées et les objectifs de l’onglet Objectifs. Elle aide à organiser les habitudes, sans remplacer un avis médical ou diététique.', textAlign: TextAlign.center, style: _hintStyle()),
          ])),
        ]),
      ),
    );
  }
}
