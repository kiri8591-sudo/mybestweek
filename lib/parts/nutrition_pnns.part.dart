// V12.34.0 — Bilan alimentaire du jour et de la semaine, comparé aux repères de consommation du PNNS
// (profil Senior ou Adulte). Deux modes de suivi, adaptés à la grille Nutrition existante :
//  • repères « chaque jour » en quantité (fruits et légumes, produits laitiers, féculents complets,
//    fruits à coque, eau) : de petits compteurs +/− propres au bilan ;
//  • repères « chaque semaine » (légumes secs, poisson, viande, charcuterie) : lus dans tes habitudes
//    Nutrition existantes, associées à chaque repère, sans double saisie.
// Ce sont des repères de santé publique suivis par portions, pas un avis médical.

part of '../main.dart';

class _PnnsRef {
  final String id;
  final String label;
  final String cadence; // 'jour' | 'semaine'
  final bool isMax;
  final int adultTarget;
  final int seniorTarget;
  final String icon; // identifiant du pack d'icônes
  final String singular;
  final String plural;
  final String portion; // ce que vaut une portion
  final String hint; // idée concrète pour rattraper
  final String habitName; // nom proposé pour l'habitude (repères hebdomadaires)
  final String pattern; // reconnaissance d'une habitude existante (repères hebdomadaires)
  final bool defaultOn;

  const _PnnsRef({
    required this.id,
    required this.label,
    required this.cadence,
    required this.adultTarget,
    required this.seniorTarget,
    required this.icon,
    required this.singular,
    required this.plural,
    required this.portion,
    required this.hint,
    this.isMax = false,
    this.habitName = '',
    this.pattern = '',
    this.defaultOn = true,
  });

  int target(String profile) => profile == 'senior' ? seniorTarget : adultTarget;
  String noun(int n) => n > 1 ? plural : singular;
}

