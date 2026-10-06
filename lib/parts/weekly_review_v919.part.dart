// V12.5.0 — Bilan redessiné sur les composants communs (app_ui.part.dart) :
// résumé de la semaine en tête, regard du coach, rythme sur 4 semaines en barres,
// ressentis proportionnels, déplacements lisibles. Les calculs restent ceux de V9.32.

part of '../main.dart';

class _WeeklyReviewPage extends StatefulWidget {
  final List<PlanItem> plan;
  final List<ActivityLog> logs;
  final List<ActivityMoveLog> moveLogs;
  final List<Activity> activities;
  final String weeklyNote;
  final ValueChanged<String> onSaveNote;
  final VoidCallback onOpenHistory;
  final VoidCallback onReplan;
  final String coachSummary;
  final List<String> coachInsights;
  final VoidCallback onOpenCoachDecisions;
  final DateTime referenceNow;

  const _WeeklyReviewPage({
    required this.plan,
    required this.logs,
    required this.moveLogs,
    required this.activities,
    required this.weeklyNote,
    required this.onSaveNote,
    required this.onOpenHistory,
    required this.onReplan,
    required this.coachSummary,
    required this.coachInsights,
    required this.onOpenCoachDecisions,
    required this.referenceNow,
  });

  @override
  State<_WeeklyReviewPage> createState() => _WeeklyReviewPageState();
}

