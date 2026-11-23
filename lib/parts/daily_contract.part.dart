// V12.32.0 — Contrat du matin : UNE priorité incontournable par jour, avec son créneau et une
// version minimale (10 minutes ou une coche) si l'énergie manque. L'état du contrat n'est jamais
// stocké : il se déduit du journal (tenu si l'activité a été réalisée ce jour-là), donc il reste
// exact même si l'on valide, annule ou corrige un moment ailleurs dans l'app.

part of '../main.dart';

class DailyContract {
  final String dateKey; // yyyy-mm-dd
  final String activityId;
  final String title;
  final String period; // Matin / Après-midi / Soir
  final bool minimal; // version minimale choisie
  final DateTime createdAt;

  const DailyContract({
    required this.dateKey,
    required this.activityId,
    required this.title,
    required this.period,
    required this.minimal,
    required this.createdAt,
  });

  DailyContract copyWith({bool? minimal, String? period}) => DailyContract(
        dateKey: dateKey,
        activityId: activityId,
        title: title,
        period: period ?? this.period,
        minimal: minimal ?? this.minimal,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'dateKey': dateKey,
        'activityId': activityId,
        'title': title,
        'period': period,
        'minimal': minimal,
        'createdAt': createdAt.toIso8601String(),
      };

  static DailyContract? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final dateKey = raw['dateKey'];
    final activityId = raw['activityId'];
    final title = raw['title'];
    if (dateKey is! String || activityId is! String || title is! String || dateKey.isEmpty || activityId.isEmpty) return null;
    final period = raw['period'];
    return DailyContract(
      dateKey: dateKey,
      activityId: activityId,
      title: title,
      period: (period is String && ['Matin', 'Après-midi', 'Soir'].contains(period)) ? period : 'Après-midi',
      minimal: raw['minimal'] == true,
      createdAt: DateTime.tryParse('${raw['createdAt']}') ?? DateTime.now(),
    );
  }
}

enum _ContractStatus { open, kept, missed }

class _ContractCandidate {
  final Activity activity;
  final String reason;
  const _ContractCandidate(this.activity, this.reason);
}

extension _DailyContractPart on _MaBelleSemaineAppState {
  String _contractKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DailyContract? _contractFor(DateTime day) {
    final key = _contractKey(day);
    for (var i = _dailyContracts.length - 1; i >= 0; i--) {
      if (_dailyContracts[i].dateKey == key) return _dailyContracts[i];
    }
    return null;
  }

  bool _activityDoneOn(String activityId, String fallbackName, String dateKey) {
    final activity = findActivity(activityId);
    final name = (activity?.name ?? fallbackName).trim().toLowerCase();
    return logs.any((l) {
      if (_contractKey(l.date) != dateKey) return false;
      final same = l.activityId == activityId || (l.activityId == null && l.title.trim().toLowerCase() == name);
      return same && _logIsRealised(l);
    });
  }

  _ContractStatus _contractStatus(DailyContract c) {
    if (_activityDoneOn(c.activityId, c.title, c.dateKey)) return _ContractStatus.kept;
    return c.dateKey.compareTo(_contractKey(_clockNow)) >= 0 ? _ContractStatus.open : _ContractStatus.missed;
  }

  /// Contrats tenus / jugés sur [from, toExclusive). Le contrat du jour encore ouvert n'est pas jugé.
  ({int kept, int total}) _contractStats(DateTime from, DateTime toExclusive) {
    final fromKey = _contractKey(from);
    final toKey = _contractKey(toExclusive);
    var kept = 0;
    var total = 0;
    for (final c in _dailyContracts) {
      if (c.dateKey.compareTo(fromKey) < 0 || c.dateKey.compareTo(toKey) >= 0) continue;
      final status = _contractStatus(c);
      if (status == _ContractStatus.open) continue;
      total++;
      if (status == _ContractStatus.kept) kept++;
    }
    return (kept: kept, total: total);
  }

  String _contractDefaultPeriod() {
    for (final p in const ['Matin', 'Après-midi', 'Soir']) {
      if (!_homePeriodIsPast(p)) return p;
    }
    return 'Soir';
  }

