// V12.28.0 — Coach Nutrition : la semaine en perspective, d'un jour sur l'autre.
// Chaque jour est évalué avec les objectifs Nutrition « par jour » (au moins / au plus), puis replacé
// dans la semaine : hier → aujourd'hui, jours tenus, semaine dernière, jour le plus délicat sur 4 semaines,
// marge restante des objectifs hebdomadaires. Le Coach ne demande jamais de compenser un écart.

part of '../main.dart';

const List<String> _nutDayNames = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const List<String> _nutDayShort = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

String _nutPlural(int n, String one, String many) => n > 1 ? many : one;

String _nutJoinNames(List<String> names) {
  final quoted = [for (final n in names) '« $n »'];
  if (quoted.isEmpty) return 'un plafond';
  if (quoted.length == 1) return quoted.first;
  return '${quoted.sublist(0, quoted.length - 1).join(', ')} et ${quoted.last}';
}

enum _NutDayState { held, partial, missed, off, none, today, future }

class _NutDay {
  final DateTime date;
  final _NutDayState state;
  final int satisfied; // repères quotidiens tenus
  final int total; // repères quotidiens applicables ce jour-là
  final int minDone; // minimums (« au moins ») atteints : seuls repères actifs pour la journée en cours
  final int minTotal;
  final List<String> exceeded; // plafonds dépassés
  final List<String> missing; // minimums non atteints

  const _NutDay({
    required this.date,
    required this.state,
    this.satisfied = 0,
    this.total = 0,
    this.minDone = 0,
    this.minTotal = 0,
    this.exceeded = const <String>[],
    this.missing = const <String>[],
  });

  /// Jour jugé : passé et renseigné (le jour en cours et les jours à venir ne sont pas jugés).
  bool get evaluated =>
      state == _NutDayState.held ||
      state == _NutDayState.partial ||
      state == _NutDayState.missed ||
      state == _NutDayState.off;
}

enum _NutBudgetKind { done, onTrack, tight, unreachable, capRoom, capReached, capOver }

class _NutBudget {
  final Activity activity;
  final RealizationGoal goal;
  final int actual;
  final int target;
  final int daysLeft; // jours encore disponibles pour placer une occasion (jusqu'à dimanche)
  final _NutBudgetKind kind;

  const _NutBudget({
    required this.activity,
    required this.goal,
    required this.actual,
    required this.target,
    required this.daysLeft,
    required this.kind,
  });

  bool get isMaximum => goal.isMaximum;
  int get remaining => target - actual;

  String get text {
    switch (kind) {
      case _NutBudgetKind.done:
        return 'Objectif atteint pour cette semaine.';
      case _NutBudgetKind.onTrack:
        return 'Encore $remaining ${_nutPlural(remaining, 'occasion', 'occasions')} sur $daysLeft ${_nutPlural(daysLeft, 'jour', 'jours')} : tu as de la marge.';
      case _NutBudgetKind.tight:
        return 'Chaque jour compte : $remaining ${_nutPlural(remaining, 'occasion', 'occasions')} pour $daysLeft ${_nutPlural(daysLeft, 'jour', 'jours')}.';
      case _NutBudgetKind.unreachable:
        return 'Plus atteignable cette semaine : vise ${actual + daysLeft}, la cible de $target reprendra lundi.';
      case _NutBudgetKind.capRoom:
        return 'Il reste $remaining ${_nutPlural(remaining, 'occasion', 'occasions')} pour $daysLeft ${_nutPlural(daysLeft, 'jour', 'jours')}.';
      case _NutBudgetKind.capReached:
        return 'Plafond atteint : pas de marge d’ici dimanche.';
      case _NutBudgetKind.capOver:
        return 'Dépassé de ${-remaining} cette semaine : pas de compensation, reviens simplement au cadre.';
    }
  }
}

class _NutFocus {
  final String text;
  final Activity? activity; // activité qu'on peut cocher aujourd'hui en un geste
  const _NutFocus({required this.text, this.activity});
}

