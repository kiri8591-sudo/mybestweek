// V12.32.0 — Bilan hebdomadaire de vie.
// Le dimanche (ou le lundi / mardi si on l'a manqué), le Coach rassemble la semaine : activités et
// objectifs, réussites et difficultés (avec les freins connus), forme (Nutrition, ressenti, poids s'il
// existe des mesures), puis débouche sur des ajustements applicables en un geste et UNE priorité pour
// la semaine suivante, qui nourrit ensuite le contrat du matin.

part of '../main.dart';

class LifeReviewEntry {
  final String weekKey; // lundi de la semaine analysée (yyyy-mm-dd)
  final String? focusActivityId;
  final String focusTitle; // vide si aucune priorité n'a été choisie
  final DateTime doneAt;

  const LifeReviewEntry({
    required this.weekKey,
    required this.focusActivityId,
    required this.focusTitle,
    required this.doneAt,
  });

  Map<String, Object?> toJson() => {
        'weekKey': weekKey,
        'focusActivityId': focusActivityId,
        'focusTitle': focusTitle,
        'doneAt': doneAt.toIso8601String(),
      };

  static LifeReviewEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final weekKey = raw['weekKey'];
    if (weekKey is! String || weekKey.isEmpty) return null;
    final focusId = raw['focusActivityId'];
    final focusTitle = raw['focusTitle'];
    return LifeReviewEntry(
      weekKey: weekKey,
      focusActivityId: focusId is String && focusId.isNotEmpty ? focusId : null,
      focusTitle: focusTitle is String ? focusTitle : '',
      doneAt: DateTime.tryParse('${raw['doneAt']}') ?? DateTime.now(),
    );
  }
}

class _ReviewAdjust {
  final String id;
  final String label;
  final String detail;
  final String button;
  final Future<void> Function() onTap;
  const _ReviewAdjust({required this.id, required this.label, required this.detail, required this.button, required this.onTap});
}

class _LifeReviewData {
  final DateTime monday;
  final DateTime lastDay;
  final bool complete;
  final int activeDays;
  final int prevActiveDays;
  final int minutes;
  final int prevMinutes;
  final int contractsKept;
  final int contractsTotal;
  final int goalsReached;
  final int goalsTotal;
  final List<String> wins;
  final List<String> struggles;
  final List<String> form;
  final List<_ContractCandidate> candidates;

  const _LifeReviewData({
    required this.monday,
    required this.lastDay,
    required this.complete,
    required this.activeDays,
    required this.prevActiveDays,
    required this.minutes,
    required this.prevMinutes,
    required this.contractsKept,
    required this.contractsTotal,
    required this.goalsReached,
    required this.goalsTotal,
    required this.wins,
    required this.struggles,
    required this.form,
    required this.candidates,
  });
}

extension _LifeReviewPart on _MaBelleSemaineAppState {
  DateTime _reviewMonday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
  String _reviewKey(DateTime monday) => _contractKey(monday);
  bool _reviewDone(DateTime monday) => _lifeReviews.any((r) => r.weekKey == _reviewKey(monday));

  /// Le bilan est à faire le dimanche, ou le lundi / mardi pour la semaine écoulée s'il a été manqué.
  bool _lifeReviewDue() {
    final now = _clockNow;
    final thisMonday = _reviewMonday(now);
    if (now.weekday == 7) return !_reviewDone(thisMonday);
    if (now.weekday <= 2) return !_reviewDone(_addDays(thisMonday, -7));
    return false;
  }

  DateTime _lifeReviewTargetMonday() {
    final now = _clockNow;
    final thisMonday = _reviewMonday(now);
    final previous = _addDays(thisMonday, -7);
    if (now.weekday <= 2 && !_reviewDone(previous)) return previous;
    return thisMonday;
  }

  /// Priorité de la semaine : celle choisie lors du dernier bilan. Le dimanche, le bilan du jour
  /// (qui vaut pour la semaine suivante) passe devant.
  ({LifeReviewEntry entry, bool next})? _weeklyFocusEntry() {
    final now = _clockNow;
    final thisMonday = _reviewMonday(now);
    LifeReviewEntry? find(DateTime monday) {
      for (final r in _lifeReviews.reversed) {
        if (r.weekKey == _reviewKey(monday) && r.focusTitle.isNotEmpty) return r;
      }
      return null;
    }

    if (now.weekday == 7) {
      final current = find(thisMonday);
      if (current != null) return (entry: current, next: true);
    }
    final previous = find(_addDays(thisMonday, -7));
    if (previous != null) return (entry: previous, next: false);
    return null;
  }

