// V12.20.0 — Consignes du Coach (Sport) : étape 1.
// Types : imposer (au moins N fois / semaine), plafonner (au plus N fois / semaine),
// jours imposés, jours interdits. Portée : chaque semaine, cette semaine, jusqu'à une date.
// Force : obligatoire (le moteur la respecte ou l'explique) ou préférence (bonus de score).

part of '../main.dart';

class CoachRule {
  final String id;
  String type; // 'require' | 'cap' | 'on_days' | 'never_days'
  String targetKind; // 'activity' | 'family'
  String targetId; // identifiant d'activité ou nom de famille
  int count;
  Set<int> days;
  String scope; // 'always' | 'week' | 'until'
  String weekKey;
  DateTime? until;
  bool must;
  bool enabled;

  CoachRule({
    required this.id,
    required this.type,
    required this.targetKind,
    required this.targetId,
    this.count = 1,
    Set<int>? days,
    this.scope = 'always',
    this.weekKey = '',
    this.until,
    this.must = true,
    this.enabled = true,
  }) : days = days ?? <int>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'targetKind': targetKind,
        'targetId': targetId,
        'count': count,
        'days': (days.toList()..sort()),
        'scope': scope,
        'weekKey': weekKey,
        'until': until?.toIso8601String(),
        'must': must,
        'enabled': enabled,
      };

  static CoachRule? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final type = '${raw['type']}';
    if (!const {'require', 'cap', 'on_days', 'never_days'}.contains(type)) return null;
    final id = '${raw['id'] ?? ''}';
    final targetId = '${raw['targetId'] ?? ''}';
    if (id.isEmpty || targetId.isEmpty) return null;
    return CoachRule(
      id: id,
      type: type,
      targetKind: '${raw['targetKind']}' == 'family' ? 'family' : 'activity',
      targetId: targetId,
      count: raw['count'] is num ? max(1, min(7, (raw['count'] as num).toInt())) : 1,
      days: raw['days'] is List
          ? {for (final d in raw['days'] as List) if (d is num && d >= 0 && d < 7) d.toInt()}
          : <int>{},
      scope: const {'always', 'week', 'until'}.contains('${raw['scope']}') ? '${raw['scope']}' : 'always',
      weekKey: '${raw['weekKey'] ?? ''}',
      until: raw['until'] == null ? null : DateTime.tryParse('${raw['until']}'),
      must: raw['must'] != false,
      enabled: raw['enabled'] != false,
    );
  }
}

/// Consignes enregistrées (sauvegardées avec les activités).
final List<CoachRule> _coachRules = <CoachRule>[];

/// Bilan de la dernière génération Sport : consignes appliquées ou non tenues.
final List<String> _coachRuleReport = <String>[];

// ---------------------------------------------------------------------------
// Phrases et correspondances (sans état)
// ---------------------------------------------------------------------------

String _joinDays(Iterable<int> days) {
  final names = (days.toList()..sort()).map((d) => _frWeekdaysLong[d]).toList();
  if (names.isEmpty) return '—';
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} et ${names.last}';
}

String _ruleTargetName(CoachRule r) {
  if (r.targetKind == 'family') return r.targetId;
  return _registeredActivity(id: r.targetId)?.name ?? 'activité supprimée';
}

String _ruleSentence(CoachRule r) {
  final t = _ruleTargetName(r);
  switch (r.type) {
    case 'require':
      return '$t au moins ${r.count} fois par semaine';
    case 'cap':
      return '$t au plus ${r.count} fois par semaine';
    case 'on_days':
      return '$t le ${_joinDays(r.days)}';
    default:
      return '$t jamais le ${_joinDays(r.days)}';
  }
}

String _ruleScopeLabel(CoachRule r) {
  switch (r.scope) {
    case 'week':
      return 'cette semaine';
    case 'until':
      final u = r.until;
      return u == null ? 'jusqu’à une date' : 'jusqu’au ${u.day.toString().padLeft(2, '0')}/${u.month.toString().padLeft(2, '0')}';
    default:
      return 'chaque semaine';
  }
}

