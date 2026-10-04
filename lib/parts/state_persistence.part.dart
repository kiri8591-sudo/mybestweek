part of '../main.dart';

// V8.89 — deuxième étape du découpage : persistance / sauvegardes.
// Cette partie partage volontairement la même bibliothèque que main.dart afin
// de conserver les membres privés et l'état existant sans introduire de rupture.
extension _StatePersistence on _MaBelleSemaineAppState {
  void _persistLocalState({bool recordUndo = true}) {
    // Au tout premier démarrage, le planning par défaut est construit avant
    // que l'ancienne sauvegarde ait été lue. Il ne faut surtout pas écrire
    // cette version intermédiaire et écraser la sauvegarde précédente.
    if (_isHydratingLocalState) return;
    try {
      final previousRaw = _preferences?.getString(_MaBelleSemaineAppState._localStateKey);
      final root = jsonDecode(_backupJson()) as Map<String, dynamic>;
      root['weekKey'] = _currentWeekKey();
      root['savedAt'] = DateTime.now().toIso8601String();
      final nextRaw = const JsonEncoder.withIndent('  ').convert(root);
      var undoChanged = false;
      if (recordUndo && !_undoInProgress &&
          previousRaw != null && previousRaw.trim().isNotEmpty &&
          previousRaw != nextRaw) {
        if (!_undoActionPrepared) {
          _undoSnapshotJson = previousRaw;
          undoChanged = true;
        }
        _undoActionPrepared = false;
      }
      // Sur iPhone/Safari/PWA, conserver aussi une copie directement dans
      // localStorage. Cette écriture est synchrone et ne dépend pas d'une
      // opération de plateforme en attente au moment où Safari masque ou
      // recharge la page.
      if (kIsWeb) {
        try {
          html.window.localStorage[_MaBelleSemaineAppState._localStateKey] = nextRaw;
          html.window.localStorage[_MaBelleSemaineAppState._localStateMirrorKey] = nextRaw;
        } catch (_) {
          // localStorage peut être indisponible (mode privé/politique Safari).
        }
      }

      final prefs = _preferences;
      if (prefs != null) {
        // Les écritures sont mises en file et exécutées dans l'ordre.
        // C'est essentiel sur iPhone : un ancien write lancé avant une
        // réinitialisation ne doit jamais pouvoir revenir après le nouveau write.
        final asyncPrefs = SharedPreferencesAsync();
        _persistenceWriteChain = _persistenceWriteChain.then<void>((_) async {
          try {
            await asyncPrefs.setString(_MaBelleSemaineAppState._localStateKey, nextRaw);
            await asyncPrefs.setString(_MaBelleSemaineAppState._localStateMirrorKey, nextRaw);
            // On garde aussi le cache SharedPreferencesWithCache cohérent pour
            // le mécanisme Undo et les lectures locales ultérieures.
            await prefs.setString(_MaBelleSemaineAppState._localStateKey, nextRaw);
            await prefs.setString(_MaBelleSemaineAppState._localStateMirrorKey, nextRaw);
          } catch (_) {
            // Une politique de stockage restrictive reste non bloquante.
          }
        });
        unawaited(_persistenceWriteChain);
      }
      if (undoChanged && mounted) setState(() {});
    } catch (_) {
      // La persistance locale est facultative : une politique de stockage
      // navigateur restrictive ne doit jamais empêcher l'application de vivre.
    }
  }

  Future<void> _flushPersistenceWrites() async {
    try {
      await _persistenceWriteChain;
    } catch (_) {
      // La persistance reste best-effort, sans bloquer l'interface.
    }
  }