  int _focusDoneCount(LifeReviewEntry entry) {
    final monday = _reviewMonday(_clockNow);
    final name = entry.focusTitle.trim().toLowerCase();
    return logs.where((l) {
      if (!_logIsRealised(l) || l.date.isBefore(monday)) return false;
      return l.activityId == entry.focusActivityId || (l.activityId == null && l.title.trim().toLowerCase() == name);
    }).length;
  }

  String _reviewReasonLabel(String? activityId) {
    if (activityId == null) return '';
    final key = _coachRemobilizationReasons[activityId];
    if (key == null) return '';
    for (final entry in kCoachRemobilizationReasons) {
      if (entry.$1 == key) return entry.$2.toLowerCase();
    }
    return '';
  }

  _LifeReviewData _buildLifeReview(DateTime monday) {
    final now = _clockNow;
    final isCurrent = monday == _reviewMonday(now);
    final spanDays = isCurrent ? now.weekday : 7;
    final complete = !isCurrent || now.weekday == 7;
    final end = _addDays(monday, spanDays);
    final prevMonday = _addDays(monday, -7);
    final prevEnd = _addDays(prevMonday, spanDays);
    bool inRange(DateTime d, DateTime a, DateTime b) => !d.isBefore(a) && d.isBefore(b);

    final weekLogs = logs.where((l) => _logIsRealised(l) && inRange(l.date, monday, end)).toList();
    final prevLogs = logs.where((l) => _logIsRealised(l) && inRange(l.date, prevMonday, prevEnd)).toList();
    int dayCount(List<ActivityLog> list) => list.map((l) => _contractKey(l.date)).toSet().length;
    final activeDays = dayCount(weekLogs);
    final prevActiveDays = dayCount(prevLogs);
    final minutes = _timeMinutesOf(weekLogs);
    final prevMinutes = _timeMinutesOf(prevLogs);
    final contracts = _contractStats(monday, end);

    final wins = <String>[];
    final struggles = <String>[];
    final form = <String>[];
    final missedGoalActivityIds = <String>[];

    // ----- objectifs -----
    var goalsReached = 0;
    var goalsTotal = 0;
    for (final g in _realizationGoals) {
      final activity = findActivity(g.activityId);
      if (activity == null || activity.isFrozen) continue;
      if (g.cadence == 'semaine') {
        goalsTotal++;
        final count = _goalProgress(g, monday);
        final target = _goalTargetFor(g, monday);
        final ok = g.isMaximum ? count <= target : count >= target;
        if (ok) {
          goalsReached++;
          if (!g.isMaximum) wins.add('Objectif atteint : ${activity.name} ($count/$target)');
        } else if (complete || (!g.isMaximum && _remobCurrentPeriodBehind(g, count, now))) {
          struggles.add(g.isMaximum ? '${activity.name} : plafond dépassé ($count/$target)' : '${activity.name} : $count/$target cette semaine');
          missedGoalActivityIds.add(activity.id);
        } else {
          // semaine en cours : l'objectif reste atteignable, on ne le juge pas.
          goalsTotal--;
        }
      } else if (g.cadence == 'jour') {
        var okDays = 0;
        var judged = 0;
        for (var i = 0; i < spanDays; i++) {
          final day = _addDays(monday, i);
          if (day.isAfter(now) || DateTime(g.createdAt.year, g.createdAt.month, g.createdAt.day).isAfter(day)) continue;
          judged++;
          final count = _goalProgress(g, day);
          final target = _goalTargetFor(g, day);
          if (g.isMaximum ? count <= target : count >= target) okDays++;
        }
        if (judged >= 3) {
          goalsTotal++;
          if (okDays / judged >= 0.8) {
            goalsReached++;
            wins.add('${activity.name} : tenu $okDays jours sur $judged');
          } else if (okDays / judged <= 0.4) {
            struggles.add('${activity.name} : tenu seulement $okDays jours sur $judged');
            missedGoalActivityIds.add(activity.id);
          }
        }
      }
    }

    // ----- reports et freins -----
    final postponed = <String, int>{};
    final postponedNames = <String, String>{};
    for (final m in activityMoveLogs) {
      if (!inRange(m.date, monday, end) || !_isPostponementMove(m)) continue;
      final key = m.activityId ?? 'title:${m.activityName.trim().toLowerCase()}';
      postponed[key] = (postponed[key] ?? 0) + 1;
      postponedNames[key] = m.activityName;
    }
    final topPostponed = postponed.entries.where((e) => e.value >= 2).toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in topPostponed.take(2)) {
      final reason = _reviewReasonLabel(e.key.startsWith('title:') ? null : e.key);
      struggles.add('« ${postponedNames[e.key]} » repoussé ${e.value} fois${reason.isEmpty ? '' : ' · frein : $reason'}');
    }