bool _ruleMatches(CoachRule r, Activity a) =>
    r.targetKind == 'activity' ? a.id == r.targetId : _sportFamilyOf(a) == r.targetId;

bool _ruleTargetsOverlap(CoachRule a, CoachRule b) {
  if (a.targetKind == b.targetKind) return a.targetId == b.targetId;
  final act = a.targetKind == 'activity' ? a : b;
  final fam = a.targetKind == 'family' ? a : b;
  final activity = _registeredActivity(id: act.targetId);
  return activity != null && _sportFamilyOf(activity) == fam.targetId;
}

/// Contradictions entre consignes obligatoires (affichées dans l'écran des consignes).
List<String> _coachRuleConflicts(List<CoachRule> rules) {
  final out = <String>[];
  final live = rules.where((r) => r.enabled && r.must).toList();
  for (var i = 0; i < live.length; i++) {
    for (var j = i + 1; j < live.length; j++) {
      final a = live[i];
      final b = live[j];
      if (!_ruleTargetsOverlap(a, b)) continue;
      final pair = {a.type, b.type};
      if (pair.containsAll({'on_days', 'never_days'})) {
        final on = a.type == 'on_days' ? a : b;
        final never = a.type == 'never_days' ? a : b;
        final common = on.days.intersection(never.days);
        if (common.isNotEmpty) out.add('« ${_ruleSentence(on)} » et « ${_ruleSentence(never)} » se contredisent (${_joinDays(common)}).');
      }
      if (pair.containsAll({'require', 'cap'})) {
        final req = a.type == 'require' ? a : b;
        final cap = a.type == 'cap' ? a : b;
        if (req.count > cap.count) out.add('« ${_ruleSentence(req)} » dépasse « ${_ruleSentence(cap)} ».');
      }
      if (pair.containsAll({'on_days', 'cap'})) {
        final on = a.type == 'on_days' ? a : b;
        final cap = a.type == 'cap' ? a : b;
        if (on.days.length > cap.count) out.add('« ${_ruleSentence(on)} » dépasse « ${_ruleSentence(cap)} ».');
      }
    }
  }
  for (final r in live.where((r) => r.type == 'require')) {
    final never = <int>{};
    for (final o in live.where((o) => o.type == 'never_days' && _ruleTargetsOverlap(r, o))) {
      never.addAll(o.days);
    }
    if (r.count > 7 - never.length) out.add('« ${_ruleSentence(r)} » est impossible : seulement ${7 - never.length} jours autorisés.');
  }
  return out;
}

// ---------------------------------------------------------------------------
// Moteur : intégration dans la génération Sport
// ---------------------------------------------------------------------------

extension _CoachRulesEngine on _MaBelleSemaineAppState {
  /// Consignes en vigueur (activées, dans leur portée, cible existante).
  List<CoachRule> _activeCoachRules() {
    if (_coachRules.isEmpty) return const <CoachRule>[];
    final weekKey = _currentWeekKey();
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    return _coachRules.where((r) {
      if (!r.enabled) return false;
      if (r.scope == 'week' && r.weekKey != weekKey) return false;
      if (r.scope == 'until' && (r.until == null || DateTime(r.until!.year, r.until!.month, r.until!.day).isBefore(today0))) return false;
      if (r.targetKind == 'activity' && findActivity(r.targetId) == null) return false;
      return true;
    }).toList();
  }

  /// Nombre de jours déjà couverts par la consigne : séances conservées + séances générées.
  int _ruleCountSoFar(CoachRule r, {int? excludeDay, Map<String, int>? generatedCount, List<PlanItem>? generated}) {
    final days = <int>{};
    final start = _coachRuleGenStart;
    for (final p in plan) {
      if (p.activityId == null || !_isSportPlanItem(p)) continue;
      if (excludeDay != null && p.day == excludeDay) continue;
      final kept = start == null || p.day < start || p.manualPlacement || p.fixedInWeeklyTemplate || p.done;
      if (!kept) continue;
      final a = findActivity(p.activityId!);
      if (a != null && _ruleMatches(r, a)) days.add(p.day);
    }
    var generatedDays = 0;
    if (generated != null) {
      final gDays = <int>{};
      for (final p in generated) {
        if (p.activityId == null || p.day == excludeDay) continue;
        final a = findActivity(p.activityId!);
        if (a != null && _isSportActivity(a) && _ruleMatches(r, a)) gDays.add(p.day);
      }
      days.addAll(gDays);
    } else if (generatedCount != null) {
      for (final e in generatedCount.entries) {
        final a = findActivity(e.key);
        if (a != null && _ruleMatches(r, a)) generatedDays += e.value;
      }
    }
    return days.length + generatedDays;
  }