const List<_PnnsRef> _pnnsRefs = [
  _PnnsRef(
    id: 'fruitsLegumes',
    label: 'Fruits et légumes',
    cadence: 'jour',
    adultTarget: 5,
    seniorTarget: 5,
    icon: 'apple',
    singular: 'portion de fruits et légumes',
    plural: 'portions de fruits et légumes',
    portion: 'Une portion = 80 à 100 g : une tomate, une pomme, un bol de soupe, une poignée de haricots verts.',
    hint: 'Ajoute une soupe, des crudités ou un fruit.',
  ),
  _PnnsRef(
    id: 'laitiers',
    label: 'Produits laitiers',
    cadence: 'jour',
    adultTarget: 2,
    seniorTarget: 3,
    icon: 'cheese',
    singular: 'produit laitier',
    plural: 'produits laitiers',
    portion: 'Une portion = un yaourt, un fromage blanc, 30 g de fromage ou un verre de lait.',
    hint: 'Un yaourt nature, un fromage blanc ou un verre de lait.',
  ),
  _PnnsRef(
    id: 'feculentsComplets',
    label: 'Féculents complets',
    cadence: 'jour',
    adultTarget: 1,
    seniorTarget: 1,
    icon: 'balanced_meal',
    singular: 'portion de féculents complets',
    plural: 'portions de féculents complets',
    portion: 'Pain complet, riz complet, pâtes complètes ou flocons de céréales.',
    hint: 'Pain complet, riz complet ou flocons d’avoine.',
  ),
  _PnnsRef(
    id: 'fruitsCoque',
    label: 'Fruits à coque',
    cadence: 'jour',
    adultTarget: 1,
    seniorTarget: 1,
    icon: 'apple',
    singular: 'poignée de fruits à coque',
    plural: 'poignées de fruits à coque',
    portion: 'Une petite poignée de noix, amandes ou noisettes non salées.',
    hint: 'Une petite poignée de noix ou d’amandes non salées.',
    defaultOn: false,
  ),
  _PnnsRef(
    id: 'eau',
    label: 'Eau',
    cadence: 'jour',
    adultTarget: 6,
    seniorTarget: 6,
    icon: 'water_glass',
    singular: 'verre d’eau',
    plural: 'verres d’eau',
    portion: 'Un verre ≈ 25 cl : six verres font environ 1,5 L, en plus des autres boissons.',
    hint: 'Un grand verre d’eau, une tisane ou une infusion.',
  ),
  _PnnsRef(
    id: 'legumesSecs',
    label: 'Légumes secs',
    cadence: 'semaine',
    adultTarget: 2,
    seniorTarget: 2,
    icon: 'beans',
    singular: 'repas avec légumes secs',
    plural: 'repas avec légumes secs',
    portion: 'Lentilles, pois chiches, haricots secs, flageolets, pois cassés.',
    hint: 'Lentilles, pois chiches ou haricots blancs.',
    habitName: 'Légumineuses',
    pattern: r'l[ée]gumineuse|lentille|pois.?chiche|haricot|f[eè]ve|l[ée]gume.?sec|flageolet',
  ),
  _PnnsRef(
    id: 'poisson',
    label: 'Poisson',
    cadence: 'semaine',
    adultTarget: 2,
    seniorTarget: 2,
    icon: 'fish',
    singular: 'repas avec poisson',
    plural: 'repas avec poisson',
    portion: 'Deux fois par semaine, dont un poisson gras (saumon, sardine, maquereau, hareng).',
    hint: 'Un poisson gras : saumon, sardine, maquereau.',
    habitName: 'Poisson',
    pattern: r'poisson|saumon|thon|sardine|truite|maquereau|hareng',
  ),
  _PnnsRef(
    id: 'viande',
    label: 'Viande hors volaille',
    cadence: 'semaine',
    adultTarget: 5,
    seniorTarget: 5,
    icon: 'restaurant',
    singular: 'portion de viande',
    plural: 'portions de viande',
    portion: 'Porc, bœuf, veau, agneau, abats : environ 500 g par semaine au plus, soit 5 portions de 100 g.',
    hint: 'Remplace-la par de la volaille, du poisson, des œufs ou des légumineuses.',
    isMax: true,
    habitName: 'Viande rouge',
    pattern: r'viande|b[oœ]euf|porc|veau|agneau|steak|abats',
  ),
  _PnnsRef(
    id: 'charcuterie',
    label: 'Charcuterie',
    cadence: 'semaine',
    adultTarget: 3,
    seniorTarget: 3,
    icon: 'cake',
    singular: 'portion de charcuterie',
    plural: 'portions de charcuterie',
    portion: 'Environ 150 g par semaine au plus, soit 3 portions de 50 g.',
    hint: 'Garde-la pour les occasions.',
    isMax: true,
    habitName: 'Charcuterie',
    pattern: r'charcuterie|jambon|saucisson|saucisse|lardon|p[aâ]t[eé]',
  ),
];

enum _PnnsStatus { met, progress, missing, over, capOk, capReached, untracked }

class _PnnsRow {
  final _PnnsRef ref;
  final int value;
  final int target;
  final _PnnsStatus status;
  final String detail;
  final Activity? activity;
  const _PnnsRow({
    required this.ref,
    required this.value,
    required this.target,
    required this.status,
    required this.detail,
    this.activity,
  });

  bool get held => status == _PnnsStatus.met || status == _PnnsStatus.capOk || status == _PnnsStatus.capReached;
  bool get judged => status != _PnnsStatus.progress && status != _PnnsStatus.untracked;
}

class _PnnsFibre {
  final String name;
  final String grams;
  const _PnnsFibre(this.name, this.grams);
}

const List<_PnnsFibre> _pnnsFibreIdeas = [
  _PnnsFibre('Haricots blancs cuits', '≈ 14 g de fibres pour 100 g'),
  _PnnsFibre('Flocons de céréales', '≈ 10 g pour 100 g'),
  _PnnsFibre('Lentilles vertes cuites', '≈ 8 g pour 100 g'),
  _PnnsFibre('Pain complet', '≈ 7 g pour 100 g'),
  _PnnsFibre('Amandes', '≈ 12 g pour 100 g'),
  _PnnsFibre('Framboises', '≈ 4 g pour 100 g'),
];