/// Calculs du Coach Nutrition : fonctions pures sur le journal, sans état.
class _NutritionCoachEngine {
  final List<Activity> activities;
  final List<RealizationGoal> goals;
  final DateTime now;
  final Map<String, Activity> _byId = <String, Activity>{};
  final Map<int, Map<String, int>> _counts = <int, Map<String, int>>{};

  _NutritionCoachEngine({
    required List<Activity> activities,
    required List<ActivityLog> logs,
    required List<RealizationGoal> goals,
    required this.now,
  })  : activities = List<Activity>.of(activities),
        goals = [
          for (final g in goals)
            if (activities.any((a) => a.id == g.activityId)) g
        ] {
    for (final a in this.activities) {
      _byId[a.id] = a;
    }
    final idByName = <String, String>{
      for (final a in this.activities) a.name.trim().toLowerCase(): a.id,
    };
    for (final log in logs) {
      String? id = log.activityId;
      if (id != null) {
        if (!_byId.containsKey(id)) continue; // réalisation d'une autre activité
      } else {
        id = idByName[log.title.trim().toLowerCase()];
        if (id == null) continue;
      }
      final activity = _byId[id];
      if (activity == null) continue;
      if (!(activity.countOnly || log.realisedMinutes > 0 || (log.reps ?? 0) > 0)) continue;
      final perDay = _counts.putIfAbsent(_key(log.date), () => <String, int>{});
      perDay[id] = (perDay[id] ?? 0) + 1;
    }
  }

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _shift(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  DateTime get _today => _dateOnly(now);
  DateTime get monday => _shift(_today, -(_today.weekday - 1));
  int get todayIndex => _today.weekday - 1;

  /// Jours restants dans la semaine, aujourd'hui compris.
  int get daysLeft => 7 - todayIndex;

  int _countOn(DateTime day, String activityId) => _counts[_key(day)]?[activityId] ?? 0;

  _NutDay dayFor(DateTime date) {
    final d = _dateOnly(date);
    if (d.isAfter(_today)) return _NutDay(date: d, state: _NutDayState.future);
    final isToday = d == _today;
    final counts = _counts[_key(d)] ?? const <String, int>{};
    if (counts.isEmpty && !isToday) return _NutDay(date: d, state: _NutDayState.none);

    final daily = goals.where((g) => g.cadence == 'jour' && !_dateOnly(g.createdAt).isAfter(d)).toList();
    var satisfied = 0;
    var minDone = 0;
    var minTotal = 0;
    final exceeded = <String>[];
    final missing = <String>[];
    for (final g in daily) {
      final c = counts[g.activityId] ?? 0;
      final name = _byId[g.activityId]?.name ?? '';
      if (!g.isMaximum) {
        minTotal++;
        if (c >= g.target) minDone++;
      }
      if (g.isMaximum ? c <= g.target : c >= g.target) {
        satisfied++;
      } else if (g.isMaximum) {
        exceeded.add(name);
      } else {
        missing.add(name);
      }
    }

    final _NutDayState state;
    if (daily.isEmpty) {
      state = counts.isEmpty ? _NutDayState.today : _NutDayState.held;
    } else if (exceeded.isNotEmpty) {
      state = _NutDayState.off;
    } else if (satisfied == daily.length) {
      state = (isToday && counts.isEmpty) ? _NutDayState.today : _NutDayState.held;
    } else if (isToday) {
      state = _NutDayState.today;
    } else {
      state = satisfied > 0 ? _NutDayState.partial : _NutDayState.missed;
    }
    return _NutDay(
      date: d,
      state: state,
      satisfied: satisfied,
      total: daily.length,
      minDone: minDone,
      minTotal: minTotal,
      exceeded: exceeded,
      missing: missing,
    );
  }

  /// Les sept jours de la semaine (lundi → dimanche) ; [weeksBack] = 1 pour la semaine dernière.
  List<_NutDay> weekDays([int weeksBack = 0]) {
    final start = _shift(monday, -7 * weeksBack);
    return [for (var i = 0; i < 7; i++) dayFor(_shift(start, i))];
  }

  int _heldIn(List<_NutDay> days) => days.where((d) => d.state == _NutDayState.held).length;
  int _evaluatedIn(List<_NutDay> days) => days.where((d) => d.evaluated).length;

  /// Jours tenus d'affilée, en remontant d'hier (et aujourd'hui s'il est déjà tenu).
  int get heldStreak {
    var n = dayFor(_today).state == _NutDayState.held ? 1 : 0;
    var cursor = _shift(_today, -1);
    for (var i = 0; i < 60; i++) {
      if (dayFor(cursor).state != _NutDayState.held) break;
      n++;
      cursor = _shift(cursor, -1);
    }
    return n;
  }

  /// Jour de la semaine le plus souvent non tenu sur les 4 dernières semaines (au moins 3 observations).
  ({int index, int held, int total})? get weakestWeekday {
    final heldBy = List<int>.filled(7, 0);
    final totalBy = List<int>.filled(7, 0);
    for (var i = 1; i <= 28; i++) {
      final d = dayFor(_shift(_today, -i));
      if (!d.evaluated) continue;
      final w = d.date.weekday - 1;
      totalBy[w]++;
      if (d.state == _NutDayState.held) heldBy[w]++;
    }
    final sumTotal = totalBy.fold<int>(0, (a, b) => a + b);
    final sumHeld = heldBy.fold<int>(0, (a, b) => a + b);
    if (sumTotal < 10) return null;
    final overall = sumHeld / sumTotal;
    int? best;
    var bestRate = 2.0;
    for (var i = 0; i < 7; i++) {
      if (totalBy[i] < 3) continue;
      final rate = heldBy[i] / totalBy[i];
      if (rate < bestRate) {
        bestRate = rate;
        best = i;
      }
    }
    if (best == null || bestRate > 0.5 || overall - bestRate < 0.25) return null;
    return (index: best, held: heldBy[best], total: totalBy[best]);
  }

  // ----- objectifs hebdomadaires : marge restante --------------------------------------------

  List<_NutBudget> weeklyBudgets() {
    final result = <_NutBudget>[];
    for (final g in goals) {
      if (g.cadence != 'semaine') continue;
      final activity = _byId[g.activityId];
      if (activity == null) continue;
      var actual = 0;
      for (var i = 0; i <= todayIndex; i++) {
        actual += _countOn(_shift(monday, i), g.activityId);
      }
      final doneToday = _countOn(_today, g.activityId) > 0;
      final _NutBudgetKind kind;
      var left = daysLeft;
      if (g.isMaximum) {
        kind = actual > g.target
            ? _NutBudgetKind.capOver
            : actual == g.target
                ? _NutBudgetKind.capReached
                : _NutBudgetKind.capRoom;
      } else {
        // Une habitude déjà cochée aujourd'hui ne peut plus l'être : il reste un jour de moins à utiliser.
        if (doneToday) left = max(0, left - 1);
        final remaining = g.target - actual;
        kind = remaining <= 0
            ? _NutBudgetKind.done
            : remaining > left
                ? _NutBudgetKind.unreachable
                : remaining == left
                    ? _NutBudgetKind.tight
                    : _NutBudgetKind.onTrack;
      }
      result.add(_NutBudget(activity: activity, goal: g, actual: actual, target: g.target, daysLeft: left, kind: kind));
    }
    int rank(_NutBudgetKind k) {
      switch (k) {
        case _NutBudgetKind.capOver:
          return 0;
        case _NutBudgetKind.tight:
          return 1;
        case _NutBudgetKind.unreachable:
          return 2;
        case _NutBudgetKind.onTrack:
          return 3;
        case _NutBudgetKind.capReached:
          return 4;
        case _NutBudgetKind.capRoom:
          return 5;
        case _NutBudgetKind.done:
          return 6;
      }
    }

    result.sort((a, b) {
      final byRank = rank(a.kind).compareTo(rank(b.kind));
      return byRank != 0 ? byRank : a.activity.name.toLowerCase().compareTo(b.activity.name.toLowerCase());
    });
    return result;
  }

  /// Une seule priorité pour aujourd'hui.
  _NutFocus? focus() {
    final todayCounts = _counts[_key(_today)] ?? const <String, int>{};

    // 1) Minimum quotidien pas encore tenu.
    final dailyMissing = goals
        .where((g) =>
            g.cadence == 'jour' &&
            !g.isMaximum &&
            !_dateOnly(g.createdAt).isAfter(_today) &&
            (todayCounts[g.activityId] ?? 0) < g.target)
        .toList();
    if (dailyMissing.isNotEmpty) {
      final g = dailyMissing.first;
      final activity = _byId[g.activityId];
      if (activity != null) {
        return _NutFocus(
          text: 'Cap du jour : « ${activity.name} » (${todayCounts[g.activityId] ?? 0}/${g.target}).',
          activity: activity,
        );
      }
    }

    // 2) Minimum hebdomadaire à placer, le plus pressant d'abord.
    final pressing = weeklyBudgets()
        .where((b) =>
            !b.isMaximum &&
            (b.kind == _NutBudgetKind.tight || b.kind == _NutBudgetKind.onTrack) &&
            _countOn(_today, b.activity.id) == 0 &&
            b.remaining / max(1, b.daysLeft) >= 0.5)
        .toList()
      ..sort((a, b) => (b.remaining / max(1, b.daysLeft)).compareTo(a.remaining / max(1, a.daysLeft)));
    if (pressing.isNotEmpty) {
      final b = pressing.first;
      return _NutFocus(
        text: 'Cap du jour : « ${b.activity.name} » — ${b.remaining} ${_nutPlural(b.remaining, 'occasion', 'occasions')} à placer d’ici dimanche.',
        activity: b.activity,
      );
    }

    // 3) Plafond hebdomadaire déjà atteint.
    final capped = weeklyBudgets().where((b) => b.kind == _NutBudgetKind.capReached).toList();
    if (capped.isNotEmpty) {
      return _NutFocus(text: 'À garder en tête : « ${capped.first.activity.name} » a atteint son plafond de la semaine.');
    }
    return null;
  }

  // ----- phrases (selon le ton du Coach) -----------------------------------------------------

  String _pick(String tone, String doux, String motivant, String direct) =>
      tone == 'doux' ? doux : tone == 'direct' ? direct : motivant;

  /// Hier → aujourd'hui.
  String headline(String tone) {
    final y = dayFor(_shift(_today, -1));
    final td = dayFor(_today);
    String part = '';
    switch (y.state) {
      case _NutDayState.held:
        final streak = heldStreak;
        part = streak >= 3
            ? _pick(
                tone,
                'Hier tenu, et cela fait $streak jours d’affilée : belle régularité.',
                'Hier tenu : $streak jours d’affilée, la série prend forme.',
                'Hier : tenu. Série : $streak jours.',
              )
            : _pick(
                tone,
                'Hier, tout était dans ton cadre.',
                'Hier tenu en entier : c’est ainsi que la semaine se construit.',
                'Hier : tenu.',
              );
        break;
      case _NutDayState.partial:
        part = _pick(
          tone,
          'Hier, une partie de tes repères a été tenue (${y.satisfied}/${y.total}). Un pas de plus aujourd’hui suffit.',
          'Hier : ${y.satisfied}/${y.total} repères tenus. Aujourd’hui, vise un pas de plus.',
          'Hier : ${y.satisfied}/${y.total}. Un de plus aujourd’hui.',
        );
        break;
      case _NutDayState.off:
        final names = _nutJoinNames(y.exceeded);
        part = _pick(
          tone,
          'Hier, $names a dépassé le cadre. Une journée ne fait pas la semaine : on repart sur tes repères, sans compenser.',
          'Hier : écart sur $names. Une journée ne fait pas la semaine : retour au cadre aujourd’hui, sans compenser.',
          'Hier : $names au-dessus du plafond. Aujourd’hui, retour au cadre, sans compenser.',
        );
        break;
      case _NutDayState.missed:
        part = _pick(
          tone,
          'Hier, peu d’habitudes cochées. Aujourd’hui est un nouveau départ : une seule suffit pour relancer.',
          'Hier a été léger côté habitudes. Une seule coche aujourd’hui et le rythme reprend.',
          'Hier : habitudes manquées. Coches-en une dès ce matin.',
        );
        break;
      case _NutDayState.none:
      case _NutDayState.today:
      case _NutDayState.future:
        break;
    }

    String todayPart = '';
    switch (td.state) {
      case _NutDayState.held:
        todayPart = td.minTotal > 0
            ? ' Aujourd’hui : ${td.minDone}/${td.minTotal} ${_nutPlural(td.minTotal, 'habitude', 'habitudes')}, tout est tenu pour l’instant.'
            : ' Aujourd’hui, c’est déjà noté.';
        break;
      case _NutDayState.today:
        todayPart = td.minTotal > 0
            ? ' Aujourd’hui : ${td.minDone}/${td.minTotal} ${_nutPlural(td.minTotal, 'habitude', 'habitudes')} pour l’instant.'
            : '';
        break;
      case _NutDayState.off:
        todayPart = ' Aujourd’hui, un plafond est déjà dépassé (${_nutJoinNames(td.exceeded)}) : reviens au cadre pour les prochains repas.';
        break;
      case _NutDayState.partial:
      case _NutDayState.missed:
      case _NutDayState.none:
      case _NutDayState.future:
        break;
    }

    if (part.isEmpty && todayPart.isEmpty) {
      return _pick(
        tone,
        'La semaine se construit jour après jour : chaque coche compte.',
        'Chaque coche compte : la semaine se construit jour après jour.',
        'Coche tes habitudes du jour.',
      );
    }
    return part.isEmpty ? todayPart.trim() : '$part$todayPart';
  }

  /// « Semaine en cours : 3/4 jours tenus · semaine dernière : 5/7 ».
  String weekStats() {
    final week = weekDays();
    final held = _heldIn(week);
    final evaluated = _evaluatedIn(week);
    final last = weekDays(1);
    final lastEvaluated = _evaluatedIn(last);
    final buffer = StringBuffer(evaluated == 0
        ? 'Semaine en cours : pas encore de jour évalué'
        : 'Semaine en cours : $held/$evaluated ${_nutPlural(evaluated, 'jour tenu', 'jours tenus')}');
    if (lastEvaluated >= 3) buffer.write(' · semaine dernière : ${_heldIn(last)}/$lastEvaluated');
    return buffer.toString();
  }

  /// Lecture de la semaine en cours, une fois au moins deux jours évalués.
  String? weekPerspective(String tone) {
    final week = weekDays();
    final evaluated = _evaluatedIn(week);
    if (evaluated < 2) return null;
    final ratio = _heldIn(week) / evaluated;
    final left = daysLeft;
    final days = '$left ${_nutPlural(left, 'jour', 'jours')}';
    if (ratio >= 0.7) {
      return _pick(tone, 'Une belle semaine se dessine.', 'La semaine se présente bien : garde ce rythme.', 'Semaine solide : maintiens.');
    }
    if (ratio >= 0.4) {
      return _pick(
        tone,
        'Semaine en équilibre : il reste $days pour la faire pencher du bon côté.',
        'Il reste $days : assez pour finir sur une bonne note.',
        'Semaine moyenne. $days pour la redresser.',
      );
    }
    return _pick(
      tone,
      'Début de semaine difficile, cela arrive. Les $days restants sont une vraie occasion de repartir.',
      'Départ compliqué, mais il reste $days : quelques jours tenus changent vite le bilan.',
      'Semaine en retrait. Objectif : tenir les $days restants.',
    );
  }

  /// Jour le plus délicat, avec anticipation si c'est demain.
  String? patternLine(String tone) {
    final w = weakestWeekday;
    if (w == null) return null;
    final name = _nutDayNames[w.index];
    final span = 'tenu ${w.held} ${_nutPlural(w.held, 'fois', 'fois')} sur ${w.total} ces 4 dernières semaines';
    final tomorrowIndex = _today.weekday % 7;
    if (tomorrowIndex == w.index) {
      return _pick(
        tone,
        'Demain, c’est ton jour le plus délicat ($name : $span). Prépare-le dès ce soir.',
        'Demain, le $name : ton jour le plus fragile ($span). Une préparation ce soir change la donne.',
        'Demain : $name, jour fragile ($span). Anticipe.',
      );
    }
    if (todayIndex == w.index) {
      return _pick(
        tone,
        'Aujourd’hui est ton jour le plus délicat ($name : $span). Sois indulgent, reste simple.',
        'Aujourd’hui, le $name : ton jour le plus fragile ($span). Garde le cap.',
        'Aujourd’hui : $name, jour fragile ($span). Reste au cadre.',
      );
    }
    return _pick(
      tone,
      'Ton jour le plus délicat : le $name ($span).',
      'Point d’attention : le $name, $span.',
      'Jour fragile : $name ($span).',
    );
  }
}

/// Carte Coach Nutrition : bande Lu→Di, lecture hier→aujourd'hui, cap du jour, marge hebdomadaire.
class _NutritionCoachCard extends StatelessWidget {
  final _NutritionCoachEngine engine;
  final String tone;
  final bool compact;
  final VoidCallback? onOpenAnalysis;
  final void Function(Activity activity)? onCheckToday;