  /// Consigne obligatoire qui interdit cette activité ce jour-là (jour interdit ou plafond atteint).
  bool _coachRuleBlocks(Activity a, int day, Map<String, int> generatedCount) {
    for (final r in _activeCoachRules()) {
      if (!r.must || !_ruleMatches(r, a)) continue;
      if (r.type == 'never_days' && r.days.contains(day)) return true;
      if (r.type == 'cap' && _ruleCountSoFar(r, excludeDay: day, generatedCount: generatedCount) >= r.count) return true;
    }
    return false;
  }

  /// Bonus / malus des consignes « préférence » dans le score de rotation.
  double _coachRulePreferenceScore(Activity a, int day) {
    var s = 0.0;
    for (final r in _activeCoachRules()) {
      if (r.must || !_ruleMatches(r, a)) continue;
      switch (r.type) {
        case 'on_days':
          s += r.days.contains(day) ? 40 : -8;
          break;
        case 'never_days':
          if (r.days.contains(day)) s -= 60;
          break;
        case 'require':
          s += 6;
          break;
        case 'cap':
          s -= 4;
          break;
      }
    }
    return s;
  }

  PlanItem _ruleGeneratedItem(Activity a, int day, int seq, String reason) => PlanItem(
        id: 'sport_${DateTime.now().microsecondsSinceEpoch}_r$seq',
        day: day,
        period: _periodForActivity(a, day),
        timeLabel: null,
        activityId: a.id,
        title: a.name,
        details: 'Consigne du Coach : $reason',
        duration: _sportGenerationDuration(a),
        optional: false,
        userAdded: false,
        fixedInWeeklyTemplate: false,
      );

  /// Consignes « ces jours-là » obligatoires : activités placées en premier sur la journée.
  List<Activity> _placeForcedRuleActivities(
    List<CoachRule> rules,
    int day,
    int budget,
    List<Activity> dayCandidates,
    List<Activity> all,
    Set<String> manualIds,
    List<PlanItem> generated,
    int seq,
    Map<String, int> generatedCount,
    Map<String, int> remaining,
  ) {
    final forced = <Activity>[];
    var used = 0;
    for (final r in rules.where((r) => r.must && r.type == 'on_days' && r.days.contains(day))) {
      if (all.any((a) => _ruleMatches(r, a) && manualIds.contains(a.id))) continue; // déjà prévue à la main
      final matching = all.where((a) => _ruleMatches(r, a)).toList();
      if (matching.isEmpty) {
        _coachRuleReport.add('⚠ « ${_ruleSentence(r)} » : aucune activité Sport active ne correspond.');
        continue;
      }
      final pool = dayCandidates
          .where((a) => _ruleMatches(r, a) && !forced.any((f) => f.id == a.id) && !_sportFamilyClash(a, forced) && !_coachRuleBlocks(a, day, generatedCount))
          .toList();
      if (pool.isEmpty) {
        _coachRuleReport.add('⚠ « ${_ruleSentence(r)} » impossible ${_frWeekdaysLong[day]} : autre consigne (jour interdit ou plafond) ou famille déjà présente.');
        continue;
      }
      pool.sort((x, y) => _sportRotationScore(y, day, <String>{}, generatedCount).compareTo(_sportRotationScore(x, day, <String>{}, generatedCount)));
      final a = pool.first;
      generated.add(_ruleGeneratedItem(a, day, seq + forced.length, _ruleSentence(r)));
      used += _sportGenerationDuration(a);
      forced.add(a);
      generatedCount[a.id] = (generatedCount[a.id] ?? 0) + 1;
      final key = _sportRotationKey(a);
      remaining[key] = max(0, (remaining[key] ?? 0) - 1);
      _coachRuleReport.add('✔ ${a.name} placée ${_frWeekdaysLong[day]} : consigne « ${_ruleSentence(r)} ».');
      if (used > budget) {
        _coachRuleReport.add('⚠ ${_frWeekdaysLong[day]} dépasse le budget Sport du jour (${used} min pour ${budget} min) à cause de la consigne.');
      }
    }
    return forced;
  }