class _WeeklyReviewPageState extends State<_WeeklyReviewPage> {
  late final TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    noteController = TextEditingController(text: widget.weeklyNote);
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  String _dm(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  Widget _coachBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 9),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: _colors.accentIcon, shape: BoxShape.circle)),
        ),
        Expanded(child: Text(text, style: TextStyle(fontSize: AppType.body, color: _colors.textStrong, height: 1.35))),
      ]),
    );
  }

  Widget _meterLine({
    required String iconKey,
    required IconData icon,
    required String label,
    required int minutes,
    required int total,
    required Color color,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _uiIcon(iconKey, icon, size: 20, color: _colors.accentIcon),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
        Text(_minutesLabel(minutes), style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
      ]),
      const SizedBox(height: 7),
      _MeterBar(value: total <= 0 ? 0 : minutes / total, color: color),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = <String>['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final trackedPlan = widget.plan.where((p) => p.activityId != null).toList();
    final completed = trackedPlan.where((p) => p.done).length;
    final completionRate = trackedPlan.isEmpty ? 0.0 : completed / trackedPlan.length;
    final plannedMinutes = trackedPlan.fold<int>(0, (sum, item) => sum + item.duration);
    final realisedMinutes = trackedPlan.where((item) => item.done).fold<int>(0, (sum, item) => sum + (item.realisedMinutes ?? item.duration));
    final remainingMinutes = max(0, plannedMinutes - realisedMinutes);
    final currentWeekStart = widget.referenceNow;
    final monday = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day).subtract(Duration(days: currentWeekStart.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final weekMoves = widget.moveLogs.where((m) => !m.date.isBefore(monday) && m.date.isBefore(nextMonday)).toList()..sort((a,b) => b.date.compareTo(a.date));
    final weekLogs = widget.logs.where((log) => !log.date.isBefore(monday) && log.date.isBefore(nextMonday) && log.realisedMinutes > 0).toList();
    final validatedMinutes = weekLogs.fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final unplanned = weekLogs.where((log) => log.unplanned).length;
    final pianoMinutes = weekLogs
        .where((log) => log.title.toLowerCase().contains('piano'))
        .fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final sportMinutes = weekLogs
        .where((log) => log.category == 'Sport')
        .fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final veryGood = weekLogs.where((log) => _normalizeFeeling(log.feeling) == 'Très bien').length;
    final good = weekLogs.where((log) => _normalizeFeeling(log.feeling) == 'Bien').length;
    final difficult = weekLogs.where((log) => _normalizeFeeling(log.feeling) == 'Difficile').length;
    final feelingTotal = veryGood + good + difficult;

    // Rythme sur 4 semaines calendaires (index 0 = semaine en cours).
    final fourWeekRows = List.generate(4, (index) {
      final start = monday.subtract(Duration(days: index * 7));
      final end = start.add(const Duration(days: 7));
      final rowLogs = widget.logs.where((log) => !log.date.isBefore(start) && log.date.isBefore(end) && log.realisedMinutes > 0).toList();
      final minutes = rowLogs.fold<int>(0, (sum, log) => sum + max(0, log.realisedMinutes));
      final activeDays = rowLogs
          .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
          .toSet()
          .length;
      final difficultCount = rowLogs.where((log) => _normalizeFeeling(log.feeling) == 'Difficile').length;
      return _ReviewWeekSummary(
        start: start,
        end: end,
        moments: rowLogs.length,
        minutes: minutes,
        activeDays: activeDays,
        difficult: difficultCount,
      );
    });
    final totalFourWeeksMinutes = fourWeekRows.fold<int>(0, (sum, row) => sum + row.minutes);
    final totalFourWeeksMoments = fourWeekRows.fold<int>(0, (sum, row) => sum + row.moments);
    final totalFourWeeksDifficult = fourWeekRows.fold<int>(0, (sum, row) => sum + row.difficult);
    final maxWeekMinutes = fourWeekRows.fold<int>(0, (m, row) => max(m, row.minutes));
    final totalActiveDays = widget.logs
        .where((log) => !log.date.isBefore(monday.subtract(const Duration(days: 21))) && log.date.isBefore(nextMonday) && log.realisedMinutes > 0)
        .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
        .toSet()
        .length;

    String directionTitle;
    String directionText;
    final averageActiveDays = totalActiveDays / 4.0;
    final averageMinutes = totalFourWeeksMinutes / 4.0;
    if (totalFourWeeksDifficult >= 4) {
      directionTitle = 'Garder de la respiration';
      directionText = 'Les ressentis difficiles sont assez présents sur les quatre semaines. Pour la suite, le Coach préservera davantage les espaces libres et évitera de charger inutilement les journées déjà denses.';
    } else if (averageActiveDays < 2.0) {
      directionTitle = 'Retrouver un petit rythme';
      directionText = 'Le rythme reste léger sur les quatre dernières semaines. Le Coach cherchera surtout à installer quelques rendez-vous réguliers et faciles à tenir, plutôt qu’à augmenter brutalement le volume.';
    } else if (averageMinutes >= 180) {
      directionTitle = 'Consolider ce qui fonctionne';
      directionText = 'Le temps réellement vécu est déjà bien installé. La suite peut privilégier la continuité, les activités qui apportent du plaisir et quelques ajustements ciblés plutôt qu’une augmentation générale.';
    } else {
      directionTitle = 'Avancer sans forcer';
      directionText = 'Le rythme est présent mais encore perfectible. Le Coach cherchera à conserver les habitudes qui fonctionnent, tout en rééquilibrant progressivement les moments moins réguliers.';
    }

    final backIcon = _uiIconValue('reviewBack', '←');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan · 4 semaines'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: (backIcon.startsWith('customicon://') || backIcon.startsWith('pack://'))
              ? _activityIconWidget(backIcon, size: 20)
              : Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _colors.textStrong),
          tooltip: 'Retour',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 28),
          children: [
            // 1. Résumé de la semaine
            _AppCard(
              tone: _CardTone.tint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionHeader(
                  iconKey: 'reviewMoments',
                  fallbackIcon: Icons.check_circle_outline,
                  title: 'Cette semaine',
                  trailing: _Pill('${_dm(monday)} – ${_dm(nextMonday.subtract(const Duration(days: 1)))}', background: _colors.card, foreground: _colors.textMuted),
                ),
                const SizedBox(height: AppSpace.l),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${(completionRate * 100).round()} %',
                    style: TextStyle(fontFamily: AppFonts.serif, fontSize: AppType.hero, fontWeight: FontWeight.w700, color: _colors.textStrong, height: 1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        trackedPlan.isEmpty
                            ? 'Aucun moment planifié cette semaine'
                            : '$completed moment${completed > 1 ? 's' : ''} réalisé${completed > 1 ? 's' : ''} sur ${trackedPlan.length}',
                        style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textMuted),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpace.m),
                _MeterBar(value: completionRate, height: 10),
                const SizedBox(height: AppSpace.l),
                _statTiles([
                  _StatTile(label: 'Prévu', value: _minutesLabel(plannedMinutes), iconKey: 'reviewPlanned', icon: Icons.schedule_outlined),
                  _StatTile(label: 'Réalisé', value: _minutesLabel(realisedMinutes), iconKey: 'reviewRealized', icon: Icons.play_circle_outline),
                  _StatTile(label: 'À faire', value: _minutesLabel(remainingMinutes), iconKey: 'reviewRemaining', icon: Icons.hourglass_empty_outlined),
                ]),
                const SizedBox(height: AppSpace.s),
                _statTiles([
                  _StatTile(label: 'Temps validé', value: _minutesLabel(validatedMinutes), iconKey: 'reviewValidated', icon: Icons.timer_outlined),
                  _StatTile(label: 'Déplacées', value: '${weekMoves.length}', iconKey: 'reviewMoved', icon: Icons.open_with_outlined),
                  _StatTile(label: 'Imprévus', value: '$unplanned', iconKey: 'reviewUnexpected', icon: Icons.auto_awesome_outlined),
                ]),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 2. Regard du coach + cap
            _AppCard(
              tone: _CardTone.tint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionHeader(
                  iconKey: 'coach',
                  fallbackIcon: Icons.psychology_outlined,
                  title: 'Le regard du coach',
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Pourquoi ces choix ?',
                    onPressed: widget.onOpenCoachDecisions,
                    icon: _uiIcon('help', Icons.help_outline_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                Text(widget.coachSummary, style: TextStyle(fontSize: AppType.body, height: 1.4, color: _colors.textStrong)),
                if (widget.coachInsights.isNotEmpty) const SizedBox(height: AppSpace.s),
                ...widget.coachInsights.take(5).map(_coachBullet),
                const SizedBox(height: AppSpace.s),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _colors.card,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    border: Border.all(color: _colors.borderTint),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _uiIcon('coach', Icons.auto_awesome_outlined, size: 18, color: _colors.accentIcon),
                      const SizedBox(width: 8),
                      Text('Cap pour la suite', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                    ]),
                    const SizedBox(height: 6),
                    Text(directionTitle, style: (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(fontSize: AppType.title, fontWeight: FontWeight.w700, color: _colors.accentStrongText)),
                    const SizedBox(height: 5),
                    Text(directionText, style: TextStyle(fontSize: AppType.body, height: 1.4, color: _colors.textMuted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 3. Rythme sur 4 semaines
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionHeader(
                  iconKey: 'week',
                  fallbackIcon: Icons.calendar_month_outlined,
                  title: 'Ton rythme sur 4 semaines',
                  subtitle: 'Le temps réellement vécu, semaine par semaine, sans mélanger les semaines.',
                ),
                const SizedBox(height: AppSpace.m),
                _statTiles([
                  _StatTile(label: 'Jours actifs', value: '$totalActiveDays/28', iconKey: 'reviewActiveDays', icon: Icons.event_available_outlined),
                  _StatTile(label: 'Moments', value: '$totalFourWeeksMoments', iconKey: 'reviewMoments', icon: Icons.check_circle_outline),
                ]),
                const SizedBox(height: AppSpace.s),
                _statTiles([
                  _StatTile(label: 'Temps vécu', value: _minutesLabel(totalFourWeeksMinutes), iconKey: 'reviewTime', icon: Icons.timer_outlined),
                  _StatTile(label: 'Difficiles', value: '$totalFourWeeksDifficult', iconKey: 'reviewDifficult', icon: Icons.battery_alert_outlined),
                ]),
                const SizedBox(height: AppSpace.l),
                ...fourWeekRows.asMap().entries.map((entry) => Padding(
                      padding: EdgeInsets.only(top: entry.key == 0 ? 0 : AppSpace.m),
                      child: _ReviewWeekRow(
                        label: entry.key == 0 ? 'Cette semaine' : 'S-${entry.key}',
                        summary: entry.value,
                        maxMinutes: maxWeekMinutes,
                        current: entry.key == 0,
                      ),
                    )),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 4. Ressentis
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionHeader(
                  iconKey: 'reviewMood',
                  fallbackIcon: Icons.sentiment_satisfied_alt_outlined,
                  title: 'Comment s’est passée la semaine ?',
                ),
                const SizedBox(height: AppSpace.m),
                if (feelingTotal == 0)
                  const _MeterBar(value: 0, height: 10)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Row(children: [
                      if (veryGood > 0) Expanded(flex: veryGood, child: Container(height: 10, color: _feelingColor('Très bien'))),
                      if (good > 0) Expanded(flex: good, child: Container(height: 10, margin: EdgeInsets.only(left: veryGood > 0 ? 2 : 0), color: _feelingColor('Bien'))),
                      if (difficult > 0) Expanded(flex: difficult, child: Container(height: 10, margin: EdgeInsets.only(left: (veryGood + good) > 0 ? 2 : 0), color: _feelingColor('Difficile'))),
                    ]),
                  ),
                const SizedBox(height: AppSpace.m),
                Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
                  _Pill('Très bien · $veryGood', dot: _feelingColor('Très bien')),
                  _Pill('Bien · $good', dot: _feelingColor('Bien')),
                  _Pill('Difficile · $difficult', dot: _feelingColor('Difficile')),
                ]),
                const SizedBox(height: AppSpace.m),
                Text(
                  weekLogs.isEmpty
                      ? 'Pas encore de retour cette semaine. Le bilan se remplira au fil des moments validés.'
                      : difficult >= 2
                          ? 'Plusieurs moments ont été difficiles : la semaine suivante pourra garder davantage de respiration.'
                          : veryGood + good >= 3
                              ? 'Les retours sont plutôt positifs. Le rythme semble confortable.'
                              : 'Les retours sont variés : le prochain bilan permettra d’affiner le rythme.',
                  style: TextStyle(fontSize: AppType.body, height: 1.4, color: _colors.textMuted),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 5. Musique & mouvement
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionHeader(
                  iconKey: 'reviewPiano',
                  fallbackIcon: Icons.piano_outlined,
                  title: 'Musique & mouvement',
                ),
                const SizedBox(height: AppSpace.l),
                _meterLine(iconKey: 'reviewPiano', icon: Icons.piano_outlined, label: 'Piano', minutes: pianoMinutes, total: validatedMinutes, color: _colors.accentFill),
                const SizedBox(height: AppSpace.l),
                _meterLine(iconKey: 'sport', icon: Icons.directions_walk_outlined, label: 'Activité physique', minutes: sportMinutes, total: validatedMinutes, color: _colors.accentOutline),
                const SizedBox(height: AppSpace.m),
                Text('Part du temps validé cette semaine : ${_minutesLabel(validatedMinutes)} au total.', style: _hintStyle()),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 6. Déplacements
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionHeader(
                  iconKey: 'move',
                  fallbackIcon: Icons.open_with_outlined,
                  title: 'Les déplacements de la semaine',
                  trailing: weekMoves.isEmpty ? null : _Pill('${weekMoves.length}'),
                ),
                const SizedBox(height: AppSpace.m),
                if (weekMoves.isEmpty)
                  Text('Aucune activité n’a été déplacée cette semaine.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted))
                else
                  ...weekMoves.take(8).map((m) {
                    final from = (m.fromDay >= 0 && m.fromDay < dayNames.length) ? dayNames[m.fromDay] : '';
                    final to = (m.toDay >= 0 && m.toDay < dayNames.length) ? dayNames[m.toDay] : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1, right: 10),
                          child: Icon(Icons.swap_horiz_rounded, size: 20, color: _colors.accentIcon),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.activityName, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                            const SizedBox(height: 2),
                            Text('$from ${m.fromPeriod}  →  $to ${m.toPeriod}', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
                          ]),
                        ),
                      ]),
                    );
                  }),
                if (weekMoves.length > 8)
                  Text('${weekMoves.length - 8} autre(s) déplacement(s).', style: _hintStyle()),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 7. Note personnelle
            _AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionHeader(
                  iconKey: 'edit',
                  fallbackIcon: Icons.edit_note_rounded,
                  title: 'Mon petit bilan personnel',
                  subtitle: 'Une phrase suffit : ce qui m’a plu, ce qui a été facile ou ce que j’aimerais changer.',
                ),
                const SizedBox(height: AppSpace.m),
                TextField(
                  controller: noteController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'Ex. Belle balade vendredi, piano agréable lundi…'),
                ),
                const SizedBox(height: AppSpace.m),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onSaveNote(noteController.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilan personnel enregistré.')));
                    },
                    icon: _uiIcon('save', Icons.save_outlined, size: 18, color: _colors.onPrimary),
                    label: const Text('Enregistrer mon bilan'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.m),

            // 8. Pour aller plus loin
            _AppCard(
              tone: _CardTone.soft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Le bilan compare ce qui était prévu avec ce qui a été vécu : validations, durées, ressentis et déplacements aident MyBestWeek à mieux comprendre ton rythme.',
                  style: _hintStyle(),
                ),
                const SizedBox(height: AppSpace.m),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenHistory,
                      icon: _uiIcon('history', Icons.history_outlined, size: 17),
                      label: const Text('Historique'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: widget.onReplan,
                      icon: _uiIcon('coach', Icons.auto_awesome_outlined, size: 17),
                      label: const Text('Repenser'),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}


