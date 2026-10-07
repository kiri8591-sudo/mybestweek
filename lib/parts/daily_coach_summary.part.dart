// V9.02 — Bilans quotidiens et synthèse Coach
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _DailyCoachSummaryPart on _MaBelleSemaineAppState {
  List<ActivityLog> _currentWeekLogs() {
    final start = _startOfCurrentWeek();
    final end = _addDays(start, 7);
    return logs.where((log) => !log.date.isBefore(start) && log.date.isBefore(end)).toList();
  }

  String _todayDateKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<DailySummary> _recentDailySummaries([int days = 14]) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return dailySummaries.where((summary) => !summary.date.isBefore(cutoff)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  DailySummary? _todayDailySummary() {
    final key = _todayDateKey();
    for (final summary in dailySummaries) {
      if (summary.dateKey == key) return summary;
    }
    return null;
  }

  String _todayMoodComment(DailySummary summary) {
    switch (summary.moodEmoji) {
      case '😄':
        return 'Une journée vécue avec le sourire ✨';
      case '🙂':
        return 'Une journée bien vécue, à garder comme repère 🌿';
      case '😌':
        return 'Une journée sereine, avec un bon rythme 🌿';
      case '😐':
        return 'Une journée neutre : demain pourra être un peu plus doux.';
      case '😓':
        return 'Une journée fatigante : le Coach en tiendra compte demain 🌙';
      default:
        return 'Ton ressenti du jour est conservé pour le Coach.';
    }
  }

  bool _todayIsCompleted() {
    final items = actionableItemsForDay(today);
    return items.isNotEmpty && items.every((item) => item.done);
  }

  void _upsertTodayDailySummary({String? moodEmoji, bool persist = true}) {
    final items = actionableItemsForDay(today);
    if (items.isEmpty || !items.every((item) => item.done)) return;
    final doneItems = items.where((item) => item.done).toList();
    final planned = items.fold<int>(0, (sum, item) => sum + max(0, item.duration));
    final realised = doneItems.fold<int>(0, (sum, item) => sum + max(0, item.realisedMinutes ?? item.duration));
    final titles = doneItems
        .map((item) => item.title.trim())
        .where((title) => title.isNotEmpty)
        .toSet()
        .take(10)
        .toList();
    final mood = moodEmoji ?? _todayDailySummary()?.moodEmoji ?? '🙂';
    final titleList = titles.isEmpty ? 'Les moments du jour' : titles.join(' · ');
    final textSummary = '$titleList. ${doneItems.length} moment(s) réalisé(s) · $realised min vécues sur $planned min prévus.';
    final summary = DailySummary(
      date: DateTime.now(),
      dateKey: _todayDateKey(),
      moodEmoji: mood,
      summary: textSummary,
      completedCount: doneItems.length,
      totalCount: items.length,
      plannedMinutes: planned,
      realisedMinutes: realised,
      activityTitles: titles,
    );
    final index = dailySummaries.indexWhere((item) => item.dateKey == summary.dateKey);
    if (index >= 0) {
      dailySummaries[index] = summary;
    } else {
      dailySummaries.add(summary);
    }
    dailySummaries.sort((a, b) => b.date.compareTo(a.date));
    if (dailySummaries.length > 180) dailySummaries.removeRange(180, dailySummaries.length);
    if (persist) _queueLocalStatePersist();
  }

  Future<void> _openTodayDailySummary() async {
    if (!_todayIsCompleted()) return;
    final current = _todayDailySummary();
    final mood = await showModalBottomSheet<String>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DailySummarySheet(summary: current, dayLabel: dayNames[today]),
    );
    if (mood == null || !mounted) return;
    setState(() {
      _upsertTodayDailySummary(moodEmoji: mood, persist: false);
    });
    _queueLocalStatePersist();
    _showFeedback('Ton humeur du jour $mood est conservée pour le Coach.');
  }

  String? _dailyMoodCoachSignal() {
    final recent = _recentDailySummaries(14);
    if (recent.isEmpty) return null;
    final tired = recent.where((summary) => const {'😓', '😐'}.contains(summary.moodEmoji)).length;
    final positive = recent.where((summary) => const {'😄', '🙂', '😌'}.contains(summary.moodEmoji)).length;
    if (tired >= 2) return 'plusieurs journées récentes ont été ressenties comme lourdes';
    if (positive >= 3) return 'plusieurs journées récentes ont été ressenties positivement';
    return null;
  }

  String _coachWeeklySummary() {
    final weekLogs = _currentWeekLogs();
    final trackedUntilToday = plan.where((p) => p.activityId != null && p.day <= today && !_isDateRangePlanItem(p)).toList();
    final completed = trackedUntilToday.where((p) => p.done).length;
    final planned = trackedUntilToday.length;
    final completion = planned == 0 ? 0.0 : completed / planned;
    final realisedMinutes = weekLogs.fold<int>(0, (sum, l) => sum + l.realisedMinutes);
    final difficult = weekLogs.where((l) => _normalizeFeeling(l.feeling) == 'Difficile').length;
    final veryGood = weekLogs.where((l) => _normalizeFeeling(l.feeling) == 'Très bien').length;
    final moves = activityMoveLogs.where((m) {
      final start = _startOfCurrentWeek();
      return !m.date.isBefore(start) && m.date.isBefore(_addDays(start, 7));
    }).length;
    final manualAdded = plan.where((p) => p.userAdded && p.manualPlacement && p.activityId != null && p.day >= today).length;
    final manualRemoved = _manualDayRemovals.values.fold<int>(0, (sum, days) => sum + days.values.fold<int>(0, (s, c) => s + c));
    final parts = <String>[];
    if (planned == 0) {
      parts.add('La semaine n’a pas encore assez de moments passés pour tirer une conclusion solide.');
    } else {
      parts.add('J’ai constaté $completed moment(s) réalisé(s) sur $planned déjà passés cette semaine (${(completion * 100).round()} %).');
    }
    if (realisedMinutes > 0) parts.add('Cela représente $realisedMinutes min réellement vécues.');
    if (moves > 0) parts.add('$moves déplacement(s) me montrent que la souplesse du planning reste utile.');
    if (manualAdded > 0) parts.add('$manualAdded moment(s) ajouté(s) manuellement restent protégés comme choix personnels.');
    if (manualRemoved > 0) parts.add('$manualRemoved occurrence(s) retirée(s) manuellement restent exclues de la génération sur leur jour.');
    final manualSportOver = _manualSportBudgetOverrideDays.fold<int>(0, (sum, day) => sum + _acceptedSportOverrunForDay(day));
    if (manualSportOver > 0) parts.add('Le Sport dépasse actuellement de $manualSportOver min le budget accepté par choix manuel ; je peux proposer un rééquilibrage entre les jours.');
    final moodSignal = _dailyMoodCoachSignal();
    if (moodSignal != null) parts.add('Les bilans d’humeur récents indiquent que $moodSignal ; je garde ce signal comme repère complémentaire.');
    if (difficult >= 2) {
      parts.add('$difficult ressentis « Difficile » sont un signal de charge à surveiller pour la suite.');
    } else if (veryGood >= 2) {
      parts.add('$veryGood ressentis « Très bien » montrent des moments bien installés dans ton rythme actuel.');
    }
    if (_weatherForecast.isNotEmpty) {
      final outdoorFuture = plan.any((item) {
        final activity = item.activityId == null ? null : findActivity(item.activityId!);
        return activity != null && item.day >= today && _isOutdoorPlanningActivity(activity);
      });
      if (outdoorFuture) {
        final weatherDays = <String>[];
        for (var d = today; d < 7; d++) {
          final weather = _weatherForWeekDay(d);
          if (weather != null) weatherDays.add('${dayNames[d]} : ${_weatherBrief(weather)}');
        }
        if (weatherDays.isNotEmpty) {
          parts.add('🌦️ Météo intégrée aux arbitrages extérieurs : ${weatherDays.take(4).join(' · ')}.');
        }
      }
    }
    if (parts.isEmpty) return 'Je continue d’observer ton rythme avant de renforcer mes conclusions.';
    return parts.join(' ');
  }

  List<String> _coachWeeklyInsights() {
    final weekLogs = _currentWeekLogs();
    final insights = <String>[];
    final difficult = weekLogs.where((l) => _normalizeFeeling(l.feeling) == 'Difficile').length;
    final veryGood = weekLogs.where((l) => _normalizeFeeling(l.feeling) == 'Très bien').length;
    final movedThisWeek = activityMoveLogs.where((m) {
      final start = _startOfCurrentWeek();
      return !m.date.isBefore(start) && m.date.isBefore(_addDays(start, 7));
    }).length;

    final activeProfiles = activities
        .map((a) => MapEntry(a, _activityLearning(a)))
        .where((e) => e.value.hasEnoughData)
        .toList();
    activeProfiles.sort((a, b) => b.value.realisedCount.compareTo(a.value.realisedCount));

    if (difficult >= 2) insights.add('Charge : je tiendrai davantage compte des ressentis difficiles lors de la prochaine génération.');
    if (veryGood >= 2) insights.add('Confort : je conserve les rythmes qui donnent régulièrement un ressenti « Très bien », sans les multiplier artificiellement.');
    if (movedThisWeek >= 2) insights.add('Souplesse : comme plusieurs moments ont bougé cette semaine, j’augmenterai le poids des habitudes de déplacement quand elles sont répétées.');
    if (_weatherForecast.isNotEmpty) {
      final weatherDays = <String>[];
      for (var d = today; d < 7; d++) {
        final weather = _weatherForWeekDay(d);
        if (weather != null) weatherDays.add('${dayNames[d]} ${weather.icon} ${weather.text.toLowerCase()}');
      }
      if (weatherDays.isNotEmpty) insights.add('Météo : je l’utilise comme critère pour les activités extérieures ; ${weatherDays.take(4).join(' · ')}.');
    }
    for (final entry in activeProfiles.take(3)) {
      final activity = entry.key;
      final profile = entry.value;
      final learned = _learningSentence(activity);
      if (learned.isNotEmpty) insights.add(learned);
    }
    if (insights.isEmpty) {
      insights.add('Le coach continue l’apprentissage : les habitudes ne deviennent des signaux forts qu’après plusieurs réalisations.');
    }
    return insights.take(5).toList();
  }


}
