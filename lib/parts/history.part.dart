// V12.5.0 — Historique harmonisé sur les composants communs (app_ui.part.dart).
// Comportement, filtres et lignes compactes conservés ; journal groupé par jour.

part of '../main.dart';

class _HistorySheet extends StatefulWidget {
  final List<ActivityLog> logs;
  final List<Activity> activities;
  final List<String> dayNames;
  final VoidCallback onOpenGenerationCriteria;
  final Future<void> Function(ActivityLog log) onEditLog;
  final Future<void> Function() onAddLog;

  const _HistorySheet({
    required this.logs,
    required this.activities,
    required this.dayNames,
    required this.onOpenGenerationCriteria,
    required this.onEditLog,
    required this.onAddLog,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  String _historyFilter = 'Tout';
  String _memoryFilter = 'Toutes';
  String _memoryNameFilter = '';
  String _memoryType = 'Tous';
  String _memorySort = 'Besoin';
  bool _memorySortAscending = false;

  List<ActivityLog> _filteredLogs() {
    final now = DateTime.now();
    DateTime? cutoff;
    switch (_historyFilter) {
      case '1 mois':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case '3 mois':
        cutoff = now.subtract(const Duration(days: 90));
        break;
      case '1 an':
        cutoff = now.subtract(const Duration(days: 365));
        break;
      case 'Tout':
      default:
        cutoff = null;
    }

    final periodLogs = widget.logs
        .where((log) => cutoff == null || !log.date.isBefore(cutoff!))
        .toList();

    // Le journal utilise exactement les mêmes filtres que « Mémoire par activité ».
    // La sélection nom/type/état est donc calculée une seule fois par _memoryActivities(),
    // puis les journaux de la période choisie sont ramenés aux activités retenues.
    final visibleActivities = _memoryActivities();
    final visibleIds = visibleActivities.map((a) => a.id).toSet();
    final visibleNames = visibleActivities.map((a) => a.name.trim().toLowerCase()).toSet();

    final filtered = periodLogs.where((log) {
      if (log.activityId != null) return visibleIds.contains(log.activityId);
      return visibleNames.contains(log.title.trim().toLowerCase());
    }).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  List<ActivityLog> _logsForDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return widget.logs.where((log) => !log.date.isBefore(cutoff)).toList();
  }

  int _countFor(Activity activity, int days) =>
      _logsForDays(days).where((log) =>
          (log.activityId != null && log.activityId == activity.id) ||
          (log.activityId == null &&
              log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())).length;

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours} h' : '${hours} h ${rest}';
  }

  String _dayLabelFromLogs(List<ActivityLog> source) {
    if (source.isEmpty) return '—';
    final counts = <int, int>{};
    for (final log in source) {
      counts[log.day] = (counts[log.day] ?? 0) + 1;
    }
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return best >= 0 && best < widget.dayNames.length ? widget.dayNames[best] : '—';
  }