class _ReviewWeekSummary {
  final DateTime start;
  final DateTime end;
  final int moments;
  final int minutes;
  final int activeDays;
  final int difficult;

  const _ReviewWeekSummary({
    required this.start,
    required this.end,
    required this.moments,
    required this.minutes,
    required this.activeDays,
    required this.difficult,
  });
}

/// Une semaine du rythme : libellé + dates, durée, barre relative, détail.
class _ReviewWeekRow extends StatelessWidget {
  final String label;
  final _ReviewWeekSummary summary;
  final int maxMinutes;
  final bool current;

  const _ReviewWeekRow({required this.label, required this.summary, required this.maxMinutes, required this.current});

  String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      '${summary.activeDays} jour${summary.activeDays > 1 ? 's' : ''} actif${summary.activeDays > 1 ? 's' : ''}',
      '${summary.moments} moment${summary.moments > 1 ? 's' : ''}',
      if (summary.difficult > 0) '${summary.difficult} difficile${summary.difficult > 1 ? 's' : ''}',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(label, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: current ? _colors.accentStrongText : _colors.textStrong)),
        const SizedBox(width: 8),
        Expanded(child: Text('${_dateLabel(summary.start)} – ${_dateLabel(summary.end.subtract(const Duration(days: 1)))}', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted))),
        Text(_minutesLabel(summary.minutes), style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
      ]),
      const SizedBox(height: 6),
      _MeterBar(
        value: maxMinutes <= 0 ? 0 : summary.minutes / maxMinutes,
        color: current ? _colors.accentFill : _colors.accentSoftBorder,
      ),
      const SizedBox(height: 5),
      Text(details.join(' · '), style: TextStyle(fontSize: AppType.small, color: summary.difficult > 0 ? _colors.textWarm : _colors.textMuted)),
    ]);
  }
}
