// V12.24.0 — Rendez-vous du Coach, version « motivation » :
// aujourd'hui d'abord avec action en un geste, élan (série tolérante et tendance), progrès vers les
// objectifs, records et victoires, phrases variées selon le ton choisi, bilan du soir en 10 secondes.

part of '../main.dart';

class _CoachBadge {
  final IconData icon;
  final String text;
  const _CoachBadge(this.icon, this.text);
}

class _CoachProgress {
  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final double ratio;
  final bool done;
  const _CoachProgress({required this.icon, required this.title, required this.value, required this.hint, required this.ratio, required this.done});
}

const List<(String, String)> kCoachTones = [('doux', 'Doux'), ('motivant', 'Motivant'), ('direct', 'Direct')];

const List<String> _coachTips = [
  'Dix minutes valent mieux qu’une heure qu’on reporte.',
  'Prépare tout la veille : le plus dur, c’est de commencer.',
  'Une activité courte et faite bat une activité parfaite et oubliée.',
  'Associe une action à un moment fixe : après le café, avant le dîner.',
  'Coche tout de suite : la petite victoire nourrit la suivante.',
  'Un jour de repos prévu fait partie du plan, pas d’un échec.',
  'Commence par la plus petite version de l’activité.',
  'Note comment tu te sens : ton rythme se dessine mieux.',
  'Une série se construit un jour à la fois.',
  'Choisis ce qui te fait envie en premier : l’élan fait le reste.',
  'Fais-le d’abord imparfait, tu l’amélioreras ensuite.',
  'Regarde ce que tu as déjà fait cette semaine avant ce qu’il reste.',
  'Deux minutes suffisent pour relancer une habitude.',
  'Mets l’activité dans ton agenda comme un rendez-vous.',
  'Reviens à la dernière fois où tu t’es senti bien après l’effort.',
  'Un obstacle prévu est à moitié franchi : anticipe ton frein du jour.',
  'Récompense-toi vite : un thé, une pause, un morceau de piano.',
  'La régularité l’emporte toujours sur l’intensité.',
  'Si la journée déborde, garde une seule chose essentielle.',
  'Fais équipe : annonce ton objectif à quelqu’un.',
  'Change de décor : la même activité dehors paraît plus légère.',
  'Respecte ton énergie : léger quand tu es fatigué, ambitieux quand tu es en forme.',
  'Chaque réalisation est un vote pour la personne que tu veux devenir.',
  'Ce que tu fais aujourd’hui prépare la facilité de demain.',
];

String _coachStreakMemoKey = '';
({int now, int best, bool todayActive})? _coachStreakMemo;

extension _HomeCoachMotivation on _MaBelleSemaineAppState {
  // ----- utilitaires -------------------------------------------------------

  String _coachPick(List<String> variants, int salt) => variants[(_dayKey(DateTime.now()) + salt * 7) % variants.length];

  Set<int> _coachActiveDayKeys() => {for (final l in logs) if (l.realisedMinutes > 0) _dayKey(l.date)};

  /// Série tolérante : on peut manquer un jour, à condition que deux jours manqués soient séparés d'au moins 7 jours.
  int _coachTolerantStreak(Set<int> active, DateTime end, DateTime first) {
    var count = 0;
    DateTime? lastMiss;
    var d = _coachDateOnly(end);
    for (var i = 0; i < 400; i++) {
      if (d.isBefore(first)) break;
      if (active.contains(_dayKey(d))) {
        count++;
      } else {
        if (lastMiss != null && _daysBetween(d, lastMiss) < 7) break;
        lastMiss = d;
      }
      d = _addDays(d, -1);
    }
    return count;
  }

