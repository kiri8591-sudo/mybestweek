// V12.25.1 — Carte Nutrition autonome sur l'écran d'accueil.
// Les activités de cette catégorie sont séparées des créneaux horaires,
// sur le même principe que la carte Sport.

part of '../main.dart';

extension _NutritionHomePart on _MaBelleSemaineAppState {
  bool _isNutritionActivity(Activity activity) =>
      activity.category.trim().toLowerCase() == 'nutrition';

  bool _isNutritionPlanItem(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    if (activity != null) return _isNutritionActivity(activity);
    return (item.customCategory ?? '').trim().toLowerCase() == 'nutrition';
  }

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
      ),
    );
  }

  Widget _nutritionDayCard(int day, {bool compactHome = false}) {
    final items = _nutritionItemsForDay(day);
    final done = items.where((item) => item.done).length;
    final allDone = items.isNotEmpty && items.every((item) => item.done);
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
                        items.isEmpty
                            ? 'Aucune habitude prévue aujourd’hui'
                            : '$done/${items.length} habitudes réalisées',
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
                  tooltip: 'Ajouter une activité Nutrition',
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
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 7, 4, 3),
                child: Text(
                  'Aucune activité Nutrition proposée ce jour.',
                  style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                ),
              )
            else
              ...items.map(_nutritionItemRow),
          ],
        ],
      ),
    );
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
            Checkbox(
              value: item.done,
              onChanged: (_) => openPlanItem(item),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
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

  Future<void> _addNutritionActivityToDay(int day) async {
    final available = activities
        .where((activity) => _isNutritionActivity(activity) && !activity.isDateRange && !activity.isSportProgram)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

  const _NutritionWeeklyAnalysisSheet({
    required this.activities,
    required this.logs,
    required this.goals,
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
