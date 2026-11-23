// V12.30.0 — Coach : vue immédiate « + / − / action » et détection de la procrastination.
// Un seul bloc en tête d'accueil fusionne les signaux des coachs (objectifs, reprise, Nutrition, reports)
// et propose UNE action maintenant. Les reports répétés d'une même activité sont repérés comme de
// l'évitement (et non comme une préférence de jour) : au 2e report on cherche ce qui bloque, au 3e on décide.

part of '../main.dart';

class _ProcrastinationItem {
  final String key; // identifiant d'activité, ou « title:nom » pour un moment libre
  final String title;
  final Activity? activity;
  final int count; // reports depuis la dernière réalisation, sur 14 jours
  final DateTime last;

  const _ProcrastinationItem({
    required this.key,
    required this.title,
    required this.activity,
    required this.count,
    required this.last,
  });

  /// À partir du 3e report : on décide (version courte, nouvelle méthode ou pause).
  bool get decide => count >= 3;
}

class _BalanceLine {
  final IconData icon;
  final String text;
  const _BalanceLine(this.icon, this.text);
}

class _BalanceAction {
  final String title;
  final String detail;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _BalanceAction({
    required this.title,
    required this.detail,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });
}

class _ProgressChip {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback? onTap;
  const _ProgressChip(this.icon, this.label, this.value, this.sub, [this.onTap]);
}

/// Barre de progression avec un repère : la part de la semaine déjà échue (rythme attendu).
class _PaceBar extends StatelessWidget {
  final double value;
  final double? expected;
  const _PaceBar({required this.value, this.expected});

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final e = expected;
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: 10,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 4,
              backgroundColor: _colors.tintStrong,
              valueColor: AlwaysStoppedAnimation<Color>(_colors.accentOutline),
            ),
          ),
          if (e != null && e > 0 && e < 1)
            Positioned(
              left: (constraints.maxWidth * e - 1).clamp(0.0, max(0.0, constraints.maxWidth - 2)).toDouble(),
              top: 0,
              bottom: 0,
              child: Container(width: 2, decoration: BoxDecoration(color: _colors.textMuted, borderRadius: BorderRadius.circular(1))),
            ),
        ]),
      );
    });
  }
}

class _CoachBalance {
  final List<_BalanceLine> plus;
  final List<_BalanceLine> minus;
  final _BalanceAction? action;
  const _CoachBalance({required this.plus, required this.minus, required this.action});
}

extension _CoachBalancePart on _MaBelleSemaineAppState {
  // ----- reports : évitement, pas préférence --------------------------------------------------

  /// Un report = un moment déjà échu (ou du jour) repoussé vers un créneau plus tardif.
  /// Déplacer un moment futur est de la planification, pas un report.
  bool _isPostponementMove(ActivityMoveLog m) {
    final moveDay = m.date.weekday - 1;
    if (m.fromDay > moveDay) return false;
    int order(String p) => p == 'Matin' ? 0 : (p == 'Soir' ? 2 : 1);
    return m.toDay > m.fromDay || (m.toDay == m.fromDay && order(m.toPeriod) > order(m.fromPeriod));
  }