  ({int now, int best, bool todayActive}) _coachStreakInfo() {
    final today0 = _coachDateOnly(DateTime.now());
    var minutes = 0;
    var dates = 0;
    for (final l in logs) {
      minutes += l.realisedMinutes;
      dates += l.date.day + l.date.month * 31;
    }
    final key = '${logs.length}|${_dayKey(today0)}|$minutes|$dates';
    final memo = _coachStreakMemo;
    if (memo != null && key == _coachStreakMemoKey) return memo;

    final active = _coachActiveDayKeys();
    ({int now, int best, bool todayActive}) result = (now: 0, best: 0, todayActive: false);
    if (active.isNotEmpty) {
      DateTime? first;
      for (final l in logs) {
        if (l.realisedMinutes <= 0) continue;
        final d = _coachDateOnly(l.date);
        if (first == null || d.isBefore(first)) first = d;
      }
      final firstDay = first ?? today0;
      final todayActive = active.contains(_dayKey(today0));
      final end = todayActive ? today0 : _addDays(today0, -1);
      final nowStreak = _coachTolerantStreak(active, end, firstDay);
      var best = nowStreak;
      final limit = _addDays(today0, -400);
      for (final k in active) {
        final d = DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);
        if (d.isBefore(limit)) continue;
        best = max(best, _coachTolerantStreak(active, d, firstDay));
      }
      result = (now: nowStreak, best: best, todayActive: todayActive);
    }
    _coachStreakMemoKey = key;
    _coachStreakMemo = result;
    return result;
  }

  /// Semaine en cours comparée à la même période de la semaine précédente.
  ({int thisDays, int lastDays, int thisMin, int lastMin}) _coachWeekTrend() {
    final today0 = _coachDateOnly(DateTime.now());
    final monday = _coachDateOnly(_startOfCurrentWeek());
    final span = today0.weekday - 1;
    final lastMonday = _addDays(monday, -7);
    final active = _coachActiveDayKeys();
    int days(DateTime from) {
      var c = 0;
      for (var k = 0; k <= span; k++) {
        if (active.contains(_dayKey(_addDays(from, k)))) c++;
      }
      return c;
    }

    int minutes(DateTime from) {
      final end = _addDays(from, span + 1);
      return _timeMinutesOf(logs.where((l) => l.realisedMinutes > 0 && !l.date.isBefore(from) && l.date.isBefore(end)));
    }

    return (thisDays: days(monday), lastDays: days(lastMonday), thisMin: minutes(monday), lastMin: minutes(lastMonday));
  }

  String _coachTrendArrow(int diff) => diff > 0 ? '↗ +$diff' : diff < 0 ? '↘ $diff' : '= identique';

  // ----- records et victoires ---------------------------------------------

  List<_CoachBadge> _coachBadges(({int now, int best, bool todayActive}) streak, ({int thisDays, int lastDays, int thisMin, int lastMin}) trend) {
    final out = <_CoachBadge>[];
    final today0 = _coachDateOnly(DateTime.now());

    for (final a in activities) {
      if (!_isRepsActivity(a)) continue;
      final withReps = logs.where((l) => l.reps != null && _logIsOfActivity(l, a)).toList()..sort((x, y) => y.date.compareTo(x.date));
      if (withReps.length < 2) continue;
      final latest = withReps.first;
      if (_daysBetween(latest.date, today0) > 3) continue;
      final previousBest = withReps.skip(1).fold<int>(0, (m, l) => max(m, l.reps ?? 0));
      if ((latest.reps ?? 0) > previousBest) out.add(_CoachBadge(Icons.emoji_events_rounded, 'Record : ${latest.reps} rép. · ${a.name}'));
    }

    if (streak.now >= 3 && streak.now >= streak.best) {
      out.add(_CoachBadge(Icons.local_fire_department_rounded, 'Meilleure série : ${streak.now} jours'));
    }

    // Semaine la plus active des 12 dernières semaines.
    final active = _coachActiveDayKeys();
    final monday = _coachDateOnly(_startOfCurrentWeek());
    var bestPrevious = 0;
    for (var w = 1; w <= 12; w++) {
      final from = _addDays(monday, -7 * w);
      var c = 0;
      for (var k = 0; k < 7; k++) {
        if (active.contains(_dayKey(_addDays(from, k)))) c++;
      }
      bestPrevious = max(bestPrevious, c);
    }
    if (trend.thisDays >= 4 && trend.thisDays > bestPrevious) {
      out.add(const _CoachBadge(Icons.workspace_premium_rounded, 'Semaine la plus active'));
    }

    // Retour en piste après une pause d'au moins 7 jours.
    if (streak.todayActive) {
      final todayKey = _dayKey(today0);
      int? lastBefore;
      for (final k in active) {
        if (k < todayKey && (lastBefore == null || k > lastBefore)) lastBefore = k;
      }
      if (lastBefore != null) {
        final d = DateTime(lastBefore ~/ 10000, (lastBefore ~/ 100) % 100, lastBefore % 100);
        final gap = _daysBetween(d, today0);
        if (gap >= 7) out.add(_CoachBadge(Icons.replay_rounded, 'Retour en piste après $gap jours'));
      }
    }
    return out.take(3).toList();
  }

  // ----- progrès vers les objectifs ---------------------------------------

  List<_CoachProgress> _coachProgressItems() {
    final items = <_CoachProgress>[];
    for (final g in _realizationGoals) {
      final a = findActivity(g.activityId);
      if (a == null) continue;
      final doneCount = _goalProgress(g);
      final target = max(1, g.target);
      final ratio = (doneCount / target).clamp(0.0, 1.0).toDouble();
      final remaining = target - doneCount;
      final period = g.cadence == 'jour' ? 'aujourd’hui' : g.cadence == 'mois' ? 'ce mois-ci' : 'cette semaine';
      items.add(_CoachProgress(
        icon: Icons.flag_rounded,
        title: a.name,
        value: '$doneCount/$target $period',
        hint: remaining <= 0 ? 'Objectif atteint !' : remaining == 1 ? 'Plus que 1 !' : ratio >= .6 ? 'Tu y es presque' : '',
        ratio: ratio,
        done: remaining <= 0,
      ));
    }
    for (final a in activities) {
      if (!_isRepsActivity(a)) continue;
      final last = _lastRepsLog(a)?.reps;
      final target = a.repsTarget;
      if (last == null || target == null || target <= 0) continue;
      final ratio = (last / target).clamp(0.0, 1.0).toDouble();
      final remaining = target - last;
      items.add(_CoachProgress(
        icon: Icons.repeat_rounded,
        title: a.name,
        value: '$last/$target rép.',
        hint: remaining <= 0 ? 'Objectif atteint !' : ratio >= .8 ? 'Plus que $remaining rép.' : '',
        ratio: ratio,
        done: remaining <= 0,
      ));
    }
    items.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return b.ratio.compareTo(a.ratio);
    });
    return items.take(2).toList();
  }

  // ----- phrases variées selon le ton -------------------------------------

  String _coachTodayHeadline({
    required String tone,
    required int done,
    required int total,
    required String next,
    required int minutesLeft,
    required ({int now, int best, bool todayActive}) streak,
    required bool hadActivityRecently,
  }) {
    final remaining = max(0, total - done);
    String pick(Map<String, List<String>> byTone, int salt) => _coachPick(byTone[tone] ?? byTone['motivant']!, salt);
    if (total > 0 && remaining == 0) {
      return pick({
        'doux': ['Journée complète : beau travail. Prends le temps d’en profiter.', 'Tout est fait. Tu peux souffler, c’était une belle journée.'],
        'direct': ['Tout est validé. Journée tenue.', 'Objectif du jour atteint, rien à rattraper.'],
        'motivant': ['Journée complète ! $done sur $total : c’est comme ça qu’on construit une série.', 'Tout est validé, bravo ! Demain, on garde cet élan.'],
      }, 1);
    }
    if (total == 0) {
      return pick({
        'doux': ['Rien de prévu aujourd’hui : une journée pour respirer, ou pour ajouter une petite action.', 'Journée libre. Si l’envie vient, une action de 10 minutes suffit.'],
        'direct': ['Aucun moment prévu. Ajoutes-en un de 10 minutes si tu veux avancer.', 'Journée libre : décide d’une seule action utile.'],
        'motivant': ['Journée libre : choisis une petite action et fais-en une victoire.', 'Pas de programme aujourd’hui : 10 minutes suffisent pour garder l’élan.'],
      }, 2);
    }
    if (!streak.todayActive && streak.now >= 2 && DateTime.now().hour >= 15) {
      return pick({
        'doux': ['Ta série de ${streak.now} jours est encore là : une petite action suffit.', 'Même 10 minutes comptent pour garder ton rythme de ${streak.now} jours.'],
        'direct': ['Série de ${streak.now} jours en jeu : fais « $next » maintenant.', 'Il reste du temps : valide quelque chose avant ce soir.'],
        'motivant': ['Garde ta série de ${streak.now} jours : ${minutesLeft > 0 ? '$minutesLeft min' : 'quelques minutes'} suffisent !', 'Ne lâche pas : ${streak.now} jours d’affilée, un de plus et c’est ${streak.now + 1} !'],
      }, 3);
    }
    if (done > 0) {
      return pick({
        'doux': ['$done de fait, c’est déjà bien. Continue à ton rythme.', 'Un pas après l’autre : $done validé${done > 1 ? 's' : ''}.'],
        'direct': ['$done sur $total. Il en reste $remaining.', 'Continue : encore $remaining à valider.'],
        'motivant': ['$done sur $total, plus que $remaining ! Prochaine étape : $next.', 'Tu es lancé : encore $remaining et la journée est gagnée.'],
      }, 4);
    }
    if (streak.now == 0 && !hadActivityRecently) {
      return pick({
        'doux': ['Content de te revoir. On reprend en douceur avec une seule action.', 'Pas de reproche : reprendre est déjà un succès.'],
        'direct': ['Reprise : une action aujourd’hui, rien de plus.', 'Remets le pied à l’étrier avec « $next ».'],
        'motivant': ['Retour en piste ! Une petite action aujourd’hui relance toute la dynamique.', 'Chaque série commence par un jour : que ce soit aujourd’hui.'],
      }, 5);
    }
    return pick({
      'doux': ['Commence doucement : « $next » est un bon premier pas.', 'Pas besoin de tout faire. Un premier geste simple : « $next ».'],
      'direct': ['Premier rendez-vous : « $next ». Lance-le.', 'Commence par « $next », sans te poser de question.'],
      'motivant': ['Aujourd’hui commence par « $next » : le plus dur est le premier pas !', 'Une victoire rapide pour démarrer : « $next ».'],
    }, 6);
  }

  String _coachYesterdayHeadline(String tone, _HomeCoachSnapshot snap) {
    final c = snap.completedCount;
    final min = snap.realisedMinutes;
    String pick(Map<String, List<String>> byTone, int salt) => _coachPick(byTone[tone] ?? byTone['motivant']!, salt);
    if (c > 0) {
      return pick({
        'doux': ['Hier : $c moment${c > 1 ? 's' : ''} vécu${c > 1 ? 's' : ''}. Une bonne base pour aujourd’hui.'],
        'direct': ['Hier : $c moment${c > 1 ? 's' : ''}${min > 0 ? ', $min min' : ''}. Même rythme aujourd’hui.'],
        'motivant': ['Hier, $c moment${c > 1 ? 's' : ''} réalisé${c > 1 ? 's' : ''} : refais-le aujourd’hui !'],
      }, 7);
    }
    return pick({
      'doux': ['Hier était calme, ce n’est pas grave. Aujourd’hui est une nouvelle page.'],
      'direct': ['Rien d’enregistré hier. Aujourd’hui, une action.'],
      'motivant': ['Hier n’a pas compté ? Aujourd’hui, si ! Choisis une action et lance-toi.'],
    }, 8);
  }

  String _coachWeekHeadline(String tone, _HomeCoachSnapshot snap, ({int thisDays, int lastDays, int thisMin, int lastMin}) trend) {
    final d = snap.activeDays;
    final diff = trend.thisDays - trend.lastDays;
    final trendText = diff > 0 ? ', soit ${diff} de plus que la semaine dernière' : diff < 0 ? ', ${-diff} de moins que la semaine dernière' : ', comme la semaine dernière';
    String pick(Map<String, List<String>> byTone, int salt) => _coachPick(byTone[tone] ?? byTone['motivant']!, salt);
    if (d == 0) {
      return pick({
        'doux': ['Semaine tranquille jusqu’ici. Une petite action peut tout relancer.'],
        'direct': ['Aucun jour actif cette semaine. Commence aujourd’hui.'],
        'motivant': ['La semaine démarre aujourd’hui : une action et tu es lancé !'],
      }, 9);
    }
    return pick({
      'doux': ['$d jour${d > 1 ? 's' : ''} actif${d > 1 ? 's' : ''} cette semaine$trendText. C’est un bon rythme.'],
      'direct': ['$d jour${d > 1 ? 's' : ''} actif${d > 1 ? 's' : ''}$trendText.'],
      'motivant': ['$d jour${d > 1 ? 's' : ''} actif${d > 1 ? 's' : ''}$trendText : continue sur cette lancée !'],
    }, 10);
  }

  // ----- bilan du soir ------------------------------------------------------

  void _saveEveningMood(String emoji) {
    final items = actionableItemsForDay(today);
    final done = items.where((i) => i.done).toList();
    final planned = items.fold<int>(0, (s, i) => s + max(0, i.duration));
    final realised = done.fold<int>(0, (s, i) => s + max(0, i.realisedMinutes ?? i.duration));
    final titles = done.map((i) => i.title.trim()).where((t) => t.isNotEmpty).toSet().take(10).toList();
    final summary = DailySummary(
      date: DateTime.now(),
      dateKey: _todayDateKey(),
      moodEmoji: emoji,
      summary: '${titles.isEmpty ? 'Journée' : titles.join(' · ')}. ${done.length} moment${done.length > 1 ? 's' : ''} réalisé${done.length > 1 ? 's' : ''} · $realised min vécues sur $planned min prévues.',
      completedCount: done.length,
      totalCount: items.length,
      plannedMinutes: planned,
      realisedMinutes: realised,
      activityTitles: titles,
    );
    setState(() {
      final index = dailySummaries.indexWhere((s) => s.dateKey == summary.dateKey);
      if (index >= 0) {
        dailySummaries[index] = summary;
      } else {
        dailySummaries.add(summary);
      }
    });
    _queueLocalStatePersist();
    _showFeedback('Bilan du soir enregistré ${summary.moodEmoji}');
  }

  // ----- interface ----------------------------------------------------------

  Widget _coachTile(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: _colors.accentIcon),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong, height: 1.1)),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted, height: 1.2)),
        ]),
      ),
    );
  }

  Widget _coachNextActionCard(PlanItem next) {
    final amount = _itemIsReps(next) ? _repsLineForItem(next) : (_itemIsCount(next) ? 'Occurrence' : '${next.duration} min');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.l), border: Border.all(color: _colors.borderTint)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Prochaine étape', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
        const SizedBox(height: 3),
        Text(_coachPendingTitle(next), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
        const SizedBox(height: 2),
        Text(amount, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
        const SizedBox(height: 8),
        Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
          FilledButton.icon(
            onPressed: () => togglePlanItemDone(next, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Valider'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
          ),
          OutlinedButton.icon(
            onPressed: () => openItemActions(next),
            icon: const Icon(Icons.event_repeat_rounded, size: 18),
            label: const Text('Replacer'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
          ),
        ]),
      ]),
    );
  }

  Widget _coachProgressRow(_CoachProgress p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(p.icon, size: 17, color: p.done ? _colors.goldText : _colors.accentIcon),
          const SizedBox(width: 7),
          Expanded(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong))),
          Text(p.value, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted)),
        ]),
        const SizedBox(height: 4),
        _MeterBar(value: p.ratio, height: 7, color: p.done ? _colors.goldBorder : _colors.accentFill),
        if (p.hint.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(p.hint, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: p.done ? _colors.goldText : _colors.accentText)),
        ],
      ]),
    );
  }

  Widget _coachBadgeRow(List<_CoachBadge> badges) {
    return Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
      for (final b in badges)
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: .8, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _colors.peachBg, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: _colors.goldBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(b.icon, size: 16, color: _colors.goldText),
              const SizedBox(width: 6),
              Flexible(child: Text(b.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.goldText))),
            ]),
          ),
        ),
    ]);
  }

  Widget _coachEveningCheckIn() {
    final summary = _todayDailySummary();
    final recorded = summary != null && summary.moodEmoji.isNotEmpty;
    if (recorded) {
      return Row(children: [
        Icon(Icons.nights_stay_outlined, size: 18, color: _colors.accentIcon),
        const SizedBox(width: 8),
        Expanded(child: Text('Bilan du soir enregistré ${summary!.moodEmoji}', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong))),
      ]);
    }
    Widget mood(String emoji, IconData icon, String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: OutlinedButton.icon(
              onPressed: () => _saveEveningMood(emoji),
              icon: Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 6)),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.nights_stay_outlined, size: 18, color: _colors.accentIcon),
        const SizedBox(width: 8),
        Text('Comment s’est passée ta journée ?', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        mood('😄', Icons.sentiment_very_satisfied_rounded, 'Super'),
        mood('🙂', Icons.sentiment_satisfied_alt_rounded, 'Bien'),
        mood('😓', Icons.sentiment_dissatisfied_rounded, 'Dure'),
      ]),
    ]);
  }

  Widget _homeCoachDashboard() {
    final tone = kCoachTones.any((t) => t.$1 == _coachTone) ? _coachTone : 'motivant';
    final streak = _coachStreakInfo();
    final trend = _coachWeekTrend();
    final today0 = _coachDateOnly(DateTime.now());
    final items = actionableItemsForDay(today).where((p) => !p.optional).toList();
    final doneToday = items.where((p) => p.done).length;
    final remaining = items.where((p) => !p.done).toList();
    final minutesLeft = remaining.where((p) => !_isDateRangePlanItem(p) && !_itemIsCount(p)).fold<int>(0, (s, p) => s + p.duration);
    final next = _coachNextAction();
    final view = (_homeCoachView == 'week' || _homeCoachView == 'yesterday') ? _homeCoachView : 'today';
    final diffDays = trend.thisDays - trend.lastDays;
    final expanded = _homeCoachExpanded;
    final hadRecent = streak.now > 0 || logs.any((l) => l.realisedMinutes > 0 && _daysBetween(l.date, today0) <= 3);
    final summaryLine = [
      'Série ${streak.now} j',
      '$doneToday/${items.length} aujourd’hui',
      if (trend.thisDays + trend.lastDays > 0) _coachTrendArrow(diffDays).split(' ').first,
    ].join(' · ');

    Widget body;
    if (!expanded) {
      body = const SizedBox.shrink();
    } else if (view == 'today') {
      final progress = items.isEmpty ? 0.0 : doneToday / items.length;
      final badges = _coachBadges(streak, trend);
      final goals = _coachProgressItems();
      final remobilization = _coachRemobilizationItems();
      final hour = DateTime.now().hour;
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _coachTodayHeadline(
            tone: tone,
            done: doneToday,
            total: items.length,
            next: next == null ? 'une petite action' : _coachPendingTitle(next),
            minutesLeft: minutesLeft,
            streak: streak,
            hadActivityRecently: hadRecent,
          ),
          style: TextStyle(fontSize: AppType.bodyL, height: 1.35, fontWeight: FontWeight.w800, color: _colors.textStrong),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          Row(children: [
            Expanded(child: _MeterBar(value: progress, height: 9, color: progress >= 1 ? _colors.goldBorder : _colors.accentFill)),
            const SizedBox(width: 10),
            Text('$doneToday/${items.length}${minutesLeft > 0 ? ' · ~${_minutesLabel(minutesLeft)} restantes' : ''}', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted)),
          ]),
        ],
        if (next != null && remaining.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          _coachNextActionCard(next),
        ],
        const SizedBox(height: AppSpace.m),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _coachTile('${streak.now} j', streak.best > streak.now ? 'Série · record ${streak.best} j' : 'Série en cours', Icons.local_fire_department_rounded),
          const SizedBox(width: AppSpace.s),
          _coachTile('${trend.thisDays} j', 'Actifs · ${_coachTrendArrow(diffDays)} vs S-1', Icons.calendar_month_outlined),
          const SizedBox(width: AppSpace.s),
          _coachTile(_minutesLabel(trend.thisMin), 'Cette semaine · S-1 : ${_minutesLabel(trend.lastMin)}', Icons.timer_outlined),
        ]),
        if (goals.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          Text('Plus proches de la ligne d’arrivée', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
          const SizedBox(height: 6),
          for (final p in goals) _coachProgressRow(p),
        ],
        if (remobilization.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          _coachRemobilizationCard(source: remobilization),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          _coachBadgeRow(badges),
        ],
        if (hour >= 18) ...[
          const SizedBox(height: AppSpace.m),
          _coachEveningCheckIn(),
        ],
        const SizedBox(height: AppSpace.m),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, size: 15, color: _colors.textFaint),
          const SizedBox(width: 6),
          Expanded(child: Text(_coachTips[_dayKey(DateTime.now()) % _coachTips.length], style: _hintStyle())),
        ]),
      ]);
    } else {
      final weekly = view == 'week';
      final snapshot = weekly ? _coachSnapshotForWeek() : _coachSnapshotForDate(_addDays(today0, -1));
      final badges = weekly ? _coachBadges(streak, trend) : const <_CoachBadge>[];
      final remobilization = weekly ? _coachRemobilizationItems() : const <_CoachRemobilizationItem>[];
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          weekly ? _coachWeekHeadline(tone, snapshot, trend) : _coachYesterdayHeadline(tone, snapshot),
          style: TextStyle(fontSize: AppType.bodyL, height: 1.35, fontWeight: FontWeight.w800, color: _colors.textStrong),
        ),
        const SizedBox(height: AppSpace.m),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _coachTile(weekly ? '${snapshot.activeDays} j' : '${snapshot.completedCount}', weekly ? 'Jours actifs · ${_coachTrendArrow(diffDays)}' : 'Moments réalisés', weekly ? Icons.calendar_month_outlined : Icons.check_circle_outline),
          const SizedBox(width: AppSpace.s),
          _coachTile(
            snapshot.realisedReps > 0 && snapshot.realisedMinutes == 0 ? '${snapshot.realisedReps} rép.' : _minutesLabel(snapshot.realisedMinutes),
            snapshot.realisedReps > 0 && snapshot.realisedMinutes > 0 ? 'Temps · ${snapshot.realisedReps} rép.' : 'Temps vécu',
            Icons.timer_outlined,
          ),
          const SizedBox(width: AppSpace.s),
          _coachTile(snapshot.canCompareWithPlan ? '${snapshot.pending.length}' : '—', 'À reprendre', Icons.event_repeat_rounded),
        ]),
        if (snapshot.canCompareWithPlan && snapshot.pending.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          for (final item in snapshot.pending.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(child: Text(_coachPendingTitle(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.body, color: _colors.textStrong))),
                TextButton(
                  onPressed: () => openItemActions(item),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Replacer'),
                ),
              ]),
            ),
        ],
        if (remobilization.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          _coachRemobilizationCard(source: remobilization),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          _coachBadgeRow(badges),
        ],
        const SizedBox(height: AppSpace.m),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, size: 15, color: _colors.textFaint),
          const SizedBox(width: 6),
          Expanded(child: Text(_coachTips[(_dayKey(DateTime.now()) + 5) % _coachTips.length], style: _hintStyle())),
        ]),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _AppCard(
        tone: _CardTone.tint,
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.m),
            onTap: () => setState(() => _homeCoachExpanded = !_homeCoachExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                _uiIcon('coach', Icons.psychology_outlined, size: 24, color: _colors.accentIcon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Rendez-vous du Coach', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                    if (!expanded) Text(summaryLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ton du Coach',
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.tune_rounded, size: 20, color: _colors.textMuted),
                  onSelected: (value) {
                    setState(() => _coachTone = value);
                    _queueLocalStatePersist();
                  },
                  itemBuilder: (context) => [
                    for (final t in kCoachTones) CheckedPopupMenuItem<String>(value: t.$1, checked: tone == t.$1, child: Text('Ton ${t.$2.toLowerCase()}')),
                  ],
                ),
                Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _colors.textMuted),
              ]),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpace.s),
            Wrap(spacing: 6, children: [
              _coachPeriodChoice('Aujourd’hui', 'today'),
              _coachPeriodChoice('Hier', 'yesterday'),
              _coachPeriodChoice('Semaine', 'week'),
            ]),
            const SizedBox(height: AppSpace.m),
            body,
          ],
        ]),
      ),
    );
  }
}
