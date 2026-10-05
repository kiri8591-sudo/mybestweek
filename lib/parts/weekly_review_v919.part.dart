// V9.32.0 — Bilan final : semaine courante + rythme sur 4 semaines.
// La page conserve la lecture de la semaine en cours et ajoute une vue
// réellement calculée sur les quatre dernières semaines calendaires.

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan · 4 semaines'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: (_uiIconValue('reviewBack', '←').startsWith('customicon://') || _uiIconValue('reviewBack', '←').startsWith('pack://')) ? _activityIconWidget(_uiIconValue('reviewBack', '←'), size: 20) : Text(_uiIconValue('reviewBack', '←'), style: const TextStyle(fontSize: AppType.h1)),
          tooltip: 'Retour',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Card(
              color: _colors.tintStrong,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cette semaine en quelques chiffres', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'Moments réalisés', value: '$completed/${trackedPlan.length}', iconKey: 'reviewMoments', icon: Icons.check_circle_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Régularité', value: '${(completionRate * 100).round()} %', iconKey: 'reviewRegularity', icon: Icons.calendar_month_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'Prévu', value: '$plannedMinutes min', iconKey: 'reviewPlanned', icon: Icons.schedule_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Réalisé', value: '$realisedMinutes min', iconKey: 'reviewRealized', icon: Icons.play_circle_outline)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'À faire', value: '$remainingMinutes min', iconKey: 'reviewRemaining', icon: Icons.hourglass_empty_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Déplacées', value: '${weekMoves.length}', iconKey: 'reviewMoved', icon: Icons.open_with_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'Temps validé', value: '$validatedMinutes min', iconKey: 'reviewValidated', icon: Icons.timer_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Imprévus', value: '$unplanned', iconKey: 'reviewUnexpected', icon: Icons.auto_awesome_outlined)),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: completionRate, minHeight: 9, borderRadius: BorderRadius.circular(AppRadius.xl)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: _colors.tintStrong,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('coach', Icons.psychology_outlined, size: 18, color: _colors.accentIcon),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Le regard du coach', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Pourquoi ces choix ?',
                      onPressed: widget.onOpenCoachDecisions,
                      icon: _uiIcon('help', Icons.help_outline_rounded, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 7),
                  Text(widget.coachSummary, style: const TextStyle(fontSize: AppType.body, height: 1.35)),
                  const SizedBox(height: 8),
                  ...widget.coachInsights.take(5).map((text) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('• ', style: TextStyle(fontWeight: FontWeight.w800, color: _colors.accentIcon)),
                      Expanded(child: Text(text, style: TextStyle(fontSize: AppType.label, color: _colors.accentIcon, height: 1.25))),
                    ]),
                  )),
                ]),
              ),
            ),

            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final weekStart = monday;
                final fourWeekRows = List.generate(4, (index) {
                  final start = weekStart.subtract(Duration(days: index * 7));
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
                final totalActiveDays = widget.logs
                    .where((log) => !log.date.isBefore(weekStart.subtract(const Duration(days: 21))) && log.date.isBefore(nextMonday) && log.realisedMinutes > 0)
                    .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
                    .toSet()
                    .length;

                String directionTitle;
                String directionText;
                final averageActiveDays = totalActiveDays / 4.0;
                final averageMinutes = totalFourWeeksMinutes / 4.0;
                if (totalFourWeeksDifficult >= 4) {
                  directionTitle = 'Cap conseillé : garder de la respiration';
                  directionText = 'Les ressentis difficiles sont assez présents sur les quatre semaines. Pour la suite, le Coach préservera davantage les espaces libres et évitera de charger inutilement les journées déjà denses.';
                } else if (averageActiveDays < 2.0) {
                  directionTitle = 'Cap conseillé : retrouver un petit rythme';
                  directionText = 'Le rythme reste léger sur les quatre dernières semaines. Le Coach cherchera surtout à installer quelques rendez-vous réguliers et faciles à tenir, plutôt qu’à augmenter brutalement le volume.';
                } else if (averageMinutes >= 180) {
                  directionTitle = 'Cap conseillé : consolider ce qui fonctionne';
                  directionText = 'Le temps réellement vécu est déjà bien installé. La suite peut privilégier la continuité, les activités qui apportent du plaisir et quelques ajustements ciblés plutôt qu’une augmentation générale.';
                } else {
                  directionTitle = 'Cap conseillé : avancer sans forcer';
                  directionText = 'Le rythme est présent mais encore perfectible. Le Coach cherchera à conserver les habitudes qui fonctionnent, tout en rééquilibrant progressivement les moments moins réguliers.';
                }

                return Column(
                  children: [
                    Card(
                      color: _colors.tintStrong,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            _uiIcon('coach', Icons.auto_awesome_outlined, size: 19, color: _colors.accentIcon),
                            const SizedBox(width: 8),
                            Expanded(child: Text('La direction pour la suite', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          ]),
                          const SizedBox(height: 7),
                          Text(directionTitle, style: const TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(directionText, style: TextStyle(fontSize: AppType.label, height: 1.35, color: _colors.accentIcon)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: _colors.surfaceSunken,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('🗓️', style: TextStyle(fontSize: AppType.h2)),
                        const SizedBox(width: 7),
                        Expanded(child: Text('Ton rythme sur 4 semaines', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                      ]),
                      const SizedBox(height: 5),
                      Text(
                        'Une vue simple des quatre dernières semaines pour voir le rythme réel, sans mélanger les semaines.',
                        style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.3),
                      ),
                      const SizedBox(height: 11),
                      Row(children: [
                        Expanded(child: _ReviewStat(label: 'Jours actifs', value: '$totalActiveDays/28', iconKey: 'reviewActiveDays', icon: Icons.event_available_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _ReviewStat(label: 'Moments', value: '$totalFourWeeksMoments', iconKey: 'reviewMoments', icon: Icons.check_circle_outline)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _ReviewStat(label: 'Temps vécu', value: '$totalFourWeeksMinutes min', iconKey: 'reviewTime', icon: Icons.timer_outlined)),
                        const SizedBox(width: 8),
                        Expanded(child: _ReviewStat(label: 'Difficiles', value: '$totalFourWeeksDifficult', iconKey: 'reviewDifficult', icon: Icons.battery_alert_outlined)),
                      ]),
                      const SizedBox(height: 13),
                      ...fourWeekRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 7),
                          child: _ReviewWeekRow(
                            label: index == 0 ? 'Cette semaine' : 'S-${index}',
                            summary: row,
                          ),
                        );
                      }),
                    ]),
                  ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              color: _colors.surfaceSunken,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('insights', Icons.insights_outlined, size: 18, color: _colors.accentIcon),
                    const SizedBox(width: 8),
                    Expanded(child: Text('À quoi sert ce bilan ?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 7),
                  Text(
                    'Le bilan compare ce qui était prévu avec ce qui a réellement été vécu. Il rassemble tes validations, tes durées, tes ressentis et tes déplacements pour aider MyBestWeek à mieux comprendre ton rythme.',
                    style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenHistory,
                        icon: _uiIcon('history', Icons.history_outlined, size: 17),
                        label: const Text('Historique & mémoire'),
                      ),
                    ),
                    const SizedBox(width: 8),
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
            ),
            const SizedBox(height: 12),
            Card(
              color: _colors.surfaceSunken,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('reviewPiano', Icons.piano_outlined, size: 21, color: _colors.danger),
                    const SizedBox(width: 8),
                    Text('Musique & mouvement', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 12),
                  Text('🎹 Piano réalisé : $pianoMinutes min'),
                  const SizedBox(height: 6),
                  Text('🚶 Activité physique réalisée : $sportMinutes min'),
                  const SizedBox(height: 6),
                  Text('⏱️ Sur les moments enregistrés : $validatedMinutes min d’activités validées.'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: _colors.tintStrong,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('reviewMood', Icons.sentiment_satisfied_alt_outlined, size: 21, color: _colors.accentIcon),
                    const SizedBox(width: 8),
                    Text('Comment s’est passée la semaine ?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Très bien  $veryGood')),
                      Chip(label: Text('Bien  $good')),
                      Chip(label: Text('Difficile  $difficult')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(weekLogs.isEmpty
                      ? 'Pas encore de retour cette semaine. Le bilan se remplira au fil des moments validés.'
                      : difficult >= 2
                          ? 'Plusieurs moments ont été difficiles : la semaine suivante pourra garder davantage de respiration.'
                          : veryGood + good >= 3
                              ? 'Les retours sont plutôt positifs. Le rythme semble confortable.'
                              : 'Les retours sont variés : le prochain bilan permettra d’affiner le rythme.'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: _colors.border,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('move', Icons.open_with_outlined, size: 18, color: _colors.accentIcon),
                    const SizedBox(width: 8),
                    Text('Les déplacements de la semaine', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  if (weekMoves.isEmpty)
                    Text('Aucune activité n’a été déplacée cette semaine.', style: TextStyle(color: _colors.textMuted))
                  else
                    ...weekMoves.take(8).map((m) => Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('↔ ', style: TextStyle(fontWeight: FontWeight.w800, color: _colors.accentIcon)),
                        Expanded(child: Text('${m.activityName} · ${dayNames[m.fromDay]} ${m.fromPeriod} → ${dayNames[m.toDay]} ${m.toPeriod}', style: const TextStyle(fontSize: AppType.body))),
                      ]),
                    )),
                  if (weekMoves.length > 8)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('${weekMoves.length - 8} autre(s) déplacement(s).', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mon petit bilan personnel', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Une phrase suffit : ce qui m’a plu, ce qui a été facile ou ce que j’aimerais changer.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(hintText: 'Ex. Belle balade vendredi, piano agréable lundi…'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        widget.onSaveNote(noteController.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilan personnel enregistré.')));
                      },
                      icon: _uiIcon('save', Icons.save_outlined, size: 18),
                      label: const Text('Enregistrer mon bilan'),
                    ),
                  ),
                ]),
              ),
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

class _ReviewWeekRow extends StatelessWidget {
  final String label;
  final _ReviewWeekSummary summary;

  const _ReviewWeekRow({required this.label, required this.summary});

  String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _colors.borderStrong),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.accentText)),
              const SizedBox(height: 2),
              Text('${_dateLabel(summary.start)}–${_dateLabel(summary.end.subtract(const Duration(days: 1)))}', style: TextStyle(fontSize: AppType.micro, color: _colors.textMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 7,
              runSpacing: 3,
              children: [
                Text('${summary.activeDays} j', style: const TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800)),
                Text('${summary.moments} moments', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                Text('${summary.minutes} min', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                if (summary.difficult > 0)
                  Text('${summary.difficult} difficile${summary.difficult > 1 ? 's' : ''}', style: TextStyle(fontSize: AppType.small, color: _colors.textWarm)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _ReviewStat extends StatelessWidget {
  final String label;
  final String value;
  final String iconKey;
  final IconData icon;

  const _ReviewStat({required this.label, required this.value, required this.iconKey, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: _colors.borderStrong),
      ),
      child: Row(
        children: [
          _uiIcon(iconKey, icon, size: 20, color: _colors.accentText),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800)),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
          ])),
        ],
      ),
    );
  }
}