  const _NutritionCoachCard({
    required this.engine,
    required this.tone,
    this.compact = true,
    this.onOpenAnalysis,
    this.onCheckToday,
  });

  Widget _dayColumn(_NutDay day, int index, bool isToday) {
    Color background = Colors.transparent;
    Color foreground = _colors.textMuted;
    IconData? icon;
    switch (day.state) {
      case _NutDayState.held:
        background = _colors.accentFill;
        foreground = Colors.white;
        icon = Icons.check_rounded;
        break;
      case _NutDayState.partial:
        background = _colors.tintStrong;
        foreground = _colors.accentText;
        icon = Icons.remove_rounded;
        break;
      case _NutDayState.off:
        background = _colors.peachBg;
        foreground = _colors.goldText;
        icon = Icons.priority_high_rounded;
        break;
      case _NutDayState.missed:
        background = _colors.surfaceSoft;
        foreground = _colors.textMuted;
        icon = Icons.close_rounded;
        break;
      case _NutDayState.today:
        foreground = _colors.accentText;
        icon = Icons.more_horiz_rounded;
        break;
      case _NutDayState.none:
      case _NutDayState.future:
        break;
    }
    return Column(children: [
      Text(
        _nutDayShort[index],
        style: TextStyle(
          fontSize: AppType.micro,
          fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
          color: isToday ? _colors.accentText : _colors.textMuted,
        ),
      ),
      const SizedBox(height: 3),
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(color: isToday ? _colors.accentFillBorder : _colors.borderTint, width: isToday ? 2 : 1),
        ),
        child: icon == null ? null : Icon(icon, size: 15, color: foreground),
      ),
    ]);
  }

  Color _budgetColor(_NutBudgetKind kind) {
    switch (kind) {
      case _NutBudgetKind.done:
        return _colors.accentText;
      case _NutBudgetKind.tight:
      case _NutBudgetKind.unreachable:
      case _NutBudgetKind.capReached:
        return _colors.goldText;
      case _NutBudgetKind.capOver:
        return _colors.warnBorder;
      case _NutBudgetKind.onTrack:
      case _NutBudgetKind.capRoom:
        return _colors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = engine.weekDays();
    final todayIndex = engine.todayIndex;
    final focus = engine.focus();
    final perspective = engine.weekPerspective(tone);
    final pattern = engine.patternLine(tone);
    final budgets = compact ? const <_NutBudget>[] : engine.weeklyBudgets();
    final canCheck = focus?.activity != null && onCheckToday != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: _colors.card,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: _colors.borderTint),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onOpenAnalysis,
          borderRadius: BorderRadius.circular(AppRadius.s),
          child: Row(children: [
            Icon(Icons.psychology_outlined, size: 18, color: _colors.accentIcon),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'COACH NUTRITION · LA SEMAINE EN PERSPECTIVE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w900, letterSpacing: .3, color: _colors.accentStrongText),
              ),
            ),
            if (onOpenAnalysis != null) Icon(Icons.chevron_right_rounded, size: 18, color: _colors.textFaint),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 7; i++) Expanded(child: _dayColumn(week[i], i, i == todayIndex)),
        ]),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            '✓ tenu · – en partie · ! écart · ✕ manqué · … en cours · vide : non renseigné',
            style: TextStyle(fontSize: AppType.micro, color: _colors.textFaint),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          engine.headline(tone),
          style: TextStyle(fontSize: AppType.body, height: 1.35, fontWeight: FontWeight.w700, color: _colors.textStrong),
        ),
        const SizedBox(height: 5),
        Text(
          engine.weekStats(),
          style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.textMuted),
        ),
        if (perspective != null) ...[
          const SizedBox(height: 2),
          Text(perspective, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted)),
        ],
        if (pattern != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.event_note_outlined, size: 15, color: _colors.goldText),
            const SizedBox(width: 6),
            Expanded(child: Text(pattern, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textStrong))),
          ]),
        ],
        if (focus != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(Icons.flag_outlined, size: 15, color: _colors.accentIcon),
            const SizedBox(width: 6),
            Expanded(child: Text(focus.text, style: TextStyle(fontSize: AppType.small, height: 1.3, fontWeight: FontWeight.w700, color: _colors.textStrong))),
            if (canCheck) ...[
              const SizedBox(width: 6),
              FilledButton.tonal(
                onPressed: () => onCheckToday!(focus.activity!),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 10)),
                child: const Text('Cocher'),
              ),
            ],
          ]),
        ],
        if (budgets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Marge de la semaine', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
          const SizedBox(height: 4),
          for (final b in budgets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      b.activity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong),
                    ),
                  ),
                  Text(
                    '${b.actual}/${b.target}${b.isMaximum ? ' max' : ''}',
                    style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w900, color: _budgetColor(b.kind)),
                  ),
                ]),
                Text(b.text, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _budgetColor(b.kind))),
              ]),
            ),
        ],
      ]),
    );
  }
}

extension _NutritionCoachPart on _MaBelleSemaineAppState {
  String get _nutritionCoachTone => kCoachTones.any((t) => t.$1 == _coachTone) ? _coachTone : 'motivant';

  /// Carte compacte de l'accueil : cocher le cap du jour s'y fait en un geste.
  Widget _nutritionCoachCard() => _NutritionCoachCard(
        engine: _NutritionCoachEngine(
          activities: _nutritionActivitiesForChecklist(),
          logs: logs,
          goals: _realizationGoals,
          now: _clockNow,
        ),
        tone: _nutritionCoachTone,
        compact: true,
        onOpenAnalysis: _openNutritionWeeklyAnalysis,
        onCheckToday: (activity) => _setNutritionActivityDoneForDay(activity, today, true),
      );
}