    // ----- contrats -----
    if (contracts.total > 0) {
      if (contracts.kept > 0) wins.add('Contrats tenus : ${contracts.kept}/${contracts.total}');
      final missed = contracts.total - contracts.kept;
      if (missed > 0) struggles.add('${missed == 1 ? 'Un contrat non tenu' : '$missed contrats non tenus'} cette semaine');
    }

    // ----- régularité, série, ressenti -----
    if (activeDays > prevActiveDays && activeDays >= 2) {
      wins.add('$activeDays jours actifs (+${activeDays - prevActiveDays} vs la semaine précédente)');
    }
    final streak = _coachStreakInfo();
    if (streak.now >= 3) wins.add('Série en cours : ${streak.now} jours');
    final veryGood = weekLogs.where((l) => l.feeling == 'Très bien').length;
    final good = weekLogs.where((l) => l.feeling == 'Bien').length;
    final difficult = weekLogs.where((l) => l.feeling == 'Difficile').length;
    if (veryGood >= 2) wins.add('$veryGood moments ressentis « Très bien »');
    if (difficult >= 2) struggles.add('$difficult moments ressentis « Difficile » : charge à surveiller');

    // ----- forme : Nutrition, ressenti, poids -----
    final engine = _balanceNutritionEngine();
    if (engine != null) {
      final days = engine.weekDays(isCurrent ? 0 : 1);
      final evaluated = days.where((d) => d.evaluated).length;
      if (evaluated > 0) {
        final held = days.where((d) => d.state == _NutDayState.held).length;
        final off = days.where((d) => d.state == _NutDayState.off).length;
        form.add('Nutrition : $held/$evaluated ${_nutPlural(evaluated, 'jour tenu', 'jours tenus')}${off > 0 ? ' · $off hors cadre' : ''}');
        if (off >= 2) struggles.add('Nutrition : $off jours hors cadre');
      }
    }
    final pnns = _pnnsWeek(monday, spanDays);
    if (pnns.total > 0) {
      form.add('Repères PNNS : ${pnns.met}/${pnns.total} tenus');
      final worst = pnns.rows.where((r) => r.status == _PnnsStatus.missing || r.status == _PnnsStatus.over).toList();
      if (worst.isNotEmpty) struggles.add('PNNS : ${worst.first.ref.label} à améliorer (${worst.first.detail.toLowerCase()})');
    }
    if (veryGood + good + difficult > 0) {
      form.add('Ressenti : $veryGood « Très bien » · $good « Bien » · $difficult « Difficile »');
    }
    // Le poids n'apparaît que s'il existe des mesures : une donnée absente n'est pas un échec.
    final weight = _weightProgressChip();
    if (weight.value != 'À saisir') form.add('Poids : ${weight.value} (${weight.sub})');

    // ----- priorité possible pour la semaine suivante -----
    final candidates = <_ContractCandidate>[];
    final seen = <String>{};
    void addCandidate(Activity? a, String reason) {
      if (a == null || a.isFrozen || a.isDateRange || _isNutritionActivity(a) || !seen.add(a.id)) return;
      candidates.add(_ContractCandidate(a, reason));
    }

    for (final p in _procrastinationItems()) {
      addCandidate(p.activity, 'Repoussée ${p.count} fois');
    }
    for (final id in missedGoalActivityIds) {
      addCandidate(findActivity(id), 'Objectif manqué cette semaine');
    }
    for (final r in _coachRemobilizationItems()) {
      if (r.level != _CoachRemobilizationLevel.returnToTrack && r.level != _CoachRemobilizationLevel.overLimit) {
        addCandidate(r.activity, 'À relancer');
      }
    }
    for (final id in _dailyPriorityActivityIds) {
      addCandidate(findActivity(id), 'Une de tes priorités');
    }