  /// Priorités possibles, de la plus utile à la moins utile : priorité de la semaine, activités repoussées,
  /// en retard sur leur objectif, priorités du jour, puis moments prévus aujourd'hui.
  List<_ContractCandidate> _contractCandidates() {
    final result = <_ContractCandidate>[];
    final seen = <String>{};
    final todayKey = _contractKey(_clockNow);
    void add(Activity? a, String reason) {
      if (a == null || a.isFrozen || a.isDateRange || _isNutritionActivity(a)) return;
      if (_activityDoneOn(a.id, a.name, todayKey)) return;
      if (!seen.add(a.id)) return;
      result.add(_ContractCandidate(a, reason));
    }

    final focus = _weeklyFocusEntry();
    if (focus != null && focus.entry.focusActivityId != null) {
      add(findActivity(focus.entry.focusActivityId!), 'Priorité de la semaine');
    }
    for (final p in _procrastinationItems()) {
      add(p.activity, 'Repoussée ${p.count} fois');
    }
    for (final r in _coachRemobilizationItems()) {
      if (r.level != _CoachRemobilizationLevel.returnToTrack && r.level != _CoachRemobilizationLevel.overLimit) {
        add(r.activity, 'En retard sur son objectif');
      }
    }
    for (final id in _dailyPriorityActivityIds) {
      add(findActivity(id), 'Une de tes priorités');
    }
    for (final p in actionableItemsForDay(today)) {
      if (!p.done && !p.optional && p.activityId != null) add(findActivity(p.activityId!), 'Prévue aujourd’hui');
    }
    return result.take(5).toList();
  }

  PlanItem? _contractPlanItem(DailyContract c) {
    for (final p in plan) {
      if (p.activityId == c.activityId && p.day == today && !_isDateRangePlanItem(p) && !p.done) return p;
    }
    return null;
  }

  Future<void> _openContractSheet() async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    final candidates = _contractCandidates();
    final existing = _contractFor(_clockNow);
    if (candidates.isEmpty) {
      _showFeedback('Rien à choisir pour l’instant : planifie une activité, ou tout est déjà fait aujourd’hui.');
      return;
    }
    var selectedId = (existing != null && candidates.any((c) => c.activity.id == existing.activityId))
        ? existing.activityId
        : candidates.first.activity.id;
    var period = existing?.period ?? _contractDefaultPeriod();
    var minimal = existing?.minimal ?? false;