  void _queueLocalStatePersist() {
    // Chaque nouvelle mutation invalide les écritures différées plus anciennes.
    // Cela évite qu'une écriture programmée avant un Undo rétablisse ensuite
    // l'état qui vient précisément d'être annulé.
    final generation = ++_persistenceGeneration;

    // IMPORTANT : ne plus attendre le frame suivant pour la sauvegarde
    // principale. Sur iPhone, l'application peut être terminée avant
    // l'exécution d'un addPostFrameCallback.
    _persistLocalState(recordUndo: true);

    // Une seconde écriture après le frame protège les mutations réalisées
    // dans des enchaînements UI complexes et garde le coût raisonnable.
    if (_persistenceQueued) return;
    _persistenceQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistenceQueued = false;
      if (mounted && generation == _persistenceGeneration) {
        _persistLocalState(recordUndo: false);
      }
    });
  }

  Future<void> _loadLocalState() async {
    var safeToPersistAfterHydration = false;
    try {
      _preferences ??= await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );

      // Lecture multi-source : sur iPhone/Safari, on compare la copie
      // SharedPreferences à la copie localStorage et on retient la plus
      // récente. Cela évite de restaurer un cache ancien après une relance.
      final asyncPrefs = SharedPreferencesAsync();
      final candidates = <String>[];
      Future<void> addCandidate(Future<String?> future) async {
        try {
          final value = await future;
          if (value != null && value.trim().isNotEmpty) candidates.add(value);
        } catch (_) {
          // Une source indisponible ne doit pas bloquer les autres.
        }
      }

      await addCandidate(asyncPrefs.getString(_MaBelleSemaineAppState._localStateKey));
      await addCandidate(asyncPrefs.getString(_MaBelleSemaineAppState._localStateMirrorKey));

      if (kIsWeb) {
        try {
          final localPrimary = html.window.localStorage[_MaBelleSemaineAppState._localStateKey];
          final localMirror = html.window.localStorage[_MaBelleSemaineAppState._localStateMirrorKey];
          if (localPrimary != null && localPrimary.trim().isNotEmpty) candidates.add(localPrimary);
          if (localMirror != null && localMirror.trim().isNotEmpty) candidates.add(localMirror);
        } catch (_) {
          // localStorage peut être indisponible.
        }
      }

      String? raw;
      DateTime? newestSavedAt;
      for (final candidate in candidates) {
        try {
          final decoded = jsonDecode(candidate);
          if (decoded is! Map || decoded['format'] != 'ma_belle_semaine_backup') continue;
          final stamp = DateTime.tryParse('${decoded['savedAt'] ?? ''}');
          if (raw == null || (stamp != null && (newestSavedAt == null || stamp.isAfter(newestSavedAt!)))) {
            raw = candidate;
            newestSavedAt = stamp;
          }
        } catch (_) {
          // Une copie corrompue est simplement ignorée.
        }
      }

      // Ancien stockage Web V9/V10/V11 : la clé historique est justement
      // celle lue directement dans localStorage ci-dessus.
      if ((raw == null || raw.trim().isEmpty) && kIsWeb) {
        try {
          final legacy = html.window.localStorage[_MaBelleSemaineAppState._localStateKey];
          if (legacy != null && legacy.trim().isNotEmpty) raw = legacy;
        } catch (_) {
          // Migration Web facultative.
        }
      }

      // Réparer les deux stockages à partir de la copie choisie.
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          if (kIsWeb) {
            html.window.localStorage[_MaBelleSemaineAppState._localStateKey] = raw;
            html.window.localStorage[_MaBelleSemaineAppState._localStateMirrorKey] = raw;
          }
          await asyncPrefs.setString(_MaBelleSemaineAppState._localStateKey, raw);
          await asyncPrefs.setString(_MaBelleSemaineAppState._localStateMirrorKey, raw);
        } catch (_) {
          // Réparation facultative : la copie sélectionnée reste exploitable.
        }
      }

      // Première installation : rien à restaurer, on pourra enregistrer l'état
      // initial une fois l'hydratation terminée.
      if (raw == null || raw.trim().isEmpty) {
        safeToPersistAfterHydration = true;
        return;
      }

      final root = jsonDecode(raw);
      if (root is! Map) return;

      final savedWeek = root['weekKey']?.toString();
      var restored = restoreBackup(raw);

      // Si le fichier principal est corrompu/incomplet, essayer le miroir avant
      // de considérer la restauration comme échouée.
      if (!restored) {
        final mirror = await asyncPrefs.getString(_MaBelleSemaineAppState._localStateMirrorKey);
        if (mirror != null && mirror.trim().isNotEmpty && mirror != raw) {
          final mirrorRoot = jsonDecode(mirror);
          if (mirrorRoot is Map) {
            restored = restoreBackup(mirror);
            if (restored) {
              raw = mirror;
            }
          }
        }
      }

      // Surtout : ne jamais réécrire l'état par défaut si une sauvegarde existe
      // mais n'a pas pu être restaurée. Cela évite la perte silencieuse des
      // données au prochain lancement.
      if (!restored) return;
      safeToPersistAfterHydration = true;

      if (savedWeek != _currentWeekKey()) {
        setState(() {
          plan.clear();
          _regeneratedSportBudgets.clear();
        });
        generateWeek(showSnack: false);
      }
    } catch (_) {
      // Une erreur de lecture ne doit jamais écraser la dernière sauvegarde.
      safeToPersistAfterHydration = false;
    } finally {
      _isHydratingLocalState = false;
      if (mounted && safeToPersistAfterHydration) {
        _persistLocalState(recordUndo: false);
      }
    }
  }

  String _backupJson() {
    final data = <String, dynamic>{
      'format': 'ma_belle_semaine_backup',
      'formatVersion': 2,
      'backupStats': {
        'activities': activities.length,
        'planItems': plan.length,
        'logs': logs.length,
        'dailySummaries': dailySummaries.length,
        'moves': activityMoveLogs.length,
      },
      'appVersion': _MaBelleSemaineAppState.version,
      'darkMode': _darkMode,
      'createdAt': DateTime.now().toIso8601String(),
      'lastICloudBackupAt': _lastICloudBackupAt?.toIso8601String(),
      'lastFileBackupAt': _lastFileBackupAt?.toIso8601String(),
      'userName': _userName,
      'weatherCity': _weatherCity,
      'weatherText': _weatherText,
      'weatherIcon': _weatherIcon,
      'weatherTemperature': _weatherTemperature,
      'weatherError': _weatherError,
      'homeMascotKind': _homeMascotKind,
      'homeMascotEmoji': _homeMascotEmoji,
      'homeMascotImageData': _homeMascotImageData,
      'dailyPriorityActivityIds': [..._dailyPriorityActivityIds],
      'priorityBonusAwardedDateKey': _priorityBonusAwardedDateKey,
      'priorityBonusAwarded': _priorityBonusAwarded,
      'priorityBonusTotal': _priorityBonusTotal,
      'priorityRewardText': _priorityRewardText,
      'realizationGoals': _realizationGoals.map((g) => {
        'id': g.id,
        'activityId': g.activityId,
        'cadence': g.cadence,
        'target': g.target,
        'rewardText': g.rewardText,
        'createdAt': g.createdAt.toIso8601String(),
        'rewardedPeriodKeys': [...g.rewardedPeriodKeys],
      }).toList(),
      'customActivityEmojis': _customActivityEmojis.map((e) => e.value).toList(),
      'customActivityIcons': _customActivityIcons.map((e) => {
        'id': e.id,
        'label': e.label,
        'data': e.data,
      }).toList(),
      'systemIconOverrides': {..._systemIconOverrides},
      'todayNameday': _todayNameday,
      'todayNamedayDateKey': _todayNamedayDateKey,
      'morningThought': _morningThought,
      'lastPlanningRegeneratedWeekKey': _lastPlanningRegeneratedWeekKey,
      'lastPlanningRegeneratedDays': [..._lastPlanningRegeneratedDays],
      'lastPlanningRegeneratedAt': _lastPlanningRegeneratedAt?.toIso8601String(),
      'planningReportReadAt': _planningReportReadAt?.toIso8601String(),
      'regenerateWholeWeekAfterReset': _regenerateWholeWeekAfterReset,
      'lastPlanningWasFullWeek': _lastPlanningWasFullWeek,
      'generationActivityRules': {..._generationActivityRules},
      'regeneratedSportBudgets': {for (final e in _regeneratedSportBudgets.entries) '${e.key}': e.value},
      'generationCriteria': {
        'respectPriorities': _generationRespectPriorities,
        'useHistory': _generationUseHistory,
        'balanceLoad': _generationBalanceLoad,
        'respectPreferredDays': _generationRespectPreferredDays,
        'alternateActivities': _generationAlternateActivities,
        'learnHabits': _generationLearnHabits,
      },
      'lastPlanningCoachExplanation': _lastPlanningCoachExplanation,
      'lastPlanningDecisionDetails': [..._lastPlanningDecisionDetails],
      'weeklyNote': weeklyNote,
      'nextWeekCoachDirections': [..._nextWeekCoachDirections],
      'sportCoachLastAnalysis': sportCoachLastAnalysis,
      'sportCoachLastAnalysisAt': sportCoachLastAnalysisAt?.toIso8601String(),
      'sportCoachSuggestion': sportCoachSuggestion,
      'sportCoachSuggestionDelta': sportCoachSuggestionDelta,
      'pendingSportCoachSuggestionDeltas': {for (final e in _pendingSportCoachSuggestionDeltas.entries) '${e.key}': e.value},
      'sportCoachDailyAdjustments': {for (final e in sportCoachDailyAdjustments.entries) '${e.key}': e.value},
      'manualSportBudgetOverrideDays': [..._manualSportBudgetOverrideDays],
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
        'period': a.period,
        'duration': a.duration,
        'frequency': a.frequency,
        'priority': a.priority,
        'preferredDays': a.preferredDays,
        'isDateRange': a.isDateRange,
        'isFrozen': a.isFrozen,
        'rangeStart': a.rangeStart?.toIso8601String(),
        'rangeEnd': a.rangeEnd?.toIso8601String(),
        'sportWeight': a.sportWeight,
        'allowMultiplePerDay': a.allowMultiplePerDay,
        'maxDailyOccurrences': a.maxDailyOccurrences,
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
        'manualPlacement': p.manualPlacement,
        'done': p.done,
        'realisedMinutes': p.realisedMinutes,
        'feeling': p.feeling,
      }).toList(),
      'activityMoveLogs': activityMoveLogs.map((m) => {
        'date': m.date.toIso8601String(),
        'activityName': m.activityName,
        'activityId': m.activityId,
        'fromDay': m.fromDay,
        'toDay': m.toDay,
        'fromPeriod': m.fromPeriod,
        'toPeriod': m.toPeriod,
      }).toList(),
      'manualDayRemovalsWeekKey': _manualDayRemovalsWeekKey,
      'manualDayRemovals': {
        for (final e in _manualDayRemovals.entries)
          e.key: {for (final d in e.value.entries) '${d.key}': d.value},
      },
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
      'dailySummaries': dailySummaries.map((summary) => {
        'date': summary.date.toIso8601String(),
        'dateKey': summary.dateKey,
        'moodEmoji': summary.moodEmoji,
        'summary': summary.summary,
        'completedCount': summary.completedCount,
        'totalCount': summary.totalCount,
        'plannedMinutes': summary.plannedMinutes,
        'realisedMinutes': summary.realisedMinutes,
        'activityTitles': [...summary.activityTitles],
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

  Map<int, int> _asSignedIntMap(dynamic value) {
    if (value is! Map) return {};
    final result = <int, int>{};
    for (final entry in value.entries) {
      final key = int.tryParse('${entry.key}');
      if (key != null && key >= 0 && key < 7) result[key] = _asInt(entry.value);
    }
    return result;
  }

  Set<int> _asIntSet(dynamic value) {
    if (value is! List) return <int>{};
    return value
        .map((item) => _asInt(item, -1))
        .where((day) => day >= 0 && day < 7)
        .toSet();
  }

  String? _asString(dynamic value) => value == null ? null : '$value';

  bool _asBool(dynamic value, [bool fallback = false]) => value is bool ? value : fallback;

  bool restoreBackup(String raw) {
    try {
      if (raw.length > 12 * 1024 * 1024) return false;
      final root = jsonDecode(raw);
      if (root is! Map || root['format'] != 'ma_belle_semaine_backup') return false;
      final formatVersion = _asInt(root['formatVersion'], 1);
      if (formatVersion < 1 || formatVersion > 2) return false;
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
          period: ((_asString(rawActivity['period']) == 'Midi') ? 'Après-midi' : (_asString(rawActivity['period']) ?? 'Après-midi')),
          duration: max(1, _asInt(rawActivity['duration'], 30)),
          frequency: max(1, min(7, _asInt(rawActivity['frequency'], 1))),
          priority: max(1, min(5, _asInt(rawActivity['priority'], 3))),
          preferredDays: _asIntList(rawActivity['preferredDays']),
          isDateRange: _asBool(rawActivity['isDateRange'], false),
          isFrozen: _asBool(rawActivity['isFrozen'], false),
          rangeStart: (() { final raw = _asString(rawActivity['rangeStart']); return raw == null ? null : DateTime.tryParse(raw); })(),
          rangeEnd: (() { final raw = _asString(rawActivity['rangeEnd']); return raw == null ? null : DateTime.tryParse(raw); })(),
          sportWeight: max(1, min(10, _asInt(rawActivity['sportWeight'], 5))),
          allowMultiplePerDay: _asBool(rawActivity['allowMultiplePerDay'], false),
          maxDailyOccurrences: max(2, min(3, _asInt(rawActivity['maxDailyOccurrences'], 2))),
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
          manualPlacement: _asBool(rawPlan['manualPlacement']),
          done: _asBool(rawPlan['done']),
          realisedMinutes: rawPlan['realisedMinutes'] == null
              ? (_asBool(rawPlan['done']) ? max(1, _asInt(rawPlan['duration'], 30)) : null)
              : max(0, _asInt(rawPlan['realisedMinutes'])),
          feeling: (() { final v = _normalizeFeeling(_asString(rawPlan['feeling'])); return v.isEmpty ? null : v; })(),
        ));
      }

      final restoredMoveLogs = <ActivityMoveLog>[];
      final rawMoveLogs = root['activityMoveLogs'];
      if (rawMoveLogs is List) {
        for (final raw in rawMoveLogs) {
          if (raw is! Map) continue;
          final dateRaw = _asString(raw['date']);
          final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);
          final name = _asString(raw['activityName']);
          final fromDay = _asInt(raw['fromDay'], -1);
          final toDay = _asInt(raw['toDay'], -1);
          if (date == null || name == null || fromDay < 0 || fromDay > 6 || toDay < 0 || toDay > 6) continue;
          restoredMoveLogs.add(ActivityMoveLog(
            date: date,
            activityName: name,
            activityId: _asString(raw['activityId']),
            fromDay: fromDay,
            toDay: toDay,
            fromPeriod: _asString(raw['fromPeriod']) ?? 'Après-midi',
            toPeriod: _asString(raw['toPeriod']) ?? 'Après-midi',
          ));
        }
      }

      final restoredManualDayRemovalsWeekKey = _asString(root['manualDayRemovalsWeekKey']) ?? '';
      final restoredManualDayRemovals = <String, Map<int, int>>{};
      final rawManualDayRemovals = root['manualDayRemovals'];
      if (rawManualDayRemovals is Map) {
        for (final entry in rawManualDayRemovals.entries) {
          final activityId = '${entry.key}';
          if (entry.value is! Map) continue;
          final days = <int, int>{};
          for (final dayEntry in (entry.value as Map).entries) {
            final day = int.tryParse('${dayEntry.key}');
            final count = int.tryParse('${dayEntry.value}');
            if (day != null && day >= 0 && day < 7 && count != null && count > 0) days[day] = count;
          }
          if (days.isNotEmpty) restoredManualDayRemovals[activityId] = days;
        }
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
          realisedMinutes: max(0, _asInt(rawLog['realisedMinutes'], _asInt(rawLog['plannedMinutes']))),
          feeling: (() { final v = _normalizeFeeling(_asString(rawLog['feeling'])); return v.isEmpty ? 'Bien' : v; })(),
          unplanned: _asBool(rawLog['unplanned']),
          planItemId: _asString(rawLog['planItemId']),
          activityId: _asString(rawLog['activityId']),
        ));
      }

      final restoredDailySummaries = <DailySummary>[];
      final rawDailySummaries = root['dailySummaries'];
      if (rawDailySummaries is List) {
        for (final rawSummary in rawDailySummaries) {
          if (rawSummary is! Map) continue;
          final dateRaw = _asString(rawSummary['date']);
          final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);
          final dateKey = _asString(rawSummary['dateKey']);
          final summaryText = _asString(rawSummary['summary']);
          if (date == null || dateKey == null || summaryText == null || dateKey.isEmpty) continue;
          final titles = rawSummary['activityTitles'] is List
              ? (rawSummary['activityTitles'] as List).map((v) => '$v').where((v) => v.trim().isNotEmpty).take(12).toList()
              : <String>[];
          restoredDailySummaries.add(DailySummary(
            date: date,
            dateKey: dateKey,
            moodEmoji: _asString(rawSummary['moodEmoji']) ?? '🙂',
            summary: summaryText,
            completedCount: max(0, _asInt(rawSummary['completedCount'])),
            totalCount: max(0, _asInt(rawSummary['totalCount'])),
            plannedMinutes: max(0, _asInt(rawSummary['plannedMinutes'])),
            realisedMinutes: max(0, _asInt(rawSummary['realisedMinutes'])),
            activityTitles: titles,
          ));
        }
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
        dailySummaries
          ..clear()
          ..addAll(restoredDailySummaries);
        activityMoveLogs
          ..clear()
          ..addAll(restoredMoveLogs);
        _manualDayRemovalsWeekKey = restoredManualDayRemovalsWeekKey;
        _manualDayRemovals = restoredManualDayRemovals;
        if (_manualDayRemovalsWeekKey.isEmpty || _manualDayRemovalsWeekKey != _currentWeekKey()) {
          _manualDayRemovals = {};
          _manualDayRemovalsWeekKey = _currentWeekKey();
        }
        final cloudBackupDate = _asString(root['lastICloudBackupAt']);
        _lastICloudBackupAt = cloudBackupDate == null ? null : DateTime.tryParse(cloudBackupDate);
        final fileBackupDate = _asString(root['lastFileBackupAt']);
        _lastFileBackupAt = fileBackupDate == null ? null : DateTime.tryParse(fileBackupDate);
        _darkMode = _asBool(root['darkMode'], false);
        _userName = _asString(root['userName']) ?? '';
        _weatherCity = _asString(root['weatherCity']) ?? '';
        _weatherText = _asString(root['weatherText']) ?? '';
        _weatherIcon = _asString(root['weatherIcon']) ?? '🌤️';
        _weatherTemperature = _asString(root['weatherTemperature']) ?? '';
        _weatherError = _asString(root['weatherError']) ?? '';
        _homeMascotKind = _asString(root['homeMascotKind']) ?? 'ourson';
        _homeMascotEmoji = _asString(root['homeMascotEmoji']) ?? '🧸';
        _homeMascotImageData = _asString(root['homeMascotImageData']) ?? '';
        _dailyPriorityActivityIds
          ..clear()
          ..addAll((root['dailyPriorityActivityIds'] is List)
              ? (root['dailyPriorityActivityIds'] as List).map((v) => '$v').where((v) => v.trim().isNotEmpty)
              : const <String>[]);
        _dailyPriorityActivityIds.removeWhere((id) => !restoredActivities.any((a) => a.id == id));
        _priorityBonusAwardedDateKey = _asString(root['priorityBonusAwardedDateKey']) ?? '';
        _priorityBonusAwarded = _asBool(root['priorityBonusAwarded'], false);
        _priorityBonusTotal = max(0, _asInt(root['priorityBonusTotal']));
        _priorityRewardText = (_asString(root['priorityRewardText']) ?? 'un moment plaisir').trim();
        if (_priorityRewardText.isEmpty) _priorityRewardText = 'un moment plaisir';
        _realizationGoals
          ..clear()
          ..addAll((root['realizationGoals'] is List ? root['realizationGoals'] as List : const [])
              .whereType<Map>()
              .map((rawGoal) {
                final createdRaw = _asString(rawGoal['createdAt']);
                final createdAt = createdRaw == null ? DateTime.now() : DateTime.tryParse(createdRaw) ?? DateTime.now();
                final activityId = _asString(rawGoal['activityId']);
                final cadence = _asString(rawGoal['cadence']) ?? 'semaine';
                return RealizationGoal(
                  id: _asString(rawGoal['id']) ?? 'goal_${createdAt.microsecondsSinceEpoch}',
                  activityId: activityId ?? '',
                  cadence: const {'jour', 'semaine', 'mois'}.contains(cadence) ? cadence : 'semaine',
                  target: max(1, min(99, _asInt(rawGoal['target'], 1))),
                  rewardText: (_asString(rawGoal['rewardText']) ?? 'un petit plaisir').trim().isEmpty ? 'un petit plaisir' : (_asString(rawGoal['rewardText']) ?? 'un petit plaisir').trim(),
                  createdAt: createdAt,
                  rewardedPeriodKeys: rawGoal['rewardedPeriodKeys'] is List
                      ? (rawGoal['rewardedPeriodKeys'] as List).map((v) => '$v').where((v) => v.trim().isNotEmpty).toSet()
                      : <String>{},
                );
              })
              .where((g) => restoredActivities.any((a) => a.id == g.activityId))
              .take(12));
        _customActivityEmojis
          ..clear()
          ..addAll(((root['customActivityEmojis'] is List) ? (root['customActivityEmojis'] as List) : const [])
              .map((v) => '${v}')
              .where((v) => v.trim().isNotEmpty && !_customActivityEmojis.any((e) => e.value == v.trim()))
              .map((v) => _CustomActivityEmoji(v.trim())));
        _customActivityIcons
          ..clear();
        _customActivityIconData.clear();
        _customActivityIconBytes.clear();
        final rawCustomIcons = root['customActivityIcons'];
        if (rawCustomIcons is List) {
          for (final rawIcon in rawCustomIcons) {
            if (rawIcon is! Map) continue;
            final id = _asString(rawIcon['id']);
            final label = _asString(rawIcon['label']) ?? 'Icône personnelle';
            final data = _asString(rawIcon['data']);
            if (id == null || id.isEmpty || data == null || data.isEmpty) continue;
            final entry = _CustomActivityIcon(id: id, label: label, data: data);
            _customActivityIcons.add(entry);
            _customActivityIconData[id] = data;
          }
        }
        _systemIconOverrides
          ..clear()
          ..addAll(((root['systemIconOverrides'] is Map) ? Map<String, dynamic>.from(root['systemIconOverrides']) : <String, dynamic>{})
              .map((key, value) => MapEntry(key, '${value}')));
        _systemUiIconOverrides
          ..clear()
          ..addAll(_systemIconOverrides);
        _todayNameday = _asString(root['todayNameday']) ?? '';
        _todayNamedayDateKey = _asString(root['todayNamedayDateKey']) ?? '';
        weeklyNote = _asString(root['weeklyNote']) ?? '';
        _nextWeekCoachDirections
          ..clear()
          ..addAll((root['nextWeekCoachDirections'] is List)
              ? (root['nextWeekCoachDirections'] as List).map((v) => '$v').where((v) => v.trim().isNotEmpty)
              : const <String>[]);
        sportCoachLastAnalysis = _asString(root['sportCoachLastAnalysis']) ?? '';
        final coachDate = _asString(root['sportCoachLastAnalysisAt']);
        sportCoachLastAnalysisAt = coachDate == null ? null : DateTime.tryParse(coachDate);
        sportCoachSuggestion = _asString(root['sportCoachSuggestion']) ?? '';
        sportCoachSuggestionDelta = _asInt(root['sportCoachSuggestionDelta']);
        _pendingSportCoachSuggestionDeltas = _asSignedIntMap(root['pendingSportCoachSuggestionDeltas']);
        sportCoachDailyAdjustments = _asSignedIntMap(root['sportCoachDailyAdjustments']);
        _manualSportBudgetOverrideDays = _asIntSet(root['manualSportBudgetOverrideDays']);
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
        _lastPlanningRegeneratedWeekKey = _asString(root['lastPlanningRegeneratedWeekKey']) ?? '';
        _lastPlanningRegeneratedDays = _asIntList(root['lastPlanningRegeneratedDays']);
        final regeneratedAtRaw = _asString(root['lastPlanningRegeneratedAt']);
        _lastPlanningRegeneratedAt = regeneratedAtRaw == null ? null : DateTime.tryParse(regeneratedAtRaw);
        final planningReportReadAtRaw = _asString(root['planningReportReadAt']);
        _planningReportReadAt = planningReportReadAtRaw == null ? null : DateTime.tryParse(planningReportReadAtRaw);
        _regenerateWholeWeekAfterReset = _asBool(root['regenerateWholeWeekAfterReset'], false);
        _lastPlanningWasFullWeek = _asBool(root['lastPlanningWasFullWeek'], false);
        _generationActivityRules.clear();
        final rawActivityRules = root['generationActivityRules'];
        if (rawActivityRules is Map) {
          for (final entry in rawActivityRules.entries) {
            final key = entry.key.toString();
            final value = entry.value?.toString();
            if (value != null && const {'normal', 'prioritize', 'avoid', 'less', 'more'}.contains(value)) {
              _generationActivityRules[key] = value;
            }
          }
        }
        _regeneratedSportBudgets.clear();
        final rawRegeneratedSportBudgets = root['regeneratedSportBudgets'];
        if (rawRegeneratedSportBudgets is Map) {
          for (final entry in rawRegeneratedSportBudgets.entries) {
            final day = _asInt(entry.key, -1);
            final minutes = _asInt(entry.value);
            if (day >= 0 && day < 7 && minutes > 0) {
              _regeneratedSportBudgets[day] = minutes;
            }
          }
        }
        final rawCriteria = root['generationCriteria'];
        if (rawCriteria is Map) {
          _generationRespectPriorities = _asBool(rawCriteria['respectPriorities'], true);
          _generationUseHistory = _asBool(rawCriteria['useHistory'], true);
          _generationBalanceLoad = _asBool(rawCriteria['balanceLoad'], true);
          _generationRespectPreferredDays = _asBool(rawCriteria['respectPreferredDays'], true);
          _generationAlternateActivities = _asBool(rawCriteria['alternateActivities'], true);
          _generationLearnHabits = _asBool(rawCriteria['learnHabits'], true);
        }
        _lastPlanningCoachExplanation = _asString(root['lastPlanningCoachExplanation']) ?? '';
        _lastPlanningDecisionDetails = root['lastPlanningDecisionDetails'] is List
            ? (root['lastPlanningDecisionDetails'] as List)
                .map((v) => '$v')
                .where((v) => v.trim().isNotEmpty)
                .take(30)
                .toList()
            : <String>[];
        final thought = _asString(root['morningThought']);
        if (thought != null && thought.isNotEmpty) _morningThought = thought;
      });
      for (final item in plan) {
        if (_isDateRangePlanItem(item)) {
          item.done = false;
          item.realisedMinutes = null;
          item.feeling = null;
        }
      }
      _normalizeSportDailyOccurrences();
      _refreshSportBudgetCoachSuggestion();
      _queueLocalStatePersist();
      _showFeedback('Sauvegarde restaurée.');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetDatabaseCompletely() async {
    if (!mounted) return;

    // Invalide toute écriture différée issue de l'ancien état avant de
    // construire le nouvel état. Un callback post-frame déjà programmé
    // verra une génération obsolète et ne pourra plus réécrire l'ancien état.
    ++_persistenceGeneration;

    // RÉINITIALISATION = base vierge de tout SAUF des activités.
    // Les activités restent exactement telles qu’elles sont aujourd’hui,
    // y compris les activités ajoutées ou modifiées par l’utilisateur.
    // Le planning est volontairement vidé : il devra être régénéré avec
    // le bouton « Repenser » lorsque l’utilisateur le souhaitera.
    final keptActivities = List<Activity>.from(activities);
    final emptyPlan = <PlanItem>[];
    final emptyLogs = <ActivityLog>[];
    final freshThought = _MaBelleSemaineAppState.morningThoughts[Random().nextInt(_MaBelleSemaineAppState.morningThoughts.length)];

    setState(() {
      activities = keptActivities;
      plan = emptyPlan;
      logs = emptyLogs;
      dailySummaries = [];
      activityMoveLogs = [];
      _manualDayRemovals = {};
      _manualDayRemovalsWeekKey = _currentWeekKey();
      weeklyNote = '';
      _nextWeekCoachDirections.clear();
      sportCoachLastAnalysis = '';
      sportCoachLastAnalysisAt = null;
      sportCoachSuggestion = '';
      sportCoachSuggestionDelta = 0;
      _pendingSportCoachSuggestionDeltas = {};
      sportCoachLogs = [];
      sportCoachDailyAdjustments = {};
      _manualSportBudgetOverrideDays = {};
      _userName = '';
      _weatherCity = '';
      _todayNameday = '';
      _todayNamedayDateKey = '';
      _weatherText = '';
      _weatherTemperature = '';
      _weatherError = '';
      _homeMascotKind = 'ourson';
      _homeMascotEmoji = '🧸';
      _homeMascotImageData = '';
      _dailyPriorityActivityIds.clear();
      _priorityBonusAwardedDateKey = '';
      _priorityBonusAwarded = false;
      _priorityBonusTotal = 0;
      _priorityRewardText = 'un moment plaisir';
      // Une réinitialisation complète repart aussi sans objectifs de réalisation.
      _realizationGoals.clear();
      _systemIconOverrides.clear();
      _systemUiIconOverrides.clear();
      categoryFilter = 'Toutes';
      tab = 0;
      _morningThought = freshThought;
      _generationRespectPriorities = true;
      _generationUseHistory = true;
      _generationBalanceLoad = true;
      _generationRespectPreferredDays = true;
      _generationAlternateActivities = true;
      _generationLearnHabits = true;
      _lastPlanningRegeneratedWeekKey = '';
      _lastPlanningRegeneratedDays = [];
      _lastPlanningRegeneratedAt = null;
      _planningReportReadAt = null;
      _regenerateWholeWeekAfterReset = true;
      _lastPlanningWasFullWeek = false;
      _lastPlanningCoachExplanation = '';
      _lastPlanningDecisionDetails = [];
      _generationActivityRules.clear();
      _regeneratedSportBudgets.clear();
      _mondayRegenPromptDismissed = false;
      _resetGeneration++;
    });

    await WidgetsBinding.instance.endOfFrame;

    if (mounted) {
      // Reset = état critique : on attend la fin de l'écriture avant de
      // laisser l'écran Data revenir en arrière.
      _persistLocalState(recordUndo: false);
      await _flushPersistenceWrites();
      _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('✓ Base vierge · ${activities.length} activités conservées · planning vide'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> exportBackupFile() async {
    final bytes = Uint8List.fromList(utf8.encode(_backupJson()));
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'mybestweek_backup_$dateStr.json';
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer ma sauvegarde MyBestWeek',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (saved == null && !kIsWeb) {
        _showFeedback('Sauvegarde annulée.');
        return false;
      }

      final now = DateTime.now();
      _lastFileBackupAt = now;
      _persistLocalState(recordUndo: false);
      if (mounted) setState(() {});
      _showFeedback(kIsWeb ? 'Sauvegarde téléchargée.' : '✓ Sauvegarde enregistrée dans Fichiers.');
      return true;
    } catch (_) {
      _showFeedback('Impossible de créer la sauvegarde.');
      return false;
    }
  }

  Future<void> exportBackupToICloud() async {
    final exported = await exportBackupFile();
    if (!exported || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (c) => AlertDialog(
        title: const Text('Sauvegarde iCloud'),
        content: const Text(
          'Le fichier vient d’être créé. Sur iPhone, vérifie qu’il est enregistré dans « Fichiers » → « iCloud Drive », puis confirme ici.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Plus tard')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('C’est fait')),
        ],
      ),
    );
    if (confirmed == true) {
      final confirmedAt = DateTime.now();
      _lastICloudBackupAt = confirmedAt;
      _persistLocalState(recordUndo: false);
      if (mounted) setState(() {});
      _showFeedback('✓ Sauvegarde iCloud enregistrée comme effectuée.');
    }
  }

  String _cloudBackupStatusText() {
    final last = _lastICloudBackupAt;
    if (last == null) return 'Aucune sauvegarde iCloud confirmée.';
    final d = last.toLocal();
    return 'Dernière sauvegarde iCloud : ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }

  String _fileBackupStatusText() {
    final last = _lastFileBackupAt;
    if (last == null) return 'Aucune copie de fichier créée.';
    final d = last.toLocal();
    return 'Dernière copie : ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> importBackupFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      var bytes = file.bytes;
      if (bytes == null) {
        try {
          bytes = await file.xFile.readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes == null || bytes.isEmpty) {
        _showFeedback('Impossible de lire le fichier de sauvegarde.');
        return false;
      }

      final raw = utf8.decode(bytes, allowMalformed: true);
      if (raw.trim().isEmpty) return false;

      final ok = restoreBackup(raw);
      if (!ok) {
        _showFeedback('Fichier de sauvegarde invalide.');
        return false;
      }
      _showFeedback('Sauvegarde restaurée.');
      return true;
    } catch (_) {
      _showFeedback('Impossible d’ouvrir cette sauvegarde.');
      return false;
    }
  }

}
