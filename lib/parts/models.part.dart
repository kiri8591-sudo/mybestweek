part of '../main.dart';

class _DayWeather {
  final String icon;
  final String text;
  final String temperature;
  final bool outdoorBad;

  const _DayWeather({
    required this.icon,
    required this.text,
    required this.temperature,
    required this.outdoorBad,
  });
}

final Map<String, String> _customActivityIconData = {};
final Map<String, Uint8List> _customActivityIconBytes = {};


// Registre global des icônes d'interface. Les écrans secondaires peuvent ainsi
// respecter les personnalisations définies dans « Système » sans dupliquer la logique.
final Map<String, String> _systemUiIconOverrides = {};

String _uiIconValue(String key, String fallback) =>
    _systemUiIconOverrides[key] ?? fallback;

double _standardUiIconSize(String key, double requested) {
  const headerKeys = {
    'navHome', 'navWeek', 'navActivities', 'navPriorities', 'navObjectives',
    'periodMorning', 'periodAfternoon', 'periodEvening', 'sport', 'coach',
    'system', 'challenge', 'objective', 'objectiveDetail', 'streak', 'priority',
    'history', 'review', 'backup', 'restore', 'reset', 'calendar', 'week',
  };
  const actionKeys = {
    'add', 'edit', 'remove', 'delete', 'confirm', 'help', 'photo',
    'emoji', 'manageIcons', 'save', 'filter', 'duration', 'move', 'repeat', 'close', 'apply',
    'settings', 'identity', 'location', 'refresh', 'insights', 'undo', 'reviewBack',
    'histTrend', 'histStable', 'histSortUp', 'histSortDown', 'histEmpty',
    'backupDevice', 'backupCloud', 'backupFile', 'backupShield', 'backupDownload', 'backupUpload', 'backupFolder',
    'backupReset', 'backupDue', 'backupOk', 'reviewMoments', 'reviewRegularity',
    'reviewPlanned', 'reviewRealized', 'reviewRemaining', 'reviewMoved', 'reviewValidated',
    'reviewUnexpected', 'reviewActiveDays', 'reviewTime', 'reviewDifficult', 'reviewPiano', 'reviewMood',
    'sportActive', 'sportMinutes', 'sportRate', 'sportMissing', 'sportFilter', 'sportBack', 'sportNext',
    'sportReactivate', 'sportWarning', 'sportTimer', 'objectiveSave', 'objectiveDelete', 'objectiveState',
    'nextWeekDirections', 'dragDown', 'expandMore', 'planOpen', 'missionDone',
  };
  if (headerKeys.contains(key)) return requested < 20 ? 20 : requested.clamp(20, 23).toDouble();
  if (actionKeys.contains(key)) return requested.clamp(17, 19).toDouble();
  return requested.clamp(16, 22).toDouble();
}

Widget _uiIcon(
  String key,
  IconData fallback, {
  String? fallbackEmoji,
  double size = 18,
  Color? color,
}) {
  final effectiveSize = _standardUiIconSize(key, size);
  final override = _systemUiIconOverrides[key];
  if (override != null && override.isNotEmpty) {
    return _activityIconWidget(override, size: effectiveSize);
  }
  return Icon(fallback, size: effectiveSize, color: color ?? _colors.textMuted);
}

Uint8List? _decodeCustomIconData(String data) {
  try {
    final comma = data.indexOf(',');
    final encoded = comma >= 0 ? data.substring(comma + 1) : data;
    if (encoded.trim().isEmpty) return null;
    return Uint8List.fromList(base64Decode(encoded));
  } catch (_) {
    return null;
  }
}

Widget _frozenActivityMarker(Activity? activity, {double size = 16}) {
  if (activity == null || !activity.isFrozen) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Tooltip(
      message: 'Activité gelée · ajout manuel possible',
      child: _activityIconWidget(_uiIconValue('frozen', '🧊'), size: size),
    ),
  );
}

String _planItemIconValue(PlanItem item, Iterable<Activity> activities) {
  if (item.activityId != null) {
    for (final activity in activities) {
      if (activity.id == item.activityId) return activity.emoji;
    }
  }
  return item.customEmoji ?? '📍';
}

String _activityLogIconValue(ActivityLog log, Iterable<Activity> activities) {
  if (log.activityId != null) {
    for (final activity in activities) {
      if (activity.id == log.activityId) return activity.emoji;
    }
  }
  return log.emoji;
}

Widget _activityIconWidget(String value, {double size = 24}) {
  if (value.startsWith('customicon://')) {
    final id = value.substring('customicon://'.length);
    final data = _customActivityIconData[id];
    if (data != null && data.isNotEmpty) {
      try {
        final bytes = _customActivityIconBytes[id] ??= _decodeCustomIconData(data)!;
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Text('🖼️', style: TextStyle(fontSize: size * .78)),
        );
      } catch (_) {}
    }
    return Text('🖼️', style: TextStyle(fontSize: size * .78));
  }
  if (value.startsWith('pack://')) {
    return Image.asset(
      'assets/icons/pack/${value.substring('pack://'.length)}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Text('🖼️', style: TextStyle(fontSize: size * .78)),
    );
  }
  if (value == '🧸') return mascotChoiceAvatar(size: size);
  return Text(value, style: TextStyle(fontSize: size * .78));
}

String _normalizeFeeling(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  if (value == 'Validé' || value == 'Valide') return 'Bien';
  return value;
}