    final result = await showModalBottomSheet<String>(
      context: navigationContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final selected = candidates.firstWhere((c) => c.activity.id == selectedId, orElse: () => candidates.first);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mon contrat du jour', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                const SizedBox(height: 4),
                Text(
                  'Une seule priorité incontournable, avec son créneau. Le reste de la journée est un bonus.',
                  style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textMuted),
                ),
                const SizedBox(height: 10),
                for (final c in candidates)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      c.activity.id == selectedId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: c.activity.id == selectedId ? _colors.accentIcon : _colors.textMuted,
                    ),
                    title: Text(c.activity.name, style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textStrong)),
                    subtitle: Text(c.reason, style: TextStyle(color: _colors.textMuted)),
                    onTap: () => setSheetState(() => selectedId = c.activity.id),
                  ),
                const SizedBox(height: 8),
                Text('Quand ?', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final p in const ['Matin', 'Après-midi', 'Soir'])
                    ChoiceChip(
                      label: Text(p),
                      selected: period == p,
                      onSelected: _homePeriodIsPast(p) && p != 'Soir' ? null : (_) => setSheetState(() => period = p),
                    ),
                ]),
                const SizedBox(height: 4),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: minimal,
                  onChanged: (value) => setSheetState(() => minimal = value),
                  title: Text(
                    selected.activity.countOnly ? 'Une simple coche suffit' : 'Version minimale de 10 minutes',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong),
                  ),
                  subtitle: Text(
                    'À choisir si l’énergie manque : l’important est de tenir le contrat.',
                    style: TextStyle(color: _colors.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'save'),
                    icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                    label: const Text('Prendre ce contrat'),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, 'skip'),
                    child: const Text('Pas aujourd’hui'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (result == 'skip') {
      setState(() => _contractSkippedDateKey = _contractKey(_clockNow));
      _queueLocalStatePersist();
      return;
    }
    if (result != 'save') return;
    final activity = findActivity(selectedId);
    if (activity == null) return;
    _saveContract(activity, period, minimal);
  }

  /// Enregistre le contrat et place (ou ajuste) le moment correspondant dans le planning du jour.
  void _saveContract(Activity activity, String period, bool minimal) {
    final key = _contractKey(_clockNow);
    final existing = plan.where((p) => p.activityId == activity.id && p.day == today && !_isDateRangePlanItem(p) && !p.done).toList();
    final shortMinutes = activity.countOnly ? 1 : 10;
    _prepareUndoSnapshot();
    setState(() {
      if (existing.isNotEmpty) {
        final item = existing.first;
        item.period = period;
        item.manualPlacement = true;
        if (minimal && !activity.countOnly) item.duration = min(item.duration, shortMinutes);
      } else {
        plan.add(PlanItem(
          id: 'contract_${activity.id}_${key}_${DateTime.now().microsecondsSinceEpoch}',
          day: today,
          period: period,
          title: activity.name,
          duration: activity.countOnly ? 1 : (minimal ? shortMinutes : max(5, activity.duration)),
          activityId: activity.id,
          details: 'Contrat du jour : ma priorité incontournable.',
          optional: false,
          userAdded: true,
          fixedInWeeklyTemplate: false,
          manualPlacement: true,
        ));
      }
      _sortPlan();
      _dailyContracts.removeWhere((c) => c.dateKey == key);
      _dailyContracts.add(DailyContract(
        dateKey: key,
        activityId: activity.id,
        title: activity.name,
        period: period,
        minimal: minimal,
        createdAt: _clockNow,
      ));
      if (_dailyContracts.length > 90) _dailyContracts.removeRange(0, _dailyContracts.length - 90);
      _contractSkippedDateKey = '';
    });
    _queueLocalStatePersist();
    _showFeedback('🤝 Contrat pris : « ${activity.name} » · ${period.toLowerCase()}${minimal ? ' · version minimale' : ''}.');
  }

  /// Bascule le contrat du jour en version minimale (10 minutes, ou une coche).
  void _contractMinimal(DailyContract c) {
    final activity = findActivity(c.activityId);
    final item = _contractPlanItem(c);
    final shortMinutes = (activity?.countOnly ?? false) ? 1 : 10;
    _prepareUndoSnapshot();
    setState(() {
      if (item != null) item.duration = min(item.duration, shortMinutes);
      final index = _dailyContracts.indexWhere((x) => x.dateKey == c.dateKey);
      if (index >= 0) _dailyContracts[index] = c.copyWith(minimal: true);
    });
    _queueLocalStatePersist();
    _showFeedback('🌱 Version minimale : ${shortMinutes == 1 ? 'une coche' : '10 minutes'} suffisent. Lance-toi maintenant.');
  }

  void _contractDone(DailyContract c) {
    final item = _contractPlanItem(c);
    if (item == null) {
      _openContractSheet();
      return;
    }
    togglePlanItemDone(item, true);
  }

  // ----- affichage dans le cockpit -------------------------------------------------------------

  Widget _contractSection() {
    final now = _clockNow;
    final contract = _contractFor(now);
    final skipped = _contractSkippedDateKey == _contractKey(now);
    final focus = _weeklyFocusEntry();
    final children = <Widget>[];

    if (contract == null && !skipped) {
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _colors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: _colors.borderTint),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.assignment_turned_in_outlined, size: 18, color: _colors.accentIcon),
            const SizedBox(width: 8),
            Expanded(child: Text('Mon contrat du jour', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong))),
          ]),
          const SizedBox(height: 3),
          Text('Choisis ta priorité incontournable et son créneau. Une seule, et tu sais où tu vas.', style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _openContractSheet,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: const Text('Prendre mon contrat'),
          ),
        ]),
      ));
    } else if (contract == null) {
      children.add(Row(children: [
        Icon(Icons.assignment_turned_in_outlined, size: 16, color: _colors.textMuted),
        const SizedBox(width: 7),
        Expanded(child: Text('Contrat du jour : non pris', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted))),
        TextButton(onPressed: _openContractSheet, child: const Text('Le prendre')),
      ]));
    } else {
      final kept = _contractStatus(contract) == _ContractStatus.kept;
      children.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(kept ? Icons.verified_rounded : Icons.assignment_turned_in_outlined, size: 16, color: kept ? _colors.accentIcon : _colors.goldText),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            kept
                ? 'Contrat tenu : « ${contract.title} ». Le reste de la journée est un bonus.'
                : 'Contrat du jour : « ${contract.title} » · ${contract.period.toLowerCase()}${contract.minimal ? ' · version minimale' : ''}',
            style: TextStyle(fontSize: AppType.body, height: 1.3, fontWeight: FontWeight.w700, color: _colors.textStrong),
          ),
        ),
      ]));
    }

    if (focus != null) {
      final doneThisWeek = _focusDoneCount(focus.entry);
      children.add(const SizedBox(height: 6));
      children.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.flag_outlined, size: 16, color: _colors.accentIcon)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            focus.next
                ? 'Priorité de la semaine prochaine : « ${focus.entry.focusTitle} »'
                : 'Priorité de la semaine : « ${focus.entry.focusTitle} » · $doneThisWeek ${_nutPlural(doneThisWeek, 'réalisation', 'réalisations')} cette semaine',
            style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textStrong),
          ),
        ),
      ]));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }
}