  /// Activités repoussées au moins 2 fois en 14 jours sans avoir été réalisées depuis.
  List<_ProcrastinationItem> _procrastinationItems() {
    final now = _clockNow;
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final cutoff = _addDays(dateOnly(now), -14);
    final grouped = <String, List<ActivityMoveLog>>{};
    for (final m in activityMoveLogs) {
      if (m.date.isBefore(cutoff) || m.date.isAfter(now) || !_isPostponementMove(m)) continue;
      final key = m.activityId ?? 'title:${m.activityName.trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => <ActivityMoveLog>[]).add(m);
    }
    final result = <_ProcrastinationItem>[];
    grouped.forEach((key, moves) {
      final isTitleKey = key.startsWith('title:');
      final activity = isTitleKey ? null : findActivity(key);
      if (!isTitleKey && (activity == null || activity.isFrozen)) return;
      final name = (activity?.name ?? moves.first.activityName).trim().toLowerCase();
      DateTime? lastDone;
      for (final log in logs) {
        final same = isTitleKey
            ? log.activityId == null && log.title.trim().toLowerCase() == key.substring(6)
            : log.activityId == key || (log.activityId == null && log.title.trim().toLowerCase() == name);
        if (!same) continue;
        final d = dateOnly(log.date);
        if (lastDone == null || d.isAfter(lastDone)) lastDone = d;
      }
      // Réaliser l'activité remet le compteur à zéro.
      final since = lastDone;
      final counted = since == null ? moves : moves.where((m) => dateOnly(m.date).isAfter(since)).toList();
      if (counted.length < 2) return;
      if (activity != null) {
        final snooze = _coachRemobSnoozes[activity.id];
        if (snooze != null && snooze.until.isAfter(now)) return;
      }
      final latest = counted.map((m) => m.date).reduce((a, b) => a.isAfter(b) ? a : b);
      result.add(_ProcrastinationItem(
        key: key,
        title: activity?.name ?? moves.first.activityName,
        activity: activity,
        count: counted.length,
        last: latest,
      ));
    });
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : b.last.compareTo(a.last);
    });
    return result;
  }

  /// À appeler juste après un report : au 2e et au 3e report, on ouvre la fiche « qu'est-ce qui bloque ? ».
  void _maybeAskProcrastination(PlanItem item) {
    if (activityMoveLogs.isEmpty || !_isPostponementMove(activityMoveLogs.last)) return;
    final key = item.activityId ?? 'title:${item.title.trim().toLowerCase()}';
    for (final hit in _procrastinationItems()) {
      if (hit.key != key) continue;
      if (hit.count != 2 && hit.count != 3) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openProcrastinationSheet(hit);
      });
      return;
    }
  }

  Future<void> _openProcrastinationSheet(_ProcrastinationItem item) async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    final activity = item.activity;
    PlanItem? pending;
    for (final p in plan) {
      if (p.done || _isDateRangePlanItem(p)) continue;
      final same = activity != null ? p.activityId == activity.id : p.title.trim().toLowerCase() == item.title.trim().toLowerCase();
      if (same) {
        pending = p;
        break;
      }
    }
    String? selected = activity == null ? null : _coachRemobilizationReasons[activity.id];

    final result = await showModalBottomSheet<String>(
      context: navigationContext,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          String? adviceFor(String? key) {
            for (final entry in kCoachRemobilizationReasons) {
              if (entry.$1 == key) return entry.$3;
            }
            return null;
          }

          final advice = adviceFor(selected);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '« ${item.title} » repoussé ${item.count} fois',
                  style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong),
                ),
                const SizedBox(height: 4),
                Text(
                  item.decide
                      ? 'Ce n’est plus un simple décalage : on décide maintenant, sans culpabiliser.'
                      : 'Deuxième report : qu’est-ce qui bloque vraiment ?',
                  style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textMuted),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final reason in kCoachRemobilizationReasons)
                    ChoiceChip(
                      label: Text(reason.$2),
                      selected: selected == reason.$1,
                      onSelected: (_) => setSheetState(() => selected = reason.$1),
                    ),
                ]),
                if (advice != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _colors.tintSoft, borderRadius: BorderRadius.circular(AppRadius.m)),
                    child: Text(advice, style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textStrong)),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'short'),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Version courte aujourd’hui'),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (pending != null)
                    OutlinedButton(onPressed: () => Navigator.pop(sheetContext, 'slot'), child: const Text('Fixer un créneau')),
                  if (activity != null && item.decide)
                    OutlinedButton(onPressed: () => Navigator.pop(sheetContext, 'method'), child: const Text('Changer de méthode')),
                  if (activity != null && item.decide)
                    OutlinedButton(onPressed: () => Navigator.pop(sheetContext, 'pause'), child: const Text('Mettre en pause')),
                ]),
                if (activity != null)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext, 'snooze'),
                      child: const Text('Me le rappeler dans 2 jours'),
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;

    if (activity != null && selected != null) {
      setState(() => _coachRemobilizationReasons[activity.id] = selected!);
      _queueLocalStatePersist();
    }
    switch (result) {
      case 'short':
        if (activity != null) {
          await _scheduleShortVersion(activity);
        } else {
          _showFeedback('Replace ce moment depuis le planning pour en faire une version courte.');
        }
        break;
      case 'slot':
        if (pending != null) await _moveGenericOrRegularPlanItem(pending);
        break;
      case 'method':
        if (activity != null) addOrEditActivity(original: activity);
        break;
      case 'pause':
        if (activity != null) _toggleActivityFrozen(activity);
        break;
      case 'snooze':
        if (activity != null) {
          final count = (_coachRemobSnoozes[activity.id]?.count ?? 0) + 1;
          setState(() {
            _coachRemobSnoozes[activity.id] = (until: _addDays(DateTime(_clockNow.year, _clockNow.month, _clockNow.day), 2), count: count);
          });
          _queueLocalStatePersist();
          _showFeedback('D’accord, le Coach reviendra dans 2 jours.');
        }
        break;
    }
  }

  // ----- rythme attendu et progression -------------------------------------------------------

  /// Moments déjà échus (jours passés, ou créneaux passés aujourd'hui) : repère du rythme attendu.
  ({int due, double ratio}) _weekPace(List<PlanItem> items) {
    if (items.isEmpty) return (due: 0, ratio: 0.0);
    final due = items.where((p) => p.day < today || (p.day == today && _homePeriodIsPast(p.period))).length;
    return (due: due, ratio: due / items.length);
  }

  _ProgressChip _weightProgressChip() {
    final now = _clockNow;
    final today0 = DateTime(now.year, now.month, now.day);
    final entries = <({DateTime date, double kg})>[];
    for (final e in _weightEntries) {
      final d = DateTime.tryParse('${e['date']}');
      final kg = e['kg'];
      if (d != null && kg is num) entries.add((date: DateTime(d.year, d.month, d.day), kg: kg.toDouble()));
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    String fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    void openGoals() => setState(() => tab = 3);
    // Une donnée absente n'est pas un échec : on invite à saisir, sans juger.
    if (entries.isEmpty) return _ProgressChip(Icons.monitor_weight_outlined, 'Poids', 'À saisir', 'aucune pesée', openGoals);
    final last = entries.last;
    final age = _daysBetween(last.date, today0);
    if (age > 14) return _ProgressChip(Icons.monitor_weight_outlined, 'Poids', 'À saisir', 'dernière il y a $age j', openGoals);
    final window = entries.where((e) => _daysBetween(e.date, last.date) <= 28).toList();
    final span = _daysBetween(window.first.date, last.date);
    if (window.length >= 3 && span >= 14) {
      final delta = last.kg - window.first.kg;
      return _ProgressChip(Icons.monitor_weight_outlined, 'Poids', '${delta <= 0 ? '−' : '+'}${fmt(delta.abs())} kg', 'sur $span jours', openGoals);
    }
    return _ProgressChip(Icons.monitor_weight_outlined, 'Poids', '${fmt(last.kg)} kg', 'tendance : trop peu de pesées', openGoals);
  }

  List<_ProgressChip> _buildProgressChips() {
    final chips = <_ProgressChip>[];
    final trend = _coachWeekTrend();
    final diff = trend.thisDays - trend.lastDays;
    chips.add(_ProgressChip(
      Icons.calendar_month_outlined,
      'Jours actifs',
      '${trend.thisDays}',
      diff > 0 ? '↗ +$diff vs semaine passée' : (diff < 0 ? '↘ $diff vs semaine passée' : '= semaine passée'),
    ));
    chips.add(_ProgressChip(
      Icons.schedule_rounded,
      'Temps',
      _minutesLabel(trend.thisMin),
      'semaine passée à date : ${_minutesLabel(trend.lastMin)}',
    ));

    // Objectifs « en bonne voie » : atteints, ou au rythme attendu pour la période (jamais jugés d'avance).
    final now = _clockNow;
    var total = 0;
    var onTrack = 0;
    for (final g in _realizationGoals) {
      final activity = findActivity(g.activityId);
      if (activity == null || activity.isFrozen) continue;
      total++;
      if (!_remobCurrentPeriodBehind(g, _goalProgress(g, now), now)) onTrack++;
    }
    if (total > 0) {
      chips.add(_ProgressChip(Icons.flag_outlined, 'Objectifs', '$onTrack/$total', 'en bonne voie', () => setState(() => tab = 3)));
    }

    final engine = _balanceNutritionEngine();
    if (engine != null) {
      final week = engine.weekDays();
      final evaluated = week.where((d) => d.evaluated).length;
      if (evaluated > 0) {
        final held = week.where((d) => d.state == _NutDayState.held).length;
        chips.add(_ProgressChip(Icons.restaurant_outlined, 'Nutrition', '$held/$evaluated', 'jours tenus', _openNutritionWeeklyAnalysis));
      }
    }
    if (_homeShowWeight) chips.add(_weightProgressChip());
    return chips;
  }

  Widget _progressRow(List<_ProgressChip> chips) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 16) / 3;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final chip in chips)
          SizedBox(
            width: width,
            child: InkWell(
              onTap: chip.onTap,
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
                decoration: BoxDecoration(
                  color: _colors.card,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: _colors.borderTint),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(chip.icon, size: 12, color: _colors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(chip.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(chip.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                  Text(chip.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, height: 1.2, color: _colors.textMuted)),
                ]),
              ),
            ),
          ),
      ]);
    });
  }

  // ----- bloc « + / − / action » ---------------------------------------------------------------

  _NutritionCoachEngine? _balanceNutritionEngine() {
    final nutrition = _nutritionActivitiesForChecklist();
    if (nutrition.isEmpty) return null;
    return _NutritionCoachEngine(activities: nutrition, logs: logs, goals: _realizationGoals, now: _clockNow);
  }

  _CoachBalance _buildCoachBalance() {
    final plus = <_BalanceLine>[];
    final minus = <_BalanceLine>[];
    final remobilization = _coachRemobilizationItems();
    final procrastination = _procrastinationItems();
    final streak = _coachStreakInfo();
    final trend = _coachWeekTrend();
    final now = _clockNow;
    final todayItems = actionableItemsForDay(today).where((p) => !p.optional && !_isDateRangePlanItem(p)).toList();
    final doneToday = todayItems.where((p) => p.done).length;
    final overdue = todayItems.where((p) => !p.done && !_isNutritionPlanItem(p) && _homePeriodIsPast(p.period)).toList()
      ..sort((a, b) => _homePeriodRank(a.period).compareTo(_homePeriodRank(b.period)));
    final engine = _balanceNutritionEngine();

    // ----- ce qui va bien -----
    for (final r in remobilization) {
      if (r.level == _CoachRemobilizationLevel.returnToTrack) {
        plus.add(_BalanceLine(Icons.trending_up_rounded, 'Belle reprise sur ${r.activity.name}'));
        break;
      }
    }
    final progress = _coachProgressItems();
    final reached = progress.where((p) => p.done).toList();
    final close = progress.where((p) => !p.done && p.ratio >= 0.66 && p.hint.isNotEmpty).toList();
    if (reached.isNotEmpty) {
      plus.add(_BalanceLine(Icons.flag_rounded, 'Objectif atteint : ${reached.first.title} (${reached.first.value})'));
    } else if (close.isNotEmpty) {
      plus.add(_BalanceLine(Icons.flag_outlined, '${close.first.title} : ${close.first.value}, ${close.first.hint.toLowerCase()}'));
    }
    if (streak.now >= 2) {
      plus.add(_BalanceLine(
        Icons.local_fire_department_rounded,
        streak.now >= streak.best && streak.now >= 3 ? 'Série de ${streak.now} jours : ton record' : 'Série de ${streak.now} jours${streak.best > streak.now ? ' (record ${streak.best})' : ''}',
      ));
    }
    if (trend.thisDays >= 2 && trend.thisDays > trend.lastDays) {
      plus.add(_BalanceLine(Icons.calendar_month_outlined, '${trend.thisDays} jours actifs cette semaine (${trend.lastDays} la semaine dernière)'));
    }
    if (engine != null && engine.heldStreak >= 2) {
      plus.add(_BalanceLine(Icons.restaurant_outlined, 'Nutrition : ${engine.heldStreak} jours tenus d’affilée'));
    }
    if (doneToday > 0 && todayItems.isNotEmpty) {
      plus.add(_BalanceLine(Icons.check_circle_outline_rounded, '$doneToday/${todayItems.length} fait aujourd’hui'));
    }

    // ----- ce qui dérape -----
    final seen = <String>{};
    for (final p in procrastination) {
      seen.add(p.activity?.id ?? p.key);
      minus.add(_BalanceLine(Icons.event_repeat_rounded, '« ${p.title} » repoussé ${p.count} fois en 14 jours'));
    }
    if (overdue.isNotEmpty) {
      for (final o in overdue) {
        if (o.activityId != null) seen.add(o.activityId!);
      }
      final first = overdue.first;
      minus.add(_BalanceLine(
        Icons.schedule_rounded,
        overdue.length == 1
            ? '« ${first.title} » : créneau ${first.period.toLowerCase()} passé'
            : '${overdue.length} moments passés non faits : « ${first.title} »${overdue.length > 1 ? ' et ${overdue.length - 1} autre${overdue.length > 2 ? 's' : ''}' : ''}',
      ));
    }
    for (final r in remobilization) {
      if (r.level == _CoachRemobilizationLevel.returnToTrack || seen.contains(r.activity.id)) continue;
      seen.add(r.activity.id);
      final String text;
      switch (r.level) {
        case _CoachRemobilizationLevel.atRisk:
          text = '${r.activity.name} : en retard (${r.currentCount}/${r.target} ${r.periodLabel})';
          break;
        case _CoachRemobilizationLevel.missedOnce:
          text = '${r.activity.name} : dernière période manquée';
          break;
        case _CoachRemobilizationLevel.recurring:
        case _CoachRemobilizationLevel.pattern:
          text = '${r.activity.name} : ${r.missedPeriods} ${_remobUnit(r.goal, r.missedPeriods)} sous la cible';
          break;
        case _CoachRemobilizationLevel.overLimit:
          text = '${r.activity.name} : plafond dépassé';
          break;
        case _CoachRemobilizationLevel.returnToTrack:
          continue;
      }
      minus.add(_BalanceLine(Icons.error_outline_rounded, text));
    }
    if (engine != null) {
      final y = engine.dayFor(DateTime(now.year, now.month, now.day - 1));
      String? nutritionLine;
      if (y.state == _NutDayState.off) {
        nutritionLine = 'Nutrition : écart hier (${_nutJoinNames(y.exceeded)})';
      } else {
        for (final b in engine.weeklyBudgets()) {
          if (b.kind == _NutBudgetKind.capOver) {
            nutritionLine = '${b.activity.name} : plafond de la semaine dépassé';
            break;
          }
          if (b.kind == _NutBudgetKind.unreachable) {
            nutritionLine = '${b.activity.name} : minimum de la semaine hors d’atteinte';
            break;
          }
        }
      }
      if (nutritionLine != null) minus.add(_BalanceLine(Icons.restaurant_outlined, nutritionLine));
    }

    // ----- une seule action maintenant -----
    _BalanceAction? action;
    if (overdue.isNotEmpty) {
      final item = overdue.first;
      action = _BalanceAction(
        title: 'Fais « ${item.title} » maintenant',
        detail: 'Créneau ${item.period.toLowerCase()} passé${_itemIsCount(item) ? '' : ' · ${_minutesLabel(item.duration)}'}. Fais-le tel quel ou en version courte.',
        primaryLabel: 'Je l’ai fait',
        onPrimary: () => togglePlanItemDone(item, true),
        secondaryLabel: 'Reporter ou passer',
        onSecondary: () => _showPastPlanQuickActions(item),
      );
    } else if (procrastination.isNotEmpty) {
      final p = procrastination.first;
      action = _BalanceAction(
        title: 'Débloque « ${p.title} »',
        detail: p.decide ? 'Repoussé ${p.count} fois : décide maintenant, sans culpabiliser.' : 'Repoussé ${p.count} fois : qu’est-ce qui bloque ?',
        primaryLabel: 'Débloquer',
        onPrimary: () => _openProcrastinationSheet(p),
      );
    } else {
      _CoachRemobilizationItem? top;
      for (final r in remobilization) {
        if (r.level != _CoachRemobilizationLevel.returnToTrack && r.level != _CoachRemobilizationLevel.overLimit) {
          top = r;
          break;
        }
      }
      if (top != null) {
        final r = top;
        final canRamp = r.rampTarget != null;
        action = _BalanceAction(
          title: 'Relance « ${r.activity.name} »',
          detail: r.baseMessage,
          primaryLabel: canRamp ? 'Alléger à ${r.rampTarget}' : 'Trouver une solution',
          onPrimary: () => canRamp ? _applyCoachRamp(r) : _openCoachRemobilization(r),
          secondaryLabel: canRamp ? 'Autres solutions' : null,
          onSecondary: canRamp ? () => _openCoachRemobilization(r) : null,
        );
      } else {
        final focus = engine?.focus();
        final next = _coachNextAction();
        if (focus?.activity != null && next == null) {
          final activity = focus!.activity!;
          action = _BalanceAction(
            title: focus.text,
            detail: 'Coach Nutrition',
            primaryLabel: 'Cocher',
            onPrimary: () => _setNutritionActivityDoneForDay(activity, today, true),
          );
        } else if (next != null) {
          action = _BalanceAction(
            title: 'Prochaine action : ${_coachPendingTitle(next)}',
            detail: _itemIsCount(next) ? 'Une coche suffit.' : '${_minutesLabel(next.duration)} · ${next.period.toLowerCase()}',
            primaryLabel: 'Ouvrir',
            onPrimary: () => openItemActions(next),
          );
        }
      }
    }

    return _CoachBalance(plus: plus.take(3).toList(), minus: minus.take(3).toList(), action: action);
  }

  Widget _balanceRow(_BalanceLine line, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(line.icon, size: 16, color: color)),
        const SizedBox(width: 7),
        Expanded(child: Text(line.text, style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textStrong))),
      ]),
    );
  }

  Widget _homeCoachBalance() {
    final data = _buildCoachBalance();
    final action = data.action;
    final progressChips = _buildProgressChips();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _AppCard(
        tone: _CardTone.tint,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.explore_outlined, size: 18, color: _colors.accentIcon),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'MA SITUATION · CAP DU MOMENT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w900, letterSpacing: .3, color: _colors.accentStrongText),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Ça va bien', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.accentText)),
          const SizedBox(height: 3),
          if (data.plus.isEmpty)
            _balanceRow(const _BalanceLine(Icons.wb_sunny_outlined, 'Pas encore de point positif aujourd’hui : une première coche suffit à lancer la série.'), _colors.textMuted)
          else
            for (final line in data.plus) _balanceRow(line, _colors.accentIcon),
          const SizedBox(height: 4),
          Text('À corriger', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.goldText)),
          const SizedBox(height: 3),
          if (data.minus.isEmpty)
            _balanceRow(const _BalanceLine(Icons.check_circle_outline_rounded, 'Rien à corriger : tu es dans le cadre.'), _colors.textMuted)
          else
            for (final line in data.minus) _balanceRow(line, _colors.goldText),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _colors.card,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: _colors.borderTint),
            ),
            child: action == null
                ? Row(children: [
                    Icon(Icons.celebration_outlined, size: 18, color: _colors.accentIcon),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Tout est à jour pour le moment. Profite.', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong))),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.bolt_rounded, size: 18, color: _colors.accentIcon)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(action.title, style: TextStyle(fontSize: AppType.bodyL, height: 1.25, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                          const SizedBox(height: 2),
                          Text(action.detail, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      FilledButton(
                        onPressed: action.onPrimary,
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        child: Text(action.primaryLabel),
                      ),
                      if (action.secondaryLabel != null && action.onSecondary != null)
                        OutlinedButton(
                          onPressed: action.onSecondary,
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: Text(action.secondaryLabel!),
                        ),
                    ]),
                  ]),
          ),
          const SizedBox(height: 10),
          Text('Ma progression', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
          const SizedBox(height: 5),
          _progressRow(progressChips),
        ]),
      ),
    );
  }
}