  int _sportLoadOnDay(int day, List<PlanItem> generated) {
    final start = _coachRuleGenStart;
    var total = 0;
    for (final p in plan) {
      if (p.day != day || p.activityId == null || !_isSportPlanItem(p)) continue;
      final kept = start == null || p.day < start || p.manualPlacement || p.fixedInWeeklyTemplate || p.done;
      if (kept) total += p.duration;
    }
    for (final p in generated) {
      if (p.day == day && p.activityId != null) total += p.duration;
    }
    return total;
  }

  /// Consignes « au moins N fois » : complète la semaine sur les meilleurs jours restants.
  int _topUpRequireRules(
    List<CoachRule> rules,
    List<PlanItem> generated,
    int seq,
    List<int> days,
    List<Activity> sportActivities,
    Map<String, int> generatedCount,
  ) {
    final requires = rules.where((r) => r.type == 'require').toList()..sort((a, b) => (b.must ? 1 : 0).compareTo(a.must ? 1 : 0));
    for (final r in requires) {
      var have = _ruleCountSoFar(r, generated: generated);
      final need = r.count - have;
      if (need <= 0) {
        _coachRuleReport.add('✔ « ${_ruleSentence(r)} » : déjà atteint ($have).');
        continue;
      }
      var added = 0;
      final order = [...days]..sort((x, y) => _sportLoadOnDay(x, generated).compareTo(_sportLoadOnDay(y, generated)));
      for (final day in order) {
        if (added >= need) break;
        if (_sportBudgetForDay(day) <= 0) continue;
        final already = <Activity>[];
        for (final p in [...plan.where((p) => p.day == day), ...generated.where((p) => p.day == day)]) {
          if (p.activityId == null) continue;
          final a = findActivity(p.activityId!);
          if (a != null && _isSportActivity(a)) already.add(a);
        }
        if (already.any((a) => _ruleMatches(r, a))) continue;
        final pool = sportActivities
            .where((a) => _ruleMatches(r, a) && !_manualDayBlocked(a, day) && !_sportFamilyClash(a, already) && !_coachRuleBlocks(a, day, generatedCount))
            .toList();
        if (pool.isEmpty) continue;
        pool.sort((x, y) => _sportRotationScore(y, day, <String>{}, generatedCount).compareTo(_sportRotationScore(x, day, <String>{}, generatedCount)));
        final a = pool.first;
        final slack = _sportBudgetForDay(day) - _sportLoadOnDay(day, generated);
        if (slack < _sportGenerationDuration(a) && !r.must) continue; // préférence : jamais au-delà du budget
        generated.add(_ruleGeneratedItem(a, day, seq, _ruleSentence(r)));
        seq++;
        generatedCount[a.id] = (generatedCount[a.id] ?? 0) + 1;
        added++;
        _coachRuleReport.add('✔ ${a.name} ajoutée ${_frWeekdaysLong[day]} : consigne « ${_ruleSentence(r)} »${slack < _sportGenerationDuration(a) ? ' (dépasse le budget du jour)' : ''}.');
      }
      have += added;
      if (have < r.count) {
        _coachRuleReport.add('⚠ « ${_ruleSentence(r)} » non tenue : $have sur ${r.count} (jours disponibles insuffisants, famille déjà présente ou plafond).');
      }
    }
    return seq;
  }

