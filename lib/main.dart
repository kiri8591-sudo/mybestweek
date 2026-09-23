import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:html' as html;

void _installMascotBrowserIcon() {
  // Identité visuelle autonome pour la version web/iPhone : la mascotte est
  // injectée dans le document sans dépendre d'un fichier asset externe.
  const svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180">
    <rect width="180" height="180" rx="42" fill="#FFF4EA"/>
    <circle cx="90" cy="96" r="52" fill="#FFE7D7"/>
    <circle cx="70" cy="91" r="7" fill="#526B78"/>
    <circle cx="110" cy="91" r="7" fill="#526B78"/>
    <path d="M76 111 Q90 123 104 111" fill="none" stroke="#C67E67" stroke-width="6" stroke-linecap="round"/>
    <circle cx="46" cy="61" r="17" fill="#F4B7A1"/>
    <circle cx="134" cy="61" r="17" fill="#F4B7A1"/>
    <circle cx="90" cy="42" r="18" fill="#7D988D"/>
    <circle cx="90" cy="42" r="8" fill="#FFFDF8"/>
  </svg>''';
  final href = Uri.dataFromString(svg, mimeType: 'image/svg+xml', encoding: utf8).toString();
  for (final rel in ['icon', 'shortcut icon', 'apple-touch-icon']) {
    for (final old in html.document.querySelectorAll('link[rel="$rel"]')) {
      old.remove();
    }
    final link = html.LinkElement()
      ..rel = rel
      ..href = href
      ..type = 'image/svg+xml';
    html.document.head?.append(link);
  }
}

void main() {
  _installMascotBrowserIcon();
  runApp(const MaBelleSemaineApp());
}

class Activity {
  final String id;
  String name;
  String emoji;
  String category;
  int duration;
  int frequency;
  int priority;
  List<int> preferredDays;
  int sportWeight;
  final String? sportGroup;
  final int? sportGroupFrequency;
  final bool activeInSportRotation;
  final bool isSportProgram;
  Map<int, int> sportDailyDurations;

  Activity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.duration,
    required this.frequency,
    required this.priority,
    this.preferredDays = const [],
    this.sportWeight = 5,
    this.sportGroup,
    this.sportGroupFrequency,
    this.activeInSportRotation = true,
    this.isSportProgram = false,
    Map<int, int>? sportDailyDurations,
  }) : sportDailyDurations = {
          for (final e in (sportDailyDurations ?? const <int, int>{}).entries)
            if (e.key >= 0 && e.key < 7) e.key: max(0, e.value),
        };

  Activity copy() => Activity(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        duration: duration,
        frequency: frequency,
        priority: priority,
        preferredDays: [...preferredDays],
        sportWeight: sportWeight,
        sportGroup: sportGroup,
        sportGroupFrequency: sportGroupFrequency,
        activeInSportRotation: activeInSportRotation,
        isSportProgram: isSportProgram,
        sportDailyDurations: {...sportDailyDurations},
      );
}

class PlanItem {
  final String id;
  final String? activityId;
  final int day;
  String period;
  String? timeLabel;
  String title;
  String? details;
  final String? customEmoji;
  final String? customCategory;
  int duration;
  final bool optional;
  final bool userAdded;
  final bool fixedInWeeklyTemplate;
  bool done;
  int? realisedMinutes;
  String? feeling;

  PlanItem({
    required this.id,
    required this.day,
    required this.period,
    this.timeLabel,
    required this.title,
    required this.duration,
    this.activityId,
    this.details,
    this.customEmoji,
    this.customCategory,
    this.optional = false,
    this.userAdded = false,
    this.fixedInWeeklyTemplate = false,
    this.done = false,
    this.realisedMinutes,
    this.feeling,
  });
}

class ActivityLog {
  final DateTime date;
  final String title;
  final String emoji;
  final String category;
  final String period;
  final int day;
  final int plannedMinutes;
  final int realisedMinutes;
  final String feeling;
  final bool unplanned;
  final String? planItemId;
  final String? activityId;

  ActivityLog({
    required this.date,
    required this.title,
    required this.emoji,
    required this.category,
    required this.period,
    required this.day,
    required this.plannedMinutes,
    required this.realisedMinutes,
    required this.feeling,
    this.unplanned = false,
    this.planItemId,
    this.activityId,
  });
}


class SportCoachLog {
  final DateTime date;
  final String activityName;
  final String message;
  final String? adjustment;

  SportCoachLog({
    required this.date,
    required this.activityName,
    required this.message,
    this.adjustment,
  });
}

class MaBelleSemaineApp extends StatefulWidget {
  const MaBelleSemaineApp({super.key});

  @override
  State<MaBelleSemaineApp> createState() => _MaBelleSemaineAppState();
}

class _MaBelleSemaineAppState extends State<MaBelleSemaineApp> {
  static const version = 'V7.30';

  static const List<String> morningThoughts = [
    'Une belle journée n’a pas besoin d’être remplie pour être réussie.',
    'Aujourd’hui, avance tranquillement : un petit pas reste un pas.',
    'Prendre son temps n’est pas perdre son temps.',
    'Il y a toujours une bonne raison de profiter de la journée qui commence.',
    'La retraite, c’est aussi le plaisir de choisir ce qui mérite vraiment son temps.',
    'Pas besoin de tout faire aujourd’hui. Quelques bons moments suffisent.',
    'Une promenade, quelques notes de piano, un bon livre : voilà déjà une belle journée.',
    'Fais de la place aux choses qui te font du bien, sans chercher la perfection.',
    'Le meilleur programme reste celui qui laisse un peu de place à l’imprévu.',
    'Aujourd’hui n’est pas une course. C’est une journée à savourer.',
  ];

  late String _morningThought;

  final dayNames = const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  int tab = 0;
  String categoryFilter = 'Toutes';
  int _resetGeneration = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static const String _localStateKey = 'ma_belle_semaine_local_state_v2';
  bool _persistenceQueued = false;

  List<Activity> activities = _defaultActivities();

  static List<Activity> _defaultActivities() => [
        // Programme générique : les journées « Sport » sont ensuite déclinées
        // automatiquement à partir de la liste ci-dessous.
        Activity(
          id: 'sport',
          name: 'Sport',
          emoji: '🏃',
          category: 'Sport',
          duration: 120,
          frequency: 3,
          priority: 5,
          preferredDays: [0, 1, 3],
          sportWeight: 10,
          sportDailyDurations: const {0: 120, 1: 120, 3: 120},
          isSportProgram: true,
        ),

        // TAI CHI — 30 min, 2 fois/semaine, en alternance.
        Activity(id: 'sport-tai-chi-fit-to-go', name: 'Tai Chi Fit to go — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),
        Activity(id: 'sport-tai-chi-fit-flow', name: 'Tai Chi Fit Flow — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),
        Activity(id: 'sport-tai-chi-fit-strength', name: 'Tai Chi Fit strength — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),
        Activity(id: 'sport-tai-chi-fit-over-50', name: 'Tai Chi Fit over 50 — David Dorian Ross', emoji: '🧘', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'tai-chi-fit', sportGroupFrequency: 2),

        // QI GONG — 30 min, 2 fois/semaine, en alternance.
        Activity(id: 'sport-qi-energy', name: 'Qi Gong for energy — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-anxiety', name: 'Qi Gong for anxiety — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-upper-back', name: 'Qi Gong for upper back — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-introduction', name: 'Qi Gong introduction — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),
        Activity(id: 'sport-qi-healthy-joints', name: 'Qi Gong for healthy joints — Lee Holden', emoji: '🌿', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'qi-gong', sportGroupFrequency: 2),

        // YANG TAI CHI — 30 min, 1 fois/semaine. Part 2 reste volontairement
        // dans la rotation mais sera favorisée plus tard par l’historique.
        Activity(id: 'sport-yang-tai-chi-part-1', name: 'Yang tai chi part 1', emoji: '☯️', category: 'Sport', duration: 30, frequency: 1, priority: 5, sportWeight: 8, sportGroup: 'yang-tai-chi', sportGroupFrequency: 1),
        Activity(id: 'sport-yang-tai-chi-part-2', name: 'Yang tai chi part 2 — plus tard', emoji: '☯️', category: 'Sport', duration: 30, frequency: 1, priority: 2, sportWeight: 3, sportGroup: 'yang-tai-chi', sportGroupFrequency: 1, activeInSportRotation: false),

        // ROUTINES COURTES — fréquence propre respectée indépendamment des
        // journées Sport composites.
        Activity(id: 'sport-bluetens', name: 'Bluetens session', emoji: '⚡', category: 'Sport', duration: 10, frequency: 7, priority: 4, sportWeight: 6),
        Activity(id: 'sport-betterme', name: 'BetterMe session', emoji: '💪', category: 'Sport', duration: 30, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-fiton', name: 'Fit On session', emoji: '🏋️', category: 'Sport', duration: 30, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-yoga', name: 'Yoga et yoga Égyptien session', emoji: '🧘', category: 'Sport', duration: 30, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-weasyo', name: 'Weasyo session', emoji: '🤸', category: 'Sport', duration: 15, frequency: 5, priority: 4, sportWeight: 6),
        Activity(id: 'sport-seven-minutes-chi', name: '7 minutes chi', emoji: '🌿', category: 'Sport', duration: 10, frequency: 7, priority: 4, sportWeight: 6),
        Activity(id: 'sport-foodvisor-gym', name: 'Foodvisor gym session', emoji: '🏋️', category: 'Sport', duration: 20, frequency: 2, priority: 4, sportWeight: 7),
        Activity(id: 'sport-meditation', name: 'Méditation', emoji: '🧘', category: 'Sport', duration: 10, frequency: 7, priority: 3, sportWeight: 5),
        Activity(id: 'sport-coherence', name: 'Cohérence cardiaque', emoji: '💗', category: 'Sport', duration: 10, frequency: 3, priority: 3, sportWeight: 5),
        Activity(id: 'sport-bike-cotignac', name: 'Vélo appartement à Cotignac', emoji: '🚴', category: 'Sport', duration: 30, frequency: 5, priority: 5, sportWeight: 8),
        Activity(id: 'sport-nordic-walk', name: 'Marche Nordique', emoji: '🥾', category: 'Sport', duration: 45, frequency: 3, priority: 5, sportWeight: 9),
        Activity(id: 'sport-kegel', name: 'Kegel exercices', emoji: '🌸', category: 'Sport', duration: 10, frequency: 7, priority: 3, sportWeight: 4),
        Activity(id: 'sport-five-tibetan', name: '5 Tibétain', emoji: '☀️', category: 'Sport', duration: 15, frequency: 3, priority: 4, sportWeight: 6),
        Activity(id: 'sport-pushup-abs', name: 'Challenge pompes et abdos · 10 → 100 répétitions', emoji: '💪', category: 'Sport', duration: 15, frequency: 3, priority: 4, sportWeight: 7),

        // Autres activités de la semaine.
        Activity(
          id: 'piano',
          name: 'Piano',
          emoji: '🎹',
          category: 'Loisir',
          duration: 120,
          frequency: 5,
          priority: 5,
          preferredDays: [0, 1, 2, 3, 4],
        ),
        Activity(
          id: 'reading',
          name: 'Lecture',
          emoji: '📖',
          category: 'Culture',
          duration: 45,
          frequency: 6,
          priority: 3,
        ),
        Activity(
          id: 'market',
          name: 'Marché de Sarlat',
          emoji: '🧺',
          category: 'Sortie',
          duration: 90,
          frequency: 1,
          priority: 3,
          preferredDays: [2],
        ),
        Activity(
          id: 'friends',
          name: 'Moment convivial',
          emoji: '🥂',
          category: 'Social',
          duration: 120,
          frequency: 1,
          priority: 4,
          preferredDays: [5],
        ),
      ];

  List<PlanItem> plan = [];
  List<ActivityLog> logs = [];
  String weeklyNote = '';

  // Coach Sport : une analyse unique, lisible depuis l’Accueil, puis un
  // éventuel ajustement du prochain jour Sport sans créer un second programme.
  String sportCoachLastAnalysis = '';
  DateTime? sportCoachLastAnalysisAt;
  String sportCoachSuggestion = '';
  int sportCoachSuggestionDelta = 0;
  List<SportCoachLog> sportCoachLogs = [];
  Map<int, int> sportCoachDailyAdjustments = {};

  int get today => DateTime.now().weekday - 1;

  Activity byId(String id) => activities.firstWhere((a) => a.id == id);

  Activity? findActivity(String id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _morningThought = morningThoughts[Random().nextInt(morningThoughts.length)];
    generateWeek(showSnack: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalState());
  }

  void refreshMorningThought() {
    final choices = morningThoughts.where((thought) => thought != _morningThought).toList();
    setState(() {
      _morningThought = choices[Random().nextInt(choices.length)];
    });
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

  void _persistLocalState() {
    try {
      final root = jsonDecode(_backupJson()) as Map<String, dynamic>;
      root['weekKey'] = _currentWeekKey();
      root['savedAt'] = DateTime.now().toIso8601String();
      html.window.localStorage[_localStateKey] = const JsonEncoder.withIndent('  ').convert(root);
    } catch (_) {
      // La persistance locale est facultative : une politique de stockage
      // navigateur restrictive ne doit jamais empêcher l'application de vivre.
    }
  }

  void _queueLocalStatePersist() {
    if (_persistenceQueued) return;
    _persistenceQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistenceQueued = false;
      if (mounted) _persistLocalState();
    });
  }

  void _loadLocalState() {
    try {
      final raw = html.window.localStorage[_localStateKey];
      if (raw == null || raw.trim().isEmpty) return;
      final root = jsonDecode(raw);
      if (root is! Map) return;
      final savedWeek = root['weekKey']?.toString();
      if (!restoreBackup(raw)) return;
      if (savedWeek != _currentWeekKey()) {
        setState(() {
          plan.clear();
        });
        generateWeek(showSnack: false);
      }
      _queueLocalStatePersist();
    } catch (_) {
      // On repart simplement avec les données de démarrage.
    }
  }

  String _backupJson() {
    final data = <String, dynamic>{
      'format': 'ma_belle_semaine_backup',
      'formatVersion': 1,
      'appVersion': version,
      'createdAt': DateTime.now().toIso8601String(),
      'morningThought': _morningThought,
      'weeklyNote': weeklyNote,
      'sportCoachLastAnalysis': sportCoachLastAnalysis,
      'sportCoachLastAnalysisAt': sportCoachLastAnalysisAt?.toIso8601String(),
      'sportCoachSuggestion': sportCoachSuggestion,
      'sportCoachSuggestionDelta': sportCoachSuggestionDelta,
      'sportCoachDailyAdjustments': {for (final e in sportCoachDailyAdjustments.entries) '${e.key}': e.value},
      'sportCoachLogs': sportCoachLogs.map((l) => {
        'date': l.date.toIso8601String(),
        'activityName': l.activityName,
        'message': l.message,
        'adjustment': l.adjustment,
      }).toList(),
      'activities': activities.map((a) => {
        'id': a.id,
        'name': a.name,
        'emoji': a.emoji,
        'category': a.category,
        'duration': a.duration,
        'frequency': a.frequency,
        'priority': a.priority,
        'preferredDays': a.preferredDays,
        'sportWeight': a.sportWeight,
        'sportGroup': a.sportGroup,
        'sportGroupFrequency': a.sportGroupFrequency,
        'activeInSportRotation': a.activeInSportRotation,
        'isSportProgram': a.isSportProgram,
        'sportDailyDurations': {for (final e in a.sportDailyDurations.entries) '${e.key}': e.value},
      }).toList(),
      'plan': plan.map((p) => {
        'id': p.id,
        'activityId': p.activityId,
        'day': p.day,
        'period': p.period,
        'timeLabel': p.timeLabel,
        'title': p.title,
        'details': p.details,
        'customEmoji': p.customEmoji,
        'customCategory': p.customCategory,
        'duration': p.duration,
        'optional': p.optional,
        'userAdded': p.userAdded,
        'fixedInWeeklyTemplate': p.fixedInWeeklyTemplate,
        'done': p.done,
        'realisedMinutes': p.realisedMinutes,
        'feeling': p.feeling,
      }).toList(),
      'logs': logs.map((l) => {
        'date': l.date.toIso8601String(),
        'title': l.title,
        'emoji': l.emoji,
        'category': l.category,
        'period': l.period,
        'day': l.day,
        'plannedMinutes': l.plannedMinutes,
        'realisedMinutes': l.realisedMinutes,
        'feeling': l.feeling,
        'unplanned': l.unplanned,
        'planItemId': l.planItemId,
        'activityId': l.activityId,
      }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  int _asInt(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  List<int> _asIntList(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => _asInt(item)).toList();
  }

  Map<int, int> _asIntMap(dynamic value) {
    if (value is! Map) return {};
    final result = <int, int>{};
    for (final entry in value.entries) {
      final key = int.tryParse('${entry.key}');
      if (key != null && key >= 0 && key < 7) result[key] = max(0, _asInt(entry.value));
    }
    return result;
  }

  String? _asString(dynamic value) => value == null ? null : '$value';

  bool _asBool(dynamic value, [bool fallback = false]) => value is bool ? value : fallback;

  bool restoreBackup(String raw) {
    try {
      final root = jsonDecode(raw);
      if (root is! Map || root['format'] != 'ma_belle_semaine_backup') return false;
      final activityData = root['activities'];
      final planData = root['plan'];
      final logData = root['logs'];
      if (activityData is! List || planData is! List || logData is! List) return false;

      final restoredActivities = <Activity>[];
      for (final rawActivity in activityData) {
        if (rawActivity is! Map) continue;
        final id = _asString(rawActivity['id']);
        final name = _asString(rawActivity['name']);
        if (id == null || name == null || name.trim().isEmpty) continue;
        restoredActivities.add(Activity(
          id: id,
          name: name,
          emoji: _asString(rawActivity['emoji']) ?? '✨',
          category: _asString(rawActivity['category']) ?? 'Autre',
          duration: max(1, _asInt(rawActivity['duration'], 30)),
          frequency: max(1, min(7, _asInt(rawActivity['frequency'], 1))),
          priority: max(1, min(5, _asInt(rawActivity['priority'], 3))),
          preferredDays: _asIntList(rawActivity['preferredDays']),
          sportWeight: max(1, min(10, _asInt(rawActivity['sportWeight'], 5))),
          sportGroup: _asString(rawActivity['sportGroup']),
          sportGroupFrequency: rawActivity['sportGroupFrequency'] == null ? null : max(1, min(7, _asInt(rawActivity['sportGroupFrequency']))),
          activeInSportRotation: _asBool(rawActivity['activeInSportRotation'], true),
          isSportProgram: _asBool(rawActivity['isSportProgram']),
          sportDailyDurations: _asIntMap(rawActivity['sportDailyDurations']),
        ));
      }
      if (restoredActivities.isEmpty) return false;

      final restoredPlan = <PlanItem>[];
      for (final rawPlan in planData) {
        if (rawPlan is! Map) continue;
        final id = _asString(rawPlan['id']);
        final day = _asInt(rawPlan['day'], 0);
        final period = _asString(rawPlan['period']) ?? 'Après-midi';
        final title = _asString(rawPlan['title']);
        if (id == null || title == null || day < 0 || day > 6) continue;
        final activityId = _asString(rawPlan['activityId']);
        if (activityId != null && !restoredActivities.any((a) => a.id == activityId)) continue;
        restoredPlan.add(PlanItem(
          id: id,
          activityId: activityId,
          day: day,
          period: period,
          timeLabel: _asString(rawPlan['timeLabel']),
          title: title,
          details: _asString(rawPlan['details']),
          customEmoji: _asString(rawPlan['customEmoji']),
          customCategory: _asString(rawPlan['customCategory']),
          duration: max(1, _asInt(rawPlan['duration'], 30)),
          optional: _asBool(rawPlan['optional']),
          userAdded: _asBool(rawPlan['userAdded']),
          fixedInWeeklyTemplate: _asBool(rawPlan['fixedInWeeklyTemplate']),
          done: _asBool(rawPlan['done']),
          realisedMinutes: _asBool(rawPlan['done']) ? max(1, _asInt(rawPlan['duration'], 30)) : null,
          feeling: _asString(rawPlan['feeling']),
        ));
      }

      final restoredLogs = <ActivityLog>[];
      for (final rawLog in logData) {
        if (rawLog is! Map) continue;
        final dateRaw = _asString(rawLog['date']);
        final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);
        final title = _asString(rawLog['title']);
        if (date == null || title == null) continue;
        final day = _asInt(rawLog['day'], 0);
        if (day < 0 || day > 6) continue;
        restoredLogs.add(ActivityLog(
          date: date,
          title: title,
          emoji: _asString(rawLog['emoji']) ?? '📍',
          category: _asString(rawLog['category']) ?? 'Autre',
          period: _asString(rawLog['period']) ?? 'Après-midi',
          day: day,
          plannedMinutes: max(0, _asInt(rawLog['plannedMinutes'])),
          realisedMinutes: max(0, _asInt(rawLog['plannedMinutes'])),
          feeling: _asString(rawLog['feeling']) ?? 'Bien',
          unplanned: _asBool(rawLog['unplanned']),
          planItemId: _asString(rawLog['planItemId']),
          activityId: _asString(rawLog['activityId']),
        ));
      }

      setState(() {
        activities
          ..clear()
          ..addAll(restoredActivities);
        plan
          ..clear()
          ..addAll(restoredPlan);
        logs
          ..clear()
          ..addAll(restoredLogs);
        weeklyNote = _asString(root['weeklyNote']) ?? '';
        sportCoachLastAnalysis = _asString(root['sportCoachLastAnalysis']) ?? '';
        final coachDate = _asString(root['sportCoachLastAnalysisAt']);
        sportCoachLastAnalysisAt = coachDate == null ? null : DateTime.tryParse(coachDate);
        sportCoachSuggestion = _asString(root['sportCoachSuggestion']) ?? '';
        sportCoachSuggestionDelta = _asInt(root['sportCoachSuggestionDelta']);
        sportCoachDailyAdjustments = _asIntMap(root['sportCoachDailyAdjustments']);
        final rawCoachLogs = root['sportCoachLogs'];
        final restoredCoachLogs = <SportCoachLog>[];
        if (rawCoachLogs is List) {
          for (final raw in rawCoachLogs) {
            if (raw is! Map) continue;
            final rawDate = _asString(raw['date']);
            final date = rawDate == null ? null : DateTime.tryParse(rawDate);
            final activityName = _asString(raw['activityName']);
            final message = _asString(raw['message']);
            if (date == null || activityName == null || message == null) continue;
            restoredCoachLogs.add(SportCoachLog(
              date: date,
              activityName: activityName,
              message: message,
              adjustment: _asString(raw['adjustment']),
            ));
          }
        }
        sportCoachLogs = restoredCoachLogs;
        final thought = _asString(root['morningThought']);
        if (thought != null && thought.isNotEmpty) _morningThought = thought;
      });
      _queueLocalStatePersist();
      _showFeedback('Sauvegarde restaurée.');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetDatabaseCompletely() async {
    if (!mounted) return;

    // RÉINITIALISATION = base vierge de tout SAUF des activités.
    // Les activités restent exactement telles qu’elles sont aujourd’hui,
    // y compris les activités ajoutées ou modifiées par l’utilisateur.
    // Le planning est volontairement vidé : il devra être régénéré avec
    // le bouton « Repenser » lorsque l’utilisateur le souhaitera.
    final keptActivities = List<Activity>.from(activities);
    final emptyPlan = <PlanItem>[];
    final emptyLogs = <ActivityLog>[];
    final freshThought = morningThoughts[Random().nextInt(morningThoughts.length)];

    setState(() {
      activities = keptActivities;
      plan = emptyPlan;
      logs = emptyLogs;
      weeklyNote = '';
      sportCoachLastAnalysis = '';
      sportCoachLastAnalysisAt = null;
      sportCoachSuggestion = '';
      sportCoachSuggestionDelta = 0;
      sportCoachLogs = [];
      sportCoachDailyAdjustments = {};
      categoryFilter = 'Toutes';
      tab = 0;
      _morningThought = freshThought;
      _resetGeneration++;
    });

    await WidgetsBinding.instance.endOfFrame;

    if (mounted) {
      _queueLocalStatePersist();
      _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('✓ Base vierge · ${activities.length} activités conservées · planning vide'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void exportBackupFile() {
    final bytes = utf8.encode(_backupJson());
    final blob = html.Blob([bytes], 'application/json;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'mybestweek_backup_$dateStr.json')
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    _showFeedback('Sauvegarde téléchargée.');
  }

  Future<bool> importBackupFile() async {
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json'
      ..multiple = false;
    input.style
      ..position = 'fixed'
      ..left = '-10000px'
      ..top = '0'
      ..width = '1px'
      ..height = '1px'
      ..opacity = '0';
    html.document.body?.children.add(input);

    try {
      input.click();
      await input.onChange.first;
      final files = input.files;
      if (files == null || files.isEmpty) return false;

      final reader = html.FileReader();
      reader.readAsText(files[0]);
      await reader.onLoad.first;
      final raw = reader.result?.toString() ?? '';
      if (raw.trim().isEmpty) return false;

      final ok = restoreBackup(raw);
      if (!ok) {
        _showFeedback('Fichier de sauvegarde invalide.');
        return false;
      }
      _showFeedback('Sauvegarde restaurée.');
      return true;
    } finally {
      input.remove();
    }
  }

  void openDataManager() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _DataPage(
          onExport: exportBackupFile,
          onImport: importBackupFile,
          onReset: resetDatabaseCompletely,
        ),
      ),
    );
  }

  Activity? get _sportProgram {
    for (final a in activities) {
      if (a.isSportProgram) return a;
    }
    return null;
  }

  bool _isSportActivity(Activity activity) =>
      activity.category.toLowerCase() == 'sport' && !activity.isSportProgram;

  String _sportRotationKey(Activity activity) =>
      activity.sportGroup == null ? activity.id : 'group:${activity.sportGroup}';

  int _sportTargetFrequency(Activity activity) =>
      activity.sportGroupFrequency ?? activity.frequency;

  bool _logMatchesActivity(ActivityLog log, Activity activity) {
    if (log.activityId != null) return log.activityId == activity.id;
    return log.title.trim().toLowerCase() == activity.name.trim().toLowerCase();
  }

  void _syncCompletedValidationDuration(PlanItem item) {
    // Une validation signifie toujours que la durée de l'activité a été réalisée.
    // Il n'existe plus de saisie d'un temps réellement réalisé.
    if (!item.done) return;
    item.realisedMinutes = item.duration;
    final index = logs.indexWhere((log) => log.planItemId == item.id);
    if (index < 0) return;
    final old = logs[index];
    logs[index] = ActivityLog(
      date: old.date,
      title: item.title,
      emoji: old.emoji,
      category: old.category,
      period: item.period,
      day: item.day,
      plannedMinutes: item.duration,
      realisedMinutes: item.duration,
      feeling: old.feeling,
      unplanned: old.unplanned,
      planItemId: old.planItemId,
      activityId: old.activityId,
    );
  }

  void _setSportActivityRotation(Activity activity, bool active) {
    final index = activities.indexWhere((a) => a.id == activity.id);
    if (index < 0) return;
    final current = activities[index];
    final updated = Activity(
      id: current.id,
      name: current.name,
      emoji: current.emoji,
      category: current.category,
      duration: current.duration,
      frequency: current.frequency,
      priority: current.priority,
      preferredDays: [...current.preferredDays],
      sportWeight: current.sportWeight,
      sportGroup: current.sportGroup,
      sportGroupFrequency: current.sportGroupFrequency,
      activeInSportRotation: active,
      isSportProgram: current.isSportProgram,
      sportDailyDurations: {...current.sportDailyDurations},
    );
    setState(() {
      activities[index] = updated;
      if (!active) {
        // « Plus tard » retire uniquement les occurrences non réalisées de
        // cette semaine. L'historique des séances déjà réalisées est conservé.
        plan.removeWhere((item) => item.activityId == activity.id && !item.done);
        _sortPlan();
      } else {
        // Réactivation : l'activité redevient éligible à la rotation ET on
        // tente immédiatement de lui réserver une occurrence dans la semaine
        // courante. Les séances déjà réalisées restent totalement inchangées.
        _ensureReactivatedSportActivityInWeek(updated);
        _sortPlan();
      }
    });
    _queueLocalStatePersist();
    _showFeedback(active
        ? '✓ « ${current.name} » réactivée dans la rotation Sport.'
        : '⏸ « ${current.name} » mise de côté pour plus tard.');
  }

  void reactivateSportActivity(Activity activity) => _setSportActivityRotation(activity, true);
  void postponeSportActivity(Activity activity) => _setSportActivityRotation(activity, false);

  void openSportWeekOverview() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _SportWeekPage(
          dayNames: dayNames,
          getActivities: () => activities.where(_isSportActivity).toList(),
          getPlan: () => List<PlanItem>.from(plan),
          getLogs: () => List<ActivityLog>.from(logs),
          getSportDays: () => _sportDays().toSet(),
          getSportBudgets: () => {
            for (var day = 0; day < 7; day++) day: _sportBaseBudgetForDay(day),
          },
          onReactivate: reactivateSportActivity,
          onPostpone: postponeSportActivity,
          onToggleDay: toggleSportActivityOnDay,
          onSetBudget: _setSportDailyBudget,
        ),
      ),
    );
  }

  double _sportRotationScore(Activity activity, int day, Set<String> selectedToday,
      Map<String, int> generatedCount) {
    final now = DateTime.now();
    final recent14 = logs.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 0 && age < 14 && _logMatchesActivity(log, activity);
    }).toList();
    final recent30 = logs.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 0 && age < 30 && _logMatchesActivity(log, activity);
    }).toList();

    final last = recent30.isEmpty
        ? null
        : (recent30..sort((a, b) => b.date.compareTo(a.date))).first;
    final daysSinceLast = last == null ? 60 : now.difference(last.date).inDays;

    var score = activity.sportWeight * 5.0;
    score += activity.priority * 1.5;
    if (activity.preferredDays.contains(day)) score += 8.0;

    // Rotation historique : ce qui vient d’être fait descend, ce qui n’est
    // pas sorti depuis longtemps remonte.
    score += min(daysSinceLast, 14) * 1.15;
    score -= recent14.length * 4.0;
    score -= recent14.where((l) => l.feeling == 'Difficile').length * 3.0;
    score += recent14.where((l) => l.feeling == 'Très bien').length * 0.8;

    // Évite de remettre deux jours de suite exactement la même activité.
    if (selectedToday.contains(activity.id)) score -= 100.0;

    // Respecte aussi la fréquence propre de l’activité dans la semaine.
    score -= (generatedCount[activity.id] ?? 0) * 2.5;
    return score;
  }

  List<Activity> _chooseSportActivitiesForDay(
      int day, int budget, List<Activity> candidates,
      Map<String, int> remaining, Map<String, int> generatedCount,
      Set<String> previousDayIds) {
    if (budget <= 0 || candidates.isEmpty) return [];

    final available = candidates.where((a) =>
        a.activeInSportRotation &&
        (remaining[_sportRotationKey(a)] ?? 0) > 0 &&
        a.duration <= budget).toList();
    if (available.isEmpty) return [];

    // Petit sac à dos : on cherche la combinaison qui remplit au mieux le
    // budget quotidien sans couper artificiellement la durée d’une activité.
    final dp = <int, _SportChoice>{
      0: const _SportChoice(minutes: 0, score: 0, activities: []),
    };

    for (final activity in available) {
      final activityScore = _sportRotationScore(
        activity, day, <String>{...previousDayIds}, generatedCount,
      );
      final snapshot = Map<int, _SportChoice>.from(dp);
      for (final entry in snapshot.entries) {
        final newMinutes = entry.key + activity.duration;
        if (newMinutes > budget) continue;
        if (entry.value.activities.any((a) => _sportRotationKey(a) == _sportRotationKey(activity))) continue;
        final choice = _SportChoice(
          minutes: newMinutes,
          score: entry.value.score + activityScore,
          activities: [...entry.value.activities, activity],
        );
        final current = dp[newMinutes];
        if (current == null || choice.score > current.score) {
          dp[newMinutes] = choice;
        }
      }
    }

    final choices = dp.values.where((c) => c.activities.isNotEmpty).toList();
    choices.sort((a, b) {
      if (a.minutes != b.minutes) return b.minutes.compareTo(a.minutes);
      return b.score.compareTo(a.score);
    });
    if (choices.isEmpty) return [];

    final selected = choices.first.activities.toList();
    // Si plusieurs combinaisons ont la même couverture, le score historique
    // départage naturellement la rotation.
    selected.sort((a, b) => _sportRotationScore(b, day, <String>{}, generatedCount)
        .compareTo(_sportRotationScore(a, day, <String>{}, generatedCount)));
    return selected;
  }

  int _sportDayCount() {
    final program = _sportProgram;
    if (program == null) return 0;
    final customDays = program.sportDailyDurations.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();
    if (customDays.isNotEmpty) return customDays.length;
    return program.frequency.clamp(1, 7).toInt();
  }

  List<int> _sportDays() {
    final program = _sportProgram;
    if (program == null) return [];
    final customDays = program.sportDailyDurations.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList()..sort();
    if (customDays.isNotEmpty) return customDays;

    final target = _sportDayCount();
    final preferred = program.preferredDays.where((d) => d >= 0 && d < 7).toList()..sort();
    final result = <int>[];
    for (final day in preferred) {
      if (result.length >= target) break;
      if (!result.contains(day)) result.add(day);
    }
    for (var day = 0; day < 7 && result.length < target; day++) {
      if (!result.contains(day)) result.add(day);
    }
    return result;
  }

  int _sportBaseBudgetForDay(int day) {
    final program = _sportProgram;
    if (program == null) return 0;
    return program.sportDailyDurations.containsKey(day)
        ? max(0, program.sportDailyDurations[day] ?? 0)
        : (_sportDays().contains(day) ? max(1, program.duration) : 0);
  }

  int _sportBudgetForDay(int day) {
    return max(0, _sportBaseBudgetForDay(day) + (sportCoachDailyAdjustments[day] ?? 0));
  }

  void _generateSportPart(List<PlanItem> generated, int seqStart) {
    final sportActivities = activities.where((a) => _isSportActivity(a) && a.activeInSportRotation).toList();
    if (sportActivities.isEmpty || _sportProgram == null) return;

    final days = _sportDays();
    final generatedCount = <String, int>{for (final a in sportActivities) a.id: 0};
    var seq = seqStart;
    Set<String> previousDayIds = {};

    // Toutes les activités Sport sont des sous-items du programme générique.
    // Leur somme quotidienne est strictement plafonnée par la durée Sport
    // définie pour ce jour. Il n'y a plus de « séances Sport extra » hors budget.
    final compositeActivities = sportActivities.toList();
    final remaining = <String, int>{
      for (final a in compositeActivities)
        _sportRotationKey(a): _sportTargetFrequency(a).clamp(1, 7).toInt(),
    };

    for (final day in days) {
      final budget = _sportBudgetForDay(day);
      if (budget <= 0) continue;
      final selected = _chooseSportActivitiesForDay(
        day, budget, compositeActivities, remaining, generatedCount, previousDayIds,
      );
      final selectedIds = selected.map((a) => a.id).toSet();
      var usedMinutes = 0;
      for (final activity in selected) {
        if (usedMinutes + activity.duration > budget) continue;
        generated.add(PlanItem(
          id: 'sport_${DateTime.now().microsecondsSinceEpoch}_$seq',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · ${budget} min disponibles ce jour · rotation selon historique, poids et fréquence.',
          duration: activity.duration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        usedMinutes += activity.duration;
        remaining[_sportRotationKey(activity)] = max(0, (remaining[_sportRotationKey(activity)] ?? 0) - 1);
        generatedCount[activity.id] = (generatedCount[activity.id] ?? 0) + 1;
        seq++;
      }
      previousDayIds = selectedIds;
    }
  }

  void generateWeek({bool showSnack = true}) {
    // « Repenser » repart toujours d’un planning vide et uniquement des
    // activités actuellement présentes. Les éléments libres ajoutés par
    // l’utilisateur sont conservés, mais aucune ancienne séance planifiée ne
    // peut réapparaître.
    final personalMoments = plan
        .where((p) => p.userAdded && p.activityId == null)
        .map((p) => PlanItem(
              id: p.id,
              day: p.day,
              period: p.period,
              timeLabel: p.timeLabel,
              title: p.title,
              details: p.details,
              duration: p.duration,
              activityId: p.activityId,
              customEmoji: p.customEmoji,
              customCategory: p.customCategory,
              optional: p.optional,
              userAdded: true,
              fixedInWeeklyTemplate: false,
              done: false,
              realisedMinutes: null,
              feeling: null,
            ))
        .toList();

    final generated = <PlanItem>[];
    var seq = 0;

    // 1) Le sport est un programme composite : une journée Sport a une durée
    // totale définie par l’activité générique « Sport », puis elle est remplie
    // par plusieurs activités Sport réelles selon leurs propres fiches.
    _generateSportPart(generated, seq);
    seq = generated.length;

    // 2) Toutes les autres activités restent gérées par leur fréquence,
    // priorité et jours préférés.
    final normalActivities = activities.where((a) => !_isSportActivity(a) && !a.isSportProgram).toList();
    final usedByActivity = <String, Set<int>>{
      for (final a in normalActivities) a.id: <int>{},
    };

    final orderedActivities = [...normalActivities]
      ..sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return b.frequency.compareTo(a.frequency);
      });

    for (final activity in orderedActivities) {
      final target = activity.frequency.clamp(1, 7).toInt();
      for (var occurrence = 0; occurrence < target; occurrence++) {
        final candidates = List<int>.generate(7, (i) => i)
          ..sort((a, b) {
            final aPreferred = activity.preferredDays.contains(a) ? 0 : 1;
            final bPreferred = activity.preferredDays.contains(b) ? 0 : 1;
            if (aPreferred != bPreferred) return aPreferred.compareTo(bPreferred);

            final aSameActivity = usedByActivity[activity.id]!.contains(a) ? 1 : 0;
            final bSameActivity = usedByActivity[activity.id]!.contains(b) ? 1 : 0;
            if (aSameActivity != bSameActivity) return aSameActivity.compareTo(bSameActivity);

            int load(int day) => generated.where((p) => p.day == day).fold<int>(0, (sum, p) => sum + p.duration);
            final loadCompare = load(a).compareTo(load(b));
            if (loadCompare != 0) return loadCompare;
            return a.compareTo(b);
          });

        final chosenDay = candidates.firstWhere(
          (day) => !usedByActivity[activity.id]!.contains(day),
          orElse: () => candidates.first,
        );
        usedByActivity[activity.id]!.add(chosenDay);

        generated.add(PlanItem(
          id: 'gen_${DateTime.now().microsecondsSinceEpoch}_$seq',
          day: chosenDay,
          period: _periodForActivity(activity, chosenDay),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Créneau généré à partir de ta fiche activité.',
          duration: activity.duration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        seq++;
      }
    }

    plan
      ..clear()
      ..addAll(generated)
      ..addAll(personalMoments);
    _sortPlan();

    setState(() {});
    _queueLocalStatePersist();
    if (showSnack && mounted) {
      final sportDays = _sportDays();
      final totalSportMinutes = sportDays.fold<int>(0, (sum, day) => sum + _sportBudgetForDay(day));
      final sportMessage = sportDays.isEmpty
          ? ''
          : ' Sport : ${sportDays.length} jour(s) · ${totalSportMinutes} min/semaine, réparti selon l’historique et le poids.';
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Nouveau planning généré à partir de ${activities.length} activités.$sportMessage')),
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

  int completedCount() => plan.where((p) => p.done).length;

  List<PlanItem> itemsForDay(int day) => plan.where((p) => p.day == day).toList();

  String dateText() {
    final d = DateTime.now();
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
      'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void togglePlanItemDone(PlanItem item, bool checked) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    if (!checked) {
      setState(() {
        item.done = false;
        item.realisedMinutes = null;
        item.feeling = null;
        logs.removeWhere((log) => log.planItemId == item.id);
      });
      _queueLocalStatePersist();
      _showFeedback('Validation annulée pour « ${item.title} ».');
      return;
    }

    final now = DateTime.now();
    setState(() {
      item.done = true;
      item.realisedMinutes = item.duration;
      item.feeling = 'Validé';
      logs.removeWhere((log) => log.planItemId == item.id);
      logs.add(ActivityLog(
        date: now,
        title: item.title,
        emoji: activity?.emoji ?? item.customEmoji ?? '📍',
        category: activity?.category ?? item.customCategory ?? 'Autre',
        period: item.period,
        day: item.day,
        plannedMinutes: item.duration,
        realisedMinutes: item.duration,
        feeling: 'Validé',
        unplanned: item.activityId == null,
        planItemId: item.id,
        activityId: item.activityId,
      ));
    });
    if (activity != null && _isSportActivity(activity)) analyzeSportSession(item, activity);
    _queueLocalStatePersist();
    _showFeedback('✓ « ${item.title} » validé.');
  }

  void _completePlanItem(PlanItem item, Activity activity, [int? ignoredMinutes]) {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      item.done = true;
      item.realisedMinutes = item.duration;
      item.feeling = 'Validé';
      logs.removeWhere((log) => log.planItemId == item.id);
      logs.add(ActivityLog(
        date: now,
        title: item.title,
        emoji: activity.emoji,
        category: activity.category,
        period: item.period,
        day: item.day,
        plannedMinutes: item.duration,
        realisedMinutes: item.duration,
        feeling: 'Validé',
        unplanned: false,
        planItemId: item.id,
        activityId: item.activityId,
      ));
    });
    if (_isSportActivity(activity)) analyzeSportSession(item, activity);
    _queueLocalStatePersist();
    _showFeedback('✓ « ${item.title} » validé · ${item.duration} min.');
  }

  void openPlanItem(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    if (item.done) {
      togglePlanItemDone(item, false);
      return;
    }
    if (activity == null) {
      togglePlanItemDone(item, true);
      return;
    }
    togglePlanItemDone(item, true);
  }


  void openItemActions(PlanItem item) {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text('${item.duration} min', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF526B78))),
                ],
              ),
              const SizedBox(height: 6),
              Text('${item.period}${item.userAdded ? (item.activityId != null ? ' · ajouté au planning' : ' · ajout personnel') : ''}'),
              if (item.done) ...[
                const SizedBox(height: 8),
                const Text('✓ Ce moment est déjà validé.', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6F8E80))),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    togglePlanItemDone(item, !item.done);
                  },
                  icon: Icon(item.done ? Icons.undo : Icons.check_circle_outline),
                  label: Text(item.done ? 'Annuler la validation' : 'Valider ce moment'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    editPlanItem(item);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier ce moment'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() => plan.removeWhere((p) => p.id == item.id));
                    _scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text('« ${item.title} » retiré de la semaine.')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Retirer de la semaine'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void editPlanItem(PlanItem item) {
    final title = TextEditingController(text: item.title);
    final details = TextEditingController(text: item.details ?? '');
    final duration = TextEditingController(text: '${item.duration}');
    var period = item.period;

    showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Modifier le moment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: details,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Détail / note'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: 'Moment'),
                  items: const ['Matin', 'Après-midi', 'Soir']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => period = v ?? period),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Durée (min)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final newTitle = title.text.trim();
                if (newTitle.isEmpty) return;
                final newDuration = int.tryParse(duration.text) ?? item.duration;
                final safeDuration = newDuration < 1 ? 1 : newDuration;
                final activity = item.activityId == null ? null : findActivity(item.activityId!);
                if (activity != null && _isSportActivity(activity)) {
                  final budget = _sportBudgetForDay(item.day);
                  final otherSport = _sportItemsForDay(item.day)
                      .where((p) => p.id != item.id)
                      .fold<int>(0, (sum, p) => sum + p.duration);
                  if (otherSport + safeDuration > budget) {
                    _showFeedback('Cette modification dépasserait le plafond Sport de ${dayNames[item.day]} (${budget} min).');
                    return;
                  }
                }
                setState(() {
                  item.period = period;
                  item.title = newTitle;
                  item.details = details.text.trim().isEmpty ? null : details.text.trim();
                  item.duration = safeDuration;
                  _syncCompletedValidationDuration(item);
                });
                _queueLocalStatePersist();
                Navigator.pop(dialogContext);
                _scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(content: Text('« ${item.title} » modifié.')),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      title.dispose();
      details.dispose();
      duration.dispose();
    });
  }

  Future<void> addUnplannedToDay(int day) async {
    final result = await _navigatorKey.currentState?.push<_NewMomentResult>(
      MaterialPageRoute(
        builder: (_) => _AddMomentPage(dayName: dayNames[day]),
      ),
    );

    if (!mounted || result == null) return;

    if (result.category == 'Sport') {
      final budget = _sportBudgetForDay(day);
      final currentSport = _sportItemsForDay(day).fold<int>(0, (sum, item) => sum + item.duration);
      if (budget <= 0 || currentSport + result.duration > budget) {
        _showFeedback('Ce moment Sport dépasserait le plafond de ${budget} min prévu pour ${dayNames[day]}.');
        return;
      }
    }

    final newItem = PlanItem(
      id: 'extra_${DateTime.now().microsecondsSinceEpoch}',
      day: day,
      period: result.period,
      title: result.title,
      duration: result.duration,
      customEmoji: result.emoji,
      customCategory: result.category,
      optional: false,
      userAdded: true,
    );

    setState(() {
      plan.add(newItem);
      plan.sort((a, b) {
        final dayCompare = a.day.compareTo(b.day);
        if (dayCompare != 0) return dayCompare;
        const order = {'Matin': 0, 'Après-midi': 1, 'Soir': 2};
        final periodCompare = (order[a.period] ?? 9).compareTo(order[b.period] ?? 9);
        if (periodCompare != 0) return periodCompare;
        return a.id.compareTo(b.id);
      });
    });
    _queueLocalStatePersist();

    _showFeedback('« ${result.title} » ajouté à ${dayNames[day]}.');
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return monday;
  }

  List<ActivityLog> _currentWeekLogs() {
    final start = _startOfCurrentWeek();
    final end = start.add(const Duration(days: 7));
    return logs.where((log) => !log.date.isBefore(start) && log.date.isBefore(end)).toList();
  }

  void openWeeklyReview() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => _WeeklyReviewPage(
        plan: plan,
        logs: _currentWeekLogs(),
        activities: activities,
        weeklyNote: weeklyNote,
        onSaveNote: (value) => setState(() => weeklyNote = value),
      )),
    );
  }

  void openHistory() {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _HistorySheet(logs: logs, dayNames: dayNames),
    );
  }

  int _dayLoadMinutes(int day) => plan
      .where((p) => p.day == day)
      .fold<int>(0, (sum, p) => sum + p.duration);

  String _periodForActivity(Activity activity, int day) {
    switch (activity.category) {
      case 'Sport':
      case 'Bien-être':
      case 'Sortie':
        return 'Matin';
      case 'Culture':
        return 'Soir';
      case 'Social':
        return 'Soir';
      case 'Loisir':
        return day <= 2 ? 'Après-midi' : 'Soir';
      default:
        return 'Après-midi';
    }
  }

  List<int> _planningCandidates(Activity activity) {
    final all = List<int>.generate(7, (i) => i);
    final preferred = activity.preferredDays.where((d) => d >= 0 && d < 7).toSet();
    final candidates = [...all]..sort((a, b) {
      final ap = preferred.contains(a) ? 0 : 1;
      final bp = preferred.contains(b) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      final loadCompare = _dayLoadMinutes(a).compareTo(_dayLoadMinutes(b));
      if (loadCompare != 0) return loadCompare;
      return a.compareTo(b);
    });
    return candidates;
  }

  void _sortPlan() {
    plan.sort((a, b) {
      final dayCompare = a.day.compareTo(b.day);
      if (dayCompare != 0) return dayCompare;
      const order = {'Matin': 0, 'Après-midi': 1, 'Soir': 2};
      final periodCompare = (order[a.period] ?? 9).compareTo(order[b.period] ?? 9);
      if (periodCompare != 0) return periodCompare;
      return a.id.compareTo(b.id);
    });
  }

  bool _sameDays(List<int> a, List<int> b) {
    final aa = [...a]..sort();
    final bb = [...b]..sort();
    if (aa.length != bb.length) return false;
    for (var i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
  }

  void _syncActivityToWeek(Activity activity, {Activity? previous}) {
    final linked = plan.where((p) => p.activityId == activity.id).toList();

    // Les éléments du planning modèle (lundi piano 2 h, vendredi grande marche,
    // etc.) restent des piliers de la semaine. Une modification de la fiche
    // activité met à jour leur nom et leur durée, mais ne les supprime pas au
    // seul motif que la fréquence a changé.
    for (final item in linked) {
      item.duration = activity.duration;
      if (previous != null && item.title.contains(previous.name)) {
        item.title = item.title.replaceFirst(previous.name, activity.name);
      }
      _syncCompletedValidationDuration(item);
    }

    // Les activités Sport réelles sont des composants du programme générique
    // « Sport ». Elles ne doivent pas être ajoutées une par une dans le
    // planning : leur fréquence et leur rotation sont recalculées au prochain
    // clic sur « Repenser ».
    if (_isSportActivity(activity) || activity.isSportProgram) {
      _sortPlan();
      return;
    }

    // Seuls les créneaux ajoutés automatiquement depuis la fiche activité
    // peuvent être déplacés ou ajustés par la fréquence / les jours préférés.
    final generated = linked.where((p) => p.userAdded && !p.fixedInWeeklyTemplate).toList();

    if (previous != null && !_sameDays(previous.preferredDays, activity.preferredDays)) {
      final preferred = activity.preferredDays.where((d) => d >= 0 && d < 7).toList()..sort();
      final movable = generated.where((item) => !item.done).toList()
        ..sort((a, b) => _dayLoadMinutes(b.day).compareTo(_dayLoadMinutes(a.day)));
      for (final desiredDay in preferred) {
        if (generated.any((item) => item.day == desiredDay)) continue;
        if (movable.isEmpty) break;
        final old = movable.removeAt(0);
        final replacement = PlanItem(
          id: old.id,
          day: desiredDay,
          period: _periodForActivity(activity, desiredDay),
          timeLabel: old.timeLabel,
          activityId: old.activityId,
          title: old.title,
          details: old.details,
          customEmoji: old.customEmoji,
          customCategory: old.customCategory,
          duration: old.duration,
          optional: old.optional,
          userAdded: old.userAdded,
          fixedInWeeklyTemplate: old.fixedInWeeklyTemplate,
          done: old.done,
          realisedMinutes: old.realisedMinutes,
          feeling: old.feeling,
        );
        final index = plan.indexWhere((item) => item.id == old.id);
        if (index >= 0) plan[index] = replacement;
      }
    }

    // Une nouvelle activité personnelle apparaît immédiatement dans la semaine.
    // Pour une activité déjà personnalisée, fréquence et jours préférés ajustent
    // uniquement ses créneaux générés, sans toucher au cadre hebdomadaire fixe.
    final frequencyChanged = previous == null || previous.frequency != activity.frequency;
    if (frequencyChanged) {
      final managed = plan.where((p) => p.activityId == activity.id && p.userAdded && !p.fixedInWeeklyTemplate).toList();
      final currentCount = managed.length;
      final target = activity.frequency.clamp(1, 7).toInt();

      if (currentCount > target) {
        final removable = [...managed]..sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          final ap = activity.preferredDays.contains(a.day) ? 1 : 0;
          final bp = activity.preferredDays.contains(b.day) ? 1 : 0;
          if (ap != bp) return ap.compareTo(bp);
          return _dayLoadMinutes(b.day).compareTo(_dayLoadMinutes(a.day));
        });
        final idsToRemove = removable.take(currentCount - target).map((p) => p.id).toSet();
        plan.removeWhere((p) => idsToRemove.contains(p.id));
      }

      var safety = 0;
      while (plan.where((p) => p.activityId == activity.id && p.userAdded && !p.fixedInWeeklyTemplate).length < target && safety < 30) {
        final candidates = _planningCandidates(activity);
        final day = candidates[safety % candidates.length];
        final alreadyThisDay = plan.any((p) => p.activityId == activity.id && p.day == day && p.userAdded && !p.fixedInWeeklyTemplate);
        if (!alreadyThisDay) {
          plan.add(PlanItem(
            id: 'activity_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_$safety',
            day: day,
            period: _periodForActivity(activity, day),
            activityId: activity.id,
            title: activity.name,
            duration: activity.duration,
            userAdded: true,
          ));
        }
        safety++;
      }
    }

    _sortPlan();
  }

  void addOrEditActivity({Activity? original}) {
    final edit = original != null;
    final draft = original?.copy() ?? Activity(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      emoji: '✨',
      category: 'Loisir',
      duration: 30,
      frequency: 1,
      priority: 3,
    );
    final name = TextEditingController(text: draft.name);
    final duration = TextEditingController(text: '${draft.duration}');
    var category = draft.category;
    var emoji = draft.emoji;
    var frequency = draft.frequency;
    var priority = draft.priority;
    var sportWeight = draft.sportWeight;
    var preferred = Set<int>.from(draft.preferredDays);
    final sportGroup = draft.sportGroup;
    final sportGroupFrequency = draft.sportGroupFrequency;
    var activeInSportRotation = draft.activeInSportRotation;
    final sportDailyDurations = {...draft.sportDailyDurations};

    // Toujours inclure la valeur actuellement enregistrée dans les listes
    // déroulantes. Cela évite l'assertion Flutter si une ancienne sauvegarde
    // contient une icône ou une catégorie qui n'est plus proposée aujourd'hui.
    final categoryOptions = <String>[
      'Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social'
    ];
    if (!categoryOptions.contains(category)) {
      categoryOptions.insert(0, category);
    }

    final emojiOptions = <String>[
      '🚶', '🏊', '💪', '🧘', '🎹', '📖', '🧺', '🥂',
      '🚴', '🌱', '🎨', '✨'
    ];
    if (!emojiOptions.contains(emoji)) {
      emojiOptions.insert(0, emoji);
    }

    showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(edit ? 'Modifier l’activité' : 'Nouvelle activité'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categoryOptions
                      .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: emoji,
                  decoration: const InputDecoration(labelText: 'Icône'),
                  items: emojiOptions
                      .map((v) => DropdownMenuItem<String>(value: v, child: Text(v, style: const TextStyle(fontSize: 20))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => emoji = v ?? emoji),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Durée de référence (min)'),
                ),
                if (draft.isSportProgram) ...[
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text('Durée Sport par jour', style: TextStyle(fontWeight: FontWeight.w900))),
                  const SizedBox(height: 4),
                  const Align(alignment: Alignment.centerLeft, child: Text('Le curseur fixe le plafond quotidien. Les activités Sport restent à l’intérieur de ce budget.', style: TextStyle(fontSize: 12, color: Color(0xFF6F7777)))),
                  const SizedBox(height: 6),
                  ...List.generate(7, (day) => _SportDailySlider(
                    label: dayNames[day],
                    value: sportDailyDurations[day] ?? 0,
                    onChanged: (v) => setDialogState(() => sportDailyDurations[day] = v),
                  )),
                ],
                const SizedBox(height: 10),
                _StepperLine(label: 'Fréquence / semaine', value: frequency, min: 1, max: 7, onChanged: (v) => setDialogState(() => frequency = v)),
                _StepperLine(label: 'Priorité', value: priority, min: 1, max: 5, onChanged: (v) => setDialogState(() => priority = v)),
                if (category == 'Sport')
                  _StepperLine(label: 'Poids dans la rotation sport', value: sportWeight, min: 1, max: 10, onChanged: (v) => setDialogState(() => sportWeight = v)),
                if (category == 'Sport' && !draft.isSportProgram) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: activeInSportRotation ? const Color(0xFFEAF1ED) : const Color(0xFFF1EEE8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: activeInSportRotation ? const Color(0xFFC9D9CF) : const Color(0xFFDCD8CF),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🏃', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeInSportRotation ? 'Dans la rotation Sport' : 'Mise en attente · « Plus tard »',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeInSportRotation
                                    ? 'L’activité pourra être proposée cette semaine.'
                                    : 'L’activité reste enregistrée et pourra être réactivée depuis Semaine Sport.',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F7777)),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: activeInSportRotation,
                          onChanged: (value) => setDialogState(() => activeInSportRotation = value),
                        ),
                      ],
                    ),
                  ),
                ],
                if (category == 'Sport' && sportGroup != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      activeInSportRotation
                          ? 'Rotation : ${sportGroup!} · cible ${sportGroupFrequency ?? frequency}×/semaine'
                          : 'Rotation : ${sportGroup!} · mise en attente (« plus tard »)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Jours préférés', style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (day) {
                    final selected = preferred.contains(day);
                    return FilterChip(
                      selected: selected,
                      label: Text(dayNames[day].substring(0, 3)),
                      onSelected: (_) => setDialogState(() {
                        if (selected) {
                          preferred.remove(day);
                        } else {
                          preferred.add(day);
                        }
                      }),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            if (edit)
              TextButton(
                onPressed: () {
                  setState(() {
                    activities.removeWhere((a) => a.id == original.id);
                    plan.removeWhere((p) => p.activityId == original.id);
                  });
                  _queueLocalStatePersist();
                  Navigator.pop(context);
                },
                child: const Text('Supprimer'),
              ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                final updated = Activity(
                  id: draft.id,
                  name: name.text.trim(),
                  emoji: emoji,
                  category: category,
                  duration: int.tryParse(duration.text) ?? 30,
                  frequency: frequency,
                  priority: priority,
                  preferredDays: preferred.toList()..sort(),
                  sportWeight: sportWeight,
                  sportGroup: sportGroup,
                  sportGroupFrequency: sportGroupFrequency,
                  activeInSportRotation: activeInSportRotation,
                  isSportProgram: draft.isSportProgram,
                  sportDailyDurations: draft.isSportProgram ? {...sportDailyDurations} : draft.sportDailyDurations,
                );
                final changedSportDays = <int>[];
                if (draft.isSportProgram) {
                  for (var day = 0; day < 7; day++) {
                    final before = draft.sportDailyDurations[day] ?? 0;
                    final after = sportDailyDurations[day] ?? 0;
                    if (before != after) changedSportDays.add(day);
                  }
                }
                setState(() {
                  if (edit) {
                    final index = activities.indexWhere((a) => a.id == original.id);
                    if (index >= 0) activities[index] = updated;
                    _syncActivityToWeek(updated, previous: original);
                  } else {
                    activities.add(updated);
                    _syncActivityToWeek(updated);
                  }
                  if (updated.isSportProgram) {
                    for (final day in changedSportDays) {
                      _refreshSportDay(day);
                    }
                    _sortPlan();
                  }
                });
                _queueLocalStatePersist();
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(edit
                          ? '« ${updated.name} » modifiée.'
                          : '« ${updated.name} » ajoutée.'),
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }


  List<int> _futureSportDays() {
    return _sportDays().where((d) => d > today).toList()..sort();
  }

  int? _nextSportDay() {
    final future = _futureSportDays();
    if (future.isNotEmpty) return future.first;
    final all = _sportDays()..sort();
    for (final d in all) {
      if (d >= 0 && d < today) return d;
    }
    return null;
  }

  List<PlanItem> _sportItemsForDayMutable(int day) => plan.where((item) {
    if (item.day != day || item.activityId == null) return false;
    final activity = findActivity(item.activityId!);
    return activity != null && _isSportActivity(activity);
  }).toList();

  void _ensureReactivatedSportActivityInWeek(Activity activity) {
    if (!_isSportActivity(activity) || !activity.activeInSportRotation) return;

    final days = _sportDays().toSet().toList()..sort((a, b) {
      int distance(int day) => (day - today + 7) % 7;
      return distance(a).compareTo(distance(b));
    });
    if (days.isEmpty) return;

    if (plan.any((item) => item.activityId == activity.id && days.contains(item.day))) return;

    PlanItem? bestRemovalForDay(int day, List<PlanItem> items, int budget) {
      final removable = items.where((item) {
        if (item.done) return false;
        final other = item.activityId == null ? null : findActivity(item.activityId!);
        if (other == null || !_isSportActivity(other)) return false;
        return true;
      }).toList();
      if (removable.isEmpty) return null;
      removable.sort((a, b) {
        final aa = a.activityId == null ? null : findActivity(a.activityId!);
        final bb = b.activityId == null ? null : findActivity(b.activityId!);
        final sa = aa == null ? 0.0 : _sportRotationScore(aa, day, <String>{}, <String, int>{});
        final sb = bb == null ? 0.0 : _sportRotationScore(bb, day, <String>{}, <String, int>{});
        return sa.compareTo(sb);
      });
      return removable.first;
    }

    for (final day in days) {
      final budget = _sportBudgetForDay(day);
      if (budget <= 0) continue;

      final items = _sportItemsForDayMutable(day);
      final List<PlanItem> sameGroup = activity.sportGroup == null
          ? <PlanItem>[]
          : items.where((item) {
              if (item.activityId == null) return false;
              final other = findActivity(item.activityId!);
              return other != null && _isSportActivity(other) && other.sportGroup == activity.sportGroup;
            }).toList();

      // Une séance du même groupe est remplaçable uniquement si elle n'est pas réalisée.
      if (sameGroup.isNotEmpty && sameGroup.any((item) => item.done)) continue;
      if (sameGroup.isNotEmpty) {
        final replace = sameGroup.first;
        final usedWithoutReplace = items.fold<int>(0, (sum, item) => sum + (item.id == replace.id ? 0 : item.duration));
        if (usedWithoutReplace + activity.duration <= budget) {
          plan.removeWhere((item) => item.id == replace.id);
          plan.add(PlanItem(
            id: 'sport_reactivated_${DateTime.now().microsecondsSinceEpoch}_$day',
            day: day,
            period: _periodForActivity(activity, day),
            timeLabel: null,
            activityId: activity.id,
            title: activity.name,
            details: 'Sport · activité réactivée cette semaine.',
            duration: activity.duration,
            optional: false,
            userAdded: false,
            fixedInWeeklyTemplate: false,
          ));
          return;
        }
      }

      var used = items.fold<int>(0, (sum, item) => sum + item.duration);
      while (used + activity.duration > budget) {
        final removable = bestRemovalForDay(day, _sportItemsForDayMutable(day), budget);
        if (removable == null) break;
        used -= removable.duration;
        plan.removeWhere((item) => item.id == removable.id);
      }

      final nowItems = _sportItemsForDayMutable(day);
      final finalUsed = nowItems.fold<int>(0, (sum, item) => sum + item.duration);
      final groupConflict = activity.sportGroup != null && nowItems.any((item) {
        if (item.activityId == null) return false;
        final other = findActivity(item.activityId!);
        return other != null && _isSportActivity(other) && other.sportGroup == activity.sportGroup;
      });
      if (finalUsed + activity.duration <= budget && !groupConflict) {
        plan.add(PlanItem(
          id: 'sport_reactivated_${DateTime.now().microsecondsSinceEpoch}_$day',
          day: day,
          period: _periodForActivity(activity, day),
          timeLabel: null,
          activityId: activity.id,
          title: activity.name,
          details: 'Sport · activité réactivée cette semaine.',
          duration: activity.duration,
          optional: false,
          userAdded: false,
          fixedInWeeklyTemplate: false,
        ));
        return;
      }
    }
  }


  void _setSportDailyBudget(int day, int minutes) {
    final program = _sportProgram;
    if (program == null || day < 0 || day > 6) return;
    final safeMinutes = (minutes.clamp(0, 240) ~/ 5) * 5;
    final durations = <int, int>{...program.sportDailyDurations, day: safeMinutes};
    final updated = Activity(
      id: program.id,
      name: program.name,
      emoji: program.emoji,
      category: program.category,
      duration: program.duration,
      frequency: program.frequency,
      priority: program.priority,
      preferredDays: [...program.preferredDays],
      sportWeight: program.sportWeight,
      sportGroup: program.sportGroup,
      sportGroupFrequency: program.sportGroupFrequency,
      activeInSportRotation: program.activeInSportRotation,
      isSportProgram: true,
      sportDailyDurations: durations,
    );
    final index = activities.indexWhere((a) => a.id == program.id);
    if (index < 0) return;
    setState(() {
      activities[index] = updated;
      _refreshSportDay(day);
      _sortPlan();
    });
    _queueLocalStatePersist();
  }

  void _refreshSportDay(int day) {
    final budget = _sportBudgetForDay(day);
    final existing = _sportItemsForDayMutable(day);
    final completed = existing.where((item) => item.done).toList();
    plan.removeWhere((item) {
      if (item.day != day || item.activityId == null || item.done) return false;
      final activity = findActivity(item.activityId!);
      return activity != null && _isSportActivity(activity);
    });

    if (budget <= 0) return;
    final reserved = completed.fold<int>(0, (sum, item) => sum + item.duration);
    final availableBudget = max(0, budget - reserved);
    if (availableBudget <= 0) return;

    final candidates = activities.where((a) => _isSportActivity(a) && a.activeInSportRotation).toList();
    final generatedCount = <String, int>{};
    final remaining = <String, int>{};
    for (final a in candidates) {
      final key = _sportRotationKey(a);
      final existingCount = plan.where((p) {
        if (p.activityId == null) return false;
        final other = findActivity(p.activityId!);
        return other != null && _isSportActivity(other) && _sportRotationKey(other) == key;
      }).length;
      remaining[key] = max(0, _sportTargetFrequency(a) - existingCount);
      generatedCount[a.id] = 0;
    }

    final previousDayIds = completed.map((item) => item.activityId).whereType<String>().toSet();
    final selected = _chooseSportActivitiesForDay(
      day,
      availableBudget,
      candidates,
      remaining,
      generatedCount,
      previousDayIds,
    );
    var seq = 0;
    for (final activity in selected) {
      final used = _sportItemsForDayMutable(day).fold<int>(0, (sum, item) => sum + item.duration);
      if (used + activity.duration > budget) continue;
      plan.add(PlanItem(
        id: 'sport_${DateTime.now().microsecondsSinceEpoch}_${day}_$seq',
        day: day,
        period: 'Matin',
        timeLabel: null,
        activityId: activity.id,
        title: activity.name,
        details: 'Sport · budget ${budget} min ce jour · rotation selon historique.',
        duration: activity.duration,
        optional: false,
        userAdded: false,
        fixedInWeeklyTemplate: false,
      ));
      seq++;
    }
    _sortPlan();
  }

  void _fitSportDayToBudget(int day) {
    final budget = _sportBudgetForDay(day);
    var items = _sportItemsForDayMutable(day)
      ..sort((a, b) => b.id.compareTo(a.id));
    var total = items.fold<int>(0, (sum, item) => sum + item.duration);
    while (total > budget && items.isNotEmpty) {
      final removable = items.firstWhere((i) => !i.done, orElse: () => items.last);
      if (removable.done) break;
      total -= removable.duration;
      plan.removeWhere((p) => p.id == removable.id);
      items = _sportItemsForDayMutable(day)..sort((a, b) => b.id.compareTo(a.id));
    }
  }

  void analyzeSportSession(PlanItem item, Activity activity) {
    if (!_isSportActivity(activity)) return;

    String message;
    String? adjustmentLabel;
    var delta = 0;

    if (item.feeling == 'Difficile') {
      delta = -10;
      message = 'J’ai analysé « ${activity.name} ». Le ressenti difficile justifie un peu plus de récupération.';
      adjustmentLabel = '−10 min sur le prochain jour Sport';
    } else if (item.feeling == 'Très bien') {
      message = 'J’ai analysé « ${activity.name} ». Le ressenti est très bon : je conserve le rythme prévu.';
    } else {
      message = 'J’ai analysé « ${activity.name} ». Rien ne justifie de changer le planning.';
    }

    final now = DateTime.now();
    setState(() {
      sportCoachLastAnalysis = message;
      sportCoachLastAnalysisAt = now;
      sportCoachSuggestion = adjustmentLabel ?? '';
      sportCoachSuggestionDelta = delta;
      sportCoachLogs.insert(0, SportCoachLog(
        date: now,
        activityName: activity.name,
        message: message,
        adjustment: adjustmentLabel,
      ));
      if (sportCoachLogs.length > 30) {
        sportCoachLogs = sportCoachLogs.take(30).toList();
      }
    });
    _queueLocalStatePersist();
  }

  void applySportCoachSuggestion() {
    if (sportCoachSuggestionDelta >= 0 || sportCoachSuggestion.isEmpty) return;
    final day = _nextSportDay();
    if (day == null) {
      _showFeedback('Aucun prochain jour Sport disponible pour appliquer l’ajustement.');
      return;
    }

    final delta = sportCoachSuggestionDelta;
    final current = _sportBudgetForDay(day);
    final next = max(0, current + delta);
    // L’ajustement du coach est séparé de la durée choisie par l’utilisateur.
    // La valeur de base par jour reste donc intacte.
    final baseAdjustment = sportCoachDailyAdjustments[day] ?? 0;
    final targetAdjustment = baseAdjustment + sportCoachSuggestionDelta;

    setState(() {
      sportCoachDailyAdjustments[day] = targetAdjustment;
      sportCoachSuggestion = '';
      sportCoachSuggestionDelta = 0;
      _fitSportDayToBudget(day);
      sportCoachLogs.insert(0, SportCoachLog(
        date: DateTime.now(),
        activityName: 'Ajustement du planning',
        message: 'Le coach Sport a allégé ${dayNames[day]} de ${-delta} min.',
        adjustment: '${dayNames[day]} · ${current} → ${next} min',
      ));
    });
    _queueLocalStatePersist();
    _showFeedback('Coach Sport appliqué pour ${dayNames[day]}.');
  }

  void openSportCoachJournal() {
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SportCoachJournalSheet(logs: sportCoachLogs, dayNames: dayNames),
    );
  }

  String coachMessage() {
    if (logs.isEmpty) {
      return 'Pas encore assez de retours pour ajuster la semaine. Le planning reste simple et respirable.';
    }
    final recent = logs.where((l) => DateTime.now().difference(l.date).inDays < 7).toList();
    if (recent.isEmpty) {
      return 'Cette semaine repart tranquillement. Je garde le rythme prévu en attendant de nouveaux retours.';
    }
    return 'J’ai regardé les derniers passages et validations. Le planning peut continuer sans changement majeur.';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyBestWeek',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        platform: TargetPlatform.iOS,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF607786),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF526B78),
          onPrimary: Colors.white,
          secondary: const Color(0xFF7D988D),
          onSecondary: Colors.white,
          tertiary: const Color(0xFFC67E67),
          onTertiary: Colors.white,
          surface: const Color(0xFFFFFDF8),
          onSurface: const Color(0xFF33414A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5F0),
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF33414A),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          toolbarHeight: 52,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF33414A),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFEFB),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shadowColor: const Color(0x16000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5E1D9)),
          ),
        ),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(44, 44)),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: Color(0xFFD7D2C8)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFBF9F4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD9D5CB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD9D5CB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF526B78), width: 1.6)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFEFB),
          indicatorColor: const Color(0xFFDCE7EA),
          height: 66,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF52616A))),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFD9D5CB)),
          backgroundColor: const Color(0xFFFAF8F3),
          selectedColor: const Color(0xFFDCE5E7),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: Scaffold(
        key: ValueKey('root-$_resetGeneration'),
        body: SafeArea(
          bottom: false,
          child: KeyedSubtree(
            key: ValueKey('content-$_resetGeneration'),
            child: IndexedStack(index: tab, children: [buildHome(), buildWeek(), buildActivities()]),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 4, 10, 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3DED5)),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (v) { setState(() => tab = v); },
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
                  NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Semaine'),
                  NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Activités'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget pageTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF33414A), letterSpacing: -0.35, height: 1.12)),
          const SizedBox(height: 5),
          Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: Color(0xFF6F7777), height: 1.3)),
        ]),
      );

  Widget mascotAvatar({double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE7D4C6), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Center(child: Text('🌸', style: TextStyle(fontSize: size * .48))),
    );
  }


String _formatCoachDateTime(DateTime value) {
  final d = value.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm · $hh:$min';
}

  Widget buildHome() {
    final todayItems = itemsForDay(today);
    final todaySportItems = _sportItemsForDay(today);
    final todayOtherItems = todayItems.where((item) {
      if (item.activityId == null) return true;
      final activity = findActivity(item.activityId!);
      return activity == null || !_isSportActivity(activity);
    }).toList();
    final trackableItems = plan.where((p) => p.activityId != null).toList();
    final progress = trackableItems.isEmpty ? 0.0 : trackableItems.where((x) => x.done).length / trackableItems.length;
    final todayDone = todayItems.where((x) => x.done).length;
    final sportBudget = _sportBudgetForDay(today);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
            child: Row(children: [
              mascotAvatar(size: 48),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MyBestWeek', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF33414A), letterSpacing: -0.35)),
                const SizedBox(height: 4),
                Text(dateText(), style: const TextStyle(color: Color(0xFF6F7777))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFFE8E3D7), borderRadius: BorderRadius.circular(14)),
                child: Text(version, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5F696B))),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: openDataManager,
                tooltip: 'Sauvegarde et données',
                icon: const Icon(Icons.save_outlined),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE0E8EA), Color(0xFFE8E9DE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD2D9D5)),
              ),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withOpacity(.82), shape: BoxShape.circle), child: const Center(child: Icon(Icons.wb_sunny_outlined, size: 29, color: Color(0xFFC67E67)))),
                const SizedBox(width: 14),
                const Expanded(child: Text('Une semaine à ton rythme.\nDes temps forts, et de vraies respirations.', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF3E4D55), height: 1.4))),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFF0E9DE),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3D6C5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFC67E67)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Pensée du matin',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Changer la pensée',
                                onPressed: refreshMorningThought,
                                icon: const Icon(Icons.refresh, size: 20),
                              ),
                            ],
                          ),
                          Text(
                            '« $_morningThought »',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF4F5758),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFE5EEE9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Aujourd’hui · ${dayNames[today]}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    if (todayItems.isNotEmpty) Text('$todayDone/${todayItems.length}'),
                  ]),
                  const SizedBox(height: 5),
                  Text(todayItems.isEmpty ? 'Journée libre. Profite-en.' : 'Ta journée, dans l’ordre : Sport, matin, midi et soir.'),
                  if (sportBudget > 0 || todaySportItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sportDayCard(today),
                  ],
                  const SizedBox(height: 10),
                  if (todayOtherItems.isEmpty)
                    const Text('Aucune autre activité prévue aujourd’hui.', style: TextStyle(color: Color(0xFF6F7777)))
                  else ...[
                    _todayPeriodSection('Matin', todayOtherItems.where((item) => item.period == 'Matin').toList()),
                    _todayPeriodSection('Midi', todayOtherItems.where((item) => item.period == 'Après-midi').toList()),
                    _todayPeriodSection('Soir', todayOtherItems.where((item) => item.period == 'Soir').toList()),
                  ],
                ]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFE7EDF0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    mascotAvatar(size: 42),
                    const SizedBox(width: 11),
                    Expanded(child: Text('COACH SPORT', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Journal du coach Sport',
                      onPressed: openSportCoachJournal,
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    sportCoachLastAnalysis.isEmpty
                        ? 'Aucune analyse récente. La prochaine analyse apparaîtra après ta prochaine séance Sport.'
                        : sportCoachLastAnalysis,
                    style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600),
                  ),
                  if (sportCoachLastAnalysisAt != null) ...[
                    const SizedBox(height: 5),
                    Text(_formatCoachDateTime(sportCoachLastAnalysisAt!), style: const TextStyle(fontSize: 11.5, color: Color(0xFF6F7777))),
                  ],
                  if (sportCoachSuggestion.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(color: const Color(0xFFF6F3EB), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Expanded(child: Text('Suggestion : $sportCoachSuggestion', style: const TextStyle(fontWeight: FontWeight.w800))),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: applySportCoachSuggestion,
                          icon: const Icon(Icons.bolt_outlined, size: 17),
                          label: const Text('Appliquer'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFE9EEE9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE5D9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.my_location_outlined, color: Color(0xFF6F8E80)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Focus du jour', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(_todayFocus(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF42534C))),
                          const SizedBox(height: 5),
                          Text(_todayFocusReason(), style: const TextStyle(color: Color(0xFF66706C), height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFF0EBDF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('La semaine en un coup d’œil', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: LinearProgressIndicator(value: progress, minHeight: 10, borderRadius: BorderRadius.circular(20))),
                    const SizedBox(width: 12),
                    Text('${trackableItems.where((x) => x.done).length} / ${trackableItems.length}'),
                  ]),
                  const SizedBox(height: 10),
                  Text(trackableItems.isEmpty ? 'Le programme est prêt.' : 'Continue sans pression : la régularité compte plus que la perfection.'),
                ]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFF3EEE4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3D6C5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.insights_outlined, color: Color(0xFFC67E67)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bilan de la semaine', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('Ce qui a réellement été fait, le piano, les activités et les moments imprévus.'),
                    ])),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: openWeeklyReview,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Voir'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: const Color(0xFFE7EDF0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Le regard du coach', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => generateWeek(), icon: const Icon(Icons.refresh), tooltip: 'Recharger le planning type'),
                  ]),
                  const SizedBox(height: 6),
                  Text(coachMessage()),
                  const SizedBox(height: 12),
                  TextButton.icon(onPressed: () => setState(() => tab = 1), icon: const Icon(Icons.calendar_month), label: const Text('Voir mon planning')),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _todayPeriodSection(String label, List<PlanItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF526B78))),
        const SizedBox(height: 4),
        ...items.map(todayCard),
      ]),
    );
  }

  Widget todayCard(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final category = activity?.category ?? (item.customCategory ?? 'Autre');
    final bg = item.optional ? const Color(0xFFF0EDE6) : _pastelFor(category);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 9, 6, 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.8))),
        child: Row(
          children: [
            Checkbox(
              value: item.done,
              onChanged: (value) {
                if (value == true || item.done) openPlanItem(item);
              },
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openItemActions(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(item.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: item.done ? TextDecoration.lineThrough : null))), if (item.optional) const Text('optionnel', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF7A7770)))]),
                    const SizedBox(height: 2),
                    Text(item.done
                        ? '${item.period} · ${item.duration} min · ✓ validé'
                        : '${item.period} · ${item.duration} min'),
                  ]),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Voir / modifier',
              visualDensity: VisualDensity.compact,
              onPressed: () => openItemActions(item),
              icon: const Icon(Icons.chevron_right, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodBadge(String period) {
    return Container(
      width: 67,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFFFFFDF8), borderRadius: BorderRadius.circular(12)),
      child: Text(period, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF526B78))),
    );
  }

  Color _pastelFor(String category) {
    switch (category) {
      case 'Sport': return const Color(0xFFE3ECE7);
      case 'Bien-être': return const Color(0xFFE7EAEA);
      case 'Loisir': return const Color(0xFFE9E5DD);
      case 'Culture': return const Color(0xFFF0E9D8);
      case 'Sortie': return const Color(0xFFF1E3DC);
      case 'Social': return const Color(0xFFE2E8EC);
      default: return const Color(0xFFEEECE7);
    }
  }

  List<PlanItem> _sportItemsForDay(int day) {
    return plan.where((item) {
      if (item.day != day || item.activityId == null) return false;
      final activity = findActivity(item.activityId!);
      return activity != null && _isSportActivity(activity);
    }).toList();
  }

  Widget _sportDayCard(int day) {
    final items = _sportItemsForDay(day);
    final target = _sportBudgetForDay(day);
    final planned = items.fold<int>(0, (sum, item) => sum + item.duration);
    final validated = items.where((item) => item.done).fold<int>(0, (sum, item) => sum + item.duration);
    final over = planned > target;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE2ECE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: over ? const Color(0xFFC67E67) : const Color(0xFFD4E0DA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏃', style: TextStyle(fontSize: 19)),
          const SizedBox(width: 7),
          Expanded(child: Text('Sport · $planned / $target min prévus · $validated min validés', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF526B78)))),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Semaine Sport',
            onPressed: openSportWeekOverview,
            icon: const Icon(Icons.calendar_view_week_outlined, size: 19),
          ),
        ]),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Aucune activité Sport proposée ce jour.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6F7777)))
        else
          ...items.map((item) => _sportItemRow(item)),
      ]),
    );
  }

  Widget _sportItemRow(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final emoji = activity?.emoji ?? '🏃';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openItemActions(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 6),
            Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, decoration: item.done ? TextDecoration.lineThrough : null))),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${item.duration} min', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF526B78))),
              const SizedBox(height: 3),
              if (activity != null) _sportWeeklyIndicator(activity),
            ]),
            const SizedBox(width: 5),
            Checkbox(value: item.done, onChanged: (v) { if (v == true || item.done) openPlanItem(item); }, visualDensity: VisualDensity.compact),
          ]),
        ),
      ),
    );
  }

  void toggleSportActivityOnDay(Activity activity, int day) {
    if (!_isSportActivity(activity)) return;

    PlanItem? item;
    for (final candidate in plan) {
      if (candidate.day == day && candidate.activityId == activity.id) {
        item = candidate;
        break;
      }
    }

    // Une occurrence existe déjà ce jour : la petite case ne fait que
    // valider/dévalider cette occurrence. Elle n'ouvre jamais un écran.
    if (item != null) {
      togglePlanItemDone(item, !item.done);
      return;
    }

    // Aucun item n'était prévu ce jour. On autorise tout de même la coche :
    // cela correspond au cas où l'activité a été réalisée un autre jour que
    // celui prévu. La coche reste alors active sur ce nouveau jour.
    final manualItem = PlanItem(
      id: 'sport_manual_${activity.id}_${day}_${DateTime.now().microsecondsSinceEpoch}',
      activityId: activity.id,
      day: day,
      period: _periodForActivity(activity, day),
      timeLabel: null,
      title: activity.name,
      details: 'Sport · réalisé ce jour, hors jour prévu.',
      duration: activity.duration,
      optional: false,
      userAdded: true,
      fixedInWeeklyTemplate: false,
    );

    setState(() {
      plan.add(manualItem);
      _sortPlan();
    });

    _completePlanItem(manualItem, activity);

    // Conserver l'information « réalisé un autre jour » dans l'historique.
    final logIndex = logs.indexWhere((log) => log.planItemId == manualItem.id);
    if (logIndex >= 0) {
      final old = logs[logIndex];
      logs[logIndex] = ActivityLog(
        date: old.date,
        title: old.title,
        emoji: old.emoji,
        category: old.category,
        period: old.period,
        day: old.day,
        plannedMinutes: old.plannedMinutes,
        realisedMinutes: old.realisedMinutes,
        feeling: old.feeling,
        unplanned: true,
        planItemId: old.planItemId,
        activityId: old.activityId,
      );
    }

    _queueLocalStatePersist();
    _showFeedback('✓ « ${activity.name} » réalisé ${dayNames[day]}.');
  }

  Widget _sportWeeklyIndicator(Activity activity) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (day) {
        PlanItem? item;
        for (final candidate in plan) {
          if (candidate.day == day && candidate.activityId == activity.id) {
            item = candidate;
            break;
          }
        }
        final active = item?.done == true;
        final planned = item != null && !item!.done;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(labels[day], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF6F7777))),
            const SizedBox(height: 1),
            // Les 7 cases sont uniquement des cases de suivi.
            // Aucune ne doit ouvrir l'écran de modification.
            InkWell(
              onTap: () => toggleSportActivityOnDay(activity, day),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF7D988D)
                      : planned
                          ? const Color(0xFFE5EEE9)
                          : const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF6C887A)
                        : const Color(0xFFBFCFC7),
                  ),
                ),
                child: active
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : planned
                        ? const Text('•', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF526B78)))
                        : null,
              ),
            ),
          ]),
        );
      }),
    );
  }

  Widget buildWeek() {
    final trackable = plan.where((p) => p.activityId != null).toList();
    final totalMinutes = trackable.fold<int>(0, (sum, p) => sum + p.duration);
    const periods = ['Matin', 'Après-midi', 'Soir'];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: pageTitle(
            'Ma semaine',
            'Un cadre simple : matin, après-midi, soirée. Le reste peut rester libre.',
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    const Icon(Icons.event_note_outlined, color: Color(0xFF526B78)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$totalMinutes min prévues · ${completedCount()} moment(s) validé(s)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: openWeeklyReview,
                      icon: const Icon(Icons.insights_outlined, size: 18),
                      label: const Text('Bilan'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Card(
              color: const Color(0xFFE5EEE9),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.self_improvement_outlined, color: Color(0xFF6F8E80)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Le planning est un cadre, pas une obligation. Garde du temps pour l’envie, la météo et les imprévus.',
                        style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: 7,
            itemBuilder: (context, day) {
              final isToday = day == today;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: isToday ? const Color(0xFFE7EDF0) : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                dayNames[day],
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                            ),
                            if (isToday)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCE5E7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'AUJOURD’HUI',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF526B78)),
                                ),
                              ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Ajouter un moment',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => addUnplannedToDay(day),
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF526B78)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _dayMood(day),
                        if (_sportBudgetForDay(day) > 0) ...[
                          const SizedBox(height: 7),
                          _sportDayCard(day),
                        ],
                        const SizedBox(height: 10),
                        ...periods.map((period) {
                          final periodItems = itemsForDay(day).where((item) {
                            if (item.period != period) return false;
                            // Les activités Sport appartiennent exclusivement au
                            // bloc Sport de l'en-tête de la journée. Elles ne
                            // doivent pas être répétées dans « Matin », même si
                            // leur créneau logique est le matin.
                            if (item.activityId != null) {
                              final activity = findActivity(item.activityId!);
                              if (activity != null && _isSportActivity(activity)) return false;
                            }
                            return true;
                          }).toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F1EB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    period,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF5E6D73)),
                                  ),
                                ),
                                if (periodItems.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(10, 7, 10, 3),
                                    child: Text('Temps libre', style: TextStyle(fontSize: 13, color: Color(0xFF7A807D))),
                                  )
                                else
                                  ...periodItems.map(planRow),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => addUnplannedToDay(day),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Ajouter autre chose'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 18)),
      ],
    );
  }

  String _baseDayMood(int day) {
    const moods = [
      'Focus musique & intérieur',
      'Équilibre actif',
      'Le grand jour du marché',
      'Créativité & bien-être',
      'Nature & plein air',
      'Sorties & loisirs',
      'Détente',
    ];
    return moods[day];
  }

  List<ActivityLog> _recentHistory([int days = 14]) {
    final now = DateTime.now();
    return logs.where((log) {
      final age = now.difference(log.date).inDays;
      return age >= 0 && age < days;
    }).toList();
  }

  String _todayFocus() {
    final recent = _recentHistory(14);
    if (recent.isEmpty) {
      return _baseDayMood(today);
    }

    final difficult = recent.where((log) => log.feeling == 'Difficile').toList();
    if (difficult.length >= 2) {
      return 'Récupération & rythme doux';
    }

    bool hasCategory(String category, int days) {
      final now = DateTime.now();
      return logs.any((log) {
        final age = now.difference(log.date).inDays;
        return age >= 0 && age < days && log.category == category;
      });
    }

    final lowerTitles = recent.map((log) => log.title.toLowerCase()).toList();
    final pianoRecent = lowerTitles.where((title) => title.contains('piano')).length;
    final sportRecent = recent.where((log) => log.category == 'Sport' || log.category == 'Bien-être').length;

    if (pianoRecent == 0) {
      return 'Musique & plaisir du piano';
    }
    if (sportRecent == 0) {
      return 'Mouvement & énergie';
    }
    if (!hasCategory('Culture', 5)) {
      return 'Culture & curiosité';
    }
    if (!hasCategory('Sortie', 7) && !hasCategory('Social', 7)) {
      return 'Sortie & découverte';
    }

    switch (today) {
      case 0:
        return 'Focus musique & intérieur';
      case 1:
        return 'Équilibre actif';
      case 2:
        return 'Marché & vie locale';
      case 3:
        return 'Créativité & bien-être';
      case 4:
        return 'Nature & plein air';
      case 5:
        return 'Sorties & loisirs';
      default:
        return 'Détente';
    }
  }

  String _todayFocusReason() {
    final recent = _recentHistory(14);
    if (recent.isEmpty) {
      return 'Pas encore assez d’historique : on garde le focus naturel de la journée.';
    }
    final difficult = recent.where((log) => log.feeling == 'Difficile').length;
    if (difficult >= 2) {
      return 'Plusieurs moments difficiles récemment : aujourd’hui, priorité à une journée plus douce.';
    }
    final pianoRecent = recent.where((log) => log.title.toLowerCase().contains('piano')).length;
    final sportRecent = recent.where((log) => log.category == 'Sport' || log.category == 'Bien-être').length;
    if (pianoRecent == 0) {
      return 'Le piano a été peu présent dans les 14 derniers jours : une petite place lui ferait du bien.';
    }
    if (sportRecent == 0) {
      return 'Peu d’activité physique récente : remettre un peu de mouvement dans la journée.';
    }
    if (!recent.any((log) => log.category == 'Culture' && DateTime.now().difference(log.date).inDays < 5)) {
      return 'Un peu de lecture ou de culture rééquilibrerait agréablement la semaine.';
    }
    if (!recent.any((log) => (log.category == 'Sortie' || log.category == 'Social') && DateTime.now().difference(log.date).inDays < 7)) {
      return 'Une sortie ou un moment partagé n’est pas apparu récemment : place à la découverte.';
    }
    return 'Ton historique est assez équilibré : je garde le caractère naturel de cette journée.';
  }

  Widget _dayMood(int day) {
    final mood = day == today ? _todayFocus() : _baseDayMood(day);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(mood, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7A7770)))),
        if (day == today)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('FOCUS DU JOUR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFC67E67))),
          ),
      ],
    );
  }

  Widget _timeLine(String time, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF526B78)))),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, color: Color(0xFF4F5758)))),
      ]),
    );
  }

  Widget planRow(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final category = activity?.category ?? (item.customCategory ?? 'Autre');
    final emoji = activity?.emoji ?? (item.customEmoji ?? '📍');
    final bg = item.optional ? const Color(0xFFF0EDE6) : _pastelFor(category).withOpacity(.42);

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.85)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.done,
              onChanged: (value) {
                if (value == true || item.done) openPlanItem(item);
              },
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            const SizedBox(width: 2),
            Text(emoji, style: const TextStyle(fontSize: 19)),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openItemActions(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                decoration: item.done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (item.userAdded)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text('ajouté', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF7A7770))),
                            ),
                        ],
                      ),
                      if (item.details != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(item.details!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF5E6463))),
                        ),
                      const SizedBox(height: 2),
                      Text('${item.duration} min', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF526B78))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Voir / modifier',
              visualDensity: VisualDensity.compact,
              onPressed: () => openItemActions(item),
              icon: const Icon(Icons.chevron_right, size: 22, color: Color(0xFF718087)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActivities() {
    final cats = <String>['Toutes', 'Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social'];
    final filtered = categoryFilter == 'Toutes' ? activities : activities.where((a) => a.category == categoryFilter).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(children: [
              mascotAvatar(size: 46),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mes activités', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF33414A))),
                const SizedBox(height: 4),
                Text('${activities.length} activités · personnalise ton rythme', style: const TextStyle(color: Color(0xFF6F7777))),
              ])),
              IconButton(onPressed: openHistory, tooltip: 'Historique', icon: const Icon(Icons.history)),
              if (activities.any(_isSportActivity)) ...[
                const SizedBox(width: 2),
                IconButton(onPressed: openSportWeekOverview, tooltip: 'Semaine Sport', icon: const Icon(Icons.calendar_view_week_outlined)),
              ],
              const SizedBox(width: 6),
              FilledButton.tonalIcon(
                onPressed: () => addOrEditActivity(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) => FilterChip(label: Text(cats[i]), selected: categoryFilter == cats[i], onSelected: (_) => setState(() => categoryFilter = cats[i])),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final a = filtered[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    onTap: () => addOrEditActivity(original: a),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    leading: CircleAvatar(radius: 25, backgroundColor: _pastelFor(a.category), child: Text(a.emoji, style: const TextStyle(fontSize: 23))),
                    title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(a.isSportProgram
                        ? 'Programme sport · ${a.sportDailyDurations.values.where((v) => v > 0).fold<int>(0, (s, v) => s + v)} min/semaine · ${a.sportDailyDurations.values.where((v) => v > 0).length} jour(s)' 
                        : '${a.category} · ${a.duration} min · ${a.frequency}×/semaine${a.category == 'Sport' ? ' · poids ${a.sportWeight}' : ''}'),
                    trailing: FilledButton.tonal(
                      onPressed: () => addOrEditActivity(original: a),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Modifier'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
      ],
    );
  }
}


class _WeeklyReviewPage extends StatefulWidget {
  final List<PlanItem> plan;
  final List<ActivityLog> logs;
  final List<Activity> activities;
  final String weeklyNote;
  final ValueChanged<String> onSaveNote;

  const _WeeklyReviewPage({
    required this.plan,
    required this.logs,
    required this.activities,
    required this.weeklyNote,
    required this.onSaveNote,
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
    final trackedPlan = widget.plan.where((p) => p.activityId != null).toList();
    final completed = trackedPlan.where((p) => p.done).length;
    final completionRate = trackedPlan.isEmpty ? 0.0 : completed / trackedPlan.length;
    final validatedMinutes = widget.logs.fold<int>(0, (sum, log) => sum + log.plannedMinutes);
    final plannedRealised = widget.logs.fold<int>(0, (sum, log) => sum + log.plannedMinutes);
    final unplanned = widget.logs.where((log) => log.unplanned).length;
    final pianoMinutes = widget.logs
        .where((log) => log.title.toLowerCase().contains('piano'))
        .fold<int>(0, (sum, log) => sum + log.plannedMinutes);
    final sportMinutes = widget.logs
        .where((log) => log.category == 'Sport')
        .fold<int>(0, (sum, log) => sum + log.plannedMinutes);
    final veryGood = widget.logs.where((log) => log.feeling == 'Très bien').length;
    final good = widget.logs.where((log) => log.feeling == 'Bien').length;
    final difficult = widget.logs.where((log) => log.feeling == 'Difficile').length;

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
                    Expanded(child: _ReviewStat(label: 'Temps des activités validées', value: '$validatedMinutes min', icon: Icons.timer_outlined)),
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
                      icon: const Icon(Icons.save_outlined),
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



class _SportWeekPage extends StatefulWidget {
  final List<String> dayNames;
  final List<Activity> Function() getActivities;
  final List<PlanItem> Function() getPlan;
  final List<ActivityLog> Function() getLogs;
  final Set<int> Function() getSportDays;
  final Map<int, int> Function() getSportBudgets;
  final ValueChanged<Activity> onReactivate;
  final ValueChanged<Activity> onPostpone;
  final void Function(Activity activity, int day) onToggleDay;
  final void Function(int day, int minutes) onSetBudget;

  const _SportWeekPage({
    required this.dayNames,
    required this.getActivities,
    required this.getPlan,
    required this.getLogs,
    required this.getSportDays,
    required this.getSportBudgets,
    required this.onReactivate,
    required this.onPostpone,
    required this.onToggleDay,
    required this.onSetBudget,
  });

  @override
  State<_SportWeekPage> createState() => _SportWeekPageState();
}

class _SportWeekPageState extends State<_SportWeekPage> {
  late Map<int, int> budgets;
  String _activityFilter = 'Toutes';
  String _stateFilter = 'Tous';
  String _sort = 'Nom';
  String _view = 'Semaine';
  int? _selectedActivityId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    budgets = {...widget.getSportBudgets()};
  }

  List<Activity> _allSportActivities() => widget.getActivities();

  List<PlanItem> _itemsFor(Activity activity, int day) {
    return widget.getPlan().where((item) {
      if (item.day != day || item.activityId != activity.id) return false;
      return true;
    }).toList();
  }

  int _plannedCount(Activity activity) =>
      widget.getPlan().where((item) => item.activityId == activity.id).length;

  int _doneCount(Activity activity) => widget.getPlan().where((item) =>
      item.activityId == activity.id && item.done).length;

  int _target(Activity activity) => activity.sportGroupFrequency ?? activity.frequency;

  bool _isMissingFromWeek(Activity activity) {
    if (!activity.activeInSportRotation) return false;
    return _plannedCount(activity) == 0;
  }

  int _logDoneCountInMonth(Activity activity) {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 1);
    // The page cannot receive logs directly without widening its contract;
    // current-month completed plan items are included below, while historical
    // monthly activity is represented by the persisted plan/log-compatible state.
    return widget.getPlan().where((item) {
      return item.activityId == activity.id && item.done &&
          item.day >= 0 && item.day < 7 &&
          DateTime.now().weekday - 1 == item.day &&
          DateTime.now().isAfter(start.subtract(const Duration(seconds: 1))) &&
          DateTime.now().isBefore(end);
    }).length;
  }

  Widget _dayCell(Activity activity, int day) {
    final items = _itemsFor(activity, day);
    final planned = items.isNotEmpty;
    final done = items.any((item) => item.done);
    final label = done ? '✓' : (planned ? '•' : '—');

    Color background;
    Color border;
    Color foreground;
    if (done) {
      background = const Color(0xFF7D988D);
      border = const Color(0xFF6C887A);
      foreground = Colors.white;
    } else if (planned) {
      background = const Color(0xFFE5EEE9);
      border = const Color(0xFFB8CCC1);
      foreground = const Color(0xFF526B78);
    } else if (widget.getSportDays().contains(day)) {
      background = const Color(0xFFF7F5EF);
      border = const Color(0xFFDAD6CC);
      foreground = const Color(0xFFA8A39A);
    } else {
      background = const Color(0xFFF1F0EC);
      border = const Color(0xFFE0DDD5);
      foreground = const Color(0xFFB8B4AC);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.dayNames[day].substring(0, 3),
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF6F7777))),
        const SizedBox(height: 3),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onToggleDay(activity, day),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: foreground)),
          ),
        ),
      ],
    );
  }

  bool _passesFilters(Activity activity) {
    if (_activityFilter != 'Toutes' && activity.name != _activityFilter) return false;
    final planned = _plannedCount(activity);
    final done = _doneCount(activity);
    switch (_stateFilter) {
      case 'Réalisées':
        if (done == 0) return false;
        break;
      case 'À faire':
        if (planned == 0 || done >= planned) return false;
        break;
      case 'Non prises en compte':
        if (!_isMissingFromWeek(activity)) return false;
        break;
    }
    return true;
  }

  List<Activity> _visibleActivities() {
    final list = _allSportActivities().where(_passesFilters).toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'Réalisées':
          final dc = _doneCount(b).compareTo(_doneCount(a));
          if (dc != 0) return dc;
          break;
        case 'À faire':
          final ac = (_plannedCount(a) - _doneCount(a));
          final bc = (_plannedCount(b) - _doneCount(b));
          final rc = bc.compareTo(ac);
          if (rc != 0) return rc;
          break;
        case 'Cible':
          final rc = _target(b).compareTo(_target(a));
          if (rc != 0) return rc;
          break;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Widget _summary() {
    final all = _allSportActivities();
    final active = all.where((a) => a.activeInSportRotation).toList();
    final planned = widget.getPlan().where((p) =>
        p.activityId != null &&
        all.any((a) => a.id == p.activityId)).toList();
    final done = planned.where((p) => p.done).toList();
    final missing = active.where(_isMissingFromWeek).length;
    final plannedMinutes = planned.fold<int>(0, (s, p) => s + p.duration);
    final doneMinutes = done.fold<int>(0, (s, p) => s + p.duration);
    final rate = plannedMinutes == 0 ? 0 : (doneMinutes * 100 / plannedMinutes).round();

    Widget stat(String value, String label, IconData icon) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0DDD5)),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: const Color(0xFF6F8E80)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF33414A))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: Color(0xFF6F7777))),
        ]),
      ),
    );

    return Column(children: [
      Row(children: [
        stat('${active.length}', 'actives', Icons.directions_run_outlined),
        const SizedBox(width: 7),
        stat('$doneMinutes / $plannedMinutes', 'min réalisées / prévues', Icons.timelapse_outlined),
        const SizedBox(width: 7),
        stat('$rate %', 'taux de réalisation', Icons.check_circle_outline),
        const SizedBox(width: 7),
        stat('$missing', 'non prises en compte', Icons.warning_amber_rounded),
      ]),
    ]);
  }

  Widget _filters() {
    final names = _allSportActivities().map((a) => a.name).toList()..sort();
    final selected = _activityFilter == 'Toutes' || names.contains(_activityFilter)
        ? _activityFilter
        : 'Toutes';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE2DE)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activité', isDense: true),
              items: ['Toutes', ...names].map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _activityFilter = v ?? 'Toutes'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _stateFilter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'État', isDense: true),
              items: const [
                DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                DropdownMenuItem(value: 'Réalisées', child: Text('Réalisées')),
                DropdownMenuItem(value: 'À faire', child: Text('À faire')),
                DropdownMenuItem(value: 'Non prises en compte', child: Text('Non prises en compte')),
              ],
              onChanged: (v) => setState(() => _stateFilter = v ?? 'Tous'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sort,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trier par', isDense: true),
              items: const [
                DropdownMenuItem(value: 'Nom', child: Text('Nom')),
                DropdownMenuItem(value: 'Réalisées', child: Text('Réalisées')),
                DropdownMenuItem(value: 'À faire', child: Text('À faire')),
                DropdownMenuItem(value: 'Cible', child: Text('Cible / semaine')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? 'Nom'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Semaine', label: Text('7 jours'), icon: Icon(Icons.view_week_outlined, size: 17)),
                ButtonSegment(value: 'Mois', label: Text('Mois'), icon: Icon(Icons.calendar_month_outlined, size: 17)),
              ],
              selected: {_view},
              onSelectionChanged: (value) => setState(() => _view = value.first),
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _activityRow(Activity activity) {
    final missing = _isMissingFromWeek(activity);
    final planned = _plannedCount(activity);
    final done = _doneCount(activity);
    final target = _target(activity);
    final remaining = max(0, planned - done);
    final percent = planned == 0 ? 0 : (done * 100 / planned).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 12, 10, 11),
      decoration: BoxDecoration(
        color: missing ? const Color(0xFFF8E7DF) : const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: missing ? const Color(0xFFE3AA95) : const Color(0xFFE0DDD5),
          width: missing ? 1.4 : 1,
        ),
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: const Color(0xFFE3ECE7), child: Text(activity.emoji, style: const TextStyle(fontSize: 19))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('${activity.duration} min · cible ${target}×/sem · $done/$planned réalisé · $percent %',
                style: const TextStyle(fontSize: 10.8, color: Color(0xFF6F7777))),
          ])),
          Text('$remaining', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF526B78))),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (day) => _dayCell(activity, day))),
        if (missing) ...[
          const SizedBox(height: 9),
          Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: const Color(0xFFF3D7CB), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [Icon(Icons.warning_amber_rounded, size: 17, color: Color(0xFFAA624B)), SizedBox(width: 7), Expanded(child: Text('Non prise en compte cette semaine', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF93553F))))]),
          ),
        ],
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  int _daysInMonth() => DateTime(_month.year, _month.month + 1, 0).day;

  String _monthLabel() {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  Widget _monthView() {
    final visible = _visibleActivities();
    final selected = _activityFilter == 'Toutes'
        ? null
        : (visible.where((a) => a.name == _activityFilter).isEmpty
            ? null
            : visible.where((a) => a.name == _activityFilter).first);
    final days = _daysInMonth();
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday - 1;
    final logs = widget.getLogs();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    bool doneOn(Activity activity, DateTime date) {
      return logs.any((log) {
        if (!_sameDay(log.date, date)) return false;
        if (log.activityId == activity.id) return true;
        return log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase();
      });
    }

    bool plannedOn(Activity activity, DateTime date) {
      // Historique réalisé = ✓ ; pour la semaine courante, les éléments du planning
      // encore à faire apparaissent comme •.
      for (final item in widget.getPlan()) {
        if (item.activityId != activity.id) continue;
        final itemDate = monday.add(Duration(days: item.day));
        if (_sameDay(itemDate, date) && !item.done) return true;
      }
      return false;
    }

    Widget cell(int day) {
      final date = DateTime(_month.year, _month.month, day);
      final activity = selected;
      final done = activity != null && doneOn(activity, date);
      final planned = activity != null && !done && plannedOn(activity, date);
      final bg = done
          ? const Color(0xFF7D988D)
          : planned
              ? const Color(0xFFE5EEE9)
              : const Color(0xFFFFFDF9);
      final fg = done ? Colors.white : const Color(0xFF526B78);
      return Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE0DDD5)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Align(alignment: Alignment.topLeft, child: Text('$day', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg))),
          Text(
            activity == null ? '' : done ? '✓' : planned ? '•' : '',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: fg),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(_monthLabel(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      if (selected == null)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Sélectionne une activité (par exemple Yoga) pour voir ses jours réalisés sur le mois.', style: TextStyle(fontSize: 11.5, color: Color(0xFF6F7777))),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Text('${selected.emoji} ${selected.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
            const Spacer(),
            Text('✓ ${logs.where((log) => _sameDay(log.date, DateTime(log.date.year, log.date.month, log.date.day)) && (log.activityId == selected.id || (log.activityId == null && log.title.trim().toLowerCase() == selected.name.trim().toLowerCase())) && log.date.year == _month.year && log.date.month == _month.month).length} jour(s)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F7777))),
          ]),
        ),
      Row(children: const [
        Expanded(child: Center(child: Text('L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
        Expanded(child: Center(child: Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
        Expanded(child: Center(child: Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
        Expanded(child: Center(child: Text('J', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
        Expanded(child: Center(child: Text('V', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
        Expanded(child: Center(child: Text('S', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
        Expanded(child: Center(child: Text('D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF77746D))))),
      ]),
      const SizedBox(height: 3),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.96,
        children: [
          for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
          for (var day = 1; day <= days; day++) cell(day),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.getActivities().where((a) => a.activeInSportRotation).toList();
    final inactive = widget.getActivities().where((a) => !a.activeInSportRotation).toList();
    final visible = _visibleActivities();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semaine Sport'),
        actions: [IconButton(tooltip: 'Accueil', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.home_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            decoration: BoxDecoration(color: const Color(0xFFE5EEE9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD0DED7))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [mascotAvatarInline(size: 40), const SizedBox(width: 10), const Expanded(child: Text('Bilan Sport', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF33414A))))]),
              const SizedBox(height: 8),
              const Text('Une vue synthétique de la semaine, avec filtre par activité, état, tri et historique mensuel.', style: TextStyle(fontSize: 12.5, color: Color(0xFF596461), height: 1.35)),
              const SizedBox(height: 12),
              _summary(),
            ]),
          ),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: const Color(0xFFFFFDF9), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0DDD5))),
            child: _view == 'Semaine'
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Suivi sur 7 jours', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('• prévu · ✓ réalisé · — non prévu. Une activité peut être validée un autre jour que son jour prévu.', style: TextStyle(fontSize: 11.5, color: Color(0xFF6F7777))),
                    const SizedBox(height: 10),
                    if (visible.isEmpty) const Text('Aucune activité ne correspond aux filtres.') else ...visible.map(_activityRow),
                  ])
                : _monthView(),
          ),
          if (inactive.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('MISES EN ATTENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7, color: Color(0xFF7A7770))),
            const SizedBox(height: 7),
            ...inactive.map((activity) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              decoration: BoxDecoration(color: const Color(0xFFF1EEE8), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFDCD8CF))),
              child: Row(children: [
                Text(activity.emoji, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(activity.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF77746D))),
                  const SizedBox(height: 2),
                  Text('${activity.duration} min · ⏸ PLUS TARD', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF9A7566))),
                ])),
                OutlinedButton.icon(onPressed: () { widget.onReactivate(activity); Navigator.pop(context); }, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réactiver')),
              ]),
            )),
          ],
        ],
      ),
    );
  }
}

class _SportCoachJournalSheet extends StatelessWidget {
  final List<SportCoachLog> logs;
  final List<String> dayNames;

  const _SportCoachJournalSheet({required this.logs, required this.dayNames});

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Journal du coach Sport', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(sorted.isEmpty ? 'Aucune analyse Sport pour le moment.' : 'Les analyses et ajustements du coach.'),
          const SizedBox(height: 14),
          SizedBox(
            height: min(MediaQuery.sizeOf(context).height * .62, 520),
            child: sorted.isEmpty
                ? const Center(child: Text('Le journal se remplira après les premières séances.'))
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final log = sorted[index];
                      final d = log.date.toLocal();
                      final dateLabel = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: const Color(0xFFF4F5F2), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFDCE2DE))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          mascotAvatarInline(size: 34),
                          const SizedBox(width: 9),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(log.activityName, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(dateLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF717977))),
                            const SizedBox(height: 5),
                            Text(log.message, style: const TextStyle(height: 1.3)),
                            if (log.adjustment != null) ...[
                              const SizedBox(height: 5),
                              Text('⚙️ ${log.adjustment}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF526B78))),
                            ],
                          ])),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

Widget mascotAvatarInline({double size = 34}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(color: const Color(0xFFFFF4EA), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE7D4C6))),
  child: Center(child: Text('🌸', style: TextStyle(fontSize: size * .46))),
);

class _SportChoice {
  final int minutes;
  final double score;
  final List<Activity> activities;

  const _SportChoice({required this.minutes, required this.score, required this.activities});
}

class _SportDailySlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SportDailySlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(0, 240);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFE7EFEA), borderRadius: BorderRadius.circular(10)),
            child: Text('$safe min', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF526B78))),
          ),
        ]),
        Slider(
          value: safe.toDouble(),
          min: 0,
          max: 240,
          divisions: 48,
          label: '$safe min',
          onChanged: (v) => onChanged((v / 5).round() * 5),
        ),
      ]),
    );
  }
}

class _StepperLine extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _StepperLine({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline)),
      ]);
}

class _InfoSheet extends StatelessWidget {
  final PlanItem item;
  const _InfoSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(item.details ?? 'Un temps libre à organiser comme bon te semble.'),
          const SizedBox(height: 10),
          Text('${item.period} · ${item.duration} min${item.optional ? ' · optionnel' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF526B78))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Très bien'))),
        ]),
      ),
    );
  }
}

class _DataPage extends StatelessWidget {
  final VoidCallback onExport;
  final Future<bool> Function() onImport;
  final Future<void> Function() onReset;

  const _DataPage({
    required this.onExport,
    required this.onImport,
    required this.onReset,
  });

  Future<void> _import(BuildContext context) async {
    final ok = await onImport();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Sauvegarde restaurée avec succès.' : 'Aucune sauvegarde valide restaurée.')),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _reset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialiser les données ?'),
        content: const Text(
          'Le planning, les validations, l’historique et le bilan seront effacés. Tes activités seront conservées telles qu’elles sont. Le planning restera vide jusqu’à ce que tu appuies sur « Repenser ».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await onReset();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Données & sauvegarde')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sauvegarder', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('Télécharge un vrai fichier .json contenant les activités, le planning, les validations, l’historique et le bilan.'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Télécharger la sauvegarde'),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Restaurer', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('Sélectionne directement un fichier .json créé par MyBestWeek.'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _import(context),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Choisir une sauvegarde'),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFF1E4DE),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Réinitialiser', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('Efface toutes les données personnelles et recrée la base initiale de l’application.'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _reset(context),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Réinitialisation complète'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final List<ActivityLog> logs;
  final List<String> dayNames;

  const _HistorySheet({required this.logs, required this.dayNames});

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .45,
      maxChildSize: .95,
      builder: (_, controller) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Historique', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(sorted.isEmpty ? 'Aucune activité enregistrée pour le moment.' : 'Les moments réalisés, prévus ou ajoutés en chemin.'),
            const SizedBox(height: 14),
            Expanded(
              child: sorted.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.history, size: 42, color: Color(0xFF879197)), SizedBox(height: 10), Text('L’historique se remplira au fil de la semaine.')]))
                  : ListView.separated(
                      controller: controller,
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final log = sorted[index];
                        final date = log.date;
                        final dateLabel = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              CircleAvatar(radius: 22, backgroundColor: const Color(0xFFE7EDF0), child: Text(log.emoji, style: const TextStyle(fontSize: 19))),
                              const SizedBox(width: 11),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(log.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  if (log.unplanned) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF1E3DC), borderRadius: BorderRadius.circular(8)), child: const Text('IMPRÉVU', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF9A634F)))),
                                ]),
                                const SizedBox(height: 3),
                                Text('${dayNames[log.day]} · ${log.period} · $dateLabel', style: const TextStyle(fontSize: 12, color: Color(0xFF697271))),
                                const SizedBox(height: 4),
                                Text(
                                  '✓ Validé · ${log.plannedMinutes} min',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF526B78)),
                                ),
                              ])),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}


class _NewMomentResult {
  final String title;
  final String period;
  final String category;
  final String emoji;
  final int duration;

  const _NewMomentResult({
    required this.title,
    required this.period,
    required this.category,
    required this.emoji,
    required this.duration,
  });
}

class _AddMomentPage extends StatefulWidget {
  final String dayName;

  const _AddMomentPage({required this.dayName});

  @override
  State<_AddMomentPage> createState() => _AddMomentPageState();
}

class _AddMomentPageState extends State<_AddMomentPage> {
  late final TextEditingController titleController;
  late final TextEditingController durationController;

  String period = 'Après-midi';
  String category = 'Sortie';
  String emoji = '📍';

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    durationController = TextEditingController(text: '60');
  }

  @override
  void dispose() {
    titleController.dispose();
    durationController.dispose();
    super.dispose();
  }

  void save() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique d’abord ce que tu as fait.')),
      );
      return;
    }

    final parsed = int.tryParse(durationController.text.trim());
    final duration = (parsed == null || parsed < 1) ? 60 : parsed;

    Navigator.of(context).pop(
      _NewMomentResult(
        title: title,
        period: period,
        category: category,
        emoji: emoji,
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter à ${widget.dayName}'),
        leading: IconButton(
          tooltip: 'Annuler',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: save,
            icon: const Icon(Icons.check),
            label: const Text('Ajouter'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            Card(
              color: const Color(0xFFE7EDF0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.add_circle_outline, color: Color(0xFF526B78)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ajoute ici un moment qui n’était pas prévu : visite, exposition, restaurant, balade, rencontre…',
                        style: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => save(),
              decoration: const InputDecoration(
                labelText: 'Qu’as-tu fait ?',
                hintText: 'Ex. Visite du château, exposition, déjeuner…',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: period,
              decoration: const InputDecoration(
                labelText: 'Moment de la journée',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              items: const ['Matin', 'Après-midi', 'Soir']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => period = v ?? period),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              items: const ['Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social', 'Autre']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: emoji,
              decoration: const InputDecoration(
                labelText: 'Icône',
                prefixIcon: Icon(Icons.emoji_emotions_outlined),
              ),
              items: const ['📍', '🏛️', '🌿', '☕', '🍽️', '🎨', '🚶', '👥', '⭐']
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, style: const TextStyle(fontSize: 20)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => emoji = v ?? emoji),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Durée (minutes)',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Ajouter à ma semaine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