class Activity {
  final String id;
  String name;
  String emoji;
  String category;
  String period;
  int duration;
  int frequency;
  int priority;
  List<int> preferredDays;
  bool isDateRange;
  bool isFrozen;
  DateTime? rangeStart;
  DateTime? rangeEnd;
  int sportWeight;
  bool allowMultiplePerDay;
  int maxDailyOccurrences;
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
    this.period = 'Après-midi',
    required this.duration,
    required this.frequency,
    required this.priority,
    this.preferredDays = const [],
    this.isDateRange = false,
    this.isFrozen = false,
    this.rangeStart,
    this.rangeEnd,
    this.sportWeight = 5,
    this.allowMultiplePerDay = false,
    this.maxDailyOccurrences = 2,
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
        period: period,
        duration: duration,
        frequency: frequency,
        priority: priority,
        preferredDays: [...preferredDays],
        isDateRange: isDateRange,
        isFrozen: isFrozen,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        sportWeight: sportWeight,
        allowMultiplePerDay: allowMultiplePerDay,
        maxDailyOccurrences: maxDailyOccurrences,
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
  bool manualPlacement;
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
    this.manualPlacement = false,
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


class DailySummary {
  final DateTime date;
  final String dateKey;
  final String moodEmoji;
  final String summary;
  final int completedCount;
  final int totalCount;
  final int plannedMinutes;
  final int realisedMinutes;
  final List<String> activityTitles;

  DailySummary({
    required this.date,
    required this.dateKey,
    required this.moodEmoji,
    required this.summary,
    required this.completedCount,
    required this.totalCount,
    required this.plannedMinutes,
    required this.realisedMinutes,
    required this.activityTitles,
  });
}

class ActivityMoveLog {
  final DateTime date;
  final String activityName;
  final String? activityId;
  final int fromDay;
  final int toDay;
  final String fromPeriod;
  final String toPeriod;

  ActivityMoveLog({
    required this.date,
    required this.activityName,
    this.activityId,
    required this.fromDay,
    required this.toDay,
    required this.fromPeriod,
    required this.toPeriod,
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

class _ActivityLearningProfile {
  final int realisedCount;
  final int skippedCount;
  final int recent7Count;
  final Map<int, int> dayCounts;
  final Map<int, int> skippedDayCounts;
  final Map<String, int> periodCounts;
  final Map<String, int> skippedPeriodCounts;
  final Map<int, int> movedToDayCounts;
  final int difficultCount;
  final int veryGoodCount;
  final int realisedMinutes;
  final int plannedMinutes;
  final int movedFromCount;
  final int movedToCount;

  const _ActivityLearningProfile({
    required this.realisedCount,
    required this.skippedCount,
    required this.recent7Count,
    required this.dayCounts,
    required this.skippedDayCounts,
    required this.periodCounts,
    required this.skippedPeriodCounts,
    required this.movedToDayCounts,
    required this.difficultCount,
    required this.veryGoodCount,
    required this.realisedMinutes,
    required this.plannedMinutes,
    required this.movedFromCount,
    required this.movedToCount,
  });

  bool get hasEnoughData => realisedCount >= 3;

  int get observedCount => realisedCount + skippedCount;

  double get completionRate => observedCount <= 0 ? 0 : realisedCount / observedCount;

  int get bestDay {
    if (dayCounts.isEmpty) return -1;
    return dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String? get bestPeriod {
    if (periodCounts.isEmpty) return null;
    return periodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double dayShare(int day) => realisedCount <= 0 ? 0 : (dayCounts[day] ?? 0) / realisedCount;

  double dayCompletionRate(int day) {
    final observed = (dayCounts[day] ?? 0) + (skippedDayCounts[day] ?? 0);
    return observed <= 0 ? 0 : (dayCounts[day] ?? 0) / observed;
  }

  double periodCompletionRate(String period) {
    final observed = (periodCounts[period] ?? 0) + (skippedPeriodCounts[period] ?? 0);
    return observed <= 0 ? 0 : (periodCounts[period] ?? 0) / observed;
  }

  int get bestMovedToDay {
    if (movedToDayCounts.isEmpty) return -1;
    return movedToDayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get bestMovedToDayShare {
    if (movedToCount <= 0 || movedToDayCounts.isEmpty) return 0;
    return movedToDayCounts.values.reduce((a, b) => a >= b ? a : b).toDouble() / movedToCount;
  }

  double get durationRatio => averagePlannedMinutes <= 0 ? 1 : averageRealisedMinutes / averagePlannedMinutes;

  double get durationGapRatio => (durationRatio - 1).abs();

  double get bestDayShare {
    if (realisedCount <= 0 || dayCounts.isEmpty) return 0;
    return dayCounts.values.reduce((a, b) => a >= b ? a : b).toDouble() / realisedCount;
  }

  double periodShare(String period) => realisedCount <= 0 ? 0 : (periodCounts[period] ?? 0) / realisedCount;

  double get averageRealisedMinutes => realisedCount <= 0 ? 0 : realisedMinutes / realisedCount;

  double get averagePlannedMinutes => realisedCount <= 0 ? 0 : plannedMinutes / realisedCount;

  double get difficultRate => realisedCount <= 0 ? 0 : difficultCount / realisedCount;

  double get veryGoodRate => realisedCount <= 0 ? 0 : veryGoodCount / realisedCount;
}