  String _categoryLabel(List<ActivityLog> source) {
    if (source.isEmpty) return '—';
    final counts = <String, int>{};
    for (final log in source) {
      counts[log.category] = (counts[log.category] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Activity? _mostFrequentActivity(List<ActivityLog> source) {
    if (source.isEmpty) return null;
    final counts = <String, int>{};
    for (final log in source) {
      final key = log.activityId ?? 'title:${log.title.trim().toLowerCase()}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final bestKey = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    for (final a in widget.activities) {
      if (a.id == bestKey) return a;
    }
    final match = source.firstWhere((l) => (l.activityId ?? 'title:${l.title.trim().toLowerCase()}') == bestKey);
    return Activity(
      id: 'history_${bestKey.hashCode}',
      name: match.title,
      emoji: match.emoji,
      category: match.category,
      period: match.period,
      duration: match.plannedMinutes,
      frequency: 1,
      priority: 1,
    );
  }

  List<Activity> _underTargetActivities() {
    const days = 30;
    final result = <Activity>[];
    for (final activity in widget.activities) {
      if (!activity.activeInSportRotation && activity.category == 'Sport') continue;
      final expected = activity.frequency.clamp(1, 7) * days / 7.0;
      final actual = _countFor(activity, days);
      if (actual < expected * .65) result.add(activity);
    }
    result.sort((a, b) {
      final da = a.frequency * days / 7.0 - _countFor(a, days);
      final db = b.frequency * days / 7.0 - _countFor(b, days);
      return db.compareTo(da);
    });
    return result.take(4).toList();
  }

  List<Activity> _wellAnchoredActivities() {
    const days = 30;
    final result = <Activity>[];
    for (final activity in widget.activities) {
      final expected = activity.frequency.clamp(1, 7) * days / 7.0;
      final actual = _countFor(activity, days);
      if (actual > 0 && actual >= expected * .80) result.add(activity);
    }
    result.sort((a, b) => _countFor(b, days).compareTo(_countFor(a, days)));
    return result.take(4).toList();
  }

  Widget _metric(String label, String value, String iconKey, IconData icon) {
    return Expanded(child: _StatTile(label: label, value: value, iconKey: iconKey, icon: icon));
  }

  Widget _insightTile({required String title, required String text, required String iconKey, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _colors.tintStrong,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: _uiIcon(iconKey, icon, size: 17, color: _colors.accentIcon),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong)),
              const SizedBox(height: 2),
              Text(text, style: TextStyle(fontSize: AppType.body, color: _colors.textMuted, height: 1.3)),
            ]),
          ),
        ],
      ),
    );
  }

  double _adherenceFor(Activity activity, int days) {
    final expected = activity.frequency.clamp(1, 7) * days / 7.0;
    if (expected <= 0) return 0;
    return (_countFor(activity, days) / expected).clamp(0.0, 1.0);
  }

  String _lastDoneLabel(Activity activity, int days) {
    final logs = _logsForDays(days)
        .where((log) => (log.activityId != null && log.activityId == activity.id) ||
            (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (logs.isEmpty) return 'Jamais sur cette période';
    final age = max(0, DateTime.now().difference(logs.first.date).inDays);
    return age == 0 ? 'Aujourd’hui' : age == 1 ? 'Hier' : 'Il y a $age j';
  }

  String _habitualDay(Activity activity, int days) {
    final source = _logsForDays(days).where((log) =>
        (log.activityId != null && log.activityId == activity.id) ||
        (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())).toList();
    if (source.isEmpty) return '—';
    final counts = <int, int>{};
    for (final log in source) {
      counts[log.day] = (counts[log.day] ?? 0) + 1;
    }
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return best >= 0 && best < widget.dayNames.length ? widget.dayNames[best] : '—';
  }

  DateTime? _lastDateFor(Activity activity, int days) {
    DateTime? latest;
    for (final log in _logsForDays(days)) {
      final matches = (log.activityId != null && log.activityId == activity.id) ||
          (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());
      if (!matches) continue;
      if (latest == null || log.date.isAfter(latest)) latest = log.date;
    }
    return latest;
  }

  bool _memoryMatches(Activity activity) {
    final done = _countFor(activity, 30);
    final adherence = _adherenceFor(activity, 30);
    if (_memoryType == 'Sport' && activity.category != 'Sport') return false;
    if (_memoryType == 'Non sport' && activity.category == 'Sport') return false;
    if (!{'Tous', 'Sport', 'Non sport'}.contains(_memoryType) && activity.category != _memoryType) return false;
    switch (_memoryFilter) {
      case 'Réalisé':
        return done > 0;
      case 'À surveiller':
        return adherence < .65;
      case 'Bien installées':
        return done > 0 && adherence >= .80;
      case 'Jamais réalisées':
        return done == 0;
      case 'Toutes':
      default:
        return true;
    }
  }

  List<String> _memoryTypes() {
    final categories = widget.activities
        .map((a) => a.category.trim())
        .where((category) => category.isNotEmpty && category != 'Sport')
        .toSet()
        .toList();
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Sport', 'Non sport', ...categories];
  }

  List<Activity> _memoryActivities() {
    final visible = widget.activities.where((a) => _memoryMatches(a) && (_memoryNameFilter.trim().isEmpty || a.name.toLowerCase().contains(_memoryNameFilter.trim().toLowerCase()))).toList();
    visible.sort((a, b) {
      int compare;
      switch (_memorySort) {
        case 'Dernière réalisation':
          final ad = _lastDateFor(a, 30);
          final bd = _lastDateFor(b, 30);
          if (ad == null && bd == null) {
            compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          } else if (ad == null) {
            compare = -1;
          } else if (bd == null) {
            compare = 1;
          } else {
            compare = bd.compareTo(ad);
          }
          break;
        case 'Fréquence réelle':
          compare = _countFor(b, 30).compareTo(_countFor(a, 30));
          if (compare == 0) compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'Écart à l’objectif':
          final gapA = a.frequency.clamp(1, 7) * 30 / 7.0 - _countFor(a, 30);
          final gapB = b.frequency.clamp(1, 7) * 30 / 7.0 - _countFor(b, 30);
          compare = gapB.compareTo(gapA);
          if (compare == 0) compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'Nom':
          compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'Besoin':
        default:
          compare = _adherenceFor(a, 30).compareTo(_adherenceFor(b, 30));
          if (compare == 0) compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
      }
      return _memorySortAscending ? compare : -compare;
    });
    return visible;
  }

  Widget _activityMemoryRow(Activity activity) {
    final done = _countFor(activity, 30);
    final expected = activity.frequency.clamp(1, 7) * 30 / 7.0;
    final ratio = _adherenceFor(activity, 30);
    return InkWell(
      onTap: () => _showActivityMemory(activity),
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: _colors.tintStrong,
            child: _activityIconWidget(activity.emoji, size: 20),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              activity.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textStrong),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: ratio,
                backgroundColor: _colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(ratio >= .8 ? _colors.accentFill : ratio >= .65 ? _colors.accentOutline : _colors.warnBorder),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$done/${expected.round()}',
            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textWarm),
          ),
          const SizedBox(width: 4),
          _uiIcon('planOpen', Icons.chevron_right, size: 17, color: _colors.textMuted),
        ]),
      ),
    );
  }

  void _showActivityMemory(Activity activity) {
    final last30 = _logsForDays(30).where((log) =>
        (log.activityId != null && log.activityId == activity.id) ||
        (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase())).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final realised = last30.fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final planned = last30.fold<int>(0, (sum, log) => sum + log.plannedMinutes);
    final difficult = last30.where((log) => log.feeling == 'Difficile').length;
    final veryGood = last30.where((log) => log.feeling == 'Très bien').length;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: _colors.tintStrong, child: _activityIconWidget(activity.emoji, size: 34)),
              const SizedBox(width: 10),
              Expanded(child: Text(activity.name, style: _sheetTitleStyle(context))),
            ]),
            const SizedBox(height: 14),
            Text('Mémoire sur 30 jours', style: _sectionTitleStyle(context)),
            const SizedBox(height: 8),
            Text('Réalisée ${last30.length} fois · prévue environ ${ (activity.frequency.clamp(1, 7) * 30 / 7.0).round()} fois.', style: const TextStyle(fontSize: AppType.body)),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: _colors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tes réglages', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                const SizedBox(height: 4),
                Text('${activity.frequency}×/semaine · ${activity.duration} min · priorité ${activity.priority}/5 · jours préférés : ${activity.preferredDays.isEmpty ? 'aucun' : activity.preferredDays.map((d) => d >= 0 && d < widget.dayNames.length ? widget.dayNames[d] : '').where((v) => v.isNotEmpty).join(', ')}',
                    style: const TextStyle(fontSize: AppType.label, height: 1.3)),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Dernière réalisation : ${_lastDoneLabel(activity, 30)} · jour habituel : ${_habitualDay(activity, 30)}.', style: const TextStyle(fontSize: AppType.body)),
            const SizedBox(height: 5),
            Text('Habitude apprise : ${_learnedMemorySentence(activity)}', style: TextStyle(fontSize: AppType.body, color: _colors.accentIcon)),
            const SizedBox(height: 5),
            Text('Temps : ${_durationText(realised)} réalisés', style: const TextStyle(fontSize: AppType.body)),
            if (planned > 0) ...[
              const SizedBox(height: 5),
              Text('Écart sur les séances enregistrées : ${realised - planned >= 0 ? '+' : ''}${realised - planned} min.', style: const TextStyle(fontSize: AppType.body)),
            ],
            if (difficult > 0 || veryGood > 0) ...[
              const SizedBox(height: 5),
              Text('Ressentis : ${veryGood > 0 ? 'Très bien $veryGood' : ''}${veryGood > 0 && difficult > 0 ? ' · ' : ''}${difficult > 0 ? 'Difficile $difficult' : ''}.', style: const TextStyle(fontSize: AppType.body)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openActivityStats(activity);
                },
                icon: _uiIcon('insights', Icons.donut_large_rounded, size: 17),
                label: const Text('Voir les statistiques'),
              ),
            ),
            const SizedBox(height: AppSpace.s),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))),
          ]),
        ),
      ),
    );
  }

  String _learnedMemorySentence(Activity activity) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 60));
    final matched = widget.logs.where((log) =>
        !log.date.isBefore(cutoff) &&
        ((log.activityId != null && log.activityId == activity.id) ||
            (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase()))).toList();
    if (matched.length < 3) return 'encore en apprentissage (moins de 3 réalisations sur 60 jours).';
    final dayCounts = <int, int>{};
    final periodCounts = <String, int>{};
    var realised = 0;
    for (final log in matched) {
      dayCounts[log.day] = (dayCounts[log.day] ?? 0) + 1;
      final period = log.period == 'Midi' ? 'Après-midi' : log.period;
      periodCounts[period] = (periodCounts[period] ?? 0) + 1;
      realised += log.realisedMinutes;
    }
    final bestDayEntry = dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final bestPeriodEntry = periodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final pieces = <String>[];
    if (bestDayEntry.value / matched.length >= .55 && bestDayEntry.key >= 0 && bestDayEntry.key < widget.dayNames.length) {
      pieces.add('surtout le ${widget.dayNames[bestDayEntry.key].toLowerCase()}');
    }
    if (bestPeriodEntry.value / matched.length >= .60) {
      pieces.add('plutôt ${bestPeriodEntry.key.toLowerCase()}');
    }
    if (realised > 0) pieces.add('${(realised / matched.length).round()} min réellement en moyenne');
    return pieces.isEmpty ? 'pas encore de tendance assez nette.' : '${pieces.join(' · ')}.';
  }

  String _durationText(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h} h' : '${h} h ${m.toString().padLeft(2, '0')}';
  }

  String _learningOverviewText() {
    final candidates = <String>[];
    for (final activity in widget.activities) {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 60));
      final matched = widget.logs.where((log) =>
          !log.date.isBefore(cutoff) &&
          ((log.activityId != null && log.activityId == activity.id) ||
              (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase()))).toList();
      if (matched.length < 3) continue;
      final dayCounts = <int, int>{};
      final periodCounts = <String, int>{};
      var realised = 0;
      for (final log in matched) {
        dayCounts[log.day] = (dayCounts[log.day] ?? 0) + 1;
        final period = log.period == 'Midi' ? 'Après-midi' : log.period;
        periodCounts[period] = (periodCounts[period] ?? 0) + 1;
        realised += log.realisedMinutes;
      }
      final bestDay = dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final bestPeriod = periodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final notes = <String>[];
      if (bestDay.value / matched.length >= .55 && bestDay.key >= 0 && bestDay.key < widget.dayNames.length) {
        notes.add('souvent ${widget.dayNames[bestDay.key].toLowerCase()}');
      }
      if (bestPeriod.value / matched.length >= .60) notes.add('plutôt ${bestPeriod.key.toLowerCase()}');
      if (notes.isNotEmpty) candidates.add('${activity.name} est ${notes.join(' et ')}');
      if (candidates.length >= 3) break;
    }
    if (candidates.isEmpty) {
      return widget.logs.isEmpty
          ? 'Je commence avec les règles de ta fiche. Dès que tu auras quelques réalisations, j’apprendrai progressivement tes jours, tes moments et tes durées habituels.'
          : 'J’apprends progressivement tes habitudes. À partir de 3 réalisations d’une activité, je peux commencer à identifier ses jours et moments réellement favorables.';
    }
    return 'Je tiens progressivement compte de tes habitudes : ${candidates.join(' · ')}.';
  }

  Widget _analysisCard() {
    final last7 = _logsForDays(7);
    final last30 = _logsForDays(30);
    final minutes7 = last7.fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final minutes30 = last30.fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final activeDays = last7.map((l) => l.date.year * 10000 + l.date.month * 100 + l.date.day).toSet().length;
    final avgWeek = (last30.length * 7 / 30).toStringAsFixed(1).replaceAll('.', ',');
    final busiestDay = _dayLabelFromLogs(last30);
    final topCategory = _categoryLabel(last30);
    final topActivity = _mostFrequentActivity(last30);
    final under = _underTargetActivities();
    final anchored = _wellAnchoredActivities();
    final memoryList = _memoryActivities();

    return Column(
      children: [
        _AppCard(
          tone: _CardTone.soft,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(
                iconKey: 'insights',
                fallbackIcon: Icons.auto_graph_outlined,
                title: 'Ce que ton historique apprend',
              ),
              const SizedBox(height: 11),
              Row(children: [
                _metric('moments · 7 j', '${last7.length}', 'reviewMoments', Icons.check_circle_outline),
                const SizedBox(width: 7),
                _metric('temps · 7 j', _durationLabel(minutes7), 'reviewTime', Icons.timer_outlined),
                const SizedBox(width: 7),
                _metric('jours actifs · 7 j', '$activeDays/7', 'reviewActiveDays', Icons.calendar_month_outlined),
              ]),
              const SizedBox(height: 7),
              Text('Sur 30 jours : ${last30.length} moments · ${_durationLabel(minutes30)} · $avgWeek moments/semaine en moyenne.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted)),
              const SizedBox(height: 5),
              Text('Tu réalises surtout tes activités le $busiestDay et la catégorie la plus présente est « $topCategory ».', style: const TextStyle(fontSize: AppType.body, height: 1.3)),
              if (topActivity != null) ...[
                const SizedBox(height: 5),
                Text('Ton activité la plus régulière sur 30 jours : ${topActivity.name}.', style: const TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 9),
        _AppCard(
          tone: _CardTone.soft,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(
                iconKey: 'settings',
                fallbackIcon: Icons.tune_outlined,
                title: 'À faire évoluer',
              ),
              const SizedBox(height: 6),
              if (under.isEmpty)
                Text('Aucune activité ne présente un écart important sur les 30 derniers jours.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted))
              else
                ...under.map((a) => _insightTile(
                      iconKey: 'histTrend',
                      title: a.name,
                      text: 'Prévue ${a.frequency}×/sem. · réalisée ${_countFor(a, 30)}× sur 30 jours. Elle mérite d’être davantage visible dans le planning.',
                      icon: Icons.trending_down_outlined,
                    )),
              if (anchored.isNotEmpty) ...[
                const SizedBox(height: 11),
                Text('Bien ancrées', style: _sectionTitleStyle(context)),
                ...anchored.map((a) => _insightTile(
                      iconKey: 'histStable',
                      title: a.name,
                      text: 'Rythme bien installé : ${_countFor(a, 30)} réalisation(s) sur les 30 derniers jours.',
                      icon: Icons.check_circle_outline,
                    )),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 9),
        _AppCard(
          tone: _CardTone.tint,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(
                iconKey: 'coach',
                fallbackIcon: Icons.psychology_outlined,
                title: 'Apprentissage du coach',
              ),
              const SizedBox(height: 6),
              Text(_learningOverviewText(), style: TextStyle(fontSize: AppType.label, color: _colors.accentIcon, height: 1.3)),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: widget.onOpenGenerationCriteria,
                icon: _uiIcon('settings', Icons.tune_rounded, size: 17),
                label: const Text('Modifier les consignes du coach'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 9),
        _AppCard(
          tone: _CardTone.soft,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(
                iconKey: 'insights',
                fallbackIcon: Icons.auto_graph_outlined,
                title: 'Mémoire par activité',
                trailing: _Pill('${memoryList.length}/${widget.activities.length}'),
              ),
              const SizedBox(height: 7),
              Text('Toutes tes activités ont une mémoire. Touche une ligne pour voir le détail sur 30 jours.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.3)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final value in const ['Toutes', 'Réalisé', 'À surveiller', 'Bien installées', 'Jamais réalisées'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(value, style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
                        selected: _memoryFilter == value,
                        onSelected: (_) => setState(() => _memoryFilter = value),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => setState(() => _memoryNameFilter = value),
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Filtrer par nom',
                  hintText: 'Nom de l’activité',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text('Type d’activité', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in <String>['Tous', ..._memoryTypes()])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(value, style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
                          selected: _memoryType == value,
                          onSelected: (_) => setState(() => _memoryType = value),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text('Trier par', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _memorySort,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'Besoin', child: Text('Besoin')),
                          DropdownMenuItem(value: 'Dernière réalisation', child: Text('Dernière réalisation')),
                          DropdownMenuItem(value: 'Fréquence réelle', child: Text('Fréquence réelle')),
                          DropdownMenuItem(value: 'Écart à l’objectif', child: Text('Écart à l’objectif')),
                          DropdownMenuItem(value: 'Nom', child: Text('Nom')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _memorySort = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    onTap: () => setState(() => _memorySortAscending = !_memorySortAscending),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _colors.tintStrong,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: _colors.borderTint),
                      ),
                      child: _uiIcon(
                        _memorySortAscending ? 'histSortUp' : 'histSortDown',
                        _memorySortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 18,
                        color: _colors.accentText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _memorySortAscending ? 'Ordre croissant' : 'Ordre décroissant',
                style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
              ),
              const SizedBox(height: 4),
              ...memoryList.map(_activityMemoryRow),
              if (memoryList.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucune activité dans ce filtre.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 9),
        _AppCard(
          tone: _CardTone.tint,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader(
                iconKey: 'coach',
                fallbackIcon: Icons.psychology_outlined,
                title: 'Ce que le coach retient',
              ),
              const SizedBox(height: 8),
              const Text(
                'Le prochain planning tient compte de la mémoire des 30 derniers jours : délai depuis la dernière réalisation, fréquence réelle, jours où l’activité est habituellement réalisée et ressentis difficiles ou très positifs.',
                style: TextStyle(fontSize: AppType.body, height: 1.35),
              ),
              const SizedBox(height: 7),
              Text(
                'Le coach ne remplace pas tes priorités ni tes jours préférés : l’historique sert à départager les possibilités et à éviter les répétitions inutiles.',
                style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.3),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _historyLogCard(ActivityLog log) {
    final date = log.date;
    final dateLabel = '${log.realisedMinutes} min';
    final feeling = _normalizeFeeling(log.feeling);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            Activity? activity;
            if (log.activityId != null) {
              for (final a in widget.activities) {
                if (a.id == log.activityId) {
                  activity = a;
                  break;
                }
              }
            }
            activity ??= _mostFrequentActivity([log]);
            if (activity != null) _showActivityMemory(activity);
          },
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _colors.tintStrong,
                  child: _activityIconWidget(_activityLogIconValue(log, widget.activities), size: 20),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    log.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.body, color: _colors.textStrong),
                  ),
                ),
                const SizedBox(width: 7),
                if (log.unplanned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Pill('Imprévu', background: _colors.warnBg, foreground: _colors.goldText),
                  ),
                if (log.feeling.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Tooltip(
                      message: 'Ressenti : ${log.feeling}',
                      child: Container(width: 9, height: 9, decoration: BoxDecoration(color: _feelingColor(feeling), shape: BoxShape.circle)),
                    ),
                  ),
                InkWell(
                  onTap: () async {
                    await widget.onEditLog(log);
                    if (mounted) setState(() {});
                  },
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        dateLabel,
                        maxLines: 1,
                        style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.edit_outlined, size: 13, color: _colors.textFaint),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StatsOverviewPage(logs: widget.logs, activities: widget.activities),
      ),
    );
  }

  void _openActivityStats(Activity activity) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ActivityStatsPage(activity: activity, logs: widget.logs),
      ),
    );
  }

  void _openUnderstanding() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ActivityUnderstandingPage(
          logs: widget.logs,
          activities: widget.activities,
          dayNames: widget.dayNames,
        ),
      ),
    );
  }

  Widget _dayHeader(DateTime day) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5, left: 2),
      child: Text(
        _friendlyDayLabel(day, DateTime.now()),
        style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _filteredLogs();
    // Entrées du journal : un en-tête par jour puis une ligne par réalisation.
    final entries = <Object>[];
    DateTime? lastDay;
    for (final log in sorted) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (lastDay == null || day != lastDay) {
        entries.add(day);
        lastDay = day;
      }
      entries.add(log);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .55,
      maxChildSize: .98,
      builder: (_, controller) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, 4, AppSpace.l, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Historique', style: _sheetTitleStyle(context)),
                  const SizedBox(height: 4),
                  Text(
                    widget.logs.isEmpty
                        ? 'Aucune activité enregistrée pour le moment.'
                        : 'Comprendre ton rythme et aider le coach.',
                    style: _hintStyle(),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpace.m),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _openStats,
                  icon: _uiIcon('insights', Icons.donut_large_rounded, size: 17),
                  label: const Text('Statistiques'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _openUnderstanding,
                  icon: _uiIcon('insights', Icons.auto_graph_outlined, size: 17),
                  label: const Text('Compréhension'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.m),
            Expanded(
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _analysisCard(),
                      const SizedBox(height: AppSpace.l),
                      Row(children: [
                        Expanded(child: Text('Journal des activités', style: _sectionTitleStyle(context))),
                        TextButton.icon(
                          style: TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
                          onPressed: () async {
                            await widget.onAddLog();
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter'),
                        ),
                      ]),
                      const SizedBox(height: AppSpace.s),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(value: '1 mois', label: Text('1 mois')),
                            ButtonSegment<String>(value: '3 mois', label: Text('3 mois')),
                            ButtonSegment<String>(value: '1 an', label: Text('1 an')),
                            ButtonSegment<String>(value: 'Tout', label: Text('Tout')),
                          ],
                          selected: <String>{_historyFilter},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            setState(() => _historyFilter = selection.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (widget.logs.isNotEmpty)
                        Text(
                          '${sorted.length} réalisation${sorted.length > 1 ? 's' : ''} affichée${sorted.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textMuted),
                        ),
                      if (sorted.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 35),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _activityIconWidget(_uiIconValue('histEmpty', '📖'), size: 42),
                                const SizedBox(height: 10),
                                Text('Aucune activité dans cette période.', style: TextStyle(color: _colors.textMuted)),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = entries[index];
                        if (entry is DateTime) return _dayHeader(entry);
                        return _historyLogCard(entry as ActivityLog);
                      },
                      childCount: entries.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


class _ActivityUnderstandingPage extends StatefulWidget {
  final List<ActivityLog> logs;
  final List<Activity> activities;
  final List<String> dayNames;

  const _ActivityUnderstandingPage({
    required this.logs,
    required this.activities,
    required this.dayNames,
  });

  @override
  State<_ActivityUnderstandingPage> createState() => _ActivityUnderstandingPageState();
}

class _ActivityUnderstandingPageState extends State<_ActivityUnderstandingPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _typeFilter = 'Toutes';

  bool _isSport(Activity activity) => activity.category.trim().toLowerCase() == 'sport';

  bool _matchesType(Activity activity) {
    if (_typeFilter == 'Sport') return _isSport(activity);
    if (_typeFilter == 'Non sport') return !_isSport(activity);
    return true;
  }

  String _monthLabel(DateTime value) {
    const names = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${names[value.month - 1]} ${value.year}';
  }

  DateTime _previousMonth(DateTime value) => DateTime(value.year, value.month - 1);
  DateTime _nextMonth(DateTime value) => DateTime(value.year, value.month + 1);

  bool _sameMonth(DateTime date) => date.year == _month.year && date.month == _month.month;

  bool _matchesActivity(ActivityLog log, Activity activity) {
    return (log.activityId != null && log.activityId == activity.id) ||
        (log.activityId == null && log.title.trim().toLowerCase() == activity.name.trim().toLowerCase());
  }

  List<ActivityLog> _activityMonthLogs(Activity activity) {
    return widget.logs.where((log) => _sameMonth(log.date) && _matchesActivity(log, activity)).toList();
  }

  int _daysInMonth() => DateTime(_month.year, _month.month + 1, 0).day;

  double _targetCount(Activity activity) {
    final frequency = activity.frequency.clamp(0, 7);
    return frequency == 0 ? 0 : frequency * _daysInMonth() / 7.0;
  }

  double _progress(Activity activity, int realisedCount) {
    final target = _targetCount(activity);
    if (target <= 0) return 0;
    return (realisedCount / target).clamp(0.0, 1.0).toDouble();
  }

  String _goalText(Activity activity) {
    final frequency = activity.frequency.clamp(0, 7);
    final duration = activity.duration;
    if (frequency == 0 && duration == 0) return 'Aucun objectif renseigné';
    final frequencyText = frequency == 1 ? '1×/semaine' : '$frequency×/semaine';
    if (duration <= 0) return 'Objectif : $frequencyText';
    return 'Objectif : $duration min · $frequencyText';
  }

  List<Activity> _visibleActivities() {
    final result = widget.activities.where(_matchesType).toList();
    result.sort((a, b) {
      final ac = _activityMonthLogs(a).length;
      final bc = _activityMonthLogs(b).length;
      if (ac != bc) return bc.compareTo(ac);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  Widget _monthArrow({required bool previous}) {
    return IconButton(
      tooltip: previous ? 'Mois précédent' : 'Mois suivant',
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() {
        _month = previous ? _previousMonth(_month) : _nextMonth(_month);
      }),
      icon: Icon(previous ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
    );
  }

  Widget _statRow(Activity activity) {
    final monthLogs = _activityMonthLogs(activity);
    final count = monthLogs.length;
    final progress = _progress(activity, count);
    final target = _targetCount(activity);
    final targetRounded = target.round();
    final realisedMinutes = monthLogs.fold<int>(0, (sum, log) => sum + log.realisedMinutes);
    final realisedText = realisedMinutes == 0 ? '' : ' · ${realisedMinutes} min réalisées';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s),
      child: _AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _colors.tintStrong,
                shape: BoxShape.circle,
              ),
              child: Center(child: _activityIconWidget(activity.emoji, size: 21)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '×$count',
                        style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textWarm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_goalText(activity)}$realisedText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(progress >= .8 ? _colors.accentFill : progress >= .5 ? _colors.accentOutline : _colors.warnBorder),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    targetRounded == 0
                        ? (count == 0 ? 'Pas encore réalisée ce mois-ci' : 'Réalisée ce mois-ci')
                        : '$count / $targetRounded réalisation${targetRounded > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleActivities();
    final monthLogs = widget.logs.where((log) => _sameMonth(log.date) &&
        (_typeFilter == 'Toutes' || (_typeFilter == 'Sport' ? log.category == 'Sport' : log.category != 'Sport'))).toList();
    final totalCount = monthLogs.length;
    final totalMinutes = monthLogs.fold<int>(0, (sum, log) => sum + log.realisedMinutes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compréhension'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 28),
          children: [
            Row(
              children: [
                _monthArrow(previous: true),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _colors.tintStrong,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: _colors.borderTint),
                      ),
                      child: Text(_monthLabel(_month), style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                    ),
                  ),
                ),
                _monthArrow(previous: false),
              ],
            ),
            const SizedBox(height: AppSpace.s),
            Center(child: Text('Statistiques mensuelles', style: _hintStyle())),
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                for (final filter in const ['Toutes', 'Sport', 'Non sport'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(filter, style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
                      selected: _typeFilter == filter,
                      onSelected: (_) => setState(() => _typeFilter = filter),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _AppCard(
              tone: _CardTone.tint,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  _uiIcon('insights', Icons.auto_graph_outlined, size: 20, color: _colors.accentIcon),
                  const SizedBox(width: 10),
                  Expanded(child: Text('$totalCount réalisation${totalCount > 1 ? 's' : ''} · ${_minutesLabel(totalMinutes)} vécues', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong))),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.m),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 55),
                child: Center(child: Text('Aucune activité dans ce filtre.', style: TextStyle(color: _colors.textMuted))),
              )
            else
              ...visible.map(_statRow),
          ],
        ),
      ),
    );
  }
}
