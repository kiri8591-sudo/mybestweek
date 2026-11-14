part of '../main.dart';

// V12.24.0 — My Best Form : suivi du poids, habitudes et bilan hebdomadaire.

class WeightEntry {
  final String id;
  final DateTime date;
  final double weightKg;
  final double? waistCm;
  final String note;

  WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.waistCm,
    this.note = '',
  });
}

class _FormHabit {
  final String id;
  final String emoji;
  final String title;
  final String hint;

  const _FormHabit(this.id, this.emoji, this.title, this.hint);
}

const List<_FormHabit> _kFormHabits = [
  _FormHabit('move', '🚶', 'Bouger dans la journée', 'Marche, jardinage ou mouvement adapté à ton énergie.'),
  _FormHabit('sport', '🏊', 'Faire mon activité prévue', 'Sport, renforcement ou mobilité selon le planning.'),
  _FormHabit('balanced', '🥗', 'Privilégier des repas équilibrés', 'Des repas variés, avec une place aux légumes et aux protéines.'),
  _FormHabit('mindful', '🍽️', 'Manger en pleine conscience', 'Prendre le temps, écouter la faim et la satiété.'),
  _FormHabit('recovery', '🌙', 'Prendre soin de ma récupération', 'Sommeil, pauses et récupération sans culpabilité.'),
];

