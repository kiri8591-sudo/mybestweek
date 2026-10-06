part of '../main.dart';

// V8.90 — Logique de génération du planning et du Coach
// Extraction architecturale : aucune logique métier modifiée.

extension _PlanningCoachPart on _MaBelleSemaineAppState {
  String _generationActivityRule(String activityId) => _generationActivityRules[activityId] ?? 'normal';

  bool get _applyNextWeekCoachDirections =>
      _nextWeekCoachDirections.isNotEmpty && _clockNow.weekday == DateTime.monday;

  int _generationNextWeekDirectionScore(Activity activity) {
    if (!_applyNextWeekCoachDirections) return 0;
    if (_isSportActivity(activity) || activity.isSportProgram || activity.isDateRange) return 0;
    final category = activity.category.trim().toLowerCase();
    final name = activity.name.trim().toLowerCase();
    var score = 0;
    if (_nextWeekCoachDirections.contains('outdoor') &&
        _isOutdoorPlanningActivity(activity)) {
      score += 4;
    }
    if (_nextWeekCoachDirections.contains('culture') &&
        (category == 'culture' ||
            name.contains('piano') ||
            name.contains('musique') ||
            name.contains('lecture') ||
            name.contains('livre'))) {
      score += 4;
    }
    if (_nextWeekCoachDirections.contains('social') && category == 'social') {
      score += 4;
    }
    if (_nextWeekCoachDirections.contains('wellness') &&
        (category == 'bien-être' ||
            name.contains('bien-être') ||
            name.contains('bien etre') ||
            name.contains('relax') ||
            name.contains('méditation') ||
            name.contains('meditation'))) {
      score += 4;
    }
    return score;
  }

  String _generationNextWeekDirectionLabel(Activity activity) {
    final labels = <String>[];
    if (_nextWeekCoachDirections.contains('outdoor') && _isOutdoorPlanningActivity(activity)) {
      labels.add('plein air');
    }
    final category = activity.category.trim().toLowerCase();
    final name = activity.name.trim().toLowerCase();
    if (_nextWeekCoachDirections.contains('culture') &&
        (category == 'culture' || name.contains('piano') || name.contains('musique') || name.contains('lecture') || name.contains('livre'))) {
      labels.add('musique / culture');
    }
    if (_nextWeekCoachDirections.contains('social') && category == 'social') {
      labels.add('vie sociale');
    }
    if (_nextWeekCoachDirections.contains('wellness') &&
        (category == 'bien-être' || name.contains('bien-être') || name.contains('bien etre') || name.contains('relax') || name.contains('méditation') || name.contains('meditation'))) {
      labels.add('bien-être');
    }
    return labels.isEmpty ? '' : labels.join(' · ');
  }

  int _effectiveGenerationFrequency(Activity activity) {
    final base = activity.frequency.clamp(1, 7).toInt();
    switch (_generationActivityRule(activity.id)) {
      case 'more':
        return min(7, base + 1);
      case 'less':
        return max(1, base - 1);
      default:
        return base;
    }
  }

  bool _generationShouldAvoid(Activity activity) => activity.isFrozen || _generationActivityRule(activity.id) == 'avoid';

  bool _isOutdoorPlanningActivity(Activity activity) {
    if (activity.category == 'Sortie') return true;
    final name = activity.name.trim().toLowerCase();
    const outdoorWords = [
      'marche', 'randonnée', 'randonnee', 'plein air', 'nature',
      'marché', 'marche ', 'promenade', 'balade', 'jardin', 'extérieur', 'exterieur',
    ];
    return outdoorWords.any(name.contains);
  }

  double _weatherPlanningScore(Activity activity, int day) {
    if (!_isOutdoorPlanningActivity(activity)) return 0;
    final weather = _weatherForWeekDay(day);
    if (weather == null) return 0;
    if (weather.outdoorBad) return -5.0;
    return 1.8;
  }

  String _weatherBrief(_DayWeather weather) {
    final temperature = weather.temperature.isEmpty ? '' : ' · ${weather.temperature}';
    return '${weather.icon} ${weather.text.toLowerCase()}$temperature';
  }

  String _weatherDecisionContext(Activity activity, int day) {
    if (!_isOutdoorPlanningActivity(activity)) return '';
    final weather = _weatherForWeekDay(day);
    if (weather == null) return '🌦️ Météo : prévision indisponible pour ${dayNames[day].toLowerCase()}.';
    final suitability = weather.outdoorBad
        ? 'conditions extérieures défavorables'
        : 'conditions extérieures favorables';
    return '🌦️ Météo prise en compte : ${_weatherBrief(weather)} ; $suitability.';
  }

  int _compareGenerationDays(
    Activity activity,
    int a,
    int b, {
    required List<PlanItem> preservedPastAndToday,
    required List<PlanItem> preservedFutureManual,
    required List<PlanItem> generated,
    required Set<int> usedDays,
    bool includeWeather = true,
  }) {
    if (_generationRespectPreferredDays) {
      final aPreferred = activity.preferredDays.contains(a) ? 0 : 1;
      final bPreferred = activity.preferredDays.contains(b) ? 0 : 1;
      if (aPreferred != bPreferred) return aPreferred.compareTo(bPreferred);
    }

    if (includeWeather && _isOutdoorPlanningActivity(activity)) {
      final weatherCompare = _weatherPlanningScore(activity, b).compareTo(_weatherPlanningScore(activity, a));
      if (weatherCompare != 0) return weatherCompare;
    }

    if (_generationAlternateActivities) {
      final aSameActivity = usedDays.contains(a) ? 1 : 0;
      final bSameActivity = usedDays.contains(b) ? 1 : 0;
      if (aSameActivity != bSameActivity) return aSameActivity.compareTo(bSameActivity);
    }

    if (_generationUseHistory) {
      // L’appelant passe ici les mêmes jours disponibles que pour la vraie
      // génération : on reproduit donc l’arbitrage exact, avec ou sans météo.
      final historyCompare = _historyPlanningScore(activity, b).compareTo(_historyPlanningScore(activity, a));
      if (historyCompare != 0) return historyCompare;
    }

    if (_generationBalanceLoad) {
      final loadCompare = _generationDayLoad(preservedPastAndToday, preservedFutureManual, generated, a)
          .compareTo(_generationDayLoad(preservedPastAndToday, preservedFutureManual, generated, b));
      if (loadCompare != 0) return loadCompare;
    }
    return a.compareTo(b);
  }

  // Retourne le facteur qui a réellement départagé le jour choisi et le
  // meilleur jour alternatif selon l'ordre exact du moteur de décision.
  // C'est volontairement le même ordre que _compareGenerationDays : le coach
  // n'annonce donc pas comme « décisif » un facteur qui n'a fait que peser
  // secondairement dans le calcul.
  String _generationDecisiveFactor(
    Activity activity,
    int day,
    List<int>? candidates, {
    Set<int>? excludedDays,
    List<PlanItem>? preservedPastAndToday,
    List<PlanItem>? preservedFutureManual,
    List<PlanItem>? generated,
  }) {
    if (candidates == null || candidates.length < 2) return '';
    final excluded = excludedDays ?? const <int>{};
    final available = candidates.where((d) => !excluded.contains(d)).toList();
    if (available.length < 2 || !available.contains(day)) return '';

    final alternative = available.firstWhere((d) => d != day, orElse: () => -1);
    if (alternative < 0) return '';

    final past = preservedPastAndToday ?? const <PlanItem>[];
    final manual = preservedFutureManual ?? const <PlanItem>[];
    final generatedItems = generated ?? const <PlanItem>[];

    // 1. Jours préférés : c'est le premier arbitre du moteur.
    if (_generationRespectPreferredDays) {
      final selectedPreferred = activity.preferredDays.contains(day);
      final alternativePreferred = activity.preferredDays.contains(alternative);
      if (selectedPreferred != alternativePreferred) {
        return selectedPreferred
            ? '🎯 Facteur décisif : ${dayNames[day]} est un de tes jours préférés, contrairement à ${dayNames[alternative].toLowerCase()}.'
            : '🎯 Facteur décisif : ${dayNames[alternative]} était un jour préféré plus adapté que ${dayNames[day].toLowerCase()}.';
      }
    }

    // 2. Météo : elle n'est annoncée décisive que lorsqu'elle atteint réellement
    // ce niveau de l'arbitrage ET que le meilleur choix global aurait été
    // différent sans la météo. Cela évite toute causalité artificielle liée à
    // une simple différence de score entre deux jours secondaires.
    if (_isOutdoorPlanningActivity(activity)) {
      final selectedWeatherScore = _weatherPlanningScore(activity, day);
      final alternativeWeatherScore = _weatherPlanningScore(activity, alternative);
      if (selectedWeatherScore != alternativeWeatherScore) {
        final withWeather = List<int>.from(available)
          ..sort((a, b) => _compareGenerationDays(
                activity, a, b,
                preservedPastAndToday: past,
                preservedFutureManual: manual,
                generated: generatedItems,
                usedDays: excluded,
                includeWeather: true,
              ));
        final withoutWeather = List<int>.from(available)
          ..sort((a, b) => _compareGenerationDays(
                activity, a, b,
                preservedPastAndToday: past,
                preservedFutureManual: manual,
                generated: generatedItems,
                usedDays: excluded,
                includeWeather: false,
              ));
        if (withWeather.isNotEmpty && withoutWeather.isNotEmpty &&
            withWeather.first == day && withoutWeather.first != day) {
          final selectedWeather = _weatherForWeekDay(day);
          final alternativeWeather = _weatherForWeekDay(withoutWeather.first);
          if (selectedWeather != null && alternativeWeather != null) {
            final contrast = selectedWeather.outdoorBad
                ? 'conditions moins défavorables'
                : alternativeWeather.outdoorBad
                    ? 'conditions plus favorables'
                    : 'conditions plus adaptées';
            return '🌦️ Météo décisive : sans la météo, j’aurais choisi ${dayNames[withoutWeather.first].toLowerCase()} ; j’ai retenu ${dayNames[day].toLowerCase()} pour des $contrast (${_weatherBrief(selectedWeather)} contre ${_weatherBrief(alternativeWeather)}).';
          }
        }
      }
    }

    // 3. Alternance : le moteur traite les jours déjà utilisés via usedDays.
    // Comme les candidats transmis ici sont déjà filtrés contre usedDays, ce
    // critère n'est généralement pas le premier facteur départageant deux jours.

    // 4. Historique et apprentissage.
    if (_generationUseHistory) {
      final selectedHistory = _historyPlanningScore(activity, day);
      final alternativeHistory = _historyPlanningScore(activity, alternative);
      if (selectedHistory != alternativeHistory) {
        final profile = _activityLearning(activity);
        if (_generationLearnHabits && profile.hasEnoughData) {
          final selectedShare = profile.dayShare(day);
          final alternativeShare = profile.dayShare(alternative);
          if (selectedShare > alternativeShare) {
            return '🧠 Facteur décisif : ton historique récent et les habitudes apprises favorisent ${dayNames[day].toLowerCase()} (${(selectedShare * 100).round()} % des réalisations contre ${(alternativeShare * 100).round()} %).' ;
          }
          if (alternativeShare > selectedShare) {
            return '🧠 Facteur décisif : malgré une fréquence historique plus forte le ${dayNames[alternative].toLowerCase()}, les autres signaux historiques actifs ont finalement départagé les jours en faveur de ${dayNames[day].toLowerCase()}.';
          }
        }
        return '🧠 Facteur décisif : l’historique récent et la fréquence restante favorisaient ${dayNames[day].toLowerCase()} plutôt que ${dayNames[alternative].toLowerCase()}.';
      }
    }

    // 5. Équilibre de charge.
    if (_generationBalanceLoad) {
      final selectedLoad = _generationDayLoad(past, manual, generatedItems, day);
      final alternativeLoad = _generationDayLoad(past, manual, generatedItems, alternative);
      if (selectedLoad != alternativeLoad) {
        return selectedLoad < alternativeLoad
            ? '⚖️ Facteur décisif : ${dayNames[day]} était moins chargé (${selectedLoad} min contre ${alternativeLoad} min prévus).'
            : '⚖️ Facteur décisif : la charge déjà prévue rendait ${dayNames[day].toLowerCase()} plus adaptée après arbitrage global.';
      }
    }

    return '↔️ Facteur décisif : les critères actifs étaient à égalité ; j’ai conservé l’ordre des jours disponibles.';
  }