extension _NutritionPnnsPart on _MaBelleSemaineAppState {
  bool _pnnsIsEnabled(_PnnsRef ref) => _pnnsEnabled[ref.id] ?? ref.defaultOn;
  String get _pnnsProfileLabel => _pnnsProfile == 'senior' ? 'Senior (≥ 65 ans)' : 'Adulte';

  /// Relit le profil, les repères actifs, les associations et les compteurs d'une sauvegarde.
  void _restorePnns(Map root) {
    _pnnsProfile = root['pnnsProfile'] == 'adulte' ? 'adulte' : 'senior';
    _pnnsEnabled.clear();
    if (root['pnnsEnabled'] is Map) {
      (root['pnnsEnabled'] as Map).forEach((key, value) {
        if (key is String && value is bool && _pnnsRefs.any((r) => r.id == key)) _pnnsEnabled[key] = value;
      });
    }
    _pnnsLinks.clear();
    if (root['pnnsLinks'] is Map) {
      (root['pnnsLinks'] as Map).forEach((key, value) {
        if (key is String && value is String && _pnnsRefs.any((r) => r.id == key)) _pnnsLinks[key] = value;
      });
    }
    _pnnsCounters.clear();
    if (root['pnnsCounters'] is Map) {
      (root['pnnsCounters'] as Map).forEach((day, counts) {
        if (day is! String || counts is! Map) return;
        final clean = <String, int>{};
        counts.forEach((ref, n) {
          if (ref is String && n is num && n > 0 && _pnnsRefs.any((r) => r.id == ref)) clean[ref] = min(30, n.toInt());
        });
        if (clean.isNotEmpty) _pnnsCounters[day] = clean;
      });
      if (_pnnsCounters.length > 120) {
        final keys = _pnnsCounters.keys.toList()..sort();
        for (final k in keys.take(_pnnsCounters.length - 120)) {
          _pnnsCounters.remove(k);
        }
      }
    }
  }

  int _pnnsCount(DateTime day, String refId) => _pnnsCounters[_contractKey(day)]?[refId] ?? 0;

  void _pnnsAdjust(String refId, int delta) {
    final key = _contractKey(_clockNow);
    setState(() {
      final counts = _pnnsCounters.putIfAbsent(key, () => <String, int>{});
      final next = max(0, min(30, (counts[refId] ?? 0) + delta));
      if (next == 0) {
        counts.remove(refId);
      } else {
        counts[refId] = next;
      }
      if (counts.isEmpty) _pnnsCounters.remove(key);
    });
    _queueLocalStatePersist();
  }

  /// Habitude Nutrition associée à un repère hebdomadaire (nulle si absente ou supprimée).
  Activity? _pnnsActivity(_PnnsRef ref) {
    final id = _pnnsLinks[ref.id];
    if (id == null) return null;
    return findActivity(id);
  }

  List<Activity> _pnnsCandidates(_PnnsRef ref) {
    final regex = RegExp(ref.pattern, caseSensitive: false);
    return [
      for (final a in _nutritionActivitiesForChecklist())
        if (regex.hasMatch(a.name) && !_pnnsLinks.values.contains(a.id)) a
    ];
  }

  // ----- calculs -------------------------------------------------------------------------------

  /// Repères « chaque jour » du jour [day] (aujourd'hui avant 19 h : en cours, pas encore manqué).
  List<_PnnsRow> _pnnsDayRows(DateTime day) {
    final now = _clockNow;
    final isToday = _contractKey(day) == _contractKey(now);
    final rows = <_PnnsRow>[];
    for (final ref in _pnnsRefs) {
      if (ref.cadence != 'jour' || !_pnnsIsEnabled(ref)) continue;
      final value = _pnnsCount(day, ref.id);
      final target = ref.target(_pnnsProfile);
      final _PnnsStatus status;
      if (value >= target) {
        status = _PnnsStatus.met;
      } else if (isToday && now.hour < 19) {
        status = _PnnsStatus.progress;
      } else {
        status = _PnnsStatus.missing;
      }
      rows.add(_PnnsRow(
        ref: ref,
        value: value,
        target: target,
        status: status,
        detail: value >= target ? 'Repère atteint' : 'Il manque ${target - value} ${ref.noun(target - value)}',
      ));
    }
    return rows;
  }

