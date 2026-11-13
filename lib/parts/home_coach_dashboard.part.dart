// V12.23.0 — Rendez-vous du Coach à l'accueil : bilan réel, point d'attention et cap d'action.
// Les réalisations viennent de l'historique daté. Les activités non faites ne sont
// comptées que pour les journées déjà écoulées de la semaine actuellement affichée.

part of '../main.dart';

class _HomeCoachSnapshot {
  final List<ActivityLog> logs;
  final List<PlanItem> pending;
  final bool canCompareWithPlan;

  const _HomeCoachSnapshot({
    required this.logs,
    required this.pending,
    required this.canCompareWithPlan,
  });

  int get completedCount => logs.length;
  int get realisedMinutes => logs.fold<int>(0, (sum, log) => sum + max(0, log.realisedMinutes));
  int get realisedReps => logs.fold<int>(0, (sum, log) => sum + max(0, log.reps ?? 0));
  int get activeDays => logs
      .map((log) => '${log.date.year}-${log.date.month}-${log.date.day}')
      .toSet()
      .length;
  int get difficultCount => logs.where((log) => _normalizeFeeling(log.feeling) == 'Difficile').length;
  int get veryGoodCount => logs.where((log) => _normalizeFeeling(log.feeling) == 'Très bien').length;
}

extension _HomeCoachDashboardPart on _MaBelleSemaineAppState {
  DateTime _coachDateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _coachDateLabel(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${dayNames[date.weekday - 1].toLowerCase()} ${date.day} ${months[date.month - 1]}';
  }

  bool _coachHasRealization(PlanItem item, List<ActivityLog> sourceLogs) {
    if (item.done) return true;
    return sourceLogs.any((log) => log.planItemId != null && log.planItemId == item.id);
  }

  List<PlanItem> _coachPendingItemsForDay(DateTime date, List<ActivityLog> sourceLogs) {
    final weekStart = _startOfCurrentWeek();
    final target = _coachDateOnly(date);
    // Le planning ne conserve qu'une trame hebdomadaire. On ne l'utilise donc
    // pour comparer les rendez-vous passés que si la date appartient à cette semaine.
    if (target.isBefore(weekStart) || !target.isBefore(_addDays(weekStart, 7))) return <PlanItem>[];
    final dayIndex = target.weekday - 1;
    return plan.where((item) {
      if (item.day != dayIndex || item.optional || _isDateRangePlanItem(item)) return false;
      if (item.activityId == null && !item.userAdded) return false;
      return !_coachHasRealization(item, sourceLogs);
    }).toList();
  }

  _HomeCoachSnapshot _coachSnapshotForDate(DateTime date) {
    final target = _coachDateOnly(date);
    final dayLogs = logs.where((log) => _coachDateOnly(log.date) == target).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return _HomeCoachSnapshot(
      logs: dayLogs,
      pending: _coachPendingItemsForDay(target, dayLogs),
      canCompareWithPlan: !target.isBefore(_startOfCurrentWeek()) && target.weekday - 1 < today,
    );
  }