  String _weatherInfluenceReason(
    Activity activity,
    int day,
    List<int>? candidates, {
    Set<int>? excludedDays,
    List<PlanItem>? preservedPastAndToday,
    List<PlanItem>? preservedFutureManual,
    List<PlanItem>? generated,
  }) {
    final factor = _generationDecisiveFactor(
      activity,
      day,
      candidates,
      excludedDays: excludedDays,
      preservedPastAndToday: preservedPastAndToday,
      preservedFutureManual: preservedFutureManual,
      generated: generated,
    );
    return factor.startsWith('🌦️') ? factor : '';
  }

  String _weatherAvailableButNotDecisiveSummary(List<PlanItem> generated) {
    if (_weatherForecast.isEmpty) return '';
    final influenced = generated.where((item) => item.details?.contains('🌦️ Météo décisive') ?? false).length;
    if (influenced > 0) {
      return '🌦️ La météo a réellement modifié $influenced choix${influenced > 1 ? ' futurs' : ' futur'} ; les choix concernés indiquent précisément lesquels et pourquoi.';
    }
    return '🌦️ J’avais les prévisions météo, mais elles n’ont finalement modifié aucun choix du planning futur.';
  }

  String _generationActivityRuleLabel(String rule) {
    switch (rule) {
      case 'prioritize': return 'Prioritaire';
      case 'avoid': return 'À éviter';
      case 'less': return 'Moins de';
      case 'more': return 'Plus de';
      default: return 'Normal';
    }
  }

