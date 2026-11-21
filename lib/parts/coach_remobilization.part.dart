// V12.26.15 — Coach Motivation & Progression.
// Détection des objectifs en retard / irréguliers, compréhension des freins,
// reprise planifiée en version courte et accompagnement dans le bilan hebdomadaire.

part of '../main.dart';

enum _CoachRemobilizationLevel {
  atRisk,
  missedOnce,
  recurring,
  pattern,
  returnToTrack,
  overLimit,
}

class _CoachRemobilizationItem {
  final Activity activity;
  final RealizationGoal goal;
  final int currentCount;
  final int target;
  final int missedPeriods;
  final String periodLabel;
  final _CoachRemobilizationLevel level;

  const _CoachRemobilizationItem({
    required this.activity,
    required this.goal,
    required this.currentCount,
    required this.target,
    required this.missedPeriods,
    required this.periodLabel,
    required this.level,
  });

  String get progressLabel => goal.isMaximum
      ? '$currentCount/$target maximum $periodLabel'
      : '$currentCount/$target $periodLabel';

  String get levelLabel {
    switch (level) {
      case _CoachRemobilizationLevel.atRisk:
        return 'À relancer';
      case _CoachRemobilizationLevel.missedOnce:
        return 'Un passage à vide';
      case _CoachRemobilizationLevel.recurring:
        return goal.isMaximum ? 'À rééquilibrer' : 'À réinstaller';
      case _CoachRemobilizationLevel.pattern:
        return goal.isMaximum ? 'Plafond à revoir' : 'Méthode à adapter';
      case _CoachRemobilizationLevel.returnToTrack:
        return 'Belle reprise';
      case _CoachRemobilizationLevel.overLimit:
        return 'Plafond dépassé';
    }
  }

  String get message {
    if (goal.isMaximum) {
      switch (level) {
        case _CoachRemobilizationLevel.overLimit:
          return 'Le plafond est dépassé de ${currentCount - target} réalisation(s). Pas besoin de compenser ni de te priver : revenons simplement à tes repères habituels et regardons ce qui rendrait cet objectif plus facile à vivre.';
        case _CoachRemobilizationLevel.recurring:
          return 'Ce plafond a été dépassé plusieurs périodes de suite. Il est peut-être trop strict ou mal adapté à ton quotidien. Le Coach te propose de revoir le réglage sans chercher à compenser.';
        case _CoachRemobilizationLevel.pattern:
          return 'Les dépassements se répètent depuis plusieurs périodes. Plutôt que de te demander davantage de contrôle, vérifions si ce plafond est réaliste et s’il correspond toujours à tes priorités.';
        default:
          return 'On peut ajuster ce repère pour qu’il reste réaliste et confortable, sans compensation stricte.';
      }
    }
    switch (level) {
      case _CoachRemobilizationLevel.atRisk:
        return 'Le rythme de cette période commence à prendre du retard. Il reste possible de faire un petit pas, sans chercher à tout rattraper.';
      case _CoachRemobilizationLevel.missedOnce:
        return 'Cet objectif a été manqué sur la dernière période complète. Une seule reprise suffit pour relancer la dynamique.';
      case _CoachRemobilizationLevel.recurring:
        return 'Cet objectif a été manqué plusieurs périodes de suite. Le plus utile est de comprendre ce qui bloque et de simplifier le prochain pas.';
      case _CoachRemobilizationLevel.pattern:
        return 'La méthode actuelle semble difficile à tenir dans la durée. Ce n’est pas un échec : adaptons le rythme ou le format.';
      case _CoachRemobilizationLevel.returnToTrack:
        return 'Tu as repris cette habitude après une période moins régulière. C’est une vraie victoire : cherchons maintenant à rendre cette reprise facile à répéter.';
      case _CoachRemobilizationLevel.overLimit:
        return 'Pas besoin de compenser. Revenons simplement à un rythme confortable pour la suite.';
    }
  }
}