  _HomeCoachSnapshot _coachSnapshotForWeek() {
    final start = _startOfCurrentWeek();
    final now = DateTime.now();
    final endExclusive = _addDays(_coachDateOnly(now), 1);
    final weekLogs = logs.where((log) {
      final date = _coachDateOnly(log.date);
      return !date.isBefore(start) && date.isBefore(endExclusive);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Le jour en cours reste ouvert : ses rendez-vous non validés ne sont pas
    // présentés comme des oublis tant que la journée n'est pas terminée.
    final pending = <PlanItem>[];
    for (var day = 0; day < today; day++) {
      for (final item in plan.where((entry) => entry.day == day)) {
        if (item.optional || _isDateRangePlanItem(item)) continue;
        if (item.activityId == null && !item.userAdded) continue;
        if (!_coachHasRealization(item, weekLogs)) pending.add(item);
      }
    }
    return _HomeCoachSnapshot(logs: weekLogs, pending: pending, canCompareWithPlan: true);
  }

  String _coachCategoryForLog(ActivityLog log) {
    final linked = log.activityId == null ? null : findActivity(log.activityId!);
    final category = (linked?.category ?? log.category).trim();
    return category.isEmpty ? 'Autre' : category;
  }

  Map<String, int> _coachCategoryCounts(List<ActivityLog> sourceLogs) {
    final counts = <String, int>{};
    for (final log in sourceLogs) {
      final category = _coachCategoryForLog(log);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  String _coachBestCategory(List<ActivityLog> sourceLogs) {
    final counts = _coachCategoryCounts(sourceLogs);
    if (counts.isEmpty) return '';
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.key;
  }

  String _coachPendingTitle(PlanItem item) {
    final title = item.title.trim();
    return title.isEmpty ? 'un rendez-vous de ton planning' : '« $title »';
  }

  PlanItem? _coachNextAction() {
    final remaining = actionableItemsForDay(today).where((item) => !item.done).toList();
    if (remaining.isEmpty) return null;
    for (final item in remaining) {
      if (item.activityId != null && _isDailyPriorityActivityId(item.activityId)) return item;
    }
    return remaining.first;
  }

  String _coachDayEncouragement(_HomeCoachSnapshot snapshot) {
    if (snapshot.completedCount == 0) {
      return 'Hier a peut-être été plus calme. Aucun jugement : une journée ne définit pas ta dynamique. Ce qui compte, c’est le prochain pas que tu choisis aujourd’hui.';
    }
    if (snapshot.veryGoodCount > 0) {
      return 'Tu as vécu ${snapshot.completedCount} moment(s), dont ${snapshot.veryGoodCount} avec un très bon ressenti. Repère ce qui t’a fait du bien et donne-lui une place aujourd’hui.';
    }
    if (snapshot.completedCount >= 3) {
      return 'Tu as tenu plusieurs engagements. C’est du concret, pas une intention. Garde cette dynamique et transforme-la en régularité.';
    }
    return 'Tu as déjà mis ${snapshot.completedCount} action(s) dans ta journée. Ne minimise pas ce que tu as fait : consolide ce premier élan aujourd’hui.';
  }

  String _coachDayAttention(_HomeCoachSnapshot snapshot) {
    if (snapshot.difficultCount >= 2) {
      return '${snapshot.difficultCount} moments ont été ressentis comme difficiles. Le signal est clair : ajuste le rythme, mais garde un petit rendez-vous qui te fait du bien.';
    }
    if (snapshot.canCompareWithPlan && snapshot.pending.isNotEmpty) {
      final first = snapshot.pending.first;
      final extra = snapshot.pending.length > 1 ? ' et ${snapshot.pending.length - 1} autre(s)' : '';
      return '${snapshot.pending.length} rendez-vous prévu(s) n’ont pas été validé(s), dont ${_coachPendingTitle(first)}$extra. Pas de culpabilité : décide simplement lesquels méritent d’être replacés.';
    }
    if (snapshot.completedCount == 0) {
      return 'Le bilan d’hier est vide dans l’historique. Il ne permet pas de conclure que tu n’as rien fait : pense à enregistrer tes réalisations pour que le Coach apprenne de tes journées.';
    }
    return 'Aucun signal d’alerte particulier. Le défi maintenant : ne pas laisser tes bonnes habitudes dépendre uniquement de la motivation.';
  }

  String _coachWeekEncouragement(_HomeCoachSnapshot snapshot) {
    if (snapshot.completedCount == 0) {
      return 'La semaine est encore à construire. N’attends pas le déclic parfait : commence par une action simple aujourd’hui, puis répète-la.';
    }
    if (snapshot.activeDays >= 3) {
      final category = _coachBestCategory(snapshot.logs);
      final categoryText = category.isEmpty ? '' : ' Tu as notamment nourri le domaine « $category ». ';
      return '${snapshot.activeDays} journées avec au moins une réalisation : voilà une vraie base de régularité.${categoryText}Continue sur cette lancée, sans chercher à remplir chaque minute.';
    }
    return 'Tu as déjà enregistré ${snapshot.completedCount} réalisation(s). Le prochain progrès n’est pas d’en faire toujours plus, mais de répartir tes efforts sur davantage de journées.';
  }

  String _coachWeekAttention(_HomeCoachSnapshot snapshot) {
    if (snapshot.difficultCount >= 2) {
      return '${snapshot.difficultCount} ressentis difficiles cette semaine : le Coach te recommande de répartir la charge et de préserver des moments de récupération.';
    }
    if (snapshot.pending.isNotEmpty) {
      final first = snapshot.pending.first;
      return '${snapshot.pending.length} rendez-vous des journées écoulées restent sans validation. Reprends-en un seul en priorité, notamment ${_coachPendingTitle(first)}.';
    }
    if (snapshot.activeDays < 3) {
      return 'La régularité est le levier à travailler : mieux vaut 15 à 20 minutes sur plusieurs jours qu’une grosse journée suivie de longues pauses.';
    }
    return 'Ton rythme est encourageant. Veille simplement à garder un équilibre entre mouvement, loisirs, culture et repos.';
  }

  String _coachActionMessage(_HomeCoachSnapshot snapshot, bool weekly) {
    final next = _coachNextAction();
    if (snapshot.difficultCount >= 2) {
      return 'Ton défi : commence par une activité douce ou raccourcis une séance. Tiens ton engagement sans te mettre dans le rouge.';
    }
    if (weekly && snapshot.pending.isNotEmpty) {
      return 'Ton défi : choisis un seul rendez-vous resté de côté et redonne-lui une place réaliste. Une reprise concrète vaut mieux qu’une liste de rattrapage.';
    }
    if (next != null) {
      return 'Ton défi : attaque ${_coachPendingTitle(next)}. Commence par 15 minutes, sans négocier avec toi-même. Une fois lancé, tu auras déjà gagné.';
    }
    if (snapshot.completedCount > 0) {
      return 'Ton défi : protège un moment qui te fait du bien et savoure-le pleinement. La régularité se construit aussi dans le plaisir.';
    }
    return 'Ton défi : choisis une action simple dans ton planning et commence-la maintenant. Pas besoin d’attendre d’être motivé pour avancer.';
  }

  Widget _homeCoachMetric(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _colors.card.withValues(alpha: .76),
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _colors.borderTint.withValues(alpha: .8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: _colors.accentIcon),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w900, color: _colors.textStrong)),
          ),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, height: 1.15, fontWeight: FontWeight.w700, color: _colors.textMuted)),
        ]),
      ),
    );
  }

  Widget _homeCoachInsight({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: _colors.card.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .25, color: color)),
          const SizedBox(height: 3),
          Text(message, style: TextStyle(fontSize: AppType.body, height: 1.28, color: _colors.textStrong, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _homeCoachDashboard() {
    final weekly = _homeCoachView == 'week';
    final todayDate = _coachDateOnly(DateTime.now());
    final yesterday = _addDays(todayDate, -1);
    final snapshot = weekly ? _coachSnapshotForWeek() : _coachSnapshotForDate(yesterday);
    const monthNames = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final weekStart = _startOfCurrentWeek();
    final titleDate = weekly
        ? 'SEMAINE DU ${weekStart.day} ${monthNames[weekStart.month - 1]} · JUSQU’AU ${todayDate.day} ${monthNames[todayDate.month - 1]}'
        : _coachDateLabel(yesterday).toUpperCase();
    final mainMessage = weekly ? _coachWeekEncouragement(snapshot) : _coachDayEncouragement(snapshot);
    final attentionMessage = weekly ? _coachWeekAttention(snapshot) : _coachDayAttention(snapshot);
    final activeLabel = weekly ? 'Jour(s) actif(s)' : 'Moment(s) vécu(s)';
    final activityValue = weekly ? '${snapshot.activeDays}/7' : '${snapshot.completedCount}';
    final timeValue = snapshot.realisedMinutes > 0 ? '${snapshot.realisedMinutes} min' : '—';
    final pendingValue = snapshot.canCompareWithPlan
        ? '${snapshot.pending.length}'
        : '—';
    final repsValue = snapshot.realisedReps > 0 ? ' · ${snapshot.realisedReps} rép.' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 1, 14, 8),
      child: softCard(
        color: _colors.tintStrong,
        borderColor: _colors.borderTint,
        radius: 23,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(color: _colors.card.withValues(alpha: .8), borderRadius: BorderRadius.circular(AppRadius.m)),
              alignment: Alignment.center,
              child: Icon(Icons.auto_awesome_rounded, color: _colors.accentIcon, size: 23),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LE RENDEZ-VOUS DU COACH', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .45, color: _colors.accentStrongText)),
              const SizedBox(height: 1),
              Text('Ton bilan. Ton cap. Ton élan.', style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted, fontWeight: FontWeight.w600)),
            ])),
            IconButton(
              tooltip: _homeCoachExpanded ? 'Réduire le bilan' : 'Afficher le bilan',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: () => setState(() => _homeCoachExpanded = !_homeCoachExpanded),
              icon: Icon(_homeCoachExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _colors.accentIcon, size: 23),
            ),
          ]),
          if (!_homeCoachExpanded) ...[
            const SizedBox(height: 7),
            Text('Bilan replié · touche la flèche pour retrouver tes progrès et ton défi.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
          ] else ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _coachPeriodChoice('Hier', 'yesterday')),
              const SizedBox(width: 6),
              Expanded(child: _coachPeriodChoice('Cette semaine', 'week')),
            ]),
            const SizedBox(height: 9),
            Text(titleDate, style: TextStyle(fontSize: AppType.micro, letterSpacing: .55, fontWeight: FontWeight.w900, color: _colors.textMuted)),
            const SizedBox(height: 7),
            Row(children: [
              _homeCoachMetric(activityValue, activeLabel, Icons.check_circle_outline_rounded),
              const SizedBox(width: 6),
              _homeCoachMetric(repsValue.isEmpty ? timeValue : '$timeValue$repsValue', 'Temps vécu · répétitions', Icons.timer_outlined),
              const SizedBox(width: 6),
              _homeCoachMetric(pendingValue, 'À reprendre', Icons.flag_outlined),
            ]),
            const SizedBox(height: 8),
            _homeCoachInsight(
              title: 'TES POINTS FORTS',
              message: mainMessage,
              icon: Icons.trending_up_rounded,
              color: _colors.accentStrongText,
            ),
            const SizedBox(height: 6),
            _homeCoachInsight(
              title: weekly ? 'LE POINT DE VIGILANCE' : 'LE POINT À REPRENDRE',
              message: attentionMessage,
              icon: Icons.track_changes_rounded,
              color: snapshot.difficultCount >= 2 || snapshot.pending.isNotEmpty ? _colors.goldText : _colors.accentIcon,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              decoration: BoxDecoration(
                color: _colors.card.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(AppRadius.l),
                border: Border.all(color: _colors.borderTint),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.bolt_rounded, color: _colors.goldText, size: 19),
                  const SizedBox(width: 6),
                  Text('TON DÉFI', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .5, color: _colors.goldText)),
                ]),
                const SizedBox(height: 4),
                Text(_coachActionMessage(snapshot, weekly), style: TextStyle(fontSize: AppType.bodyL, height: 1.28, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                const SizedBox(height: 5),
                Text('« Ne cherche pas la journée parfaite. Fais de cette journée une journée qui compte. »', style: TextStyle(fontSize: AppType.small, height: 1.2, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: _colors.textWarm)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _coachPeriodChoice(String label, String value) {
    final selected = _homeCoachView == value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: selected ? null : () => setState(() => _homeCoachView = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _colors.card : _colors.tintSoft.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? _colors.accentSoftBorder : _colors.borderTint),
        ),
        child: Text(label, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, color: selected ? _colors.accentStrongText : _colors.textMuted)),
      ),
    );
  }
}
