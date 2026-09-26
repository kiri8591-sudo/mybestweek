// V9.03 — Helpers planning / calendrier
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _PlanningHelpersPart on _MaBelleSemaineAppState {
  int _dayLoadMinutes(int day) => plan
      .where((p) => p.day == day)
      .fold<int>(0, (sum, p) => sum + p.duration);

  String _periodForActivity(Activity activity, int day) {
    if (!_isSportActivity(activity) && !activity.isSportProgram) {
      final saved = activity.period == 'Midi' ? 'Après-midi' : activity.period;
      return ['Matin', 'Après-midi', 'Soir'].contains(saved) ? saved : 'Après-midi';
    }
    switch (activity.category) {
      case 'Sport':
      case 'Bien-être':
      case 'Sortie':
        return 'Matin';
      case 'Culture':
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

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _sameDateValue(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _shortDate(DateTime value) {
    final d = _dateOnly(value);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _dateRangeLabel(Activity activity) {
    if (!activity.isDateRange || activity.rangeStart == null || activity.rangeEnd == null) {
      return '';
    }
    final start = _shortDate(activity.rangeStart!);
    final end = _shortDate(activity.rangeEnd!);
    return start == end ? 'Le $start · tous les jours' : 'Du $start au $end · tous les jours';
  }

  List<int> _dateRangeDaysForCurrentWeek(Activity activity) {
    if (!activity.isDateRange || activity.rangeStart == null || activity.rangeEnd == null) return [];
    final start = _dateOnly(activity.rangeStart!);
    final end = _dateOnly(activity.rangeEnd!);
    if (end.isBefore(start)) return [];
    final monday = _startOfCurrentWeek();
    final result = <int>[];
    for (var day = 0; day < 7; day++) {
      final date = monday.add(Duration(days: day));
      if (!date.isBefore(start) && !date.isAfter(end)) result.add(day);
    }
    return result;
  }

  void _ensureDateRangeActivityInCurrentWeek(Activity activity) {
    final days = _dateRangeDaysForCurrentWeek(activity);
    if (days.isEmpty) return;
    for (final day in days) {
      final exists = plan.any((item) =>
          item.activityId == activity.id && item.day == day && !item.fixedInWeeklyTemplate);
      if (exists) continue;
      plan.add(PlanItem(
        id: 'range_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_$day',
        activityId: activity.id,
        day: day,
        period: _periodForActivity(activity, day),
        timeLabel: null,
        title: activity.name,
        details: 'Activité quotidienne · ${_dateRangeLabel(activity)}',
        duration: activity.duration,
        optional: false,
        userAdded: true,
        fixedInWeeklyTemplate: false,
      ));
    }
  }





}