const List<(String, String, String)> kCoachRemobilizationReasons = [
  ('temps', 'Je manque de temps', 'Réduisons le format : 10 à 15 minutes suffisent pour relancer une activité. Pour une habitude alimentaire, associons-la à un repas déjà prévu.'),
  ('motivation', 'La motivation baisse', 'Rendons le premier pas minuscule et agréable. L’objectif est de commencer, pas de faire une séance parfaite.'),
  ('difficile', 'C’est trop difficile', 'Allégeons l’intensité ou choisissons une variante plus facile. Il vaut mieux une version douce et régulière.'),
  ('organisation', 'Je manque d’organisation', 'Accrochons l’habitude à un repère fixe : après le café, avant le déjeuner ou à un moment choisi dans l’agenda.'),
  ('ambitieux', 'L’objectif est trop ambitieux', 'Ajustons temporairement la cible pour qu’elle corresponde à ta semaine réelle, puis réévaluons-la plus tard.'),
  ('envie', 'J’ai envie de changer', 'Changeons le format ou l’activité pour retrouver du plaisir, tout en gardant la même intention.'),
];

extension _CoachRemobilizationPart on _MaBelleSemaineAppState {
  DateTime _remobDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _remobPreviousPeriodStart(RealizationGoal goal, DateTime currentStart) {
    switch (goal.cadence) {
      case 'jour':
        return _addDays(currentStart, -1);
      case 'mois':
        return DateTime(currentStart.year, currentStart.month - 1, 1);
      case 'semaine':
      default:
        return _addDays(currentStart, -7);
    }
  }

  int _remobCountInRange(RealizationGoal goal, DateTime start, DateTime end) {
    final activity = findActivity(goal.activityId);
    if (activity == null) return 0;
    final name = activity.name.trim().toLowerCase();
    var count = 0;
    for (final log in logs) {
      final sameActivity = log.activityId == goal.activityId ||
          (log.activityId == null && name.isNotEmpty && log.title.trim().toLowerCase() == name);
      if (!sameActivity) continue;
      if (log.realisedMinutes <= 0 && !activity.countOnly && (log.reps ?? 0) <= 0) continue;
      final day = _remobDateOnly(log.date);
      if (day.isBefore(start) || !day.isBefore(end)) continue;
      count++;
    }
    return count;
  }

  bool _remobPeriodMissed(RealizationGoal goal, int count) =>
      goal.isMaximum ? count > goal.target : count < goal.target;

  bool _remobCurrentPeriodBehind(RealizationGoal goal, int currentCount, DateTime now) {
    if (goal.isMaximum) return currentCount > goal.target;
    switch (goal.cadence) {
      case 'jour':
        // Ne pas signaler une journée en retard dès le matin.
        return now.hour >= 19 && currentCount < goal.target;
      case 'mois':
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final elapsed = now.day / daysInMonth;
        if (elapsed < .45) return false;
        final expected = (goal.target * elapsed).round();
        return expected > 0 && currentCount < expected;
      case 'semaine':
      default:
        final elapsed = now.weekday / 7.0;
        if (elapsed < .45) return false;
        final expected = (goal.target * elapsed).round();
        return expected > 0 && currentCount < expected;
    }
  }

