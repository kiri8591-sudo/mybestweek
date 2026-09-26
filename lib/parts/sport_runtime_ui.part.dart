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

  Widget _sportDayCard(int day) {
    final items = _sportItemsForDay(day);
    final target = _sportBudgetForDay(day);
    final planned = items.fold<int>(0, (sum, item) => sum + item.duration);
    final validated = items.where((item) => item.done).fold<int>(0, (sum, item) => sum + item.duration);
    final over = planned > target;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE2ECE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: over ? const Color(0xFFC67E67) : const Color(0xFFD4E0DA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _activityIconWidget(_sportProgram?.emoji ?? '🏃', size: 22),
          const SizedBox(width: 7),
          Expanded(child: Text('Sport · $planned / $target min prévus · $validated min validés', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF526B78)))),
          TextButton.icon(
            onPressed: () => _addSportActivityToDay(day),
            icon: _uiIcon('add', Icons.add_circle_outline, size: 18),
            label: const Text('Ajouter', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Semaine Sport',
            onPressed: openSportWeekOverview,
            icon: _uiIcon('week', Icons.calendar_view_week_outlined, size: 18),
          ),
        ]),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Aucune activité Sport proposée ce jour.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6F7777)))
        else
          ...items.map((item) => _sportItemRow(item)),
      ]),
    );
  }

  Widget _sportItemRow(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final emoji = _planItemIconValue(item, activities);
    final sameDay = activity == null
        ? <PlanItem>[]
        : _sportItemsForDay(item.day).where((p) => p.activityId == item.activityId).toList();
    final occurrence = sameDay.indexWhere((p) => p.id == item.id) + 1;
    final repeated = sameDay.length > 1;
    final titleStyle = _detailMetaStyle().copyWith(
      fontWeight: FontWeight.w900,
      color: const Color(0xFF3F4B45),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 5, 2, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _activityIconWidget(emoji, size: 25),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: activity == null ? null : () => addOrEditActivity(original: activity),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle.copyWith(decoration: item.done ? TextDecoration.lineThrough : null),
                        ),
                      ),
                      if (repeated) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2ED),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '$occurrence/${sameDay.length}',
                            style: _detailMetaStyle().copyWith(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF6F8E80)),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Retirer du jour',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => _removePlanOccurrence(item),
                icon: _uiIcon('remove', Icons.remove_circle_outline, size: 17, color: const Color(0xFFC27D68)),
              ),
            ]),
            const SizedBox(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  item.done ? '${item.realisedMinutes ?? item.duration} / ${item.duration} min' : '${item.duration} min',
                  style: _detailMetaStyle(),
                ),
                const SizedBox(width: 3),
                if (!item.done && activity != null)
                  IconButton(
                    tooltip: 'Saisir un temps différent',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _editSportRealisedMinutes(item, activity),
                    icon: _uiIcon('duration', Icons.timer_outlined, size: 17, color: const Color(0xFF7A8C84)),
                  ),
                if (activity != null) ...[
                  const SizedBox(width: 1),
                  _sportWeeklyIndicator(activity),
                  const SizedBox(width: 2),
                ],
                Checkbox(
                  value: item.done,
                  onChanged: (_) => openPlanItem(item),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
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
            Text('Ajouter au planning Sport · ${dayNames[day]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Budget : $used / $budget min utilisés', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6F7777))),
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
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _editActivityIcon(activity),
                      child: Tooltip(message: 'Modifier l’icône', child: _activityIconWidget(activity.emoji, size: 28)),
                    ),
                    title: Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
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
                        Icon(canAdd ? Icons.add_circle_outline : Icons.block_outlined),
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
            Text(labels[day], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF6F7777))),
            const SizedBox(height: 1),
            // Les 7 cases sont uniquement des cases de suivi.
            // Aucune ne doit ouvrir l'écran de modification.
            InkWell(
              onTap: () => toggleSportActivityOnDay(activity, day),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF7D988D)
                      : planned
                          ? const Color(0xFFE5EEE9)
                          : const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF6C887A)
                        : const Color(0xFFBFCFC7),
                  ),
                ),
                child: active
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : planned
                        ? const Text('•', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF526B78)))
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