  Future<void> openCoachRules() async {
    if (!mounted) return;
    await Navigator.of(_navigatorKey.currentContext!).push(
      MaterialPageRoute<void>(
        builder: (_) => _CoachRulesPage(
          weekKey: _currentWeekKey(),
          onChanged: () {
            if (mounted) setState(() {});
            _queueLocalStatePersist();
          },
          onApply: () => generateWeek(markAsRegenerated: true),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran des consignes
// ---------------------------------------------------------------------------

class _CoachRulesPage extends StatefulWidget {
  final String weekKey;
  final VoidCallback onChanged;
  final VoidCallback onApply;

  const _CoachRulesPage({required this.weekKey, required this.onChanged, required this.onApply});

  @override
  State<_CoachRulesPage> createState() => _CoachRulesPageState();
}

class _CoachRulesPageState extends State<_CoachRulesPage> {
  Future<void> _edit({CoachRule? existing, CoachRule? preset}) async {
    final result = await showModalBottomSheet<CoachRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CoachRuleEditor(existing: existing, preset: preset, weekKey: widget.weekKey),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _coachRules.indexWhere((r) => r.id == result.id);
      if (index >= 0) {
        _coachRules[index] = result;
      } else {
        _coachRules.add(result);
      }
    });
    widget.onChanged();
  }

  bool _expired(CoachRule r) {
    if (r.scope == 'week') return r.weekKey != widget.weekKey;
    if (r.scope == 'until') {
      final u = r.until;
      final now = DateTime.now();
      return u == null || DateTime(u.year, u.month, u.day).isBefore(DateTime(now.year, now.month, now.day));
    }
    return false;
  }

  CoachRule _preset(String type, String kind, String target, {int count = 3, Set<int>? days, bool must = true}) =>
      CoachRule(id: 'rule_${DateTime.now().microsecondsSinceEpoch}', type: type, targetKind: kind, targetId: target, count: count, days: days, must: must, weekKey: widget.weekKey);

  @override
  Widget build(BuildContext context) {
    final conflicts = _coachRuleConflicts(_coachRules);
    final sportFamilies = kSportFamilies;
    return Scaffold(
      appBar: AppBar(title: const Text('Consignes du Coach'), leading: const BackButton()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle consigne'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, 96),
          children: [
            _AppCard(
              tone: _CardTone.tint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionHeader(iconKey: 'coach', fallbackIcon: Icons.rule_rounded, title: 'Tes consignes pour le Sport'),
                const SizedBox(height: AppSpace.s),
                Text(
                  'Le Coach les applique quand il organise la semaine. « Obligatoire » : respectée ou expliquée si impossible. « Préférence » : favorisée sans jamais surcharger.',
                  style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textMuted),
                ),
                const SizedBox(height: AppSpace.m),
                FilledButton.tonalIcon(
                  onPressed: () {
                    widget.onApply();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Appliquer au planning'),
                ),
              ]),
            ),
            if (conflicts.isNotEmpty) ...[
              const SizedBox(height: AppSpace.m),
              _AppCard(
                tone: _CardTone.soft,
                borderColor: _colors.warnBorder,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: _colors.warnText),
                    const SizedBox(width: 8),
                    Text('Contradictions', style: _sectionTitleStyle(context)),
                  ]),
                  const SizedBox(height: 6),
                  for (final c in conflicts) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $c', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted))),
                ]),
              ),
            ],
            const SizedBox(height: AppSpace.m),
            if (_coachRules.isEmpty)
              _AppCard(
                tone: _CardTone.soft,
                child: Text('Aucune consigne pour l’instant. Touche « Nouvelle consigne » ou une idée ci-dessous.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
              ),
            for (final r in _coachRules)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s),
                child: _AppCard(
                  onTap: () => _edit(existing: r),
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_ruleSentence(r), style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: r.enabled ? _colors.textStrong : _colors.textFaint)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _Pill(_ruleScopeLabel(r)),
                          _Pill(r.must ? 'obligatoire' : 'préférence', background: r.must ? _colors.peachBg : _colors.surfaceSunken, foreground: r.must ? _colors.goldText : _colors.textMuted),
                          if (_expired(r)) _Pill('terminée', background: _colors.surfaceSunken, foreground: _colors.textMuted),
                        ]),
                      ]),
                    ),
                    Switch(
                      value: r.enabled,
                      onChanged: (value) {
                        setState(() => r.enabled = value);
                        widget.onChanged();
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _edit(existing: r);
                        if (value == 'delete') {
                          setState(() => _coachRules.removeWhere((x) => x.id == r.id));
                          widget.onChanged();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem<String>(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ]),
                ),
              ),
            if (_coachRuleReport.isNotEmpty) ...[
              const SizedBox(height: AppSpace.m),
              _AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionHeader(iconKey: 'history', fallbackIcon: Icons.history_rounded, title: 'Dernière génération', subtitle: 'Ce que le Coach a fait de tes consignes.'),
                  const SizedBox(height: AppSpace.s),
                  for (final line in _coachRuleReport.take(20)) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textMuted))),
                ]),
              ),
            ],
            const SizedBox(height: AppSpace.l),
            Text('Idées', style: _sectionTitleStyle(context)),
            const SizedBox(height: AppSpace.s),
            Wrap(spacing: 6, runSpacing: 0, children: [
              ActionChip(label: const Text('3 séances de renforcement par semaine'), onPressed: () => _edit(preset: _preset('require', 'family', 'Renforcement', count: 3))),
              ActionChip(label: const Text('Pas de renforcement le lundi'), onPressed: () => _edit(preset: _preset('never_days', 'family', 'Renforcement', days: {0}))),
              ActionChip(label: const Text('Au plus 2 séances de cardio'), onPressed: () => _edit(preset: _preset('cap', 'family', 'Cardio', count: 2))),
              ActionChip(label: const Text('Mouvement doux mardi et jeudi'), onPressed: () => _edit(preset: _preset('on_days', 'family', 'Mouvement doux', days: {1, 3}))),
            ]),
            if (sportFamilies.isEmpty) const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assistant de création / modification