  List<_CoachRemobilizationItem> _coachRemobilizationItems() {
    final now = _remobDateOnly(_clockNow);
    final items = <_CoachRemobilizationItem>[];

    for (final goal in _realizationGoals) {
      final activity = findActivity(goal.activityId);
      if (activity == null || activity.isFrozen) continue;

      final currentStart = _goalPeriodStart(goal, now);
      final currentCount = _goalProgress(goal, _clockNow);
      final currentSatisfied = !_remobPeriodMissed(goal, currentCount);

      // Compte les périodes complètes manquées les plus récentes. Les périodes
      // antérieures à la création de l’objectif sont ignorées, jamais pénalisées.
      final lookBack = goal.cadence == 'jour' ? 7 : 3;
      var cursor = currentStart;
      var missedPeriods = 0;
      for (var index = 0; index < lookBack; index++) {
        final previousStart = _remobPreviousPeriodStart(goal, cursor);
        final previousEnd = cursor;
        cursor = previousStart;
        if (goal.createdAt.isAfter(previousStart)) continue;
        final count = _remobCountInRange(goal, previousStart, previousEnd);
        if (_remobPeriodMissed(goal, count)) {
          missedPeriods++;
        } else {
          // On ne mesure que la série de périodes manquées la plus récente.
          break;
        }
      }

      final behind = _remobCurrentPeriodBehind(goal, currentCount, _clockNow);
      _CoachRemobilizationLevel? level;
      if (goal.isMaximum) {
        if (currentCount > goal.target) {
          level = _CoachRemobilizationLevel.overLimit;
        } else if (missedPeriods >= 3) {
          level = _CoachRemobilizationLevel.pattern;
        } else if (missedPeriods >= 2) {
          level = _CoachRemobilizationLevel.recurring;
        }
      } else if (currentSatisfied) {
        if (missedPeriods > 0) level = _CoachRemobilizationLevel.returnToTrack;
      } else if (missedPeriods >= (goal.cadence == 'jour' ? 6 : 3)) {
        level = _CoachRemobilizationLevel.pattern;
      } else if (missedPeriods >= (goal.cadence == 'jour' ? 4 : 2)) {
        level = _CoachRemobilizationLevel.recurring;
      } else if (missedPeriods > 0) {
        level = _CoachRemobilizationLevel.missedOnce;
      } else if (behind) {
        level = _CoachRemobilizationLevel.atRisk;
      }

      if (level == null) continue;
      final periodLabel = goal.cadence == 'jour'
          ? 'aujourd’hui'
          : goal.cadence == 'mois'
              ? 'ce mois'
              : 'cette semaine';
      items.add(_CoachRemobilizationItem(
        activity: activity,
        goal: goal,
        currentCount: currentCount,
        target: goal.target,
        missedPeriods: missedPeriods,
        periodLabel: periodLabel,
        level: level,
      ));
    }

    int severity(_CoachRemobilizationLevel level) {
      switch (level) {
        case _CoachRemobilizationLevel.overLimit:
        case _CoachRemobilizationLevel.pattern:
          return 0;
        case _CoachRemobilizationLevel.recurring:
          return 1;
        case _CoachRemobilizationLevel.missedOnce:
          return 2;
        case _CoachRemobilizationLevel.atRisk:
          return 3;
        case _CoachRemobilizationLevel.returnToTrack:
          return 4;
      }
    }

    items.sort((a, b) {
      final bySeverity = severity(a.level).compareTo(severity(b.level));
      if (bySeverity != 0) return bySeverity;
      return a.activity.name.toLowerCase().compareTo(b.activity.name.toLowerCase());
    });
    return items;
  }

  Color _coachRemobColor(_CoachRemobilizationLevel level) {
    switch (level) {
      case _CoachRemobilizationLevel.overLimit:
      case _CoachRemobilizationLevel.pattern:
        return _colors.danger;
      case _CoachRemobilizationLevel.recurring:
      case _CoachRemobilizationLevel.missedOnce:
      case _CoachRemobilizationLevel.atRisk:
        return _colors.goldText;
      case _CoachRemobilizationLevel.returnToTrack:
        return _colors.accentStrongText;
    }
  }

  IconData _coachRemobIcon(_CoachRemobilizationLevel level) {
    switch (level) {
      case _CoachRemobilizationLevel.overLimit:
        return Icons.tune_rounded;
      case _CoachRemobilizationLevel.pattern:
        return Icons.autorenew_rounded;
      case _CoachRemobilizationLevel.recurring:
        return Icons.route_rounded;
      case _CoachRemobilizationLevel.missedOnce:
        return Icons.replay_rounded;
      case _CoachRemobilizationLevel.atRisk:
        return Icons.flag_outlined;
      case _CoachRemobilizationLevel.returnToTrack:
        return Icons.celebration_rounded;
    }
  }