class _WeightTrendChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const _WeightTrendChart({
    required this.entries,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          entries.isEmpty ? 'Ta courbe apparaîtra après tes premières pesées.' : 'Ajoute une deuxième pesée pour voir ton évolution.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 174,
        child: CustomPaint(
          painter: _WeightTrendPainter(
            entries: entries,
            lineColor: lineColor,
            gridColor: gridColor,
          ),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_shortWeightDate(entries.first.date), style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w700)),
        Text(_shortWeightDate(entries.last.date), style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

class _WeightTrendPainter extends CustomPainter {
  final List<WeightEntry> entries;
  final Color lineColor;
  final Color gridColor;

  const _WeightTrendPainter({required this.entries, required this.lineColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2 || size.width <= 0 || size.height <= 0) return;
    const left = 8.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 12.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final values = entries.map((entry) => entry.weightKg).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    var range = maxValue - minValue;
    if (range < .6) range = .6;
    final low = minValue - range * .20;
    final high = maxValue + range * .20;
    final gridPaint = Paint()..color = gridColor.withValues(alpha: .75)..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final points = <Offset>[];
    final firstDate = entries.first.date;
    final totalDays = entries.last.date.difference(firstDate).inDays;
    for (var i = 0; i < values.length; i++) {
      final elapsedDays = entries[i].date.difference(firstDate).inDays;
      final xFactor = totalDays <= 0 ? i / (values.length - 1) : elapsedDays / totalDays;
      final x = chart.left + chart.width * xFactor;
      final y = chart.bottom - ((values[i] - low) / (high - low)) * chart.height;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = lineColor.withValues(alpha: .10)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = lineColor..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i == points.length - 1 ? 5 : 3.2, Paint()..color = lineColor);
      if (i == points.length - 1) {
        canvas.drawCircle(points[i], 8, Paint()..color = lineColor.withValues(alpha: .16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.entries != entries || oldDelegate.lineColor != lineColor || oldDelegate.gridColor != gridColor;
}

String _shortWeightDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

extension _MyBestForm on _MaBelleSemaineAppState {
  DateTime _formDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formDateKey(DateTime value) {
    final date = _formDateOnly(value);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formDateLabel(DateTime value) {
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  List<WeightEntry> get _formWeightsSorted {
    final result = List<WeightEntry>.from(_weightEntries)..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  WeightEntry? get _formLatestWeight {
    final sorted = _formWeightsSorted;
    return sorted.isEmpty ? null : sorted.last;
  }

  int _formHabitDoneFor(DateTime date) => _formHabitChecks[_formDateKey(date)]?.length ?? 0;

  int get _formTodayHabitDone => _formHabitDoneFor(DateTime.now());

  int get _formHabitDoneThisWeek {
    final monday = _startOfCurrentWeek();
    final today = _formDateOnly(DateTime.now());
    var total = 0;
    for (var i = 0; i <= today.difference(monday).inDays && i < 7; i++) {
      total += _formHabitDoneFor(monday.add(Duration(days: i)));
    }
    return total;
  }

  int get _formHabitPossibleThisWeek => (_formDateOnly(DateTime.now()).difference(_startOfCurrentWeek()).inDays + 1).clamp(1, 7).toInt() * _kFormHabits.length;

  List<ActivityLog> get _formLogsThisWeek {
    final start = _startOfCurrentWeek();
    final end = _formDateOnly(DateTime.now()).add(const Duration(days: 1));
    return logs.where((log) {
      final date = _formDateOnly(log.date);
      return !date.isBefore(start) && date.isBefore(end) && (log.realisedMinutes > 0 || (log.reps ?? 0) > 0);
    }).toList();
  }

  int get _formActivityMinutesThisWeek => _formLogsThisWeek.fold<int>(0, (sum, log) => sum + max(0, log.realisedMinutes));

  int get _formSportSessionsThisWeek => _formLogsThisWeek.where((log) {
    final activity = log.activityId == null ? null : findActivity(log.activityId!);
    return activity != null && _isSportActivity(activity);
  }).length;

  double? get _formWeightDelta {
    final sorted = _formWeightsSorted;
    if (sorted.length < 2) return null;
    return sorted.last.weightKg - sorted[sorted.length - 2].weightKg;
  }

  double? get _formProgress {
    final start = _weightStartKg;
    final goal = _weightGoalKg;
    final latest = _formLatestWeight?.weightKg;
    if (start == null || goal == null || latest == null || (start - goal).abs() < .01) return null;
    final value = goal < start ? (start - latest) / (start - goal) : (latest - start) / (goal - start);
    return value.clamp(0.0, 1.0).toDouble();
  }

  String _formCoachMessage() {
    final latest = _formLatestWeight;
    final done = _formHabitDoneThisWeek;
    final possible = _formHabitPossibleThisWeek;
    final ratio = possible == 0 ? 0.0 : done / possible;
    if (latest == null) return 'Commence par une première pesée, puis construis tes habitudes une journée après l’autre. Le point de départ n’est pas une note : c’est simplement une information pour mesurer ton chemin.';
    if (ratio >= .75) return 'Tu tiens bien tes engagements cette semaine. Cette régularité est une vraie victoire : garde le cap sans chercher à tout faire parfaitement.';
    if (ratio >= .4) return 'Tu as déjà enclenché plusieurs bonnes habitudes. Choisis-en une à consolider demain : la répétition des petits gestes fait la différence.';
    return 'La semaine n’a pas été aussi régulière que tu le souhaitais ? Pas de procès, pas de rattrapage. Choisis une action simple aujourd’hui et relance la dynamique.';
  }

  String _formWeightTrendMessage() {
    final sorted = _formWeightsSorted;
    if (sorted.length < 2) return 'Ajoute une deuxième mesure à une autre date pour commencer à observer une tendance.';
    final delta = sorted.last.weightKg - sorted[sorted.length - 2].weightKg;
    if (delta.abs() < .05) return 'Ta dernière mesure est très proche de la précédente. Une stabilité ponctuelle est normale : observons la tendance sur plusieurs semaines.';
    final direction = delta < 0 ? 'baissé' : 'augmenté';
    final amount = delta.abs().toStringAsFixed(1).replaceAll('.', ',');
    return 'Ta dernière mesure a $direction de $amount kg par rapport à la précédente. Une pesée isolée ne dit pas tout : regardons l’évolution dans la durée.';
  }

  Future<void> _openMyBestForm() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => _MyBestFormPageHost(owner: this)));
  }

  Widget _myBestFormHomeCard() {
    final latest = _formLatestWeight;
    final goal = _weightGoalKg;
    final todayCount = _formTodayHabitDone;
    final hasData = latest != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
      child: softCard(
        color: _colors.tintSoft,
        borderColor: _colors.borderTint,
        radius: 21,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 39,
              height: 39,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(13)),
              child: const Text('🌿', style: TextStyle(fontSize: 23)),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MY BEST FORM', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .55, color: _colors.accentStrongText)),
              Text('Mon poids, mes habitudes, ma progression', style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted, fontWeight: FontWeight.w600)),
            ])),
            Icon(Icons.chevron_right_rounded, color: _colors.accentIcon, size: 24),
          ]),
          const SizedBox(height: 9),
          if (!hasData) ...[
            Text('Chaque jour compte. Enregistre ton point de départ et choisis ton objectif de forme.', style: TextStyle(fontSize: AppType.body, height: 1.25, color: _colors.textStrong, fontWeight: FontWeight.w600)),
          ] else ...[
            Row(children: [
              Expanded(child: _homeCoachMetric('${latest.weightKg.toStringAsFixed(1).replaceAll('.', ',')} kg', 'Dernière pesée', Icons.monitor_weight_outlined)),
              const SizedBox(width: 7),
              Expanded(child: _homeCoachMetric(goal == null ? 'À définir' : '${goal.toStringAsFixed(1).replaceAll('.', ',')} kg', 'Mon objectif', Icons.flag_outlined)),
              const SizedBox(width: 7),
              Expanded(child: _homeCoachMetric('$todayCount/${_kFormHabits.length}', 'Habitudes du jour', Icons.checklist_rounded)),
            ]),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: _colors.card.withValues(alpha: .76), borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.bolt_rounded, color: _colors.goldText, size: 17),
              const SizedBox(width: 7),
              Expanded(child: Text(_formCoachMessage(), style: TextStyle(fontSize: AppType.small, height: 1.25, fontWeight: FontWeight.w700, color: _colors.textStrong))),
            ]),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openMyBestForm,
              icon: const Icon(Icons.favorite_outline_rounded, size: 18),
              label: Text(hasData ? 'Ouvrir mon suivi forme' : 'Commencer mon suivi forme'),
              style: FilledButton.styleFrom(backgroundColor: _colors.accentFill, foregroundColor: _colors.onPrimary, visualDensity: VisualDensity.compact),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _myBestFormPageContent() {
    final latest = _formLatestWeight;
    final sorted = _formWeightsSorted;
    final start = _weightStartKg;
    final goal = _weightGoalKg;
    final progress = _formProgress;
    final todayKey = _formDateKey(DateTime.now());
    final todayChecks = _formHabitChecks[todayKey] ?? <String>{};
    final doneWeek = _formHabitDoneThisWeek;
    final possibleWeek = _formHabitPossibleThisWeek;
    final ratioWeek = possibleWeek == 0 ? 0.0 : (doneWeek / possibleWeek).clamp(0.0, 1.0).toDouble();
    final monday = _startOfCurrentWeek();
    final chartCutoff = _formDateOnly(DateTime.now().subtract(Duration(days: _formChartMonths * 30)));
    final filteredEntries = sorted.where((entry) => !_formDateOnly(entry.date).isBefore(chartCutoff)).toList();
    final logsWeek = _formLogsThisWeek;
    final latestWeightText = latest == null ? '—' : '${latest.weightKg.toStringAsFixed(1).replaceAll('.', ',')} kg';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Best Form'),
        leading: IconButton(tooltip: 'Retour', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(tooltip: 'Définir mon objectif', onPressed: _openWeightGoalDialog, icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
          children: [
            softCard(
              color: _colors.tintStrong,
              borderColor: _colors.borderTint,
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Text('🌿', style: TextStyle(fontSize: 27)), const SizedBox(width: 8), Expanded(child: Text('CHAQUE JOUR COMPTE', style: TextStyle(fontSize: AppType.small, letterSpacing: .6, fontWeight: FontWeight.w900, color: _colors.accentStrongText)) )]),
                const SizedBox(height: 7),
                Text('En route vers mon poids de forme', style: TextStyle(fontSize: AppType.h1, fontFamily: AppFonts.serif, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                const SizedBox(height: 5),
                Text('Le but : construire des habitudes durables, suivre tes progrès et avancer sans te culpabiliser.', style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textMuted)),
              ]),
            ),
            const SizedBox(height: 11),
            softCard(
              color: _colors.card,
              borderColor: _colors.borderTint,
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('MON OBJECTIF DE POIDS', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .5, color: _colors.accentStrongText))), TextButton.icon(onPressed: _openWeightGoalDialog, icon: const Icon(Icons.edit_outlined, size: 16), label: Text(goal == null ? 'Définir' : 'Modifier'))]),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: _formBigMetric(latestWeightText, 'Dernière mesure')),
                  const SizedBox(width: 8),
                  Expanded(child: _formBigMetric(goal == null ? 'À définir' : '${goal.toStringAsFixed(1).replaceAll('.', ',')} kg', 'Objectif')),
                  if (start != null) ...[
                    const SizedBox(width: 8),
                    Expanded(child: _formBigMetric('${start.toStringAsFixed(1).replaceAll('.', ',')} kg', 'Départ')),
                  ],
                ]),
                if (progress != null) ...[
                  const SizedBox(height: 13),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Chemin parcouru', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, fontWeight: FontWeight.w700)), Text('${(progress * 100).round()} %', style: TextStyle(fontSize: AppType.body, color: _colors.accentStrongText, fontWeight: FontWeight.w900))]),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: _colors.surfaceSunken, color: _colors.accentFill)),
                ] else if (goal == null || latest == null) ...[
                  const SizedBox(height: 9),
                  Text('Enregistre une première pesée et définis un objectif réaliste pour démarrer ton suivi.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                ],
                const SizedBox(height: 11),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _openWeightEntryDialog(), icon: const Icon(Icons.add_rounded), label: const Text('Enregistrer une pesée'))),
              ]),
            ),
            const SizedBox(height: 11),
            softCard(
              color: _colors.card,
              borderColor: _colors.borderTint,
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('MON ÉVOLUTION', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .5, color: _colors.accentStrongText))), Text('${sorted.length} mesure${sorted.length > 1 ? 's' : ''}', style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted, fontWeight: FontWeight.w700))]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [3, 6, 12].map((months) => ChoiceChip(label: Text('$months mois'), selected: _formChartMonths == months, onSelected: (_) { setState(() => _formChartMonths = months); _formPageRefresh?.call(); }, visualDensity: VisualDensity.compact)).toList()),
                const SizedBox(height: 8),
                _WeightTrendChart(entries: filteredEntries, lineColor: _colors.accentFill, gridColor: _colors.borderTint, textColor: _colors.textMuted),
                const SizedBox(height: 8),
                Text(_formWeightTrendMessage(), style: TextStyle(fontSize: AppType.small, height: 1.28, fontWeight: FontWeight.w600, color: _colors.textMuted)),
              ]),
            ),
            const SizedBox(height: 11),
            softCard(
              color: _colors.tintSoft,
              borderColor: _colors.borderTint,
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('MES HABITUDES DU JOUR', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .5, color: _colors.accentStrongText))), Text('${todayChecks.length}/${_kFormHabits.length}', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w900, color: _colors.accentStrongText))]),
                const SizedBox(height: 5),
                Text('Coche ce que tu as réellement fait aujourd’hui. Un jour incomplet n’efface pas les progrès précédents.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted, height: 1.25)),
                const SizedBox(height: 7),
                ..._kFormHabits.map((habit) {
                  final checked = todayChecks.contains(habit.id);
                  return Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: _colors.card.withValues(alpha: .75), borderRadius: BorderRadius.circular(AppRadius.m)),
                    child: CheckboxListTile(
                      value: checked,
                      onChanged: (value) => _setFormHabit(habit.id, value == true),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      dense: true,
                      activeColor: _colors.accentFill,
                      title: Text('${habit.emoji}  ${habit.title}', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      subtitle: Text(habit.hint, style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted, height: 1.15)),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: Text('Cette semaine', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, fontWeight: FontWeight.w800))), Text('$doneWeek / $possibleWeek', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w900, color: _colors.accentStrongText))]),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: ratioWeek, minHeight: 9, backgroundColor: _colors.surfaceSunken, color: _colors.accentFill)),
              ]),
            ),
            const SizedBox(height: 11),
            softCard(
              color: _colors.card,
              borderColor: _colors.borderTint,
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MON BILAN DE LA SEMAINE', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .5, color: _colors.accentStrongText)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _formBigMetric('$doneWeek/$possibleWeek', 'Habitudes cochées')),
                  const SizedBox(width: 8),
                  Expanded(child: _formBigMetric('$_formSportSessionsThisWeek', 'Séances sport')),
                  const SizedBox(width: 8),
                  Expanded(child: _formBigMetric('$_formActivityMinutesThisWeek min', 'Activité réalisée')),
                ]),
                const SizedBox(height: 10),
                Text(_formCoachMessage(), style: TextStyle(fontSize: AppType.body, height: 1.3, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                if (_formWeightDelta != null) ...[
                  const SizedBox(height: 7),
                  Text(_formWeightTrendMessage(), style: TextStyle(fontSize: AppType.small, height: 1.25, color: _colors.textMuted)),
                ],
                const SizedBox(height: 8),
                Text('Semaine du ${_formDateLabel(monday)} · ${logsWeek.length} réalisation${logsWeek.length > 1 ? 's' : ''} enregistrée${logsWeek.length > 1 ? 's' : ''}.', style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted)),
              ]),
            ),
            const SizedBox(height: 11),
            softCard(
              color: _colors.card,
              borderColor: _colors.borderTint,
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('MON HISTORIQUE DE PESÉES', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w900, letterSpacing: .5, color: _colors.accentStrongText))), TextButton.icon(onPressed: () => _openWeightEntryDialog(), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter'))]),
                if (sorted.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Aucune mesure enregistrée pour le moment.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)))
                else
                  ...sorted.reversed.take(20).map((entry) => _weightEntryRow(entry, sorted)),
                if (sorted.length > 20) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Les 20 mesures les plus récentes sont affichées ici. Toutes restent conservées dans tes données.', style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted))),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _colors.surfaceSunken, borderRadius: BorderRadius.circular(AppRadius.l)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: _colors.textMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Ce suivi aide à observer tes habitudes et leur évolution. Le poids varie naturellement : regarde les tendances sur plusieurs semaines. Les objectifs d’activité et d’alimentation doivent rester adaptés à ta santé et à tes capacités.', style: TextStyle(fontSize: AppType.caption, height: 1.25, color: _colors.textMuted))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formBigMetric(String value, String label) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w900, color: _colors.textStrong))),
    const SizedBox(height: 2),
    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.textMuted)),
  ]);

  Widget _weightEntryRow(WeightEntry entry, List<WeightEntry> sorted) {
    final index = sorted.indexWhere((candidate) => candidate.id == entry.id);
    final previous = index > 0 ? sorted[index - 1] : null;
    final delta = previous == null ? null : entry.weightKg - previous.weightKg;
    final deltaPrefix = delta != null && delta > 0 ? '+' : '';
    final deltaText = delta == null ? '' : '$deltaPrefix${delta.toStringAsFixed(1).replaceAll('.', ',')} kg';
    final waistText = entry.waistCm == null ? '' : ' · Tour de taille ${entry.waistCm!.toStringAsFixed(1).replaceAll('.', ',')} cm';
    final weightAndWaistText = '${entry.weightKg.toStringAsFixed(1).replaceAll('.', ',')} kg$waistText';
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: _colors.surfaceSunken.withValues(alpha: .55), borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_formDateLabel(entry.date), style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted, fontWeight: FontWeight.w700)),
          Text(weightAndWaistText, style: TextStyle(fontSize: AppType.body, color: _colors.textStrong, fontWeight: FontWeight.w900)),
        ])),
        if (deltaText.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 3), child: Text(deltaText, style: TextStyle(fontSize: AppType.caption, color: (delta ?? 0) < 0 ? _colors.accentStrongText : _colors.textMuted, fontWeight: FontWeight.w800))),
        IconButton(tooltip: 'Modifier la pesée', visualDensity: VisualDensity.compact, onPressed: () => _openWeightEntryDialog(existing: entry), icon: Icon(Icons.edit_outlined, size: 18, color: _colors.accentIcon)),
        IconButton(tooltip: 'Supprimer la pesée', visualDensity: VisualDensity.compact, onPressed: () => _deleteWeightEntry(entry), icon: Icon(Icons.delete_outline_rounded, size: 18, color: _colors.textMuted)),
      ]),
    );
  }

  void _setFormHabit(String id, bool checked) {
    final key = _formDateKey(DateTime.now());
    setState(() {
      final values = _formHabitChecks.putIfAbsent(key, () => <String>{});
      if (checked) {
        values.add(id);
      } else {
        values.remove(id);
      }
      if (values.isEmpty) _formHabitChecks.remove(key);
    });
    _queueLocalStatePersist();
    _formPageRefresh?.call();
  }

  Future<void> _openWeightGoalDialog() async {
    final controller = TextEditingController(text: _weightGoalKg?.toStringAsFixed(1).replaceAll('.', ',') ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mon objectif de poids'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choisis un objectif personnel, progressif et adapté à ta situation.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Poids objectif (kg)', suffixText: 'kg'),
              validator: (value) {
                final number = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                if (number == null || !number.isFinite || number < 25 || number > 300) return 'Entre un poids compris entre 25 et 300 kg.';
                if (_weightStartKg != null && (number - _weightStartKg!).abs() < .05) return 'Choisis un objectif différent du poids de départ.';
                return null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.pop(dialogContext, double.parse(controller.text.trim().replaceAll(',', '.')));
          }, child: const Text('Enregistrer')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _weightGoalKg = result;
      _weightGoalStartedAt ??= DateTime.now();
    });
    _queueLocalStatePersist();
    _formPageRefresh?.call();
  }

  Future<void> _openWeightEntryDialog({WeightEntry? existing}) async {
    final weightController = TextEditingController(text: existing?.weightKg.toStringAsFixed(1).replaceAll('.', ',') ?? '');
    final waistController = TextEditingController(text: existing?.waistCm?.toStringAsFixed(1).replaceAll('.', ',') ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    final formKey = GlobalKey<FormState>();
    var selectedDate = existing?.date ?? DateTime.now();
    final result = await showDialog<_WeightDialogResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Enregistrer une pesée' : 'Modifier la pesée'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pèse-toi dans des conditions comparables, sans chercher à interpréter une variation isolée.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
            const SizedBox(height: 10),
            TextFormField(
              controller: weightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Poids', suffixText: 'kg'),
              validator: (value) {
                final number = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                if (number == null || !number.isFinite || number < 25 || number > 300) return 'Entre une valeur entre 25 et 300 kg.';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: waistController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tour de taille (facultatif)', suffixText: 'cm'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                final number = double.tryParse(value!.trim().replaceAll(',', '.'));
                if (number == null || !number.isFinite || number < 30 || number > 250) return 'Entre une valeur entre 30 et 250 cm.';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(controller: noteController, maxLength: 80, decoration: const InputDecoration(labelText: 'Note (facultatif)', hintText: 'Ex. : mesure du matin')),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(context: dialogContext, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)), helpText: 'Date de la pesée');
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: Text(_formDateLabel(selectedDate)),
            ),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            final weight = double.parse(weightController.text.trim().replaceAll(',', '.'));
            final waistText = waistController.text.trim();
            final waist = waistText.isEmpty ? null : double.parse(waistText.replaceAll(',', '.'));
            Navigator.pop(dialogContext, _WeightDialogResult(date: selectedDate, weightKg: weight, waistCm: waist, note: noteController.text.trim()));
          }, child: const Text('Enregistrer')),
        ],
      )),
    );
    weightController.dispose();
    waistController.dispose();
    noteController.dispose();
    if (result == null || !mounted) return;
    final date = _formDateOnly(result.date);
    setState(() {
      if (existing != null) {
        final conflict = _weightEntries.indexWhere((entry) => entry.id != existing.id && _formDateOnly(entry.date) == date);
        if (conflict >= 0) _weightEntries.removeAt(conflict);
        final index = _weightEntries.indexWhere((entry) => entry.id == existing.id);
        if (index >= 0) {
          _weightEntries[index] = WeightEntry(id: existing.id, date: date, weightKg: result.weightKg, waistCm: result.waistCm, note: result.note);
        }
      } else {
        final duplicate = _weightEntries.indexWhere((entry) => _formDateOnly(entry.date) == date);
        final id = duplicate >= 0 ? _weightEntries[duplicate].id : 'weight_${date.microsecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 100000}';
        final entry = WeightEntry(id: id, date: date, weightKg: result.weightKg, waistCm: result.waistCm, note: result.note);
        if (duplicate >= 0) {
          _weightEntries[duplicate] = entry;
        } else {
          _weightEntries.add(entry);
        }
      }
      _weightEntries.sort((a, b) => a.date.compareTo(b.date));
      _weightStartKg ??= _weightEntries.first.weightKg;
    });
    _queueLocalStatePersist();
    _formPageRefresh?.call();
    _showFormSnack(existing == null ? 'Pesée enregistrée.' : 'Pesée mise à jour.');
  }

  Future<void> _deleteWeightEntry(WeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette pesée ?'),
        content: Text('La mesure du ${_formDateLabel(entry.date)} sera retirée de ton historique.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Supprimer'))],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _weightEntries.removeWhere((candidate) => candidate.id == entry.id);
      if (_weightEntries.isEmpty) _weightStartKg = null;
    });
    _queueLocalStatePersist();
    _formPageRefresh?.call();
  }

  void _showFormSnack(String message) {
    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WeightDialogResult {
  final DateTime date;
  final double weightKg;
  final double? waistCm;
  final String note;

  const _WeightDialogResult({required this.date, required this.weightKg, this.waistCm, required this.note});
}


class _MyBestFormPageHost extends StatefulWidget {
  final _MaBelleSemaineAppState owner;
  const _MyBestFormPageHost({required this.owner});

  @override
  State<_MyBestFormPageHost> createState() => _MyBestFormPageHostState();
}

class _MyBestFormPageHostState extends State<_MyBestFormPageHost> {
  late final VoidCallback _refresh = () {
    if (mounted) setState(() {});
  };

  @override
  Widget build(BuildContext context) {
    widget.owner._formPageRefresh = _refresh;
    return widget.owner._myBestFormPageContent();
  }

  @override
  void dispose() {
    if (identical(widget.owner._formPageRefresh, _refresh)) {
      widget.owner._formPageRefresh = null;
    }
    super.dispose();
  }
}