  /// Repères d'une semaine : quantités du jour sur les jours suivis, habitudes pour le reste.
  /// [spanDays] = nombre de jours écoulés de la semaine (7 pour une semaine terminée).
  ({int met, int total, List<_PnnsRow> rows}) _pnnsWeek(DateTime monday, int spanDays) {
    final now = _clockNow;
    final today0 = DateTime(now.year, now.month, now.day);
    final end = _addDays(monday, spanDays);
    final isCurrent = !today0.isBefore(monday) && today0.isBefore(_addDays(monday, 7));
    final complete = !isCurrent || now.weekday == 7;
    final daysLeft = isCurrent ? 7 - (now.weekday - 1) : 0;
    final rows = <_PnnsRow>[];

    for (final ref in _pnnsRefs) {
      final target = ref.target(_pnnsProfile);
      if (ref.cadence == 'jour') {
        if (!_pnnsIsEnabled(ref)) continue;
        var tracked = 0;
        var metDays = 0;
        for (var i = 0; i < spanDays; i++) {
          final day = _addDays(monday, i);
          if (day.isAfter(today0)) break;
          final counts = _pnnsCounters[_contractKey(day)];
          final any = counts != null && counts.values.any((v) => v > 0);
          final todayInProgress = day == today0 && now.hour < 20;
          if (!any && (day != today0 || todayInProgress)) continue;
          tracked++;
          if ((counts?[ref.id] ?? 0) >= target) metDays++;
        }
        final _PnnsStatus status;
        if (tracked == 0) {
          status = _PnnsStatus.untracked;
        } else if (metDays / tracked >= 0.7) {
          status = _PnnsStatus.met;
        } else if (metDays / tracked >= 0.4) {
          status = _PnnsStatus.progress;
        } else {
          status = _PnnsStatus.missing;
        }
        rows.add(_PnnsRow(
          ref: ref,
          value: metDays,
          target: tracked,
          status: status,
          detail: tracked == 0
              ? 'Pas encore de jour suivi'
              : '$metDays ${metDays > 1 ? 'jours' : 'jour'} sur $tracked au repère de $target',
        ));
      } else {
        final activity = _pnnsActivity(ref);
        if (activity == null) {
          rows.add(_PnnsRow(ref: ref, value: 0, target: target, status: _PnnsStatus.untracked, detail: 'Habitude non associée'));
          continue;
        }
        final actual = logs.where((l) {
          if (!_logIsRealised(l) || l.date.isBefore(monday) || !l.date.isBefore(end)) return false;
          return l.activityId == activity.id || (l.activityId == null && l.title.trim().toLowerCase() == activity.name.trim().toLowerCase());
        }).length;
        final _PnnsStatus status;
        String detail;
        if (ref.isMax) {
          status = actual > target ? _PnnsStatus.over : (actual == target ? _PnnsStatus.capReached : _PnnsStatus.capOk);
          detail = actual > target ? 'Au-dessus du repère de $target' : 'Dans le repère (au plus $target)';
        } else if (actual >= target) {
          status = _PnnsStatus.met;
          detail = 'Repère atteint';
        } else if (complete || target - actual > daysLeft) {
          status = _PnnsStatus.missing;
          detail = complete ? 'Repère non atteint (au moins $target)' : 'Plus atteignable cette semaine (au moins $target)';
        } else {
          status = _PnnsStatus.progress;
          detail = 'Encore ${target - actual} d’ici dimanche';
        }
        rows.add(_PnnsRow(ref: ref, value: actual, target: target, status: status, detail: detail, activity: activity));
      }
    }
    final judged = rows.where((r) => r.judged).toList();
    return (met: judged.where((r) => r.held).length, total: judged.length, rows: rows);
  }

