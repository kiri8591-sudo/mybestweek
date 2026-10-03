// V9.22 — Helpers cœur de l'application.
// Réintroduit le noyau commun retiré de main.dart lors du découpage du shell.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _AppCoreHelpersPart on _MaBelleSemaineAppState {
  int get today => DateTime.now().weekday - 1;

  Activity byId(String id) => activities.firstWhere((a) => a.id == id);

  Activity? findActivity(String id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool _isSportPlanItem(PlanItem item) {
    if (item.activityId == null) return false;
    final activity = findActivity(item.activityId!);
    return activity != null && _isSportActivity(activity);
  }

  void refreshMorningThought() {
    final now = _clockNow;
    final day = now.weekday - 1;
    final hour = now.hour;
    final period = hour < 12
        ? 0 // matin
        : hour < 18
            ? 1 // après-midi
            : hour < 22
                ? 2 // soirée
                : 3; // nuit

    final remaining = actionableItemsForDay(day).where((item) => !item.done).toList();
    final remainingActivities = remaining
        .map((item) => item.activityId == null ? null : findActivity(item.activityId!))
        .whereType<Activity>()
        .toList();

    final hasMusic = remainingActivities.any((a) =>
        a.name.toLowerCase().contains('piano') ||
        a.name.toLowerCase().contains('musique'));
    final hasSport = remainingActivities.any((a) => a.category == 'Sport');
    final hasOutdoor = remainingActivities.any(_isOutdoorPlanningActivity);
    final hasSocial = remainingActivities.any((a) => a.category == 'Social');
    final hasCulture = remainingActivities.any((a) => a.category == 'Culture');
    final hasWellness = remainingActivities.any((a) => a.category == 'Bien-être');
    final hasMarket = remainingActivities.any((a) =>
        a.name.toLowerCase().contains('marché') ||
        a.name.toLowerCase().contains('marche de sarlat'));
    final weather = _weatherForWeekDay(day);
    final weatherBad = weather?.outdoorBad == true;

    const dayThoughts = <String>[
      'Un lundi peut simplement donner le ton de la semaine.',
      'Le mardi est un bon moment pour garder un rythme souple et vivant.',
      'Le mercredi peut laisser une belle place aux sorties et aux découvertes.',
      'Le jeudi invite à garder de la curiosité et du plaisir dans la journée.',
      'Le vendredi peut rester actif tout en gardant une place pour le plaisir.',
      'Le samedi est aussi fait pour profiter du temps choisi et des autres.',
      'Le dimanche peut rester léger : regarder la semaine, puis laisser respirer la journée.',
    ];
    const periodThoughts = <String>[
      'Ce matin, quelques bons moments suffisent pour bien commencer.',
      'Cet après-midi, avance à ton rythme et garde de la place pour l’imprévu.',
      'Ce soir, la journée peut se terminer tranquillement, sans chercher à tout remplir.',
      'Cette nuit, rien ne presse : la prochaine journée peut attendre demain.',
    ];

    // Le contenu contextuel domine, mais le jour et le moment restent présents
    // dans la sélection. Le même planning peut donc produire une ambiance
    // différente un lundi matin, un mercredi après-midi ou un dimanche soir.
    final weightedThoughts = <String>[];
    void addThought(String value, int weight) {
      for (var i = 0; i < weight; i++) {
        weightedThoughts.add(value);
      }
    }

    if (weatherBad && hasOutdoor) {
      addThought('${weather!.icon} ${weather.text.toLowerCase()} : garder les activités extérieures pour un moment plus favorable.', 8);
    } else if (hasOutdoor && hasMarket) {
      addThought('Un marché ou une sortie peut donner un joli relief à la journée.', 8);
    } else if (hasOutdoor) {
      addThought('La journée offre une vraie occasion de prendre l’air.', 7);
    }
    if (hasMusic) addThought('Quelques notes peuvent donner une belle couleur à la journée.', 6);
    if (hasSport) addThought('Un peu de mouvement, sans pression : juste ce qu’il faut.', 5);
    if (hasSocial) addThought('Un moment partagé peut être l’un des bons repères de la journée.', 4);
    if (hasCulture) addThought('La curiosité mérite aussi sa place dans la journée.', 4);
    if (hasWellness) addThought('Prendre soin de soi fait aussi partie du programme.', 4);

    addThought(dayThoughts[day.clamp(0, 6).toInt()], 4);
    addThought(periodThoughts[period], 3);
    addThought('Une belle journée n’a pas besoin d’être remplie pour être réussie.', 1);
    addThought('Prendre son temps n’est pas perdre son temps.', 1);
    addThought('Le meilleur programme reste celui qui laisse un peu de place à l’imprévu.', 1);

    final dateSeed = now.year * 10000 + now.month * 100 + now.day;
    final contextSeed =
        (hasMusic ? 11 : 0) +
        (hasSport ? 17 : 0) +
        (hasOutdoor ? 23 : 0) +
        (hasMarket ? 29 : 0) +
        (hasSocial ? 31 : 0) +
        (hasCulture ? 37 : 0) +
        (hasWellness ? 41 : 0) +
        (weatherBad ? 47 : 0);
    final seed = dateSeed * 10 + period * 101 + contextSeed;
    final random = Random(seed);
    final candidates = weightedThoughts.where((thought) => thought != _morningThought).toList();
    final thought = candidates.isEmpty
        ? weightedThoughts[random.nextInt(weightedThoughts.length)]
        : candidates[random.nextInt(candidates.length)];

    const dayIcons = <String>['🌱', '💪', '🧺', '🎵', '☀️', '🫶', '✨'];
    const periodIcons = <String>['🌅', '🌿', '🌙', '✨'];
    final weightedIcons = <String>[];
    void addIcon(String value, int weight) {
      for (var i = 0; i < weight; i++) {
        weightedIcons.add(value);
      }
    }

    if (weatherBad && hasOutdoor) addIcon('☁️', 8);
    if (hasMarket) addIcon('🧺', 7);
    if (hasOutdoor && !weatherBad) addIcon('🌿', 6);
    if (hasMusic) addIcon('🎵', 6);
    if (hasSport) addIcon('💪', 5);
    if (hasSocial) addIcon('🫶', 4);
    if (hasCulture) addIcon('📚', 4);
    if (hasWellness) addIcon('🌸', 4);
    addIcon(dayIcons[day.clamp(0, 6).toInt()], 4);
    addIcon(periodIcons[period], 3);

    final iconSeed = seed + 7919;
    final iconRandom = Random(iconSeed);
    final thoughtIcon = weightedIcons[iconRandom.nextInt(weightedIcons.length)];
    final focusIcon = weightedIcons[iconRandom.nextInt(weightedIcons.length)];

    _setMorningThoughtState(
      thought: thought,
      thoughtIcon: thoughtIcon,
      focusIcon: focusIcon,
    );
    _queueLocalStatePersist();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    final messenger = _scaffoldMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 900)),
    );
  }

  String _currentWeekKey() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final d = DateTime(monday.year, monday.month, monday.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> openDataManager() async {
    await _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _DataPage(
          onICloudExport: exportBackupToICloud,
          onImport: importBackupFile,
          onReset: resetDatabaseCompletely,
          getCloudBackupStatus: _cloudBackupStatusText,
          cloudReminderDays: _MaBelleSemaineAppState._cloudBackupReminderDays,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}