    return _LifeReviewData(
      monday: monday,
      lastDay: _addDays(end, -1),
      complete: complete,
      activeDays: activeDays,
      prevActiveDays: prevActiveDays,
      minutes: minutes,
      prevMinutes: prevMinutes,
      contractsKept: contracts.kept,
      contractsTotal: contracts.total,
      goalsReached: goalsReached,
      goalsTotal: max(0, goalsTotal),
      wins: wins.take(4).toList(),
      struggles: struggles.take(4).toList(),
      form: form,
      candidates: candidates.take(4).toList(),
    );
  }

  /// Ajustements applicables en un geste, avec les mécanismes déjà en place (rampe, déblocage, objectif).
  List<_ReviewAdjust> _reviewAdjustments() {
    final result = <_ReviewAdjust>[];
    final seen = <String>{};
    for (final p in _procrastinationItems()) {
      final id = p.activity?.id ?? p.key;
      if (!seen.add(id)) continue;
      result.add(_ReviewAdjust(
        id: 'proc_$id',
        label: 'Débloquer « ${p.title} »',
        detail: 'Repoussé ${p.count} fois : version courte, créneau fixe ou pause.',
        button: 'Débloquer',
        onTap: () => _openProcrastinationSheet(p),
      ));
    }
    for (final r in _coachRemobilizationItems()) {
      if (r.level == _CoachRemobilizationLevel.returnToTrack || r.level == _CoachRemobilizationLevel.overLimit) continue;
      if (!seen.add(r.activity.id)) continue;
      if (r.rampTarget != null) {
        result.add(_ReviewAdjust(
          id: 'ramp_${r.activity.id}',
          label: 'Alléger « ${r.activity.name} » à ${r.rampTarget} ${_goalCadenceLabel(r.goal.cadence)}',
          detail: 'Pendant ${r.rampPeriods} ${_remobUnit(r.goal, r.rampPeriods)}, puis retour à ${r.goal.target} : un planning réaliste plutôt qu\'un objectif abandonné.',
          button: 'Alléger',
          onTap: () async => _applyCoachRamp(r),
        ));
      } else if (r.level == _CoachRemobilizationLevel.pattern) {
        result.add(_ReviewAdjust(
          id: 'method_${r.activity.id}',
          label: 'Revoir « ${r.activity.name} »',
          detail: 'Plusieurs périodes sous la cible : changer de méthode ou d’objectif.',
          button: 'Revoir',
          onTap: () => _openCoachRemobilization(r),
        ));
      }
    }
    return result.take(4).toList();
  }

  Widget _reviewHeading(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w900, color: _colors.textStrong)),
      );

  Widget _reviewBullet(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textStrong))),
        ]),
      );

  Widget _reviewStat(double width, String label, String value, String sub) => SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          decoration: BoxDecoration(
            color: _colors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: _colors.borderTint),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, height: 1.2, color: _colors.textMuted)),
          ]),
        ),
      );

  String _reviewDateLabel(DateTime d) => '${d.day} ${_frMonthsLong[d.month - 1]}';

  Future<void> _openLifeReview() async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    final monday = _lifeReviewTargetMonday();
    final data = _buildLifeReview(monday);
    final adjustments = _reviewAdjustments();
    final applied = <String>{};
    final previousFocus = _lifeReviews.where((r) => r.weekKey == _reviewKey(monday)).toList();
    String? focusId = previousFocus.isNotEmpty && previousFocus.last.focusActivityId != null
        ? previousFocus.last.focusActivityId
        : (data.candidates.isNotEmpty ? data.candidates.first.activity.id : null);

    String delta(int now, int before, String unit) {
      final diff = now - before;
      if (before == 0 && now == 0) return 'comme la semaine précédente';
      return diff > 0 ? '↗ +$diff $unit vs semaine précédente' : (diff < 0 ? '↘ $diff $unit vs semaine précédente' : '= semaine précédente');
    }

    final result = await showModalBottomSheet<String>(
      context: navigationContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final statWidth = (MediaQuery.of(sheetContext).size.width - 32 - 8) / 2;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  data.complete ? 'Bilan de la semaine' : 'Point de la semaine en cours',
                  style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong),
                ),
                const SizedBox(height: 2),
                Text(
                  'Du ${_reviewDateLabel(data.monday)} au ${_reviewDateLabel(data.lastDay)}',
                  style: TextStyle(fontSize: AppType.body, color: _colors.textMuted),
                ),
                if ((weeklyNotes[_reviewKey(data.monday)] ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _colors.tintSoft, borderRadius: BorderRadius.circular(AppRadius.m)),
                    child: Text(
                      'Ton petit mot : « ${weeklyNotes[_reviewKey(data.monday)]!.trim()} »',
                      style: TextStyle(fontSize: AppType.body, height: 1.3, fontStyle: FontStyle.italic, color: _colors.textStrong),
                    ),
                  ),
                ],
                _reviewHeading('En chiffres'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _reviewStat(statWidth, 'Jours actifs', '${data.activeDays}', delta(data.activeDays, data.prevActiveDays, data.activeDays - data.prevActiveDays == 1 || data.activeDays - data.prevActiveDays == -1 ? 'jour' : 'jours')),
                  _reviewStat(statWidth, 'Temps réalisé', _minutesLabel(data.minutes), 'semaine précédente : ${_minutesLabel(data.prevMinutes)}'),
                  _reviewStat(statWidth, 'Contrats du matin', data.contractsTotal == 0 ? '–' : '${data.contractsKept}/${data.contractsTotal}', data.contractsTotal == 0 ? 'aucun contrat jugé' : 'tenus'),
                  _reviewStat(statWidth, 'Objectifs', data.goalsTotal == 0 ? '–' : '${data.goalsReached}/${data.goalsTotal}', data.goalsTotal == 0 ? 'aucun objectif jugé' : 'atteints'),
                ]),
                _reviewHeading('Réussites'),
                if (data.wins.isEmpty)
                  _reviewBullet(Icons.wb_sunny_outlined, _colors.textMuted, 'Pas encore de réussite marquante : la semaine prochaine peut changer ça.')
                else
                  for (final line in data.wins) _reviewBullet(Icons.check_circle_rounded, _colors.accentIcon, line),
                _reviewHeading('Difficultés'),
                if (data.struggles.isEmpty)
                  _reviewBullet(Icons.check_circle_outline_rounded, _colors.textMuted, 'Rien de gênant cette semaine : tu es dans le cadre.')
                else
                  for (final line in data.struggles) _reviewBullet(Icons.error_outline_rounded, _colors.goldText, line),
                if (data.form.isNotEmpty) ...[
                  _reviewHeading('Forme'),
                  for (final line in data.form) _reviewBullet(Icons.favorite_border_rounded, _colors.accentIcon, line),
                ],
                if (adjustments.isNotEmpty) ...[
                  _reviewHeading('Ajustements proposés'),
                  for (final adjust in adjustments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _colors.surfaceSoft,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          border: Border.all(color: _colors.borderTint),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(adjust.label, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                              const SizedBox(height: 2),
                              Text(adjust.detail, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          applied.contains(adjust.id)
                              ? Icon(Icons.check_circle_rounded, color: _colors.accentIcon)
                              : FilledButton.tonal(
                                  onPressed: () async {
                                    await adjust.onTap();
                                    setSheetState(() => applied.add(adjust.id));
                                  },
                                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                                  child: Text(adjust.button),
                                ),
                        ]),
                      ),
                    ),
                ],
                _reviewHeading('Ma priorité de la semaine prochaine'),
                Text(
                  'Une seule. Elle passera en tête de tes contrats du matin.',
                  style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                ),
                const SizedBox(height: 4),
                if (data.candidates.isEmpty)
                  Text('Aucune activité à relancer en particulier : garde ton rythme.', style: TextStyle(fontSize: AppType.body, color: _colors.textStrong))
                else
                  for (final c in data.candidates)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        c.activity.id == focusId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: c.activity.id == focusId ? _colors.accentIcon : _colors.textMuted,
                      ),
                      title: Text(c.activity.name, style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      subtitle: Text(c.reason, style: TextStyle(color: _colors.textMuted)),
                      onTap: () => setSheetState(() => focusId = c.activity.id),
                    ),
                if (data.candidates.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(focusId == null ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: focusId == null ? _colors.accentIcon : _colors.textMuted),
                    title: Text('Pas de priorité particulière', style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong)),
                    onTap: () => setSheetState(() => focusId = null),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'save'),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Valider le bilan'),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, 'detail'),
                    child: const Text('Voir le bilan détaillé sur 4 semaines'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (result == 'detail') {
      openWeeklyReview();
      return;
    }
    if (result != 'save') return;
    final activity = focusId == null ? null : findActivity(focusId!);
    setState(() {
      _lifeReviews.removeWhere((r) => r.weekKey == _reviewKey(monday));
      _lifeReviews.add(LifeReviewEntry(
        weekKey: _reviewKey(monday),
        focusActivityId: activity?.id,
        focusTitle: activity?.name ?? '',
        doneAt: _clockNow,
      ));
      if (_lifeReviews.length > 26) _lifeReviews.removeRange(0, _lifeReviews.length - 26);
    });
    _queueLocalStatePersist();
    _showFeedback(activity == null
        ? '📝 Bilan enregistré.'
        : '📝 Bilan enregistré. Priorité de la semaine prochaine : « ${activity.name} ».');
  }
}