  String _coachRemobAdvice(_CoachRemobilizationItem item) {
    final reason = _coachRemobilizationReasons[item.activity.id];
    if (item.level == _CoachRemobilizationLevel.overLimit) {
      return 'Pas de compensation stricte. Reviens simplement à tes choix habituels à la prochaine occasion et observe ce qui t’aiderait à respecter ton plafond.';
    }
    if (reason != null) {
      for (final entry in kCoachRemobilizationReasons) {
        if (entry.$1 == reason) return entry.$3;
      }
    }
    if (item.activity.countOnly) {
      return 'Choisis une occasion simple dans la semaine et rattache cette habitude à un repas ou à un rendez-vous déjà prévu.';
    }
    return 'Prévois une version courte de 10 à 15 minutes. Le but est de retrouver le réflexe, pas de rattraper tout le retard.';
  }


  Widget _coachRemobilizationCard({int maxItems = 2, List<_CoachRemobilizationItem>? source}) {
    final items = source ?? _coachRemobilizationItems();
    if (items.isEmpty) return const SizedBox.shrink();
    final visible = items.take(maxItems).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _colors.borderTint),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.favorite_rounded, size: 19, color: _colors.accentIcon),
          const SizedBox(width: 7),
          Expanded(child: Text('COACH MOTIVATION & PROGRESSION', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .3, color: _colors.accentStrongText))),
          if (items.length > visible.length) _Pill('+${items.length - visible.length}'),
        ]),
        const SizedBox(height: 5),
        Text('Un petit ajustement vaut mieux qu’un abandon. On reprend sans culpabiliser.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted, height: 1.3)),
        const SizedBox(height: 9),
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) Divider(height: 14, color: _colors.borderTint),
          _coachRemobilizationTile(visible[index]),
        ],
      ]),
    );
  }

  Widget _coachRemobilizationTile(_CoachRemobilizationItem item) {
    final color = _coachRemobColor(item.level);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _activityIconWidget(item.activity.emoji, size: 25),
        const SizedBox(width: 8),
        Expanded(child: Text(item.activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong))),
        if (item.level == _CoachRemobilizationLevel.pattern)
          OutlinedButton.icon(
            onPressed: () => _openCoachRemobilization(item),
            icon: const Icon(Icons.autorenew_rounded, size: 14),
            label: const Text('Changer de méthode'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800),
            ),
          )
        else ...[
          Icon(_coachRemobIcon(item.level), size: 16, color: color),
          const SizedBox(width: 4),
          _Pill(item.levelLabel, background: color.withValues(alpha: .12), foreground: color),
        ],
      ]),
      const SizedBox(height: 4),
      Text(item.progressLabel, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textMuted)),
      const SizedBox(height: 3),
      Text(item.message, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textStrong)),
      const SizedBox(height: 7),
      Wrap(spacing: 7, runSpacing: 6, children: [
        if (item.level != _CoachRemobilizationLevel.pattern)
          OutlinedButton.icon(
            onPressed: () => _openCoachRemobilization(item),
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
            label: const Text('Trouver une solution'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
        if (!item.goal.isMaximum && item.level != _CoachRemobilizationLevel.pattern)
          FilledButton.tonalIcon(
            onPressed: item.activity.isDateRange ? null : () => _scheduleCoachRestart(item),
            icon: const Icon(Icons.event_available_rounded, size: 16),
            label: Text(item.activity.countOnly ? 'Prévoir' : 'Version courte'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 10)),
          ),
      ]),
    ]);
  }

  Future<void> _openCoachRemobilization(_CoachRemobilizationItem item) async {
    if (!mounted) return;
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    var selectedReason = _coachRemobilizationReasons[item.activity.id] ?? '';
    var reasonToPersist = '';
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          (String, String, String)? selectedEntry;
          for (final entry in kCoachRemobilizationReasons) {
            if (entry.$1 == selectedReason) { selectedEntry = entry; break; }
          }
          final advice = selectedEntry?.$3 ?? _coachRemobAdvice(item);
          final primaryAction = item.goal.isMaximum
              ? 'goal'
              : item.activity.isDateRange
                  ? 'activity'
                  : 'plan';
          final primaryLabel = item.goal.isMaximum
              ? 'Ajuster mon plafond'
              : item.activity.isDateRange
                  ? 'Modifier cette activité'
                  : item.activity.countOnly
                      ? 'Prévoir cette habitude'
                      : item.level == _CoachRemobilizationLevel.pattern
                          ? 'Essayer une version courte'
                          : 'Planifier une version courte';
          void saveReasonAndClose() {
            if (selectedReason.isEmpty) return;
            reasonToPersist = selectedReason;
            Navigator.pop(sheetContext, 'remember');
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).viewInsets.bottom + 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _activityIconWidget(item.activity.emoji, size: 30),
                  const SizedBox(width: 9),
                  Expanded(child: Text(item.activity.name, style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong))),
                  if (item.level != _CoachRemobilizationLevel.pattern)
                    _Pill(item.levelLabel, foreground: _coachRemobColor(item.level)),
                ]),
                const SizedBox(height: 8),
                Text(item.message, style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textStrong)),
                const SizedBox(height: 14),
                Text(
                  item.level == _CoachRemobilizationLevel.pattern
                      ? 'Choisissons une autre méthode'
                      : 'Qu’est-ce qui te freine en ce moment ?',
                  style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w900, color: _colors.textStrong),
                ),
                if (item.level == _CoachRemobilizationLevel.pattern) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tu peux simplifier l’activité, déplacer son rendez-vous ou adapter l’objectif. Choisis ce qui te paraît le plus facile à tenir.',
                    style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final reason in kCoachRemobilizationReasons)
                    ChoiceChip(
                      label: Text(reason.$2),
                      selected: selectedReason == reason.$1,
                      onSelected: (selected) => setSheetState(() => selectedReason = selected ? reason.$1 : ''),
                    ),
                ]),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: _colors.tintStrong, borderRadius: BorderRadius.circular(AppRadius.m), border: Border.all(color: _colors.borderTint)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TA PISTE DE RELANCE', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w900, letterSpacing: .35, color: _colors.accentStrongText)),
                    const SizedBox(height: 4),
                    Text(advice, style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textStrong)),
                  ]),
                ),
                const SizedBox(height: 12),
                if (selectedReason.isNotEmpty)
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: saveReasonAndClose, icon: const Icon(Icons.bookmark_add_outlined, size: 18), label: const Text('Mémoriser ce qui me freine'))),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      reasonToPersist = selectedReason;
                      Navigator.pop(sheetContext, primaryAction);
                    },
                    icon: Icon(
                      primaryAction == 'goal'
                          ? Icons.tune_rounded
                          : primaryAction == 'activity'
                              ? Icons.edit_rounded
                              : Icons.event_available_rounded,
                      size: 18,
                    ),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  if (!item.goal.isMaximum)
                    Expanded(child: OutlinedButton(onPressed: () { reasonToPersist = selectedReason; Navigator.pop(sheetContext, 'goal'); }, child: const Text('Adapter l’objectif'))),
                  if (!item.goal.isMaximum && !item.activity.isDateRange) const SizedBox(width: 8),
                  if (!item.activity.isDateRange)
                    Expanded(child: OutlinedButton(onPressed: () { reasonToPersist = selectedReason; Navigator.pop(sheetContext, 'activity'); }, child: const Text('Modifier l’activité'))),
                ]),
                const SizedBox(height: 4),
                Center(child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Pas maintenant'))),
              ]),
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    if (reasonToPersist.isNotEmpty) {
      setState(() => _coachRemobilizationReasons[item.activity.id] = reasonToPersist);
      _queueLocalStatePersist();
      if (action == 'remember') {
        _showFeedback('🌱 Ton frein est mémorisé. Le Coach adaptera ses prochaines propositions.');
        return;
      }
    }
    if (action == null) return;
    switch (action) {
      case 'plan':
        await _scheduleCoachRestart(item);
        break;
      case 'goal':
        final rootContext = _navigatorKey.currentContext;
        if (rootContext != null) await _addOrEditGoal(context: rootContext, existing: item.goal);
        break;
      case 'activity':
        addOrEditActivity(original: item.activity);
        break;
    }
  }

  Future<void> _scheduleCoachRestart(_CoachRemobilizationItem item) async {
    if (!mounted) return;
    final activity = findActivity(item.activity.id);
    if (activity == null || activity.isDateRange) {
      _showFeedback('Cette activité ne peut pas être replacée automatiquement. Modifie son planning depuis sa fiche.');
      return;
    }
    final firstDay = _clockNow.weekday - 1;
    final availableDays = List<int>.generate(7 - firstDay, (index) => firstDay + index);
    if (availableDays.isEmpty) {
      _showFeedback('La semaine est terminée. Reprends cette habitude dans le planning de la semaine prochaine.');
      return;
    }

    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null) return;
    final selectedDay = await showModalBottomSheet<int>(
      context: navigationContext,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 10), child: Text('Quand veux-tu reprendre ?', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong))),
            for (final day in availableDays)
              ListTile(
                leading: Icon(day == firstDay ? Icons.today_rounded : Icons.calendar_today_rounded, color: _colors.accentIcon),
                title: Text(dayNames[day]),
                subtitle: Text(day == firstDay ? 'Aujourd’hui · une petite étape suffit' : 'Un rendez-vous simple, sans surcharge'),
                onTap: () => Navigator.pop(sheetContext, day),
              ),
          ],
        ),
      ),
    );
    if (selectedDay == null || !mounted) return;

    final alreadyCompleted = logs.any((log) {
      final sameActivity = log.activityId == activity.id ||
          (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());
      return sameActivity && _remobDateOnly(log.date) == _remobDateOnly(_addDays(_startOfCurrentWeek(), selectedDay));
    });
    if (alreadyCompleted) {
      _showFeedback('Cette habitude est déjà réalisée ${dayNames[selectedDay].toLowerCase()} : bravo !');
      return;
    }

    final existing = plan.where((entry) => entry.activityId == activity.id && entry.day == selectedDay && !_isDateRangePlanItem(entry)).toList();
    if (existing.any((entry) => entry.done)) {
      _showFeedback('Cette habitude est déjà validée ${dayNames[selectedDay].toLowerCase()} : bravo !');
      return;
    }
    final shortDuration = activity.countOnly ? 1 : max(5, min(15, max(1, activity.duration)));
    _prepareUndoSnapshot();
    setState(() {
      if (existing.isNotEmpty) {
        final itemToUpdate = existing.first;
        if (!itemToUpdate.done) {
          itemToUpdate.duration = shortDuration;
          itemToUpdate.period = _periodForActivity(activity, selectedDay);
          itemToUpdate.manualPlacement = true;
          itemToUpdate.title = activity.name;
        }
      } else {
        plan.add(PlanItem(
          id: 'coach_restart_${activity.id}_${selectedDay}_${DateTime.now().microsecondsSinceEpoch}',
          day: selectedDay,
          period: _periodForActivity(activity, selectedDay),
          title: activity.name,
          duration: shortDuration,
          activityId: activity.id,
          details: 'Relance douce du Coach · première étape courte.',
          optional: false,
          userAdded: true,
          fixedInWeeklyTemplate: false,
          manualPlacement: true,
        ));
      }
      _sortPlan();
    });
    _queueLocalStatePersist();
    _showFeedback(existing.isEmpty
        ? '🌱 ${activity.name} ajouté ${dayNames[selectedDay].toLowerCase()} en version courte.'
        : '🌱 ${activity.name} replacé ${dayNames[selectedDay].toLowerCase()} en version courte.');
  }
}
