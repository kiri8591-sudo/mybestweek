// V9.25 — Helpers de rythme, focus du jour et rendu du planning
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _HomePlanningPart on _MaBelleSemaineAppState {
  String _baseDayMood(int day) {
    const moods = [
      'Focus musique & intérieur',
      'Équilibre actif',
      'Le grand jour du marché',
      'Créativité & bien-être',
      'Nature & plein air',
      'Sorties & loisirs',
      'Détente',
    ];
    return moods[day];
  }

  List<ActivityLog> _recentHistory([int days = 14]) {
    final now = DateTime.now();
    return logs.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 0 && age < days;
    }).toList();
  }

  int _historyActivityCount(Activity activity, {int days = 30}) {
    return _recentHistory(days).where((log) => _logMatchesActivity(log, activity)).length;
  }

  _ActivityLearningProfile _activityLearning(Activity activity, {int days = 60}) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final matched = logs.where((log) {
      if (log.date.isBefore(cutoff) || !_logMatchesActivity(log, activity)) return false;
      return !log.date.isAfter(now);
    }).toList();

    final dayCounts = <int, int>{};
    final periodCounts = <String, int>{};
    var recent7Count = 0;
    var difficultCount = 0;
    var veryGoodCount = 0;
    var realisedMinutes = 0;
    var plannedMinutes = 0;

    final skippedDayCounts = <int, int>{};
    final skippedPeriodCounts = <String, int>{};
    var skippedCount = 0;

    for (final item in plan) {
      if (item.day >= DateTime.now().weekday - 1) continue;
      if (item.activityId != activity.id || item.done) continue;
      if (item.day < 0 || item.day > 6) continue;
      skippedCount++;
      skippedDayCounts[item.day] = (skippedDayCounts[item.day] ?? 0) + 1;
      final period = item.period == 'Midi' ? 'Après-midi' : item.period;
      skippedPeriodCounts[period] = (skippedPeriodCounts[period] ?? 0) + 1;
    }

    for (final log in matched) {
      dayCounts[log.day] = (dayCounts[log.day] ?? 0) + 1;
      final period = log.period == 'Midi' ? 'Après-midi' : log.period;
      periodCounts[period] = (periodCounts[period] ?? 0) + 1;
      final age = now.difference(log.date).inDays;
      if (age < 7) recent7Count++;
      final feeling = _normalizeFeeling(log.feeling);
      if (feeling == 'Difficile') difficultCount++;
      if (feeling == 'Très bien') veryGoodCount++;
      realisedMinutes += max(0, log.realisedMinutes);
      plannedMinutes += max(0, log.plannedMinutes);
    }

    var movedFromCount = 0;
    var movedToCount = 0;
    final movedToDayCounts = <int, int>{};
    for (final move in activityMoveLogs) {
      if (move.date.isBefore(cutoff) || move.date.isAfter(now)) continue;
      final matches = move.activityId == activity.id ||
          (move.activityId == null && move.activityName.trim().toLowerCase() == activity.name.trim().toLowerCase());
      if (!matches) continue;
      movedFromCount++;
      movedToCount++;
      if (move.toDay >= 0 && move.toDay <= 6) {
        movedToDayCounts[move.toDay] = (movedToDayCounts[move.toDay] ?? 0) + 1;
      }
    }

    return _ActivityLearningProfile(
      realisedCount: matched.length,
      skippedCount: skippedCount,
      recent7Count: recent7Count,
      dayCounts: dayCounts,
      skippedDayCounts: skippedDayCounts,
      periodCounts: periodCounts,
      skippedPeriodCounts: skippedPeriodCounts,
      movedToDayCounts: movedToDayCounts,
      difficultCount: difficultCount,
      veryGoodCount: veryGoodCount,
      realisedMinutes: realisedMinutes,
      plannedMinutes: plannedMinutes,
      movedFromCount: movedFromCount,
      movedToCount: movedToCount,
    );
  }

  String? _learnedPeriodForGeneration(Activity activity) {
    if (!_generationLearnHabits || _isSportActivity(activity) || activity.isSportProgram) return null;
    final profile = _activityLearning(activity);
    if (!profile.hasEnoughData || profile.bestPeriod == null) return null;
    final period = profile.bestPeriod!;
    return profile.periodShare(period) >= .60 ? period : null;
  }

  String _todayFocus() {
    final todayItems = actionableItemsForDay(today);
    final remaining = todayItems.where((item) => !item.done).toList();
    final done = todayItems.length - remaining.length;
    final remainingActivities = remaining
        .map((item) => item.activityId == null ? null : findActivity(item.activityId!))
        .whereType<Activity>()
        .toList();
    final doneActivities = todayItems
        .where((item) => item.done)
        .map((item) => item.activityId == null ? null : findActivity(item.activityId!))
        .whereType<Activity>()
        .toList();

    // Le Focus accompagne le planning existant : il ne crée ni ne déplace
    // jamais d'activité. Après chaque validation, ce calcul est rappelé et
    // peut donc faire évoluer le fil conducteur de la journée.
    if (todayItems.isNotEmpty && remaining.isEmpty) {
      return 'Journée accomplie ✨';
    }

    final weather = _weatherForWeekDay(today);
    final recent7 = _recentHistory(7);
    final recent7Minutes = recent7.fold<int>(0, (sum, log) => sum + max(0, log.realisedMinutes));
    final recent7Difficult = recent7.where((log) => _normalizeFeeling(log.feeling) == 'Difficile').length;
    final recent7VeryGood = recent7.where((log) => _normalizeFeeling(log.feeling) == 'Très bien').length;
    final outdoorRemaining = remainingActivities.where(_isOutdoorPlanningActivity).toList();
    final sportRemaining = remainingActivities.where((a) => a.category == 'Sport').toList();
    final pianoRemaining = remainingActivities.where((a) => a.name.toLowerCase().contains('piano')).toList();
    final wellnessRemaining = remainingActivities.where((a) => a.category == 'Bien-être').toList();
    final cultureRemaining = remainingActivities.where((a) => a.category == 'Culture').toList();
    final socialRemaining = remainingActivities.where((a) => a.category == 'Social').toList();
    final otherRemaining = remainingActivities.where((a) =>
        a.category != 'Sport' &&
        !_isOutdoorPlanningActivity(a) &&
        !a.name.toLowerCase().contains('piano') &&
        a.category != 'Bien-être' &&
        a.category != 'Culture' &&
        a.category != 'Social').toList();

    final moment = _clockNow.hour;
    final isMorning = moment < 12;
    final isAfternoon = moment >= 12 && moment < 18;
    final isEvening = moment >= 18;

    // La météo passe avant tout lorsqu'une activité extérieure reste réellement
    // à vivre. Le focus ne conseille pas de sortie s'il n'y en a pas au planning.
    if (weather?.outdoorBad == true && outdoorRemaining.isNotEmpty) {
      return isMorning
          ? 'Commencer doucement et garder la sortie pour un moment plus favorable 🌦️'
          : 'Adapter la suite de la journée à la météo 🌦️';
    }

    // Quand la semaine récente a été chargée ou ressentie comme difficile,
    // le fil conducteur privilégie la respiration plutôt que l'accumulation.
    if (recent7Minutes >= 420 || recent7Difficult >= 3) {
      if (wellnessRemaining.isNotEmpty) return 'Aujourd’hui, privilégier un rythme doux et prendre soin de soi 🌿';
      if (remaining.length <= 2) return 'Garder de l’espace pour profiter, sans chercher à remplir la journée 🌿';
    }

    // Après un ou plusieurs moments déjà réalisés, le focus passe du programme
    // abstrait à ce qu’il reste réellement à vivre.
    if (done > 0 && remaining.isNotEmpty) {
      if (pianoRemaining.isNotEmpty && sportRemaining.isNotEmpty) {
        return isEvening
            ? 'La journée avance : un peu de musique pour terminer en douceur 🎵'
            : 'Après ce qui est déjà fait, garder un bel équilibre entre musique et mouvement 🎵💪';
      }
      if (wellnessRemaining.isNotEmpty && doneActivities.any((a) => a.category == 'Sport')) {
        return 'Après le mouvement, place maintenant à la récupération et au bien-être 🌿';
      }
      if (cultureRemaining.isNotEmpty && doneActivities.any((a) => a.category == 'Sport' || a.category == 'Bien-être')) {
        return 'Après l’action, laisser une place à la curiosité 📚';
      }
      if (outdoorRemaining.isNotEmpty && weather?.outdoorBad != true) {
        return 'La journée est déjà lancée : profiter maintenant d’un peu de plein air ☀️';
      }
      if (remaining.length == 1) {
        final last = remainingActivities.isNotEmpty ? remainingActivities.first : null;
        if (last != null && last.category == 'Sport') return 'Un dernier moment de mouvement, puis place au reste de la journée 💪';
        if (last != null && last.category == 'Bien-être') return 'Un dernier moment pour prendre soin de soi 🌿';
        if (last != null && last.category == 'Culture') return 'Il reste un moment de curiosité à savourer 📚';
        if (last != null && last.category == 'Sortie') return 'Il reste une occasion de profiter de l’extérieur ☀️';
        return 'Un dernier petit moment à vivre aujourd’hui ✨';
      }
    }

    // Sans réalisation préalable, le focus s'appuie sur la forme de la journée
    // et sur l'activité dominante, plutôt que de simplement afficher son nom.
    if (pianoRemaining.isNotEmpty && sportRemaining.isNotEmpty) {
      return isMorning
          ? 'Commencer par quelques notes, puis laisser place au mouvement 🎵💪'
          : 'Garder aujourd’hui un équilibre entre musique et mouvement 🎵💪';
    }
    if (pianoRemaining.isNotEmpty) {
      return isMorning ? 'Quelques notes pour donner le ton à la journée 🎵' : 'Un moment de piano, sans se presser 🎵';
    }
    if (sportRemaining.isNotEmpty) {
      return isMorning ? 'Mettre un peu de mouvement dans la journée 💪' : 'Bouger avec plaisir, au bon moment 💪';
    }
    if (wellnessRemaining.isNotEmpty) {
      return 'Prendre soin de soi fait aussi partie du programme 🌿';
    }
    if (cultureRemaining.isNotEmpty) {
      return 'Garder une place aujourd’hui pour la curiosité 📚';
    }
    if (socialRemaining.isNotEmpty) {
      return 'Un peu de lien et de plaisir dans la journée ☀️';
    }
    if (outdoorRemaining.isNotEmpty) {
      return weather == null
          ? 'Profiter du plein air quand le moment se présente ☀️'
          : 'Profiter de l’extérieur au bon moment ☀️';
    }
    if (otherRemaining.isNotEmpty) {
      return isAfternoon ? 'Avancer tranquillement, un moment après l’autre ✨' : 'Donner la priorité aux bons moments de la journée ✨';
    }

    // Pas de planning actif : le Focus s’appuie alors uniquement sur le rythme
    // récent et la météo, sans inventer d’activité.
    if (recent7VeryGood >= 3 && recent7Difficult == 0) return 'Le rythme semble bon : continuer simplement à profiter de la journée ☀️';
    if (recent7.isEmpty) return _baseDayMood(today);
    return recent7Difficult >= 2 ? 'Respirer, ralentir un peu et garder de la place pour l’imprévu 🌿' : _baseDayMood(today);
  }

  String _todayFocusReason() {
    final todayItems = actionableItemsForDay(today);
    final remaining = todayItems.where((item) => !item.done).toList();
    final done = todayItems.length - remaining.length;
    if (todayItems.isNotEmpty && remaining.isEmpty) {
      return 'Tous les moments actifs prévus aujourd’hui sont terminés. Le reste de la journée est à toi.';
    }
    final weather = _weatherForWeekDay(today);
    final outdoor = remaining.any((item) {
      final a = item.activityId == null ? null : findActivity(item.activityId!);
      return a != null && _isOutdoorPlanningActivity(a);
    });
    if (weather?.outdoorBad == true && outdoor) {
      return '${weather!.icon} ${weather.text}${weather.temperature.isEmpty ? '' : ' · ${weather.temperature}'}. Le focus s’adapte pour préserver les activités extérieures.';
    }
    final names = remaining.map((item) => item.title).where((s) => s.trim().isNotEmpty).take(2).join(' · ');
    if (names.isNotEmpty) {
      return done > 0
          ? 'Déjà $done moment(s) validé(s). Le focus se recentre sur ce qui reste, avec la météo et le rythme récent en toile de fond.'
          : 'Le focus regarde d’abord ce qui est réellement prévu, puis le moment de la journée, la météo et le rythme récent.';
    }
    return 'J’adapte le focus à ce qui reste de la journée, sans ajouter ni déplacer d’activité.';
  }

  Widget _dayMood(int day) {
    final mood = day == today ? _todayFocus() : _baseDayMood(day);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(mood, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textWarm))),
        if (day == today)
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('FOCUS DU JOUR', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800, color: _colors.danger)),
          ),
      ],
    );
  }

  Widget _timeLine(String time, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(time, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.accentText))),
        Expanded(child: Text(title, style: TextStyle(fontSize: AppType.bodyL, color: _colors.textStrong))),
      ]),
    );
  }

  bool _isPastPlanPeriod(PlanItem item) {
    if (item.day != today || item.done) return false;
    final h = _clockNow.hour;
    switch (item.period) {
      case 'Matin':
        return h >= 12;
      case 'Après-midi':
        return h >= 18;
      case 'Soir':
        return h >= 22;
      default:
        return false;
    }
  }

  Future<void> _markPlanItemDoneQuick(PlanItem item) async {
    if (!mounted) return;
    setState(() => item.done = true);
    _queueLocalStatePersist();
    _showFeedback('« ${item.title} » marqué comme fait.');
  }

  void _showPastPlanQuickActions(PlanItem item) {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Ce créneau est passé. Que veux-tu en faire ?', style: TextStyle(color: _colors.textMuted)),
              const SizedBox(height: 12),
              ListTile(
                leading: _uiIcon('confirm', Icons.check_circle_outline_rounded, size: 22),
                title: const Text('Fait'),
                onTap: () { Navigator.pop(context); _markPlanItemDoneQuick(item); },
              ),
              ListTile(
                leading: _uiIcon('move', Icons.event_repeat_outlined, size: 22),
                title: const Text('Reporter'),
                onTap: () { Navigator.pop(context); _moveGenericOrRegularPlanItem(item); },
              ),
              ListTile(
                leading: _uiIcon('remove', Icons.remove_circle_outline, size: 22),
                title: const Text('Passer'),
                onTap: () { Navigator.pop(context); _removePlanOccurrence(item); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveGenericOrRegularPlanItem(PlanItem item) async {
    if (_isGenericActivityItem(item)) {
      await _movePlanItemDay(item);
      return;
    }
    await _moveRegularPlanItemDay(item);
  }

  Future<void> _moveRegularPlanItemDay(PlanItem item) async {
    var selectedDay = item.day;
    var selectedPeriod = item.period == 'Midi' ? 'Après-midi' : item.period;
    final result = await showDialog<Map<String, dynamic>>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Reporter l’activité'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: selectedDay,
              decoration: const InputDecoration(labelText: 'Jour'),
              items: List.generate(7, (day) => DropdownMenuItem<int>(value: day, child: Text(dayNames[day]))),
              onChanged: (value) { if (value != null) setDialogState(() => selectedDay = value); },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedPeriod,
              decoration: const InputDecoration(labelText: 'Moment'),
              items: const ['Matin', 'Après-midi', 'Soir'].map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
              onChanged: (value) { if (value != null) setDialogState(() => selectedPeriod = value); },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {'day': selectedDay, 'period': selectedPeriod}), child: const Text('Reporter')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final newDay = result['day'] as int;
    final newPeriod = result['period'] as String;
    setState(() {
      final index = plan.indexOf(item);
      if (index >= 0) {
        plan[index] = PlanItem(
          id: 'reschedule_${DateTime.now().microsecondsSinceEpoch}',
          day: newDay,
          period: newPeriod,
          timeLabel: item.timeLabel,
          activityId: item.activityId,
          title: item.title,
          duration: item.duration,
          details: item.details,
          customEmoji: item.customEmoji,
          customCategory: item.customCategory,
          optional: item.optional,
          userAdded: item.userAdded,
          fixedInWeeklyTemplate: item.fixedInWeeklyTemplate,
          manualPlacement: true,
          done: false,
          realisedMinutes: null,
          feeling: null,
        );
      }
    });
    _sortPlan();
    _queueLocalStatePersist();
    _showFeedback('« ${item.title} » reporté.');
  }

  Widget planRow(
    PlanItem item, {
    bool highlightMission = false,
    bool showPastQuickActions = false,
  }) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final emoji = _planItemIconValue(item, activities);
    final isGeneric = _isGenericActivityItem(item);
    final isSport = activity != null && _isSportActivity(activity);
    final isPast = showPastQuickActions && _isPastPlanPeriod(item);
    final isDailyPriority = item.day == today && _isDailyPriorityActivityId(item.activityId);

    final planCard = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Opacity(
        opacity: isPast ? .60 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(7, 6, 5, 6),
          decoration: BoxDecoration(
            color: _colors.card,
            borderRadius: BorderRadius.circular(AppRadius.l),
            border: Border.all(
              color: highlightMission ? _colors.warnBorder : _colors.border,
              width: highlightMission ? 1.25 : 1,
            ),
            boxShadow: [BoxShadow(color: _colors.shadowSoft, blurRadius: 5, offset: Offset(0, 2))],
          ),
          child: Row(
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
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  onTap: () {
                    if (isPast) {
                      _showPastPlanQuickActions(item);
                      return;
                    }
                    if (activity != null && isSport) {
                      addOrEditActivity(original: activity);
                    } else if (isGeneric) {
                      _openGenericActivity(item);
                    } else {
                      openItemActions(item);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (highlightMission) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _colors.warnBg,
                                  borderRadius: BorderRadius.circular(AppRadius.s),
                                  border: Border.all(color: _colors.warnBorder),
                                ),
                                child: Text(
                                  'MISSION',
                                  style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800, letterSpacing: .45, color: _colors.danger),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: _detailTitleStyle(decoration: item.done ? TextDecoration.lineThrough : null),
                              ),
                            ),
                          ],
                        ),
                        if (highlightMission) ...[
                          const SizedBox(height: 2),
                          Text(
                            activity != null
                                ? 'Je te propose de commencer par ce moment ${activity.category.toLowerCase()}, puis de laisser une place à la curiosité.'
                                : 'Je te propose de commencer par ce moment, puis de laisser une place à la curiosité.',
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textWarm, height: 1.15),
                          ),
                        ],
                        if (isSport || highlightMission || isDailyPriority || activity != null) ...[
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              if (isSport)
                                Text(
                                  item.done ? '${item.realisedMinutes ?? item.duration} / ${item.duration} min' : '${item.duration} min',
                                  style: _detailMetaStyle(),
                                ),
                              if (highlightMission && !isSport)
                                Text('${item.duration} min · ${item.period}', style: _detailMetaStyle()),
                              if (isDailyPriority)
                                _uiIcon('priority', Icons.star_rounded, size: 13, color: _colors.goldText),
                              if (activity != null) _frozenActivityMarker(activity),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (isSport)
                IconButton(
                  tooltip: 'Modifier le temps réalisé',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  onPressed: () => _editSportRealisedMinutes(item, activity!),
                  icon: _uiIcon('duration', Icons.timer_outlined, size: 18, color: _colors.textMuted),
                ),
              PopupMenuButton<String>(
                tooltip: 'Autres actions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                icon: _uiIcon('settings', Icons.more_horiz_rounded, size: 19, color: _colors.textMuted),
                onSelected: (value) {
                  if (value == 'why') _showPlanItemCoachReason(item);
                  if (value == 'edit') {
                    final a = item.activityId == null ? null : findActivity(item.activityId!);
                    if (a != null && _isSportActivity(a)) {
                      addOrEditActivity(original: a);
                    } else if (isGeneric) {
                      _movePlanItemDay(item);
                    } else {
                      openItemActions(item);
                    }
                  }
                  if (value == 'remove') _removePlanOccurrence(item);
                  if (value == 'past') _showPastPlanQuickActions(item);
                },
                itemBuilder: (context) => [
                  if (isGeneric && item.details != null) const PopupMenuItem<String>(value: 'why', child: Text('Pourquoi ce moment ?')),
                  PopupMenuItem<String>(value: 'edit', child: Text(isGeneric ? 'Déplacer' : 'Voir / modifier')),
                  if (isPast) const PopupMenuItem<String>(value: 'past', child: Text('Fait · Reporter · Passer')),
                  const PopupMenuItem<String>(value: 'remove', child: Text('Retirer du jour')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!isGeneric) return planCard;

    final feedback = Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Opacity(opacity: .90, child: planCard),
      ),
    );

    // Desktop/web: immediate drag. iPhone/iPad: long press, puis déplacement.
    if (kIsWeb) {
      return Draggable<PlanItem>(
        data: item,
        maxSimultaneousDrags: 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: .30, child: planCard),
        child: planCard,
      );
    }
    return LongPressDraggable<PlanItem>(
      data: item,
      hapticFeedbackOnStart: true,
      maxSimultaneousDrags: 1,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: .30, child: planCard),
      child: planCard,
    );
  }

}