// ---------------------------------------------------------------------------

class _CoachRuleEditor extends StatefulWidget {
  final CoachRule? existing;
  final CoachRule? preset;
  final String weekKey;

  const _CoachRuleEditor({this.existing, this.preset, required this.weekKey});

  @override
  State<_CoachRuleEditor> createState() => _CoachRuleEditorState();
}

class _CoachRuleEditorState extends State<_CoachRuleEditor> {
  late String type;
  late String targetKind;
  String? targetId;
  late int count;
  late Set<int> days;
  late String scope;
  DateTime? until;
  late bool must;

  @override
  void initState() {
    super.initState();
    final base = widget.existing ?? widget.preset;
    type = base?.type ?? 'require';
    targetKind = base?.targetKind ?? 'family';
    targetId = base?.targetId;
    count = base?.count ?? 2;
    days = {...?base?.days};
    scope = base?.scope ?? 'always';
    until = base?.until;
    must = base?.must ?? true;
  }

  List<Activity> get _sportActivities =>
      _activityRegistry
          .where((a) => a.category.toLowerCase() == 'sport' && !a.isSportProgram)
          .toList()
        ..sort((x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));

  CoachRule? _build() {
    final target = targetId;
    if (target == null || target.isEmpty) return null;
    final dayRule = type == 'on_days' || type == 'never_days';
    if (dayRule && days.isEmpty) return null;
    if (scope == 'until' && until == null) return null;
    return CoachRule(
      id: widget.existing?.id ?? 'rule_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      targetKind: targetKind,
      targetId: target,
      count: count,
      days: dayRule ? days : <int>{},
      scope: scope,
      weekKey: scope == 'week' ? widget.weekKey : '',
      until: scope == 'until' ? until : null,
      must: must,
      enabled: widget.existing?.enabled ?? true,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.m, bottom: 6),
        child: Text(text, style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
      );

  @override
  Widget build(BuildContext context) {
    final built = _build();
    final dayRule = type == 'on_days' || type == 'never_days';
    final targets = targetKind == 'activity' ? _sportActivities.map((a) => (a.id, a.name)).toList() : kSportFamilies.map((f) => (f, f)).toList();
    if (targetId != null && !targets.any((t) => t.$1 == targetId)) {
      targets.insert(0, (targetId!, targetKind == 'activity' ? (_registeredActivity(id: targetId)?.name ?? 'activité supprimée') : targetId!));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, MediaQuery.of(context).viewInsets.bottom + AppSpace.l),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SheetHeader(
            leading: _uiIcon('coach', Icons.rule_rounded, size: 24, color: _colors.accentIcon),
            title: widget.existing == null ? 'Nouvelle consigne' : 'Modifier la consigne',
            subtitle: 'Je veux que le Coach…',
          ),
          _label('Type'),
          Wrap(spacing: 6, runSpacing: 0, children: [
            for (final t in const [('require', 'Au moins N fois'), ('cap', 'Au plus N fois'), ('on_days', 'Ces jours-là'), ('never_days', 'Jamais ces jours')])
              ChoiceChip(label: Text(t.$2), selected: type == t.$1, onSelected: (_) => setState(() => type = t.$1)),
          ]),
          _label('Pour'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(value: 'family', label: Text('Une famille')),
                ButtonSegment<String>(value: 'activity', label: Text('Une activité')),
              ],
              selected: <String>{targetKind},
              onSelectionChanged: (s) => setState(() {
                if (s.isEmpty) return;
                targetKind = s.first;
                targetId = null;
              }),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          DropdownButtonFormField<String>(
            key: ValueKey('target_$targetKind'),
            initialValue: targets.any((t) => t.$1 == targetId) ? targetId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: targetKind == 'family' ? 'Famille' : 'Activité Sport'),
            items: [for (final t in targets) DropdownMenuItem<String>(value: t.$1, child: Text(t.$2, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => targetId = v),
          ),
          if (type == 'require' || type == 'cap') ...[
            _label(type == 'require' ? 'Au moins combien de jours par semaine ?' : 'Au plus combien de jours par semaine ?'),
            Row(children: [
              IconButton.filledTonal(onPressed: count > 1 ? () => setState(() => count--) : null, icon: const Icon(Icons.remove_rounded)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$count', style: TextStyle(fontSize: AppType.h1, fontWeight: FontWeight.w800, color: _colors.textStrong))),
              IconButton.filledTonal(onPressed: count < 7 ? () => setState(() => count++) : null, icon: const Icon(Icons.add_rounded)),
            ]),
          ],
          if (dayRule) ...[
            _label(type == 'on_days' ? 'Quels jours ?' : 'Quels jours à éviter ?'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(_frWeekdaysLong[d].substring(0, 3)),
                  selected: days.contains(d),
                  onSelected: (on) => setState(() => on ? days.add(d) : days.remove(d)),
                ),
            ]),
          ],
          _label('Portée'),
          Wrap(spacing: 6, runSpacing: 0, children: [
            ChoiceChip(label: const Text('Chaque semaine'), selected: scope == 'always', onSelected: (_) => setState(() => scope = 'always')),
            ChoiceChip(label: const Text('Cette semaine'), selected: scope == 'week', onSelected: (_) => setState(() => scope = 'week')),
            ChoiceChip(
              label: Text(scope == 'until' && until != null ? 'Jusqu’au ${until!.day.toString().padLeft(2, '0')}/${until!.month.toString().padLeft(2, '0')}' : 'Jusqu’à une date'),
              selected: scope == 'until',
              onSelected: (_) async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: until ?? now.add(const Duration(days: 14)),
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 2),
                  helpText: 'Jusqu’à quel jour ?',
                );
                if (picked != null) setState(() {
                  scope = 'until';
                  until = picked;
                });
              },
            ),
          ]),
          _label('Force'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('Obligatoire')),
                ButtonSegment<bool>(value: false, label: Text('Préférence')),
              ],
              selected: <bool>{must},
              onSelectionChanged: (s) => setState(() {
                if (s.isNotEmpty) must = s.first;
              }),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          _AppCard(
            tone: _CardTone.soft,
            child: Text(
              built == null ? 'Complète la consigne pour voir sa formulation.' : '${_ruleSentence(built)} · ${_ruleScopeLabel(built)} · ${built.must ? 'obligatoire' : 'préférence'}',
              style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong, height: 1.3),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
            const SizedBox(width: AppSpace.s),
            Expanded(child: FilledButton(onPressed: built == null ? null : () => Navigator.pop(context, built), child: const Text('Enregistrer'))),
          ]),
        ]),
      ),
    );
  }
}