  /// Phrase du bilan du jour : ce qu'il reste à faire, ou ce qui manque après 19 h.
  String _pnnsDaySummary() {
    final rows = _pnnsDayRows(_clockNow);
    if (rows.isEmpty) return 'Aucun repère quotidien actif : active-en dans les réglages.';
    final below = rows.where((r) => r.status == _PnnsStatus.progress || r.status == _PnnsStatus.missing).toList();
    if (below.isEmpty) return 'Journée dans les repères : bravo.';
    final text = below
        .take(3)
        .map((r) => '${r.target - r.value} ${r.ref.noun(r.target - r.value)}')
        .join(', ');
    final evening = _clockNow.hour >= 19;
    return evening ? 'Il te manque : $text.' : 'À placer aujourd’hui : $text.';
  }

  List<_PnnsFibre> _pnnsFibreSuggestions(List<_PnnsRow> rows) {
    final behind = rows.where((r) => r.status == _PnnsStatus.missing || r.status == _PnnsStatus.progress).map((r) => r.ref.id).toSet();
    final wanted = <String>[];
    if (behind.contains('legumesSecs') || behind.contains('fruitsLegumes')) wanted.addAll(['Haricots blancs cuits', 'Lentilles vertes cuites', 'Framboises']);
    if (behind.contains('feculentsComplets')) wanted.addAll(['Pain complet', 'Flocons de céréales']);
    if (behind.contains('fruitsCoque')) wanted.add('Amandes');
    return [for (final f in _pnnsFibreIdeas) if (wanted.contains(f.name)) f].take(3).toList();
  }

  // ----- actions sur les habitudes associées --------------------------------------------------------

  RealizationGoal? _pnnsGoalFor(Activity activity) {
    for (final g in _realizationGoals) {
      if (g.activityId == activity.id && g.cadence == 'semaine') return g;
    }
    return null;
  }

  void _pnnsAlignGoal(_PnnsRef ref, Activity activity) {
    final target = ref.target(_pnnsProfile);
    final existing = _pnnsGoalFor(activity);
    setState(() {
      if (existing != null) {
        existing.target = target;
        existing.isMaximum = ref.isMax;
        existing.rampTarget = null;
        existing.rampStart = null;
        existing.rampUntil = null;
      } else {
        _realizationGoals.add(RealizationGoal(
          id: 'goal_pnns_${ref.id}_${DateTime.now().microsecondsSinceEpoch}',
          activityId: activity.id,
          cadence: 'semaine',
          target: target,
          rewardText: 'Un petit plaisir mérité',
          createdAt: _clockNow,
          isMaximum: ref.isMax,
        ));
      }
    });
    _queueLocalStatePersist();
    _showFeedback('🎯 Objectif aligné sur le repère : ${ref.isMax ? 'au plus' : 'au moins'} $target par semaine pour « ${activity.name} ».');
  }

  void _pnnsLink(_PnnsRef ref, Activity activity) {
    setState(() => _pnnsLinks[ref.id] = activity.id);
    _queueLocalStatePersist();
  }

  void _pnnsUnlink(_PnnsRef ref) {
    setState(() => _pnnsLinks.remove(ref.id));
    _queueLocalStatePersist();
  }

  /// Ouvre l'éditeur d'activité prérempli ; le lien est posé tout de suite et ignoré tant que l'habitude n'existe pas.
  void _pnnsCreateHabit(_PnnsRef ref) {
    final id = 'nutrition_pnns_${ref.id}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _pnnsLinks[ref.id] = id);
    _queueLocalStatePersist();
    addOrEditActivity(
      prefill: Activity(
        id: id,
        name: ref.habitName,
        emoji: 'pack://${ref.icon}',
        category: 'Nutrition',
        duration: 1,
        frequency: ref.isMax ? 1 : ref.target(_pnnsProfile),
        priority: 3,
        countOnly: true,
      ),
    );
    _showFeedback('Enregistre l’habitude « ${ref.habitName} » pour la relier au repère.');
  }

