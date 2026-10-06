// V9.08 — Rendu et interactions Sport restants
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _SportRuntimeUiPart on _MaBelleSemaineAppState {
  List<PlanItem> _sportItemsForDay(int day) {
    return plan.where((item) {
      if (item.day != day || item.activityId == null) return false;
      final activity = findActivity(item.activityId!);
      return activity != null && _isSportActivity(activity);
    }).toList();
  }

  Widget _sportDayCard(int day, {bool compactHome = false}) {
    final items = _sportItemsForDay(day);
    final target = _sportBudgetForDay(day);
    final planned = items.fold<int>(0, (sum, item) => sum + item.duration);
    final validated = items.where((item) => item.done).fold<int>(0, (sum, item) => sum + item.duration);
    final over = planned > target;
    final completedHome = compactHome && items.isNotEmpty && items.every((item) => item.done);
    final collapsedHome = completedHome && !_homeSportExpanded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: BoxDecoration(
        color: _colors.tintStrong,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: over ? _colors.danger : _colors.borderTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (collapsedHome)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.m),
              onTap: () => setState(() => _homeSportExpanded = true),
              child: Row(
                children: [
                  _activityIconWidget(_sportProgram?.emoji ?? '🏃', size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Habitudes Sport · $validated/$target min ✓',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.accentText),
                    ),
                  ),
                  _uiIcon('sportWeek', Icons.calendar_view_week_outlined, size: 17, color: _colors.textMuted),
                ],
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _activityIconWidget(_sportProgram?.emoji ?? '🏃', size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Habitudes quotidiennes · Sport',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.accentText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$validated / $target min',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _addSportActivityToDay(day),
                  icon: _uiIcon('add', Icons.add_circle_outline, size: 16),
                  label: const Text('Ajouter', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
                  tooltip: 'Journal du coach Sport',
                  onPressed: openSportCoachJournal,
                  icon: _uiIcon('history', Icons.menu_book_rounded, size: 17),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
                  tooltip: 'Semaine Sport',
                  onPressed: openSportWeekOverview,
                  icon: _uiIcon('sportWeek', Icons.calendar_view_week_outlined, size: 17),
                ),
                if (completedHome)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
                    tooltip: 'Replier Habitudes Sport',
                    onPressed: () => setState(() => _homeSportExpanded = false),
                    icon: _uiIcon('chevronUp', Icons.keyboard_arrow_up_rounded, size: 18, color: _colors.textMuted),
                  ),
              ],
            ),
          ],
          if (!collapsedHome) ...[
            const SizedBox(height: 2),
            if (items.isEmpty)
              Text('Aucune activité Sport proposée ce jour.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted))
            else
              ...items.map((item) => _sportItemRow(item, compactHome: compactHome)),
          ],
        ],
      ),
    );
  }

  Widget _sportItemRow(PlanItem item, {bool compactHome = false}) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final emoji = _planItemIconValue(item, activities);
    final sameDay = activity == null ? <PlanItem>[] : _sportItemsForDay(item.day).where((p) => p.activityId == item.activityId).toList();
    final occurrence = sameDay.indexWhere((p) => p.id == item.id) + 1;
    final repeated = sameDay.length > 1;
    final titleStyle = _detailTitleStyle(decoration: item.done ? TextDecoration.lineThrough : null);

    Widget titlePart() => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.m),
            onTap: activity == null ? null : () => addOrEditActivity(original: activity),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.done ? '${item.realisedMinutes ?? item.duration} / ${item.duration} min' : '${item.duration} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppType.caption,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: _colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    Widget actions() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activity != null)
              IconButton(
                tooltip: 'Modifier le temps réalisé',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _editSportRealisedMinutes(item, activity),
                icon: _uiIcon('duration', Icons.timer_outlined, size: 18, color: _colors.textMuted),
              ),
            PopupMenuButton<String>(
              tooltip: 'Autres actions',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              icon: _uiIcon('settings', Icons.more_horiz_rounded, size: 19, color: _colors.textMuted),
              onSelected: (value) {
                if (value == 'duration' && activity != null) _editSportRealisedMinutes(item, activity);
                if (value == 'edit' && activity != null) addOrEditActivity(original: activity);
                if (value == 'remove') _removePlanOccurrence(item);
              },
              itemBuilder: (context) => [
                if (activity != null) const PopupMenuItem<String>(value: 'duration', child: Text('Temps réalisé')),
                if (activity != null) const PopupMenuItem<String>(value: 'edit', child: Text('Voir / modifier')),
                const PopupMenuItem<String>(value: 'remove', child: Text('Retirer du jour')),
              ],
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(7, 6, 5, 6),
        decoration: BoxDecoration(
          color: _colors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: _colors.border),
          boxShadow: [BoxShadow(color: _colors.shadowSoft, blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 500;
            final titleLeading = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: item.done,
                  onChanged: (_) => openPlanItem(item),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                ),
                const SizedBox(width: 3),
                _activityIconWidget(emoji, size: 28),
                const SizedBox(width: 8),
                titlePart(),
                if (!narrow && !compactHome && activity != null) ...[
                  const SizedBox(width: 7),
                  _sportWeeklyIndicator(activity),
                ],
                if (!narrow) actions(),
              ],
            );

            if (!narrow) return titleLeading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: item.done,
                      onChanged: (_) => openPlanItem(item),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                    ),
                    const SizedBox(width: 3),
                    _activityIconWidget(emoji, size: 28),
                    const SizedBox(width: 8),
                    titlePart(),
                    // En mode Home étroit, les actions restent accessibles
                    // sur la seconde ligne sans comprimer le libellé.
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 38, top: 2),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      if (repeated)
                        Text('$occurrence/${sameDay.length}', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.accentIcon)),
                      if (activity != null) _frozenActivityMarker(activity),
                      if (!compactHome && activity != null) _sportWeeklyIndicator(activity),
                      if (compactHome) actions(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addSportActivityToDay(int day) async {
    final budget = _sportBudgetForDay(day);
    if (budget <= 0) {
      final program = _sportProgram;
      if (program == null) {
        _showFeedback('Crée d’abord l’activité générique « Sport » pour disposer d’un budget quotidien.');
        return;
      }
      final configure = await showDialog<bool>(
        context: _navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Text('Sport · ${dayNames[day]}'),
          content: const Text('Aucun budget Sport n’est configuré pour ce jour. Configure sa durée quotidienne dans la fiche Sport avant d’ajouter une activité.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Configurer')),
          ],
        ),
      );
      if (configure == true && mounted) { addOrEditActivity(original: program); }
      return;
    }
    final items = _sportItemsForDay(day);
    final used = items.fold<int>(0, (sum, item) => sum + item.duration);
    final available = activities.where(_isSportActivity).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selected = await showModalBottomSheet<Activity>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ajouter au planning Sport · ${dayNames[day]}', style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Budget : $used / $budget min utilisés', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: available.length,
                itemBuilder: (_, index) {
                  final activity = available[index];
                  final count = items.where((p) => p.activityId == activity.id).length;
                  final maxDaily = activity.allowMultiplePerDay ? activity.maxDailyOccurrences.clamp(2, 3).toInt() : 1;
                  final dailyRoom = count < maxDaily;
                  final exceedsBudget = used + activity.duration > budget;
                  final canAdd = dailyRoom;
                  return ListTile(
                    enabled: canAdd,
                    leading: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      onTap: () => _editActivityIcon(activity),
                      child: Tooltip(message: 'Modifier l’icône', child: _activityIconWidget(activity.emoji, size: 28)),
                    ),
                    title: Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textStrong)),
                    subtitle: Text('${activity.duration} min · ${count >= maxDaily ? 'maximum quotidien atteint' : exceedsBudget ? 'budget atteint · confirmation nécessaire' : 'ajouter 1 occurrence'}'),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Modifier l’icône',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _editActivityIcon(activity),
                          icon: _uiIcon('edit', Icons.edit_outlined, size: 17),
                        ),
                        _uiIcon(canAdd ? 'add' : 'sportWarning', canAdd ? Icons.add_circle_outline : Icons.block_outlined, size: 18),
                      ],
                    ),
                    onTap: canAdd ? () => Navigator.pop(context, activity) : null,
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    _prepareUndoSnapshot();
    final newItem = PlanItem(
      id: 'sport_manual_plan_${selected.id}_${day}_${DateTime.now().microsecondsSinceEpoch}',
      day: day,
      period: _periodForActivity(selected, day),
      timeLabel: null,
      activityId: selected.id,
      title: selected.name,
      details: 'Sport · ajouté manuellement au planning ; le coach respecte ce choix.',
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
    });
    _queueLocalStatePersist();
    _showFeedback('« ${selected.name} » ajoutée au Sport de ${dayNames[day]} et protégée comme choix manuel.');
  }

  void toggleSportActivityOnDay(Activity activity, int day) {
    if (!_isSportActivity(activity)) return;
    _toggleSportActivityOnDayQuick(activity, day);
  }

  Future<void> _toggleSportActivityOnDayQuick(Activity activity, int day) async {
    PlanItem? item;
    for (final candidate in plan) {
      if (candidate.day == day && candidate.activityId == activity.id) {
        item = candidate;
        break;
      }
    }

    // Une occurrence déjà prévue : coche = validation rapide, seconde coche = annulation.
    if (item != null) {
      openPlanItem(item);
      return;
    }

    // Réalisation hors jour prévu : demander d'abord le temps réellement réalisé,
    // puis créer l'occurrence manuelle seulement si l'utilisateur confirme.
    final realised = await _askSportRealisedMinutes(
      PlanItem(
        id: 'sport_preview_${activity.id}_${DateTime.now().microsecondsSinceEpoch}',
        activityId: activity.id,
        day: day,
        period: _periodForActivity(activity, day),
        timeLabel: null,
        title: activity.name,
        details: 'Sport · réalisé ce jour, hors jour prévu.',
        duration: activity.duration,
        optional: false,
        userAdded: true,
        fixedInWeeklyTemplate: false,
      ),
      activity,
    );
    if (realised == null || !mounted) return;
    _prepareUndoSnapshot();

    final manualItem = PlanItem(
      id: 'sport_manual_${activity.id}_${day}_${DateTime.now().microsecondsSinceEpoch}',
      activityId: activity.id,
      day: day,
      period: _periodForActivity(activity, day),
      timeLabel: null,
      title: activity.name,
      details: 'Sport · réalisé ce jour, hors jour prévu.',
      duration: activity.duration,
      optional: false,
      userAdded: true,
      fixedInWeeklyTemplate: false,
    );

    setState(() {
      plan.add(manualItem);
      _sortPlan();
    });

    _completePlanItem(manualItem, activity, realised);

    final logIndex = logs.indexWhere((log) => log.planItemId == manualItem.id);
    if (logIndex >= 0) {
      final old = logs[logIndex];
      logs[logIndex] = ActivityLog(
        date: old.date,
        title: old.title,
        emoji: (old.activityId != null ? findActivity(old.activityId!)?.emoji : null) ?? old.emoji,
        category: old.category,
        period: old.period,
        day: old.day,
        plannedMinutes: old.plannedMinutes,
        realisedMinutes: old.realisedMinutes,
        feeling: old.feeling,
        unplanned: true,
        planItemId: old.planItemId,
        activityId: old.activityId,
      );
    }

    _queueLocalStatePersist();
    _showFeedback('✓ « ${activity.name} » réalisé ${dayNames[day]} · $realised min.');
  }


  Widget _sportWeeklyIndicator(Activity activity) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (day) {
        PlanItem? item;
        for (final candidate in plan) {
          if (candidate.day == day && candidate.activityId == activity.id) {
            item = candidate;
            break;
          }
        }
        final active = item?.done == true;
        final planned = item != null && !item!.done;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(labels[day], style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted)),
            const SizedBox(height: 1),
            // Les 7 cases sont uniquement des cases de suivi.
            // Aucune ne doit ouvrir l'écran de modification.
            InkWell(
              onTap: () => toggleSportActivityOnDay(activity, day),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? _colors.accentFill
                      : planned
                          ? _colors.tintStrong
                          : _colors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: active
                        ? _colors.accentFillBorder
                        : _colors.accentSoftBorder,
                  ),
                ),
                child: active
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : planned
                        ? Text('•', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.accentText))
                        : null,
              ),
            ),
          ]),
        );
      }),
    );
  }

  DateTime _weekDateForDay(int day) {
    return _startOfCurrentWeek().add(Duration(days: day));
  }

  String _weekDateShortLabel(int day) {
    final date = _weekDateForDay(day);
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _weeklyPlanningMessage(int day) {
    final date = _weekDateForDay(day);
    final dayLabel = dayNames[day];
    final items = itemsForDay(day);
    final actionable = items.where((item) => !_isDateRangePlanItem(item)).toList();
    final rangeItems = items.where(_isDateRangePlanItem).toList();
    final remaining = actionable.where((item) => !item.done).toList();
    final done = actionable.length - remaining.length;
    final uniqueActivities = <String>[];
    final categories = <String>{};
    for (final item in items) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      final name = activity?.name ?? item.title;
      if (name.trim().isNotEmpty && !uniqueActivities.contains(name)) uniqueActivities.add(name);
      final category = activity?.category;
      if (category != null && category.trim().isNotEmpty) categories.add(category);
    }

    final isToday = day == today;
    final dayWeather = _weatherForWeekDay(day);
    final weatherKnown = dayWeather != null;
    final hasOutdoor = items.any((item) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      return activity != null && _isOutdoorPlanningActivity(activity);
    });
    final hasSport = categories.contains('Sport');
    final hasCulture = categories.contains('Culture') || categories.contains('Loisir');

    String message;
    if (actionable.isNotEmpty && remaining.isEmpty) {
      message = '$dayLabel ${date.day} ${_monthName(date.month)} : tout ce qui était prévu est déjà réalisé. Tu peux garder le reste de la journée libre.';
    } else if (actionable.isEmpty && rangeItems.isNotEmpty) {
      message = '$dayLabel ${date.day} ${_monthName(date.month)} accompagne une activité sur plusieurs jours. Garde de la souplesse autour de ce rendez-vous.';
    } else if (actionable.isEmpty) {
      message = '$dayLabel ${date.day} ${_monthName(date.month)} est encore très libre : profite de cette marge pour choisir selon ton envie.';
    } else if (uniqueActivities.length == 1) {
      message = '$dayLabel ${date.day} ${_monthName(date.month)} s’articule surtout autour de ${uniqueActivities.first}.';
    } else if (uniqueActivities.length <= 3) {
      final names = uniqueActivities.take(3).join(' · ');
      message = '$dayLabel ${date.day} ${_monthName(date.month)} : $names. Le planning donne une direction, pas une obligation.';
    } else {
      message = '$dayLabel ${date.day} ${_monthName(date.month)} est bien remplie (${uniqueActivities.length} activités prévues). Laisse-toi une marge entre les moments.';
    }

    if (weatherKnown) {
      if (dayWeather!.outdoorBad && hasOutdoor) {
        message += ' ${dayWeather.icon} ${dayWeather.text}${dayWeather.temperature.isEmpty ? '' : ' · ${dayWeather.temperature}'}. Prévois une formule intérieure ou adapte la sortie selon les conditions.';
      } else if (!dayWeather.outdoorBad && hasOutdoor) {
        message += ' ${dayWeather.icon} ${dayWeather.text}${dayWeather.temperature.isEmpty ? '' : ' · ${dayWeather.temperature}'}. La météo paraît favorable pour profiter de l’extérieur.';
      } else {
        message += ' ${dayWeather.icon} ${dayWeather.text}${dayWeather.temperature.isEmpty ? '' : ' · ${dayWeather.temperature}'}. Météo du jour prise en compte par le coach.';
      }
    } else if (isToday && hasCulture) {
      message += ' Aujourd’hui, garde aussi un peu de temps pour ce qui te fait plaisir spontanément.';
    }

    if (done > 0 && remaining.isNotEmpty) {
      message += ' ✓ $done déjà réalisé(s), ${remaining.length} à venir.';
    }
    return message;
  }

  String _monthName(int month) {
    const months = <String>[
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return months[(month - 1).clamp(0, 11)];
  }





}