  String _generationActivityRulesSummary() {
    final entries = _generationActivityRules.entries.where((e) => e.value != 'normal').toList();
    if (entries.isEmpty) return '';
    final labels = <String>[];
    for (final entry in entries) {
      final activity = findActivity(entry.key);
      if (activity == null) continue;
      labels.add('${activity.name} · ${_generationActivityRuleLabel(entry.value).toLowerCase()}');
    }
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]} ; ${labels[1]}';
    return '${labels.take(3).join(' ; ')}${labels.length > 3 ? ' ; +${labels.length - 3}' : ''}';
  }

  String _regeneratedDaysMessage() {
    // Après une réinitialisation complète, toute la semaine a été reconstruite :
    // les jours passés de la semaine courante peuvent donc être annoncés.
    // Dans une régénération normale, seuls les jours strictement futurs le sont.
    final currentDay = today;
    final days = (_lastPlanningWasFullWeek
            ? _lastPlanningRegeneratedDays.where((d) => d >= 0 && d < 7)
            : _lastPlanningRegeneratedDays.where((d) => d >= 0 && d < 7 && d > currentDay))
        .toList();
    if (days.isEmpty) return '';
    final names = days.map((d) => dayNames[d]).toList();
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} et ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')} et ${names.last}';
  }

  String _generationCriteriaSummary() {
    final labels = <String>[];
    if (_generationRespectPriorities) labels.add('priorités');
    if (_generationUseHistory) labels.add('historique');
    if (_generationBalanceLoad) labels.add('équilibre');
    if (_generationRespectPreferredDays) labels.add('jours préférés');
    if (_generationAlternateActivities) labels.add('alternance');
    if (_generationLearnHabits) labels.add('mes habitudes');
    final hasWeather = _weatherForecast.isNotEmpty;
    if (hasWeather) labels.add('météo extérieure');
    if (labels.isEmpty) return 'les critères essentiels';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]} et ${labels[1]}';
    return '${labels.sublist(0, labels.length - 1).join(', ')} et ${labels.last}';
  }

  int _currentWeekRealisedCount(Activity activity) {
    final start = _startOfCurrentWeek();
    final end = start.add(const Duration(days: 7));
    return logs.where((log) =>
        !log.date.isBefore(start) &&
        log.date.isBefore(end) &&
        _logMatchesActivity(log, activity)).length;
  }
  int _currentWeekRealisedDaysCount(Activity activity) {
    final start = _startOfCurrentWeek();
    final end = start.add(const Duration(days: 7));
    final keys = <String>{};
    for (final log in logs) {
      if (log.date.isBefore(start) || !log.date.isBefore(end) || !_logMatchesActivity(log, activity)) continue;
      keys.add('${log.date.year}-${log.date.month}-${log.date.day}');
    }
    return keys.length;
  }

  int _preservedFutureDaysCount(Activity activity, List<PlanItem> preservedFutureManual) {
    return preservedFutureManual
        .where((item) => item.activityId == activity.id)
        .map((item) => item.day)
        .toSet()
        .length;
  }

  int _preservedFutureCount(Activity activity, List<PlanItem> preservedFutureManual) {
    return preservedFutureManual.where((item) => item.activityId == activity.id).length;
  }

  int _generationWeeklyTarget(Activity activity) => _effectiveGenerationFrequency(activity);

  int _generationRemainingOccurrences(Activity activity, List<PlanItem> preservedFutureManual) {
    final target = _generationWeeklyTarget(activity);
    final alreadyRealised = _currentWeekRealisedCount(activity);
    final alreadyProtected = _preservedFutureCount(activity, preservedFutureManual);
    return max(0, target - alreadyRealised - alreadyProtected);
  }

  String _generationPeriodForOccurrence(Activity activity, int day, int occurrence, int total, String primary) {
    if (total <= 1) return primary;
    const spread = ['Matin', 'Après-midi', 'Soir'];
    if (total == 2) {
      if (primary == 'Matin') return occurrence == 0 ? 'Matin' : 'Soir';
      if (primary == 'Soir') return occurrence == 0 ? 'Matin' : 'Soir';
      return occurrence == 0 ? 'Après-midi' : 'Soir';
    }
    return spread[occurrence.clamp(0, 2)];
  }

  int _learnedDurationForGeneration(Activity activity) {
    final base = max(5, activity.duration);
    if (!_generationLearnHabits) return base;
    final profile = _activityLearning(activity);
    if (!profile.hasEnoughData || profile.averageRealisedMinutes <= 0 || profile.averagePlannedMinutes <= 0) return base;
    if (profile.durationGapRatio < .20) return base;
    final learned = (profile.averageRealisedMinutes / 5).round() * 5;
    // Le coach apprend la durée réellement vécue, mais reste volontairement
    // proche de la durée de référence de la fiche pour éviter un emballement
    // après quelques séances atypiques.
    return learned.clamp(5, max(5, base + 15)).toInt();
  }

  int _sportGenerationDuration(Activity activity) =>
      _isSportActivity(activity) ? _learnedDurationForGeneration(activity) : max(5, activity.duration);

  int _generationDayLoad(List<PlanItem> preservedPastAndToday, List<PlanItem> preservedFutureManual,
      List<PlanItem> generated, int day) {
    return preservedPastAndToday.where((p) => p.day == day).fold<int>(0, (sum, p) => sum + p.duration) +
        preservedFutureManual.where((p) => p.day == day).fold<int>(0, (sum, p) => sum + p.duration) +
        generated.where((p) => p.day == day).fold<int>(0, (sum, p) => sum + p.duration);
  }

  String _generationDecisionReason(Activity activity, int day, int target, int alreadyRealised,
      List<PlanItem> preservedPastAndToday, List<PlanItem> preservedFutureManual, List<PlanItem> generated,
      {int? selectedDuration, List<int>? candidates, Set<int>? excludedDaysForDecision}) {
    final reasons = <String>[];
    final decisiveFactor = _generationDecisiveFactor(
      activity,
      day,
      candidates,
      excludedDays: excludedDaysForDecision,
      preservedPastAndToday: preservedPastAndToday,
      preservedFutureManual: preservedFutureManual,
      generated: generated,
    );
    final rule = _generationActivityRule(activity.id);
    if (rule == 'prioritize') reasons.add('consigne « Prioritaire »');
    if (rule == 'more') reasons.add('consigne « Plus de »');
    if (rule == 'less') reasons.add('consigne « Moins de »');
    if (_generationRespectPriorities && activity.priority >= 4) reasons.add('priorité ${activity.priority}/5');
    final directionLabel = _generationNextWeekDirectionLabel(activity);
    if (directionLabel.isNotEmpty) reasons.add('direction du Coach : $directionLabel');
    if (_generationRespectPreferredDays && activity.preferredDays.contains(day)) {
      reasons.add('${dayNames[day]} fait partie de tes jours préférés');
    }
    if (decisiveFactor.isNotEmpty) reasons.insert(0, decisiveFactor);

    final profile = _activityLearning(activity);
    if (_generationLearnHabits && profile.hasEnoughData) {
      if (profile.bestDay == day && profile.bestDayShare >= .55) {
        reasons.add('c’est le jour où tu la réalises le plus souvent');
      }
      if (profile.bestPeriod != null && profile.periodShare(profile.bestPeriod!) >= .60) {
        reasons.add('le coach a appris que tu la fais surtout ${profile.bestPeriod!.toLowerCase()}');
      }
      if (profile.movedToCount >= 2 && profile.bestMovedToDay == day && profile.bestMovedToDayShare >= .50) {
        reasons.add('tu la déplaces souvent vers ${dayNames[day].toLowerCase()}');
      }
      if (profile.difficultRate >= .50 && profile.difficultCount >= 2) {
        reasons.add('tes derniers ressentis invitent à ne pas la concentrer davantage');
      }
      final learnedDuration = _learnedDurationForGeneration(activity);
      if (learnedDuration != activity.duration && profile.averageRealisedMinutes > 0) {
        reasons.add('🕒 durée ajustée : environ ${profile.averageRealisedMinutes.round()} min réellement vécues, donc $learnedDuration min planifiées');
      }
    }

    if (_generationUseHistory) {
      final matches = logs.where((l) => _logMatchesActivity(l, activity)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (matches.isNotEmpty) {
        final since = DateTime.now().difference(matches.first.date).inDays;
        if (since >= 7) reasons.add('elle n’a pas été réalisée depuis $since jours');
        final alreadyPlannedDaysByCoach = generated
            .where((p) => p.activityId == activity.id)
            .map((p) => p.day)
            .toSet()
            .length;
        final protectedDays = preservedFutureManual
            .where((p) => p.activityId == activity.id)
            .map((p) => p.day)
            .toSet()
            .length;
        final remainingAfterChoice = max(0, target - alreadyRealised - protectedDays - alreadyPlannedDaysByCoach - 1);
        reasons.add(remainingAfterChoice > 0
            ? 'cette journée couvre une partie de la fréquence restante ; il restera $remainingAfterChoice journée(s)'
            : 'cette journée couvre la dernière journée nécessaire cette semaine');
      } else {
        reasons.add('aucune réalisation récente : le coach lui redonne une place');
      }
    } else if (alreadyRealised < target) {
      reasons.add('il reste ${target - alreadyRealised} réalisation(s) à couvrir cette semaine');
    }

    if (_generationBalanceLoad) {
      final selectedLoad = _generationDayLoad(preservedPastAndToday, preservedFutureManual, generated, day);
      final futureDays = List<int>.generate(7 - (today + 1), (i) => today + 1 + i);
      if (futureDays.isNotEmpty) {
        final loads = futureDays.map((d) => _generationDayLoad(preservedPastAndToday, preservedFutureManual, generated, d)).toList();
        final minLoad = loads.reduce(min);
        if (selectedLoad <= minLoad) reasons.add('la charge prévue est parmi les plus légères');
      }
    }


    if (reasons.isEmpty) reasons.add('arbitrage entre fréquence, historique et place disponible');
    // Une influence météo ne doit jamais être perdue à cause de la limite
    // d'affichage des raisons : lorsqu'elle est réelle, elle est toujours
    // affichée en premier, puis complétée par trois autres raisons.
    final selectedReasons = <String>[];
    if (decisiveFactor.isNotEmpty) selectedReasons.add(decisiveFactor);
    selectedReasons.addAll(
      reasons.where((reason) => reason != decisiveFactor).take(3),
    );
    final selected = selectedReasons.join(' · ');
    final weatherContext = _weatherDecisionContext(activity, day);
    final fullReason = weatherContext.isEmpty ? selected : '$selected · $weatherContext';
    final duration = selectedDuration ?? _learnedDurationForGeneration(activity);
    return '${dayNames[day]} · ${_generationPeriod(activity, day)} · ${activity.name} (${duration} min) — $fullReason.';
  }

  String _sportDecisionReason(Activity activity, int day, int budget, Set<String> selectedIds) {
    final reasons = <String>[];
    final profile = _activityLearning(activity);
    if (_generationRespectPriorities && activity.priority >= 4) reasons.add('priorité ${activity.priority}/5');
    if (_generationRespectPreferredDays && activity.preferredDays.contains(day)) reasons.add('jour préféré');
    if (_generationUseHistory) {
      final matches = logs.where((l) => _logMatchesActivity(l, activity)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (matches.isEmpty) reasons.add('peu/pas de réalisation récente');
      else {
        final since = DateTime.now().difference(matches.first.date).inDays;
        if (since >= 7) reasons.add('$since jours depuis la dernière réalisation');
      }
    }
    if (_generationLearnHabits && profile.hasEnoughData) {
      if (profile.bestDay == day && profile.bestDayShare >= .55) reasons.add('jour habituel appris');
      if (profile.movedToCount >= 2 && profile.bestMovedToDay == day && profile.bestMovedToDayShare >= .50) reasons.add('souvent déplacée vers ce jour');
      if (profile.durationGapRatio >= .20) reasons.add('durée ajustée selon tes réalisations réelles');
    }
    if (selectedIds.length > 1 && selectedIds.any((id) => id != activity.id)) reasons.add('complète la séance sans dépasser le budget');
    if (reasons.isEmpty) reasons.add('rotation et équilibre du jour');
    final manualRemovedCount = _manualRemovalCount(activity.id, day);
    if (manualRemovedCount > 0) reasons.insert(0, '✋ $manualRemovedCount occurrence(s) Sport retirée(s) manuellement ce jour');
    final manualAddedCount = plan.where((p) => p.day == day && p.activityId == activity.id && p.manualPlacement).length;
    if (manualAddedCount > 0) reasons.insert(0, '👤 choix manuel conservé : $manualAddedCount occurrence(s)');
    final acceptedOverrun = _acceptedSportOverrunForDay(day);
    if (acceptedOverrun > 0) reasons.insert(0, '⚖️ budget Sport dépassé de $acceptedOverrun min, choix manuel pris en compte');
    final weatherContext = _weatherDecisionContext(activity, day);
    final reasonText = reasons.take(3).join(' · ');
    final fullReason = weatherContext.isEmpty ? reasonText : '$reasonText · $weatherContext';
    final duration = _sportGenerationDuration(activity);
    return '${dayNames[day]} · Sport : ${activity.name} · $duration min — $fullReason.';
  }

  String _generatedPlanSignature(Iterable<PlanItem> items) {
    final values = items.map((p) => '${p.activityId ?? p.title}|${p.day}|${p.period}|${p.duration}').toList()..sort();
    return values.join('§');
  }

  void openPlanningCoachDecisions() {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .76,
        minChildSize: .48,
        maxChildSize: .94,
        builder: (_, controller) => SafeArea(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Row(children: [
                mascotAvatarInline(size: 38),
                const SizedBox(width: 10),
                Expanded(child: Text('Pourquoi ces choix ?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 8),
              Text(_lastPlanningCoachExplanation.isEmpty
                  ? 'Je n’ai pas encore de décision récente à expliquer. Dès la prochaine génération, je détaillerai mes arbitrages.'
                  : _lastPlanningCoachExplanation,
                  style: const TextStyle(fontSize: AppType.body, height: 1.35)),
              const SizedBox(height: 14),
              if (_lastPlanningDecisionDetails.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Aucun détail de décision disponible pour le moment.')))
              else
                ..._lastPlanningDecisionDetails.take(18).map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Card(
                    color: _colors.surfaceSoft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _uiIcon('coach', Icons.arrow_forward_rounded, size: 17, color: _colors.accentIcon),
                        const SizedBox(width: 7),
                        Expanded(child: Text(detail, style: const TextStyle(fontSize: AppType.label, height: 1.3))),
                      ]),
                    ),
                  ),
                )),
              const SizedBox(height: 6),
              Text('Le premier motif affiché est le facteur réellement décisif dans l’ordre des arbitrages. Une météo simplement consultée, une habitude secondaire ou un signal faible ne sont pas présentés comme cause principale. Le passé et aujourd’hui ne sont jamais réécrits par « Repenser ».',
                  style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.3)),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => Navigator.pop(context), icon: _uiIcon('confirm', Icons.check, size: 18, color: _colors.accentIcon), label: const Text('Fermer')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openGenerationCriteria() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var priorities = _generationRespectPriorities;
        var history = _generationUseHistory;
        var balance = _generationBalanceLoad;
        var preferred = _generationRespectPreferredDays;
        var alternate = _generationAlternateActivities;
        var learnHabits = _generationLearnHabits;
        // Après une réinitialisation complète, la règle « reconstruire toute
        // la semaine » doit être réellement appliquée par défaut. Avant ce
        // correctif, false écrasait ici le drapeau posé par le reset.
        final rebuildLockedAfterReset = _regenerateWholeWeekAfterReset;
        var rebuildWholeWeek = rebuildLockedAfterReset;
        final localRules = <String, String>{..._generationActivityRules};
        final ordered = [...activities]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        Widget criterion({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
          return SwitchListTile.adaptive(
            value: value,
            onChanged: onChanged,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: AppType.label)),
            contentPadding: EdgeInsets.zero,
          );
        }

        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 22 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Générer le planning', style: TextStyle(fontSize: AppType.h1, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Par défaut, les jours passés et aujourd’hui sont conservés. Tu peux aussi choisir de reconstruire toute la semaine.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted, height: 1.35)),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: rebuildWholeWeek,
                  onChanged: rebuildLockedAfterReset ? null : (v) => setSheetState(() => rebuildWholeWeek = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reconstruire toute la semaine', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    rebuildLockedAfterReset
                        ? 'Après une réinitialisation, cette première génération reconstruit obligatoirement lundi → dimanche. L’historique ayant été remis à zéro reste vide.'
                        : rebuildWholeWeek
                            ? 'Lundi → dimanche seront recréés. Le planning actuel de la semaine sera remplacé ; l’historique des réalisations reste conservé.'
                        : 'Les jours passés et aujourd’hui restent inchangés ; seuls les jours futurs sont repensés.',
                    style: const TextStyle(fontSize: AppType.label, height: 1.3),
                  ),
                ),
                const SizedBox(height: 8),
                criterion(
                  title: 'Priorités',
                  subtitle: 'Faire remonter les activités importantes.',
                  value: priorities,
                  onChanged: (v) {
                    setSheetState(() => priorities = v);
                    _generationRespectPriorities = v;
                    _queueLocalStatePersist();
                  },
                ),
                criterion(
                  title: 'Historique',
                  subtitle: 'Tenir compte de ce qui a été fait récemment et des ressentis.',
                  value: history,
                  onChanged: (v) {
                    setSheetState(() => history = v);
                    _generationUseHistory = v;
                    _queueLocalStatePersist();
                  },
                ),
                criterion(
                  title: 'Équilibre de la charge',
                  subtitle: 'Éviter de concentrer trop de minutes sur une même journée.',
                  value: balance,
                  onChanged: (v) {
                    setSheetState(() => balance = v);
                    _generationBalanceLoad = v;
                    _queueLocalStatePersist();
                  },
                ),
                criterion(
                  title: 'Jours préférés',
                  subtitle: 'Favoriser les jours choisis dans les fiches activités.',
                  value: preferred,
                  onChanged: (v) {
                    setSheetState(() => preferred = v);
                    _generationRespectPreferredDays = v;
                    _queueLocalStatePersist();
                  },
                ),
                criterion(
                  title: 'Alternance',
                  subtitle: 'Éviter de répéter inutilement la même activité.',
                  value: alternate,
                  onChanged: (v) {
                    setSheetState(() => alternate = v);
                    _generationAlternateActivities = v;
                    _queueLocalStatePersist();
                  },
                ),
                criterion(
                  title: 'Apprendre mes habitudes',
                  subtitle: 'Utiliser les jours et moments où tu réalises réellement tes activités.',
                  value: learnHabits,
                  onChanged: (v) {
                    setSheetState(() => learnHabits = v);
                    _generationLearnHabits = v;
                    _queueLocalStatePersist();
                  },
                ),
                const SizedBox(height: 10),
                const Text('Consignes par activité', style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Tu peux demander une activité prioritaire, à éviter, moins souvent ou plus souvent.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
                const SizedBox(height: 8),
                ...ordered.map((activity) {
                  final currentRule = localRules[activity.id] ?? 'normal';
                  final options = const <String>['normal', 'prioritize', 'avoid', 'less', 'more'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
                    decoration: BoxDecoration(
                      color: _colors.card,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(color: _colors.border),
                    ),
                    child: Row(children: [
                      _activityIconWidget(activity.emoji, size: 25),
                      const SizedBox(width: 7),
                      Expanded(child: Text(activity.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.body, color: _colors.textStrong))),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentRule,
                          isDense: true,
                          items: options.map((rule) => DropdownMenuItem<String>(value: rule, child: Text(_generationActivityRuleLabel(rule), style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)))).toList(),
                          onChanged: (value) {
                            // Une consigne par activité est une préférence durable.
                            // Elle est donc appliquée immédiatement à l'état principal
                            // et persistée sans attendre le bouton de génération.
                            setSheetState(() {
                              if (value == null || value == 'normal') {
                                localRules.remove(activity.id);
                              } else {
                                localRules[activity.id] = value;
                              }
                            });
                            if (value == null || value == 'normal') {
                              _generationActivityRules.remove(activity.id);
                            } else {
                              _generationActivityRules[activity.id] = value;
                            }
                            _queueLocalStatePersist();
                          },
                        ),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 6),
                Text('La fréquence de base reste la règle de référence : « Plus de » ajoute une occurrence future au maximum, « Moins de » en retire une, sans modifier le passé.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.3)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, {
                      'priorities': priorities,
                      'history': history,
                      'balance': balance,
                      'preferred': preferred,
                      'alternate': alternate,
                      'learnHabits': learnHabits,
                      'activityRules': localRules,
                      'rebuildWholeWeek': rebuildWholeWeek,
                    }),
                    icon: _uiIcon('coach', Icons.auto_awesome_outlined, size: 18, color: _colors.goldText),
                    label: Text(rebuildWholeWeek ? 'Reconstruire la semaine' : 'Générer le planning futur'),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _generationRespectPriorities = result['priorities'] ?? true;
      _generationUseHistory = result['history'] ?? true;
      _generationBalanceLoad = result['balance'] ?? true;
      _generationRespectPreferredDays = result['preferred'] ?? true;
      _generationAlternateActivities = result['alternate'] ?? true;
      _generationLearnHabits = result['learnHabits'] ?? true;
      _generationActivityRules
        ..clear()
        ..addAll(Map<String, String>.from((result['activityRules'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {}));
    });
    _queueLocalStatePersist();
    generateWeek(
      showSnack: true,
      markAsRegenerated: true,
      fullWeekRebuildOverride: _regenerateWholeWeekAfterReset ? true : result['rebuildWholeWeek'] == true,
    );
  }

  bool get _showMondayRegenerationPrompt {
    final now = DateTime.now();
    return now.weekday == DateTime.monday && now.hour < 12 &&
        !_mondayRegenPromptDismissed &&
        _lastPlanningRegeneratedWeekKey != _currentWeekKey();
  }

  void _dismissMondayRegenerationPrompt() {
    if (!mounted) return;
    setState(() => _mondayRegenPromptDismissed = true);
  }

  void generateWeek({
    bool showSnack = true,
    bool markAsRegenerated = false,
    bool? fullWeekRebuildOverride,
  }) {
    // En usage normal, « Repenser » protège le passé et aujourd'hui.
    // Exception : juste après une réinitialisation complète, le planning est
    // volontairement vide ; la première régénération doit alors reconstruire
    // toute la semaine à partir du lundi.
    final fullWeekRebuild = fullWeekRebuildOverride ?? _regenerateWholeWeekAfterReset;
    final cutoffDay = fullWeekRebuild ? -1 : today;
    _regeneratedSportBudgets.removeWhere((day, _) => day > cutoffDay);
    final preservedPastAndToday = plan.where((p) => p.day <= cutoffDay).toList();

    // Les éléments explicitement placés/manuels des jours futurs sont conservés
    // en génération normale. Après réinitialisation, le planning étant vierge,
    // rien n'est à protéger.
    final preservedFutureManual = fullWeekRebuild
        ? <PlanItem>[]
        : plan.where((p) =>
            p.day > cutoffDay &&
            (p.activityId == null || p.manualPlacement || p.fixedInWeeklyTemplate)).toList();

    // On garde une empreinte du planning automatique précédent afin que le
    // coach puisse dire explicitement lorsqu'une génération n'a rien changé.
    final previousGeneratedFuture = plan.where((p) =>
        p.day > cutoffDay &&
        !(p.activityId == null || p.manualPlacement || p.fixedInWeeklyTemplate)).toList();
    final previousGeneratedSignature = _generatedPlanSignature(previousGeneratedFuture);

    final generated = <PlanItem>[];
    final decisionDetails = <String>[];
    var seq = 0;

    // Une décision négative doit elle aussi être explicable : « À éviter »
    // signifie réellement qu'aucune nouvelle occurrence ne sera créée.
    for (final activity in activities.where((a) => _generationActivityRule(a.id) == 'avoid')) {
      if (decisionDetails.length >= 30) break;
      decisionDetails.add('${activity.name} — non planifiée : consigne « À éviter » active pour les jours futurs.');
    }

    // 1) Sport : uniquement les occurrences futures.
    _generateSportPart(
      generated,
      seq,
      startDay: cutoffDay + 1,
      decisionDetails: decisionDetails,
    );
    seq = generated.length;

    // 2) Activités ordinaires : le coach cherche ce qu'il reste réellement à
    // couvrir cette semaine avant de créer de nouvelles occurrences.
    final normalActivities = activities
        .where((a) => !_isSportActivity(a) && !a.isSportProgram && !_generationShouldAvoid(a))
        .toList();
    final usedByActivity = <String, Set<int>>{
      for (final a in normalActivities) a.id: <int>{},
    };
    final occurrencesByActivityDay = <String, Map<int, int>>{
      for (final a in normalActivities) a.id: <int, int>{},
    };

    final orderedActivities = [...normalActivities]
      ..sort((a, b) {
        final ar = _generationActivityRule(a.id);
        final br = _generationActivityRule(b.id);
        if (ar != br) {
          const rank = {'prioritize': 0, 'more': 1, 'normal': 2, 'less': 3, 'avoid': 4};
          final cmp = (rank[ar] ?? 2).compareTo(rank[br] ?? 2);
          if (cmp != 0) return cmp;
        }
        if (_generationRespectPriorities) {
          final priorityCompare = b.priority.compareTo(a.priority);
          if (priorityCompare != 0) return priorityCompare;
        }
        final directionCompare = _generationNextWeekDirectionScore(b).compareTo(_generationNextWeekDirectionScore(a));
        if (directionCompare != 0) return directionCompare;
        if (_generationUseHistory) {
          final historyCompare = _historyPlanningScore(b, today).compareTo(_historyPlanningScore(a, today));
          if (historyCompare != 0) return historyCompare;
        }
        return b.frequency.compareTo(a.frequency);
      });

    for (final activity in orderedActivities) {
      final futureDays = List<int>.generate(7 - (cutoffDay + 1), (i) => cutoffDay + 1 + i);
      if (futureDays.isEmpty) break;

      if (activity.isDateRange) {
        final rangeDays = _dateRangeDaysForCurrentWeek(activity).where((day) => day > cutoffDay);
        for (final day in rangeDays) {
          generated.add(PlanItem(
            id: 'range_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_$seq',
            day: day,
            period: _generationPeriod(activity, day),
            timeLabel: null,
            activityId: activity.id,
            title: activity.name,
            details: 'Activité quotidienne · ${_dateRangeLabel(activity)} · inscrite car la période est active.',
            duration: activity.duration,
            optional: false,
            userAdded: true,
            fixedInWeeklyTemplate: false,
          ));
          if (decisionDetails.length < 30) {
            decisionDetails.add('${dayNames[day]} · ${activity.name} — période active : je la place automatiquement ce jour, sans compter cette activité comme une séance répétitive.');
          }
          seq++;
        }
        continue;
      }

      final alreadyRealisedDays = _currentWeekRealisedDaysCount(activity);
      final protectedFutureDays = _preservedFutureDaysCount(activity, preservedFutureManual);
      final targetDays = _generationWeeklyTarget(activity);
      final remainingDays = max(0, targetDays - alreadyRealisedDays - protectedFutureDays);

      if (remainingDays <= 0) {
        if (decisionDetails.length < 30 &&
            (_generationActivityRule(activity.id) != 'normal' || activity.priority >= 4 || alreadyRealisedDays > 0)) {
          final protectedText = protectedFutureDays > 0 ? ' et $protectedFutureDays déjà prévue(s) et protégée(s)' : '';
          decisionDetails.add('${activity.name} — pas de nouvelle journée : $alreadyRealisedDays/$targetDays journée(s) déjà couverte(s) cette semaine$protectedText.');
        }
        continue;
      }

      var generatedDaysForActivity = 0;
      final usedDays = usedByActivity[activity.id]!;
      final counts = occurrencesByActivityDay[activity.id]!;

      for (var dayIndex = 0; dayIndex < remainingDays; dayIndex++) {
        final availableDays = futureDays.where((day) =>
            !usedDays.contains(day) && !_manualDayBlocked(activity, day)).toList();
        if (availableDays.isEmpty) break;

        final candidates = List<int>.from(availableDays)
          ..sort((a, b) => _compareGenerationDays(
            activity,
            a,
            b,
            preservedPastAndToday: preservedPastAndToday,
            preservedFutureManual: preservedFutureManual,
            generated: generated,
            usedDays: usedDays,
            includeWeather: true,
          ));

        final chosenDay = candidates.first;
        final period = _generationPeriod(activity, chosenDay);
        final configuredDailyLimit = activity.allowMultiplePerDay
            ? activity.maxDailyOccurrences.clamp(2, 3).toInt()
            : 1;
        final dailyLimit = max(0, configuredDailyLimit - _manualRemovalCount(activity.id, chosenDay));
        if (dailyLimit <= 0) continue;
        final generationDuration = _learnedDurationForGeneration(activity);
        final decisionReason = _generationDecisionReason(
          activity,
          chosenDay,
          targetDays,
          alreadyRealisedDays,
          preservedPastAndToday,
          preservedFutureManual,
          generated,
          selectedDuration: generationDuration,
          candidates: candidates,
          excludedDaysForDecision: const <int>{},
        );

        for (var occurrence = 0; occurrence < dailyLimit; occurrence++) {
          final occurrencePeriod = _generationPeriodForOccurrence(activity, chosenDay, occurrence, dailyLimit, period);
          final repeatExplanation = occurrence == 0
              ? decisionReason
              : '$decisionReason · ${occurrence + 1}e réalisation le même jour, autorisée par ta fiche.';
          generated.add(PlanItem(
            id: 'gen_${DateTime.now().microsecondsSinceEpoch}_$seq',
            day: chosenDay,
            period: occurrencePeriod,
            timeLabel: null,
            activityId: activity.id,
            title: activity.name,
            details: 'Coach : $repeatExplanation',
            duration: generationDuration,
            optional: false,
            userAdded: false,
            fixedInWeeklyTemplate: false,
          ));
          decisionDetails.add(repeatExplanation);
          seq++;
        }

        usedDays.add(chosenDay);
        counts[chosenDay] = dailyLimit;
        generatedDaysForActivity++;
      }

      if (generatedDaysForActivity < remainingDays && decisionDetails.length < 30) {
        final left = remainingDays - generatedDaysForActivity;
        final limitText = activity.allowMultiplePerDay
            ? 'après application de la limite de ${activity.maxDailyOccurrences.clamp(2, 3)} réalisation(s) par jour'
            : 'car une seule réalisation par jour est autorisée';
        decisionDetails.add('${activity.name} — $left journée(s) n’ont pas été ajoutée(s) : il ne reste plus assez de jours futurs $limitText.');
      }
    }

    final newGeneratedSignature = _generatedPlanSignature(generated);
    final noChange = previousGeneratedSignature == newGeneratedSignature;
    final planningCoachExplanation = _buildPlanningCoachExplanation(
      generated,
      noChange: noChange,
      preservedFutureManual: preservedFutureManual.length,
      fullWeekRebuild: fullWeekRebuild,
    );

    setState(() {
      if (markAsRegenerated) {
        _lastPlanningWasFullWeek = fullWeekRebuild;
        _regenerateWholeWeekAfterReset = false;
        _lastPlanningRegeneratedWeekKey = _currentWeekKey();
        _lastPlanningRegeneratedDays = List<int>.generate(
          max(0, 7 - (cutoffDay + 1)),
          (i) => cutoffDay + 1 + i,
        );
        _lastPlanningRegeneratedAt = DateTime.now();
        _planningReportReadAt = null;
        _lastPlanningCoachExplanation = planningCoachExplanation;
        final savedDetails = decisionDetails.take(30).toList();
        if (savedDetails.isEmpty) {
          savedDetails.add(noChange
              ? 'Aucun changement : les contraintes actives ne nécessitaient pas de déplacer ou de recréer les occurrences futures.'
              : 'Aucune nouvelle occurrence n’a pu être ajoutée avec les critères actuels.');
        }
        _lastPlanningDecisionDetails = savedDetails;
        _mondayRegenPromptDismissed = true;
        if (_applyNextWeekCoachDirections) {
          _nextWeekCoachDirections.clear();
        }
      }
      plan
        ..removeWhere((p) => p.day > cutoffDay && !(p.activityId == null || p.manualPlacement || p.fixedInWeeklyTemplate))
        ..addAll(generated)
        ..sort((a, b) {
          final dayCompare = a.day.compareTo(b.day);
          if (dayCompare != 0) return dayCompare;
          const order = {'Matin': 0, 'Après-midi': 1, 'Midi': 1, 'Soir': 2};
          final periodCompare = (order[a.period] ?? 9).compareTo(order[b.period] ?? 9);
          if (periodCompare != 0) return periodCompare;
          return a.id.compareTo(b.id);
        });
      for (final day in _sportDays().where((d) => d > cutoffDay)) {
        _ensureSportMultipleOccurrencesForDay(day);
      }
      _sortPlan();
    });

    // Une priorité du jour doit rester visible dans la journée même après
    // une régénération. Cela ne crée aucune occurrence sur les autres jours.
    _ensureDailyPrioritiesInTodayPlan();
    _queueLocalStatePersist();
    if (showSnack && mounted) {
      final futureDaysCount = max(0, 6 - cutoffDay);
      final sportFutureDays = <int>{
        ..._sportDays().where((d) => d > cutoffDay),
        ..._regeneratedSportBudgets.keys.where((d) => d > cutoffDay),
        ...plan.where((p) => p.day > cutoffDay && _isSportPlanItem(p)).map((p) => p.day),
      }.toList()..sort();
      final sportDays = sportFutureDays.length;
      final totalSportMinutes = sportFutureDays.fold<int>(0, (sum, day) => sum + _sportBudgetForDay(day));
      final criteria = _generationCriteriaSummary();
      final activityRules = _generationActivityRulesSummary();
      final ruleMessage = activityRules.isEmpty ? '' : ' Consignes : $activityRules.';
      final sportMessage = sportDays == 0 ? '' : ' Sport : $sportDays jour(s) futur(s) · $totalSportMinutes min.';
      final decisionMessage = noChange ? ' Aucun changement automatique n’était nécessaire.' : '';
      final snack = fullWeekRebuild
          ? 'Planning de la semaine reconstruit (7 jours) selon $criteria.$ruleMessage$sportMessage$decisionMessage'
          : 'Planning futur repensé ($futureDaysCount jour(s)) selon $criteria.$ruleMessage$sportMessage$decisionMessage';
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(snack)),
      );
    }
  }

  List<PlanItem> _defaultWeek() => _defaultWeekFor(activities);

  List<PlanItem> _defaultWeekFor(List<Activity> sourceActivities) {
    final activityById = <String, Activity>{
      for (final activity in sourceActivities) activity.id: activity,
    };
    var n = 0;

    PlanItem activityBlock({
      required int day,
      required String period,
      required String activityId,
      required String title,
      String? timeLabel,
      String? details,
      int? duration,
      bool optional = false,
    }) {
      final a = activityById[activityId];
      return PlanItem(
        id: 'p_${n++}',
        day: day,
        period: period,
        timeLabel: timeLabel,
        activityId: activityId,
        title: title,
        details: details,
        duration: duration ?? a?.duration ?? 30,
        optional: optional,
        fixedInWeeklyTemplate: true,
      );
    }

    PlanItem freeBlock({
      required int day,
      required String period,
      required String title,
      String? timeLabel,
      String? details,
      required int duration,
      bool optional = false,
    }) {
      return PlanItem(
        id: 'p_${n++}',
        day: day,
        period: period,
        timeLabel: timeLabel,
        title: title,
        details: details,
        duration: duration,
        optional: optional,
        fixedInWeeklyTemplate: true,
      );
    }

    return [
      // LUNDI — concentration et musique
      freeBlock(day: 0, period: 'Matin', timeLabel: '08h00–09h00', title: 'Petit-déjeuner + lecture', details: 'Démarrage calme de la journée.', duration: 60),
      freeBlock(day: 0, period: 'Matin', timeLabel: '09h00–09h30', title: 'Préparation', details: 'Toilette, installation et mise en route.', duration: 30),
      freeBlock(day: 0, period: 'Matin', timeLabel: '09h30–10h00', title: 'Café + installation du piano', details: 'Prendre le temps de se mettre en condition.', duration: 30),
      activityBlock(day: 0, period: 'Matin', timeLabel: '10h00–12h00', activityId: 'piano', title: 'PIANO · 2 h', details: '20 min technique · 20 min déchiffrage · 40 min morceau principal · 40 min deuxième morceau.', duration: 120),
      freeBlock(day: 0, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Déjeuner + repos', details: 'Vraie coupure après le travail musical.', duration: 120),
      freeBlock(day: 0, period: 'Après-midi', timeLabel: '14h00–15h30', title: 'Jardinage', details: 'Entretien extérieur sans chercher à tout faire.', duration: 90),
      freeBlock(day: 0, period: 'Après-midi', timeLabel: '15h30–17h00', title: 'Lecture / repos', details: 'Temps de récupération volontaire.', duration: 90),
      freeBlock(day: 0, period: 'Soir', timeLabel: '17h00–18h00', title: 'Lecture', details: 'Moment calme.', duration: 60),
      freeBlock(day: 0, period: 'Soir', timeLabel: '18h00–19h30', title: 'Temps libre', details: 'La journée reste volontairement ouverte.', duration: 90, optional: true),
      freeBlock(day: 0, period: 'Soir', timeLabel: '19h30–21h00', title: 'Cuisine / dîner', details: 'Cuisine tranquille puis repas.', duration: 90),
      freeBlock(day: 0, period: 'Soir', timeLabel: '21h00–22h30', title: 'Lecture / musique', details: 'Fin de journée sans objectif.', duration: 90, optional: true),

      // MARDI — activité physique et équilibre
      freeBlock(day: 1, period: 'Matin', timeLabel: '08h00–09h00', title: 'Petit-déjeuner + lecture', details: 'Matinée active mais sans précipitation.', duration: 60),
      freeBlock(day: 1, period: 'Matin', timeLabel: '09h00–09h30', title: 'Préparation sport', details: 'Tenue, bouteille d’eau et départ.', duration: 30),
      activityBlock(day: 1, period: 'Matin', timeLabel: '09h30–10h00', activityId: 'strength', title: 'Trajet / installation au sport', details: 'Temps de préparation autour de la séance.', duration: 30),
      activityBlock(day: 1, period: 'Matin', timeLabel: '10h00–11h00', activityId: 'strength', title: 'SPORT · 45–60 min', details: 'Séance principale puis retour au calme.', duration: 60),
      activityBlock(day: 1, period: 'Matin', timeLabel: '11h00–11h30', activityId: 'piano', title: 'Piano léger · 30 min', details: 'Après le sport, uniquement révision et plaisir.', duration: 30),
      freeBlock(day: 1, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Douche + déjeuner', details: 'Récupération avant la marche.', duration: 120),
      activityBlock(day: 1, period: 'Après-midi', timeLabel: '14h00–15h00', activityId: 'walk', title: 'Marche active', details: 'Dans Sarlat ou les environs.', duration: 60),
      activityBlock(day: 1, period: 'Après-midi', timeLabel: '15h00–16h00', activityId: 'walk', title: 'Suite de la marche', details: 'Jusqu’à 1 h 30 selon l’envie et l’énergie.', duration: 60, optional: true),
      freeBlock(day: 1, period: 'Après-midi', timeLabel: '16h00–17h00', title: 'Douche + goûter / repos', details: 'Récupération réelle.', duration: 60),
      activityBlock(day: 1, period: 'Soir', timeLabel: '17h00–17h45', activityId: 'piano', title: 'Piano plaisir · 30–45 min', details: 'Jouer sans pression.', duration: 45, optional: true),
      freeBlock(day: 1, period: 'Soir', timeLabel: '18h00–19h30', title: 'Temps libre', details: 'Aucune obligation.', duration: 90, optional: true),
      freeBlock(day: 1, period: 'Soir', timeLabel: '19h30–21h00', title: 'Dîner', details: 'Soirée simple.', duration: 90),
      freeBlock(day: 1, period: 'Soir', timeLabel: '21h00–22h30', title: 'Lecture ou film', details: 'Selon l’envie.', duration: 90, optional: true),

      // MERCREDI — marché et piano
      freeBlock(day: 2, period: 'Matin', timeLabel: '08h00–09h00', title: 'Petit-déjeuner', details: 'Matin tranquille.', duration: 60),
      freeBlock(day: 2, period: 'Matin', timeLabel: '09h00–09h30', title: 'Préparation du marché', details: 'Liste, sac et départ.', duration: 30),
      activityBlock(day: 2, period: 'Matin', timeLabel: '09h30–12h00', activityId: 'market', title: 'Marché + courses', details: 'Vie locale, courses puis retour.', duration: 150),
      freeBlock(day: 2, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Cuisine + déjeuner', details: 'Préparer puis profiter du repas.', duration: 120),
      activityBlock(day: 2, period: 'Après-midi', timeLabel: '14h00–16h00', activityId: 'piano', title: 'PIANO · 2 h', details: '30 min MyPianoPop · 45 min morceau principal · 30 min deuxième morceau · 15 min révision.', duration: 120),
      freeBlock(day: 2, period: 'Après-midi', timeLabel: '16h00–17h00', title: 'Café + repos', details: 'Pause sans écran si possible.', duration: 60, optional: true),
      activityBlock(day: 2, period: 'Soir', timeLabel: '17h00–18h00', activityId: 'reading', title: 'Lecture', details: 'Moment calme.', duration: 60),
      freeBlock(day: 2, period: 'Soir', timeLabel: '19h30–21h00', title: 'Dîner', details: 'Soirée légère.', duration: 90),
      freeBlock(day: 2, period: 'Soir', timeLabel: '21h00–22h30', title: 'Film / lecture', details: 'Fin de journée libre.', duration: 90, optional: true),

      // JEUDI — équilibre et bien-être
      freeBlock(day: 3, period: 'Matin', timeLabel: '08h00–09h00', title: 'Petit-déjeuner + lecture', details: 'Matinée douce.', duration: 60),
      freeBlock(day: 3, period: 'Matin', timeLabel: '09h00–09h30', title: 'Toilette + tenue confortable', details: 'Préparer tranquillement la séance.', duration: 30),
      activityBlock(day: 3, period: 'Matin', timeLabel: '09h30–10h00', activityId: 'tai-chi', title: 'Mobilité douce', details: 'Mise en route, respiration et mobilité.', duration: 30),
      activityBlock(day: 3, period: 'Matin', timeLabel: '10h00–10h45', activityId: 'tai-chi', title: 'SPORT DOUX · 45 min', details: 'Étirements, mobilité et équilibre.', duration: 45),
      freeBlock(day: 3, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Douche + déjeuner', details: 'Pause complète.', duration: 120),
      activityBlock(day: 3, period: 'Après-midi', timeLabel: '14h00–16h00', activityId: 'piano', title: 'PIANO · 2 h', details: '20 min technique · 50 min morceau difficile · 40 min deuxième morceau · 10 min jeu plaisir.', duration: 120),
      freeBlock(day: 3, period: 'Après-midi', timeLabel: '16h00–17h00', title: 'Pause + lecture', details: 'Temps de récupération.', duration: 60, optional: true),
      activityBlock(day: 3, period: 'Soir', timeLabel: '17h00–18h00', activityId: 'reading', title: 'Lecture', details: 'Avant la sortie.', duration: 60),
      freeBlock(day: 3, period: 'Soir', timeLabel: '18h00–19h30', title: 'Promenade dans Sarlat', details: 'Sortie tranquille, sans objectif.', duration: 90, optional: true),
      freeBlock(day: 3, period: 'Soir', timeLabel: '19h30–21h00', title: 'Restaurant / sortie', details: 'Selon l’envie.', duration: 90, optional: true),
      freeBlock(day: 3, period: 'Soir', timeLabel: '21h00–22h30', title: 'Retour + lecture', details: 'Retour au calme.', duration: 90, optional: true),

      // VENDREDI — nature et musique
      freeBlock(day: 4, period: 'Matin', timeLabel: '08h00–09h00', title: 'Petit-déjeuner', details: 'Départ progressif.', duration: 60),
      freeBlock(day: 4, period: 'Matin', timeLabel: '09h00–09h30', title: 'Préparation marche', details: 'Chaussures, eau et départ.', duration: 30),
      activityBlock(day: 4, period: 'Matin', timeLabel: '09h30–11h30', activityId: 'walk', title: 'GRANDE MARCHE · 1 h 30–2 h', details: 'Nature autour de Sarlat, selon météo et énergie.', duration: 120),
      freeBlock(day: 4, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Déjeuner + récupération', details: 'Ne rien programmer de contraignant.', duration: 120),
      freeBlock(day: 4, period: 'Après-midi', timeLabel: '14h00–15h30', title: 'Jardinage', details: 'Entretien extérieur et plaisir de faire.', duration: 90),
      freeBlock(day: 4, period: 'Après-midi', timeLabel: '15h30–16h00', title: 'Pause', details: 'Respirer et décider de la suite selon l’énergie.', duration: 30, optional: true),
      freeBlock(day: 4, period: 'Après-midi', timeLabel: '16h00–17h00', title: 'Douche + repos', details: 'Récupération avant la musique.', duration: 60),
      activityBlock(day: 4, period: 'Soir', timeLabel: '17h00–18h00', activityId: 'piano', title: 'Piano léger', details: 'Révision et consolidation.', duration: 60),
      activityBlock(day: 4, period: 'Soir', timeLabel: '19h30–21h00', activityId: 'piano', title: 'PIANO · 1 h 30', details: '20 min technique · 40 min consolidation · 30 min morceaux · 10 min jeu plaisir.', duration: 90),
      freeBlock(day: 4, period: 'Soir', timeLabel: '21h00–22h30', title: 'Lecture / musique', details: 'Début tranquille du week-end.', duration: 90, optional: true),

      // SAMEDI — sorties et convivialité
      freeBlock(day: 5, period: 'Matin', timeLabel: '08h00–09h00', title: 'Petit-déjeuner', details: 'Matinée sans urgence.', duration: 60),
      freeBlock(day: 5, period: 'Matin', timeLabel: '09h00–09h30', title: 'Préparation de la sortie', details: 'Choisir selon météo et envie.', duration: 30),
      freeBlock(day: 5, period: 'Matin', timeLabel: '09h30–12h00', title: 'Village / patrimoine / exposition', details: 'Flânerie et découverte.', duration: 150),
      freeBlock(day: 5, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Déjeuner au restaurant ou à la maison', details: 'Sans obligation de cuisiner.', duration: 120),
      activityBlock(day: 5, period: 'Après-midi', timeLabel: '14h00–15h30', activityId: 'reading', title: 'Lecture', details: 'Café, livre et repos.', duration: 90),
      freeBlock(day: 5, period: 'Après-midi', timeLabel: '15h30–16h30', title: 'Lecture / café', details: 'Pause tranquille.', duration: 60, optional: true),
      freeBlock(day: 5, period: 'Soir', timeLabel: '17h00–18h00', title: 'Préparation de la soirée', details: 'Prendre son temps.', duration: 60),
      activityBlock(day: 5, period: 'Soir', timeLabel: '19h30–21h30', activityId: 'friends', title: 'Soirée conviviale', details: 'Amis, restaurant ou moment partagé.', duration: 120),
      activityBlock(day: 5, period: 'Soir', timeLabel: '21h30–22h00', activityId: 'piano', title: 'Piano plaisir · 20–30 min', details: 'Uniquement si l’envie est là.', duration: 30, optional: true),

      // DIMANCHE — récupération et liberté
      freeBlock(day: 6, period: 'Matin', timeLabel: '08h00–09h30', title: 'Réveil tranquille + lecture', details: 'Pas de réveil pressé.', duration: 90, optional: true),
      freeBlock(day: 6, period: 'Matin', timeLabel: '09h30–10h00', title: 'Promenade douce', details: 'Autour de chez soi.', duration: 30, optional: true),
      activityBlock(day: 6, period: 'Matin', timeLabel: '10h00–10h45', activityId: 'reading', title: 'Lecture', details: 'Dimanche calme.', duration: 45),
      freeBlock(day: 6, period: 'Après-midi', timeLabel: '12h00–14h00', title: 'Déjeuner dominical', details: 'Prendre le temps du repas.', duration: 120),
      activityBlock(day: 6, period: 'Après-midi', timeLabel: '14h00–14h45', activityId: 'walk', title: 'Marche digestive · 30–45 min', details: 'Selon l’envie et la météo.', duration: 45, optional: true),
      freeBlock(day: 6, period: 'Après-midi', timeLabel: '15h00–16h00', title: 'Jardinage léger', details: 'Seulement si cela fait plaisir.', duration: 60, optional: true),
      freeBlock(day: 6, period: 'Après-midi', timeLabel: '16h00–17h00', title: 'Café + lecture', details: 'Vraie plage de récupération.', duration: 60, optional: true),
      activityBlock(day: 6, period: 'Soir', timeLabel: '17h00–17h30', activityId: 'piano', title: 'Piano plaisir', details: 'Facultatif. Quelques morceaux, juste pour le plaisir.', duration: 30, optional: true),
      freeBlock(day: 6, period: 'Soir', timeLabel: '18h00–19h30', title: 'Temps libre', details: 'Préparer tranquillement la semaine suivante.', duration: 90, optional: true),
      freeBlock(day: 6, period: 'Soir', timeLabel: '19h30–21h00', title: 'Dîner', details: 'Soirée légère.', duration: 90),
      freeBlock(day: 6, period: 'Soir', timeLabel: '21h00–22h30', title: 'Lecture / musique calme', details: 'Pas de contrainte pour terminer la semaine.', duration: 90, optional: true),
    ];
  }

  int completedCount() => plan.where((p) => p.done && !_isDateRangePlanItem(p)).length;

  List<PlanItem> itemsForDay(int day) => plan.where((p) => p.day == day).toList();

  List<PlanItem> actionableItemsForDay(int day) =>
      itemsForDay(day).where((p) => !_isDateRangePlanItem(p)).toList();

  String dateText() {
    final d = DateTime.now();
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
      'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _generationPeriod(Activity activity, int day) {
    final learned = _learnedPeriodForGeneration(activity);
    return learned ?? _periodForActivity(activity, day);
  }

  String _learningSentence(Activity activity) {
    if (!_generationLearnHabits) return '';
    final profile = _activityLearning(activity);
    if (!profile.hasEnoughData) return '';
    final parts = <String>[];
    if (profile.bestDay >= 0 && profile.bestDayShare >= .55) {
      parts.add('souvent réalisée le ${dayNames[profile.bestDay].toLowerCase()} (${profile.dayCounts[profile.bestDay]}/${profile.realisedCount})');
    }
    if (profile.bestPeriod != null && profile.periodShare(profile.bestPeriod!) >= .60) {
      parts.add('surtout ${profile.bestPeriod!.toLowerCase()}');
    }
    if (profile.averageRealisedMinutes > 0 && profile.averagePlannedMinutes > 0) {
      final deltaRatio = (profile.averageRealisedMinutes - profile.averagePlannedMinutes).abs() / profile.averagePlannedMinutes;
      if (deltaRatio >= .20) {
        parts.add('en pratique ${profile.averageRealisedMinutes.round()} min en moyenne');
      }
    }
    if (profile.movedToCount >= 2 && profile.bestMovedToDay >= 0 && profile.bestMovedToDayShare >= .50) {
      parts.add('souvent déplacée vers le ${dayNames[profile.bestMovedToDay].toLowerCase()}');
    }
    if (profile.skippedCount >= 2 && profile.completionRate < .60) {
      parts.add('parfois laissée de côté (${(profile.completionRate * 100).round()} % réalisée)');
    }
    if (profile.difficultRate >= .50 && profile.difficultCount >= 2) {
      parts.add('avec plusieurs ressentis difficiles');
    }
    if (parts.isEmpty) return '';
    return '${activity.name} : ${parts.join(' · ')}.';
  }

  String _buildPlanningCoachExplanation(
    List<PlanItem> generated, {
    bool noChange = false,
    int preservedFutureManual = 0,
    bool fullWeekRebuild = false,
  }) {
    final parts = <String>[];
    final futureGeneratedDays = generated.map((p) => p.day).toSet().length;
    if (fullWeekRebuild) {
      parts.add(noChange
          ? 'La semaine a été reconstruite après la réinitialisation complète ; aucune occurrence supplémentaire n’était nécessaire avec les critères actuels.'
          : 'J’ai reconstruit ${generated.length} moment(s) sur $futureGeneratedDays jour(s) de la semaine après la réinitialisation complète.');
    } else if (noChange) {
      parts.add('Je n’ai pas changé les créneaux automatiques futurs : après comparaison entre fréquence restante, historique, habitudes apprises, jours préférés et charge, le planning actuel reste cohérent.');
    } else {
      parts.add('J’ai reconstruit ${generated.length} moment(s) futur(s) sur $futureGeneratedDays jour(s), sans toucher au passé ni à aujourd’hui.');
    }
    if (preservedFutureManual > 0) {
      parts.add('$preservedFutureManual moment(s) futur(s) que tu avais placé(s) manuellement ont été conservé(s).');
    }
    final manualAdded = plan.where((p) => p.userAdded && p.manualPlacement && p.activityId != null && p.day > today).length;
    if (manualAdded > 0) {
      parts.add('$manualAdded activité(s) ajoutée(s) manuellement, Sport ou non-Sport, restent protégées des choix automatiques.');
    }
    final manualRemoved = _manualDayRemovals.values.fold<int>(0, (sum, days) => sum + days.values.fold<int>(0, (s, c) => s + c));
    if (manualRemoved > 0) parts.add('Retraits manuels pris en compte : $manualRemoved occurrence(s) ne sont pas recréées automatiquement au même jour.');
    final weatherSummary = _weatherAvailableButNotDecisiveSummary(generated);
    if (weatherSummary.isNotEmpty) parts.add(weatherSummary);
    final weatherReasons = generated
        .map((item) => item.details ?? '')
        .where((detail) => detail.contains('🌦️ Météo décisive'))
        .take(3)
        .toList();
    if (weatherReasons.isNotEmpty) {
      parts.add('Les décisions météo sont signalées directement dans les activités concernées.');
    }
    final ids = <String>[];
    for (final item in generated) {
      final id = item.activityId;
      if (id != null && !ids.contains(id)) ids.add(id);
    }
    final learned = <String>[];
    for (final id in ids) {
      final activity = findActivity(id);
      if (activity == null) continue;
      final sentence = _learningSentence(activity);
      if (sentence.isNotEmpty) learned.add(sentence);
      if (learned.length >= 3) break;
    }
    if (learned.isNotEmpty) {
      parts.add('Ce que j’ai appris : ${learned.join(' ')}');
    } else if (logs.isEmpty) {
      parts.add('Je commence avec tes réglages de fiche ; mes habitudes deviendront progressivement plus précises après quelques réalisations.');
    } else if (_generationLearnHabits) {
      parts.add('Je continue d’apprendre ton rythme ; je n’utilise une habitude comme signal fort qu’après au moins 3 réalisations d’une activité.');
    }
    final manualAddedCount = plan.where((p) => p.userAdded && p.manualPlacement && p.activityId != null && p.day >= today).length;
    if (manualAddedCount > 0) parts.add('Choix manuels conservés : $manualAddedCount moment(s) ajouté(s) au planning restent prioritaires sur une nouvelle décision automatique.');
    if (!_generationBalanceLoad) parts.add('L’équilibre de charge a été désactivé pour cette génération.');
    if (!_generationUseHistory) parts.add('L’historique a été désactivé : les choix reposent alors surtout sur tes réglages de fiche.');
    if (!_generationLearnHabits) parts.add('L’apprentissage personnel a été désactivé : aucune habitude apprise n’a pesé dans les choix.');
    return parts.join(' ');
  }

  double _historyPlanningScore(Activity activity, int day) {
    // Sans historique, on conserve quasiment le comportement précédent.
    final recent30 = _recentHistory(30)
        .where((log) => _logMatchesActivity(log, activity))
        .toList();
    if (recent30.isEmpty) {
      var score = activity.preferredDays.contains(day) ? 3.0 : 0.0;
      if (_generationLearnHabits) {
        final profile = _activityLearning(activity);
        if (profile.hasEnoughData) {
          score += profile.dayShare(day) * 5.0;
          if (day == profile.bestDay && profile.bestDayShare >= .55) score += 1.5;
          if (profile.difficultRate >= .50) score -= 1.2;
          if (profile.veryGoodRate >= .50) score += .6;
        }
      }
      return score;
    }

    final now = DateTime.now();
    recent30.sort((a, b) => b.date.compareTo(a.date));
    final last = recent30.first;
    final daysSinceLast = max(0, now.difference(last.date).inDays);
    final target30 = max(1.0, activity.frequency * 30.0 / 7.0);
    final actual30 = recent30.length.toDouble();
    final deficit = max(0.0, target30 - actual30);

    var score = min(deficit, 7.0) * 1.8;

    // La météo n'est volontairement PAS intégrée ici : elle est ajoutée
    // séparément dans _compareGenerationDays(). Cela permet au coach de
    // comparer exactement le même arbitrage avec et sans météo et donc de
    // savoir si la météo a réellement changé sa décision.

    // Ce qui vient d’être fait remonte moins vite ; ce qui n’a pas été fait
    // depuis un moment remonte naturellement dans le prochain planning.
    score += min(daysSinceLast, 21) * 0.22;
    if (daysSinceLast <= 2) score -= 2.5;

    final difficult = recent30.where((l) => l.feeling == 'Difficile').length;
    final veryGood = recent30.where((l) => l.feeling == 'Très bien').length;
    score -= min(difficult, 3) * 1.1;
    score += min(veryGood, 3) * 0.25;

    // Tendance récente : si une activité a disparu des 7 derniers jours
    // alors qu'elle était présente avant, elle remonte doucement. À l'inverse,
    // une activité déjà très présente cette semaine descend un peu.
    final recent7 = recent30.where((log) => now.difference(log.date).inDays < 7).length;
    final previous7 = recent30.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 7 && age < 14;
    }).length;
    if (previous7 > 0 && recent7 == 0) score += 2.2;
    if (recent7 >= 2) score -= 0.7 * (recent7 - 1);

    // Le coach apprend aussi les jours réellement utilisés, sans supprimer
    // les jours préférés définis par l’utilisateur.
    final sameDay = recent30.where((l) => l.day == day).length;
    final dayRatio = sameDay / recent30.length;
    if (recent30.length >= 2) score += dayRatio * 1.8;
    if (activity.preferredDays.contains(day)) score += 3.0;

    // Une activité déjà suffisamment présente sur les 30 derniers jours ne
    // devient pas prioritaire uniquement parce qu’elle est ancienne.
    if (actual30 > target30 * 1.20) score -= 3.0;

    // Apprentissage personnel : avec au moins 3 réalisations, le coach
    // apprend progressivement les vrais jours de réalisation, sans supprimer
    // les jours préférés définis par l’utilisateur. Les déplacements réels
    // donnent un signal complémentaire mais restent volontairement modérés.
    if (_generationLearnHabits) {
      final profile = _activityLearning(activity);
      if (profile.hasEnoughData) {
        final learnedDayShare = profile.dayShare(day);
        score += learnedDayShare * 6.0;
        if (day == profile.bestDay && profile.bestDayShare >= .55) score += 2.0;
        if (profile.difficultRate >= .50) score -= 1.7;
        if (profile.veryGoodRate >= .50) score += 0.9;
        if (profile.recent7Count >= 2) score -= .8;

        // Si l’activité a souvent été prévue mais non réalisée ce jour-là,
        // on évite doucement de la remettre au même endroit.
        final dayCompletion = profile.dayCompletionRate(day);
        final dayObserved = (profile.dayCounts[day] ?? 0) + (profile.skippedDayCounts[day] ?? 0);
        if (dayObserved >= 2 && dayCompletion < .50) score -= 3.0;
        if (dayObserved >= 3 && dayCompletion >= .80) score += 1.5;

        // Lorsqu’une activité est régulièrement déplacée vers un autre jour,
        // le coach apprend ce comportement et favorise ce jour pour l’avenir.
        if (profile.movedToCount >= 2 && profile.bestMovedToDay == day && profile.bestMovedToDayShare >= .50) score += 2.5;

        // Un écart durable entre durée prévue et durée réelle ne change pas la
        // durée de référence de la fiche, mais devient un signal de charge.
        if (profile.realisedCount >= 3 && profile.durationGapRatio >= .20) {
          if (profile.durationRatio < .80) score += 1.0;
          if (profile.durationRatio > 1.20) score -= 0.6;
        }

        // Un déplacement répété vers un autre usage du jour est un signal
        // faible : on l’utilise pour départager des jours proches.
        final moveToDay = activityMoveLogs.where((move) {
          final age = now.difference(move.date).inDays;
          final matches = move.activityId == activity.id ||
              (move.activityId == null && move.activityName.trim().toLowerCase() == activity.name.trim().toLowerCase());
          return age >= 0 && age < 60 && matches && move.toDay == day;
        }).length;
        final moveFromDay = activityMoveLogs.where((move) {
          final age = now.difference(move.date).inDays;
          final matches = move.activityId == activity.id ||
              (move.activityId == null && move.activityName.trim().toLowerCase() == activity.name.trim().toLowerCase());
          return age >= 0 && age < 60 && matches && move.fromDay == day;
        }).length;
        score += min(moveToDay, 3) * .45;
        score -= min(moveFromDay, 3) * .35;
      }
    }
    final dailyMood = _recentDailySummaries(14);
    if (dailyMood.length >= 2) {
      final tiredDays = dailyMood.where((summary) => const {'😓', '😐'}.contains(summary.moodEmoji)).length;
      final positiveDays = dailyMood.where((summary) => const {'😄', '🙂', '😌'}.contains(summary.moodEmoji)).length;
      if (tiredDays >= 2 && activity.duration >= 45) score -= 1.0;
      if (positiveDays >= 3 && activity.duration <= 60) score += 0.25;
    }
    return score;
  }
}