  // ----- affichage -----------------------------------------------------------------------------------

  Color _pnnsColor(_PnnsStatus s) {
    switch (s) {
      case _PnnsStatus.met:
      case _PnnsStatus.capOk:
        return _colors.accentIcon;
      case _PnnsStatus.progress:
        return _colors.textMuted;
      case _PnnsStatus.capReached:
      case _PnnsStatus.missing:
        return _colors.goldText;
      case _PnnsStatus.over:
        return _colors.warnBorder;
      case _PnnsStatus.untracked:
        return _colors.textFaint;
    }
  }

  IconData _pnnsStatusIcon(_PnnsStatus s) {
    switch (s) {
      case _PnnsStatus.met:
      case _PnnsStatus.capOk:
        return Icons.check_circle_rounded;
      case _PnnsStatus.progress:
        return Icons.timelapse_rounded;
      case _PnnsStatus.capReached:
        return Icons.error_outline_rounded;
      case _PnnsStatus.missing:
        return Icons.error_outline_rounded;
      case _PnnsStatus.over:
        return Icons.warning_amber_rounded;
      case _PnnsStatus.untracked:
        return Icons.remove_circle_outline_rounded;
    }
  }

  /// Ligne résumée de l'accueil : le bilan du jour, avec un +1 rapide par repère quotidien.
  Widget _pnnsHomeRow() {
    final daily = _pnnsDayRows(_clockNow);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        decoration: BoxDecoration(
          color: _colors.card,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _colors.borderTint),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: _openPnnsBilan,
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: Row(children: [
              Icon(Icons.eco_outlined, size: 18, color: _colors.accentIcon),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'BILAN ALIMENTAIRE · REPÈRES PNNS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w900, letterSpacing: .3, color: _colors.accentStrongText),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: _colors.textFaint),
            ]),
          ),
          const SizedBox(height: 4),
          Text(_pnnsDaySummary(), style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textStrong)),
          if (daily.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final row in daily)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.add_rounded, size: 16, color: _pnnsColor(row.status)),
                  label: Text('${row.ref.label} ${row.value}/${row.target}', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                  onPressed: () {
                    _pnnsAdjust(row.ref.id, 1);
                    final value = _pnnsCount(_clockNow, row.ref.id);
                    _showFeedback('${row.ref.label} : $value/${row.target}');
                  },
                ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _pnnsRowTile(_PnnsRow row, {required bool counters, VoidCallback? onChanged}) {
    final color = _pnnsColor(row.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: _colors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _colors.borderTint),
        ),
        child: Row(children: [
          _activityIconWidget('pack://${row.ref.icon}', size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(row.ref.label, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong))),
                Icon(_pnnsStatusIcon(row.status), size: 16, color: color),
              ]),
              Text(row.detail, style: TextStyle(fontSize: AppType.small, height: 1.25, color: color)),
            ]),
          ),
          if (counters) ...[
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Retirer une portion',
              onPressed: row.value > 0
                  ? () {
                      _pnnsAdjust(row.ref.id, -1);
                      onChanged?.call();
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            SizedBox(
              width: 38,
              child: Text('${row.value}/${row.target}', textAlign: TextAlign.center, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w900, color: _colors.textStrong)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Ajouter une portion',
              onPressed: () {
                _pnnsAdjust(row.ref.id, 1);
                onChanged?.call();
              },
              icon: Icon(Icons.add_circle_rounded, color: _colors.accentIcon),
            ),
          ] else
            Text(
              row.ref.cadence == 'semaine' && row.activity != null ? '${row.value}/${row.target}' : '',
              style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w900, color: _colors.textStrong),
            ),
        ]),
      ),
    );
  }

  Future<void> _openPnnsBilan({bool week = false}) async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    var weekMode = week;
    await showModalBottomSheet<void>(
      context: navigationContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final now = _clockNow;
          final monday = _reviewMonday(now);
          final weekData = _pnnsWeek(monday, now.weekday);
          final dayRows = _pnnsDayRows(now);
          final weeklyRows = weekData.rows.where((r) => r.ref.cadence == 'semaine').toList();
          final improve = weekData.rows.where((r) => r.status == _PnnsStatus.missing || r.status == _PnnsStatus.over).toList();
          final fibre = _pnnsFibreSuggestions(weekMode ? weekData.rows : dayRows);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('Bilan alimentaire', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _openPnnsSettings();
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Réglages'),
                  ),
                ]),
                Text('Repères PNNS · profil $_pnnsProfileLabel', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Aujourd’hui')),
                    ButtonSegment<bool>(value: true, label: Text('Cette semaine')),
                  ],
                  selected: <bool>{weekMode},
                  onSelectionChanged: (s) => setSheetState(() => weekMode = s.first),
                ),
                const SizedBox(height: 12),
                if (!weekMode) ...[
                  Text(_pnnsDaySummary(), style: TextStyle(fontSize: AppType.bodyL, height: 1.3, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                  const SizedBox(height: 10),
                  if (dayRows.isEmpty)
                    Text('Aucun repère quotidien actif. Active-les dans les réglages.', style: TextStyle(color: _colors.textMuted))
                  else
                    for (final row in dayRows) _pnnsRowTile(row, counters: true, onChanged: () => setSheetState(() {})),
                  if (weeklyRows.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Cette semaine', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                    const SizedBox(height: 6),
                    for (final row in weeklyRows) _pnnsRowTile(row, counters: false),
                  ],
                ] else ...[
                  Text(
                    weekData.total == 0 ? 'Pas encore de repère à juger cette semaine.' : 'Repères tenus : ${weekData.met}/${weekData.total}',
                    style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w900, color: _colors.textStrong),
                  ),
                  const SizedBox(height: 10),
                  for (final row in weekData.rows) _pnnsRowTile(row, counters: false),
                  if (improve.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('À améliorer', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.goldText)),
                    const SizedBox(height: 4),
                    for (final row in improve.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${row.ref.label} : ${row.ref.hint}', style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textStrong)),
                      ),
                  ],
                ],
                if (fibre.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Idées riches en fibres', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                  const SizedBox(height: 4),
                  for (final f in fibre)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('• ${f.name} : ${f.grams}', style: TextStyle(fontSize: AppType.body, color: _colors.textStrong)),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Repères de santé publique, suivis par portions : un point d’appui, pas un avis médical.',
                  style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: _openPnnsReferences, child: const Text('Mes repères en bref')),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPnnsSettings() async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: navigationContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void refresh() => setSheetState(() {});
          final weekly = _pnnsRefs.where((r) => r.cadence == 'semaine').toList();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mes repères', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                const SizedBox(height: 10),
                Text('Profil de référence', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: 'senior', label: Text('Senior (≥ 65 ans)')),
                    ButtonSegment<String>(value: 'adulte', label: Text('Adulte')),
                  ],
                  selected: <String>{_pnnsProfile},
                  onSelectionChanged: (s) {
                    setState(() => _pnnsProfile = s.first);
                    _queueLocalStatePersist();
                    refresh();
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  _pnnsProfile == 'senior' ? 'Senior : 3 produits laitiers par jour, protéines à chaque repas.' : 'Adulte : 2 produits laitiers par jour.',
                  style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                ),
                const SizedBox(height: 14),
                Text('Chaque jour : compteurs', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                for (final ref in _pnnsRefs.where((r) => r.cadence == 'jour'))
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _pnnsIsEnabled(ref),
                    onChanged: (value) {
                      setState(() => _pnnsEnabled[ref.id] = value);
                      _queueLocalStatePersist();
                      refresh();
                    },
                    title: Text('${ref.label} · ${ref.target(_pnnsProfile)} par jour', style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong)),
                    subtitle: Text(ref.portion, style: TextStyle(color: _colors.textMuted)),
                  ),
                const SizedBox(height: 10),
                Text('Chaque semaine : tes habitudes', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                const SizedBox(height: 6),
                for (final ref in weekly) _pnnsWeeklySettingTile(ref, refresh),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _pnnsWeeklySettingTile(_PnnsRef ref, VoidCallback refresh) {
    final activity = _pnnsActivity(ref);
    final target = ref.target(_pnnsProfile);
    final repere = '${ref.isMax ? 'au plus' : 'au moins'} $target par semaine';
    final goal = activity == null ? null : _pnnsGoalFor(activity);
    final aligned = goal != null && goal.target == target && goal.isMaximum == ref.isMax;
    final candidates = activity == null ? _pnnsCandidates(ref) : const <Activity>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _colors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _colors.borderTint),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _activityIconWidget('pack://${ref.icon}', size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(ref.label, style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textStrong))),
          ]),
          const SizedBox(height: 3),
          Text('Repère PNNS : $repere', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
          if (activity != null) ...[
            Text(
              'Habitude : « ${activity.name} » · ma règle : ${goal == null ? 'aucun objectif' : '${goal.isMaximum ? 'au plus' : 'au moins'} ${goal.target} par semaine'}',
              style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textStrong),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              if (aligned)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.check_circle_rounded, size: 16, color: _colors.accentIcon),
                  label: const Text('Aligné sur le repère'),
                )
              else
                FilledButton.tonal(
                  onPressed: () {
                    _pnnsAlignGoal(ref, activity);
                    refresh();
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: Text(goal == null ? 'Créer l’objectif ($target)' : 'Aligner mon objectif ($target)'),
                ),
              TextButton(
                onPressed: () {
                  _pnnsUnlink(ref);
                  refresh();
                },
                child: const Text('Dissocier'),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final candidate in candidates.take(2))
                FilledButton.tonal(
                  onPressed: () {
                    _pnnsLink(ref, candidate);
                    refresh();
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: Text('Associer « ${candidate.name} »'),
                ),
              OutlinedButton(
                onPressed: () => _pnnsCreateHabit(ref),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('Créer l’habitude'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _openPnnsReferences() async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    final senior = _pnnsProfile == 'senior';
    final lines = <String>[
      'Fruits et légumes : au moins 5 portions par jour (80 à 100 g chacune), sous toutes leurs formes.',
      'Produits laitiers : ${senior ? '3 par jour' : '2 par jour'} (yaourt, fromage blanc, lait, 30 g de fromage).',
      'Féculents à chaque repas, selon l’appétit ; au moins une fois par jour en version complète.',
      'Légumes secs au moins 2 fois par semaine ; poisson 2 fois par semaine, dont un poisson gras.',
      'Viande hors volaille : 500 g par semaine au plus ; charcuterie : 150 g par semaine au plus.',
      'Eau à volonté, environ 1,5 L par jour ; limiter les boissons sucrées et l’alcool.',
      'Limiter le sel, les produits sucrés et les matières grasses ; huiles de colza, d’olive ou de noix de préférence.',
      'Une petite poignée de fruits à coque non salés par jour, des plats faits maison quand c’est possible.',
      'Bouger au moins l’équivalent de 30 minutes de marche rapide par jour.',
      if (senior) 'Protéines : environ 1 g par kg de poids et par jour, réparties sur les repas, pour préserver les muscles.',
      if (senior) 'Calcium et vitamine D pour les os ; renforcement musculaire, équilibre et souplesse 2 à 3 fois par semaine.',
      if (senior) 'Prendre le temps de manger, composer des assiettes variées et colorées.',
      'Fibres : 25 à 30 g par jour (légumineuses, céréales complètes, fruits, légumes, oléagineux). Elles ne sont pas mesurées en grammes ici.',
    ];
    await showModalBottomSheet<void>(
      context: navigationContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mes repères en bref', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
            Text('Résumé des repères du PNNS · profil $_pnnsProfileLabel', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.eco_outlined, size: 16, color: _colors.accentIcon)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: TextStyle(fontSize: AppType.body, height: 1.3, color: _colors.textStrong))),
                ]),
              ),
            const SizedBox(height: 6),
            Text(
              'Ce sont des repères, pas des normes. En cas de question de santé, un professionnel reste le bon interlocuteur.',
              style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}
