// V8.96 — Extraction de la revue hebdomadaire
// Extraction architecturale uniquement : comportement conservé.

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
    final currentWeekStart = DateTime.now();
    final monday = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day).subtract(Duration(days: currentWeekStart.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final weekMoves = widget.moveLogs.where((m) => !m.date.isBefore(monday) && m.date.isBefore(nextMonday)).toList()..sort((a,b) => b.date.compareTo(a.date));
    final weekLogs = widget.logs.where((log) => !log.date.isBefore(monday) && log.date.isBefore(nextMonday)).toList();
    final validatedMinutes = weekLogs.fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final unplanned = weekLogs.where((log) => log.unplanned).length;
    final pianoMinutes = weekLogs
        .where((log) => log.title.toLowerCase().contains('piano'))
        .fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final sportMinutes = weekLogs
        .where((log) => log.category == 'Sport')
        .fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final veryGood = weekLogs.where((log) => log.feeling == 'Très bien').length;
    final good = weekLogs.where((log) => log.feeling == 'Bien').length;
    final difficult = weekLogs.where((log) => log.feeling == 'Difficile').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan de la semaine'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Card(
              color: const Color(0xFFE7EDF0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cette semaine en quelques chiffres', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'Moments réalisés', value: '$completed/${trackedPlan.length}', icon: Icons.check_circle_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Régularité', value: '${(completionRate * 100).round()} %', icon: Icons.calendar_month_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'Prévu', value: '$plannedMinutes min', icon: Icons.schedule_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Réalisé', value: '$realisedMinutes min', icon: Icons.play_circle_outline)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'À faire', value: '$remainingMinutes min', icon: Icons.hourglass_empty_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Déplacées', value: '${weekMoves.length}', icon: Icons.open_with_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ReviewStat(label: 'Temps validé', value: '$validatedMinutes min', icon: Icons.timer_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _ReviewStat(label: 'Imprévus', value: '$unplanned', icon: Icons.auto_awesome_outlined)),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: completionRate, minHeight: 9, borderRadius: BorderRadius.circular(20)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFF3EEE8),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('🗓️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 7),
                    Expanded(child: Text('Ton rythme sur 4 semaines', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 5),
                  const Text(
                    'Pour voir si ton rythme se construit dans la durée, pas seulement sur les derniers jours.',
                    style: TextStyle(fontSize: 10.8, color: Color(0xFF737976), height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(4, (index) {
                    final start = monday.subtract(Duration(days: 7 * index));
                    final end = start.add(const Duration(days: 7));
                    final weekLogs = widget.logs.where((log) => !log.date.isBefore(start) && log.date.isBefore(end)).toList();
                    final activeDays = weekLogs
                        .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
                        .toSet()
                        .length;
                    final minutes = weekLogs.fold<int>(0, (sum, log) => sum + max(0, log.realisedMinutes));
                    final difficultCount = weekLogs.where((log) => log.feeling == 'Difficile').length;
                    final label = index == 0 ? 'Cette semaine' : 'Semaine -$index';
                    final range = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} → ${(end.subtract(const Duration(days: 1))).day.toString().padLeft(2, '0')}/${(end.subtract(const Duration(days: 1))).month.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == 3 ? 0 : 7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0DDD4)),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: 78,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF4E5A55))),
                              const SizedBox(height: 2),
                              Text(range, style: const TextStyle(fontSize: 8.8, color: Color(0xFF858B87))),
                            ]),
                          ),
                          const SizedBox(width: 5),
                          Expanded(child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text('$activeDays j actif${activeDays > 1 ? 's' : ''}', style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF617069))),
                              Text('${weekLogs.length} moment${weekLogs.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF617069))),
                              Text('$minutes min', style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF617069))),
                              Text('⚠️ $difficultCount', style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF9A6D5D))),
                            ],
                          )),
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFE8F0EA),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('coach', Icons.psychology_outlined, size: 18, color: const Color(0xFF6F8E80)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Le regard du coach', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Pourquoi ces choix ?',
                      onPressed: widget.onOpenCoachDecisions,
                      icon: _uiIcon('help', Icons.help_outline_rounded, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 7),
                  Text(widget.coachSummary, style: const TextStyle(fontSize: 12.1, height: 1.35)),
                  const SizedBox(height: 8),
                  ...widget.coachInsights.take(5).map((text) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6F8E80))),
                      Expanded(child: Text(text, style: const TextStyle(fontSize: 11.6, color: Color(0xFF5E6B65), height: 1.25))),
                    ]),
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFF7F3EA),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('insights', Icons.insights_outlined, size: 18, color: const Color(0xFF7D988D)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('À quoi sert ce bilan ?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 7),
                  const Text(
                    'Le bilan compare ce qui était prévu avec ce qui a réellement été vécu cette semaine. Il rassemble tes validations, tes durées, tes ressentis et tes déplacements pour aider MyBestWeek à mieux comprendre ton rythme.',
                    style: TextStyle(fontSize: 12.1, height: 1.35, color: Color(0xFF606B6A)),
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
              color: const Color(0xFFF3EEE4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.piano_outlined, color: Color(0xFFC67E67)),
                    const SizedBox(width: 8),
                    Text('Musique & mouvement', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
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
              color: const Color(0xFFE5EEE9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.sentiment_satisfied_alt_outlined, color: Color(0xFF6F8E80)),
                    const SizedBox(width: 8),
                    Text('Comment s’est passée la semaine ?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
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
                  Text(widget.logs.isEmpty
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
              color: const Color(0xFFF0EBDF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _uiIcon('move', Icons.open_with_outlined, size: 18, color: const Color(0xFF6F8E80)),
                    const SizedBox(width: 8),
                    Text('Les déplacements de la semaine', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 8),
                  if (weekMoves.isEmpty)
                    const Text('Aucune activité n’a été déplacée cette semaine.', style: TextStyle(color: Color(0xFF6F7777)))
                  else
                    ...weekMoves.take(8).map((m) => Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('↔ ', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6F8E80))),
                        Expanded(child: Text('${m.activityName} · ${dayNames[m.fromDay]} ${m.fromPeriod} → ${dayNames[m.toDay]} ${m.toPeriod}', style: const TextStyle(fontSize: 12.5))),
                      ]),
                    )),
                  if (weekMoves.length > 8)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('${weekMoves.length - 8} autre(s) déplacement(s).', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6F7777)))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mon petit bilan personnel', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
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


class _ReviewStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReviewStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0DDD4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF526B78)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6F7777))),
          ])),
        ],
      ),
    );
  }
}



