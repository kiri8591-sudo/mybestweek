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
  final String icon; // valeur d'icône complète (pack://…, emoji ou icône personnelle)
  final String singular;
  final String plural;
  final String portion; // ce que vaut une portion
  final String hint; // idée concrète pour rattraper
  final String habitName; // nom proposé pour l'habitude
  final String pattern; // reconnaissance des aliments par leur nom
  final String exclude; // noms à écarter
  final bool defaultOn;
  final bool custom; // repère ajouté par l'utilisateur
  final int? targetOverride; // quantité choisie par l'utilisateur

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
    this.exclude = '',
    this.defaultOn = true,
    this.custom = false,
    this.targetOverride,
  });

  int target(String profile) => targetOverride ?? (profile == 'senior' ? seniorTarget : adultTarget);
  String noun(int n) => n > 1 ? plural : singular;

  _PnnsRef copyWith({String? label, String? icon, int? targetOverride}) => _PnnsRef(
        id: id,
        label: label ?? this.label,
        cadence: cadence,
        adultTarget: adultTarget,
        seniorTarget: seniorTarget,
        icon: icon ?? this.icon,
        singular: singular,
        plural: plural,
        portion: portion,
        hint: hint,
        isMax: isMax,
        habitName: habitName,
        pattern: pattern,
        exclude: exclude,
        defaultOn: defaultOn,
        custom: custom,
        targetOverride: targetOverride ?? this.targetOverride,
      );
}

final Map<String, RegExp> _pnnsRegexCache = <String, RegExp>{};
RegExp _pnnsRegex(String pattern) => _pnnsRegexCache.putIfAbsent(pattern, () => RegExp(pattern, caseSensitive: false));

String _pnnsPluralize(String word) {
  final w = word.trim();
  if (w.isEmpty) return 'portions';
  final last = w[w.length - 1].toLowerCase();
  return (last == 's' || last == 'x') ? w : '${w}s';
}

/// Ordre dans lequel les repères reconnaissent un aliment : le plus spécifique d'abord (un aliment n'est jamais compté deux fois).
const List<String> _pnnsAutoPriority = [
  'legumesSecs', 'poisson', 'viande', 'charcuterie', 'fruitsCoque', 'feculentsComplets', 'laitiers', 'fruitsLegumes', 'eau',
];

const List<_PnnsRef> _pnnsRefs = [
  _PnnsRef(
    id: 'fruitsLegumes',
    label: 'Fruits et légumes',
    cadence: 'jour',
    adultTarget: 5,
    seniorTarget: 5,
    icon: 'pack://apple',
    singular: 'portion de fruits et légumes',
    plural: 'portions de fruits et légumes',
    portion: 'Une portion = 80 à 100 g : une tomate, une pomme, un bol de soupe, une poignée de haricots verts.',
    hint: 'Ajoute une soupe, des crudités ou un fruit.',
    pattern: r'l[ée]gume|fruit|salade|crudit[ée]|soupe|compote|tomate|carotte|brocoli|courgette|poireau|[ée]pinard|chou|concombre|poivron|aubergine|haricots? verts?|petits? pois|radis|navet|endive|champignon|potiron|courge|betterave|fenouil|artichaut|pomme|poire|banane|orange|cl[ée]mentine|mandarine|kiwi|fraise|framboise|myrtille|cerise|p[eê]che|abricot|raisin|melon|past[eè]que|ananas|mangue|agrume|prune|figue|pamplemousse',
    exclude: r'l[ée]gumes?\s*secs?|l[ée]gumineuse|coque|noix|amande|noisette|lentille|pois.?chiche|flageolet|fruits? secs?|pomme de terre|\bjus\b',
  ),
  _PnnsRef(
    id: 'laitiers',
    label: 'Produits laitiers',
    cadence: 'jour',
    adultTarget: 2,
    seniorTarget: 3,
    icon: 'pack://cheese',
    singular: 'produit laitier',
    plural: 'produits laitiers',
    portion: 'Une portion = un yaourt, un fromage blanc, 30 g de fromage ou un verre de lait.',
    hint: 'Un yaourt nature, un fromage blanc ou un verre de lait.',
    pattern: r'laitier|yaourt|yogourt|fromage|faisselle|petits?.?suisses?|\blait\b|laitage|skyr|k[ée]fir|camembert|emmental|comt[ée]|ch[èe]vre|mozzarella|parmesan|beaufort|brie|roquefort|cantal|raclette',
    exclude: r'coco|soja|amande|avoine|v[ée]g[ée]tal',
  ),
  _PnnsRef(
    id: 'feculentsComplets',
    label: 'Féculents complets',
    cadence: 'jour',
    adultTarget: 1,
    seniorTarget: 1,
    icon: 'pack://balanced_meal',
    singular: 'portion de féculents complets',
    plural: 'portions de féculents complets',
    portion: 'Pain complet, riz complet, pâtes complètes ou flocons de céréales.',
    hint: 'Pain complet, riz complet ou flocons d’avoine.',
    pattern: r'complet|c[ée]r[ée]ale|avoine|flocon|muesli|quinoa|boulgour|sarrasin|[ée]peautre|seigle|polenta',
  ),
  _PnnsRef(
    id: 'fruitsCoque',
    label: 'Fruits à coque',
    cadence: 'jour',
    adultTarget: 1,
    seniorTarget: 1,
    icon: 'pack://walnut',
    singular: 'poignée de fruits à coque',
    plural: 'poignées de fruits à coque',
    portion: 'Une petite poignée de noix, amandes ou noisettes non salées.',
    hint: 'Une petite poignée de noix ou d’amandes non salées.',
    pattern: r'coque|noix|amande|noisette|cajou|pistache|pecan|pignon',
    exclude: r'\blait\b|boisson|jus|lait v[ée]g[ée]tal',
    defaultOn: false,
  ),
  _PnnsRef(
    id: 'eau',
    label: 'Eau',
    cadence: 'jour',
    adultTarget: 6,
    seniorTarget: 6,
    icon: 'pack://water_glass',
    singular: 'verre d’eau',
    plural: 'verres d’eau',
    portion: 'Un verre ≈ 25 cl : six verres font environ 1,5 L, en plus des autres boissons.',
    hint: 'Un grand verre d’eau, une tisane ou une infusion.',
    pattern: r'\beau\b|hydrat|verre d.eau|tisane|infusion',
  ),
  _PnnsRef(
    id: 'legumesSecs',
    label: 'Légumes secs',
    cadence: 'semaine',
    adultTarget: 2,
    seniorTarget: 2,
    icon: 'pack://beans',
    singular: 'repas avec légumes secs',
    plural: 'repas avec légumes secs',
    portion: 'Lentilles, pois chiches, haricots secs, flageolets, pois cassés.',
    hint: 'Lentilles, pois chiches ou haricots blancs.',
    habitName: 'Légumineuses',
    pattern: r'l[ée]gumineuse|lentille|pois.?chiche|haricot|f[eè]ve|l[ée]gumes?.?secs?|flageolet|pois cass[ée]s?',
    exclude: r'haricots? verts?',
  ),
  _PnnsRef(
    id: 'poisson',
    label: 'Poisson',
    cadence: 'semaine',
    adultTarget: 2,
    seniorTarget: 2,
    icon: 'pack://fish',
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
    icon: 'pack://restaurant',
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
    icon: 'pack://cake',
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
  final Activity? activity; // habitude principale reconnue (pour aligner l'objectif)
  final String source; // d'où vient le réalisé : habitudes et/ou ajout à la main
  final int manual; // portions ajoutées à la main aujourd'hui
  const _PnnsRow({
    required this.ref,
    required this.value,
    required this.target,
    required this.status,
    required this.detail,
    this.activity,
    this.source = '',
    this.manual = 0,
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

  /// Repère ajouté par l'utilisateur, normalisé (ou null si inutilisable).
  Map<String, Object?>? _pnnsCleanCustom(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    if (id is! String || id.isEmpty || label is! String || label.trim().isEmpty) return null;
    final target = raw['target'];
    final unit = raw['unit'];
    final keywords = raw['keywords'];
    final icon = raw['icon'];
    return {
      'id': id,
      'label': label.trim().length > 40 ? label.trim().substring(0, 40) : label.trim(),
      'icon': icon is String && icon.isNotEmpty ? icon : 'pack://sprout',
      'cadence': raw['cadence'] == 'semaine' ? 'semaine' : 'jour',
      'isMax': raw['isMax'] == true,
      'target': target is num ? max(1, min(99, target.toInt())) : 1,
      'unit': unit is String && unit.trim().isNotEmpty ? (unit.trim().length > 24 ? unit.trim().substring(0, 24) : unit.trim()) : 'portion',
      'keywords': keywords is String ? (keywords.length > 120 ? keywords.substring(0, 120) : keywords) : '',
    };
  }

  _PnnsRef _pnnsCustomToRef(Map<String, Object?> c) {
    final label = c['label'] as String;
    final unit = c['unit'] as String;
    final target = c['target'] as int;
    final words = [
      for (final w in (c['keywords'] as String).split(RegExp(r'[,;\n]')))
        if (w.trim().length >= 2) RegExp.escape(w.trim())
    ];
    return _PnnsRef(
      id: c['id'] as String,
      label: label,
      cadence: c['cadence'] as String,
      isMax: c['isMax'] == true,
      adultTarget: target,
      seniorTarget: target,
      icon: c['icon'] as String,
      singular: '$unit de « $label »',
      plural: '${_pnnsPluralize(unit)} de « $label »',
      portion: '',
      hint: '',
      habitName: label,
      pattern: words.join('|'),
      custom: true,
    );
  }

  /// Tous les repères tels que l'utilisateur les a réglés : repères PNNS (titre, icône, quantité éventuellement modifiés) puis repères ajoutés.
  List<_PnnsRef> _pnnsAllRefs() {
    final result = <_PnnsRef>[];
    for (final base in _pnnsRefs) {
      final o = _pnnsOverrides[base.id];
      final label = o?['label'];
      final icon = o?['icon'];
      final target = o?['target'];
      result.add(base.copyWith(
        label: label is String && label.trim().isNotEmpty ? label.trim() : null,
        icon: icon is String && icon.isNotEmpty ? icon : null,
        targetOverride: target is int ? target : null,
      ));
    }
    for (final c in _pnnsCustom) {
      result.add(_pnnsCustomToRef(c));
    }
    return result;
  }

  /// Relit le profil, les repères (modifiés ou ajoutés), les aliments rattachés et les compteurs d'une sauvegarde.
  void _restorePnns(Map root) {
    _pnnsProfile = root['pnnsProfile'] == 'adulte' ? 'adulte' : 'senior';
    _pnnsCustom.clear();
    if (root['pnnsCustom'] is List) {
      for (final raw in root['pnnsCustom'] as List) {
        final c = _pnnsCleanCustom(raw);
        if (c == null || _pnnsCustom.any((x) => x['id'] == c['id'])) continue;
        _pnnsCustom.add(c);
        if (_pnnsCustom.length >= 20) break;
      }
    }
    final ids = <String>{for (final r in _pnnsRefs) r.id, for (final c in _pnnsCustom) c['id'] as String};
    _pnnsOverrides.clear();
    if (root['pnnsOverrides'] is Map) {
      (root['pnnsOverrides'] as Map).forEach((key, value) {
        if (key is! String || value is! Map || !_pnnsRefs.any((r) => r.id == key)) return;
        final clean = <String, Object?>{};
        final label = value['label'];
        final icon = value['icon'];
        final target = value['target'];
        if (label is String && label.trim().isNotEmpty) clean['label'] = label.trim().length > 40 ? label.trim().substring(0, 40) : label.trim();
        if (icon is String && icon.isNotEmpty) clean['icon'] = icon;
        if (target is num) clean['target'] = max(1, min(99, target.toInt()));
        if (clean.isNotEmpty) _pnnsOverrides[key] = clean;
      });
    }
    _pnnsEnabled.clear();
    if (root['pnnsEnabled'] is Map) {
      (root['pnnsEnabled'] as Map).forEach((key, value) {
        if (key is String && value is bool && ids.contains(key)) _pnnsEnabled[key] = value;
      });
    }
    _pnnsAttach.clear();
    if (root['pnnsAttach'] is Map) {
      (root['pnnsAttach'] as Map).forEach((key, value) {
        if (key is String && key.isNotEmpty && value is String && (value.isEmpty || ids.contains(value))) _pnnsAttach[key] = value;
      });
    }
    // Ancien format (V12.34 à V12.35) : repère → habitude, converti en aliment → repère.
    if (root['pnnsLinks'] is Map) {
      (root['pnnsLinks'] as Map).forEach((refId, activityId) {
        if (refId is String && activityId is String && ids.contains(refId) && !_pnnsAttach.containsKey(activityId)) {
          _pnnsAttach[activityId] = refId;
        }
      });
    }
    _pnnsLinks.clear();
    _pnnsCounters.clear();
    if (root['pnnsCounters'] is Map) {
      (root['pnnsCounters'] as Map).forEach((day, counts) {
        if (day is! String || counts is! Map) return;
        final clean = <String, int>{};
        counts.forEach((ref, n) {
          if (ref is String && n is num && n > 0 && ids.contains(ref)) clean[ref] = min(30, n.toInt());
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

  /// Aliments (habitudes) pouvant alimenter un repère : habitudes Nutrition et habitudes comptées en occurrences.
  List<Activity> _pnnsPool() {
    final seen = <String>{};
    final pool = <Activity>[];
    for (final a in [..._nutritionActivitiesForChecklist(), ...activities.where((a) => a.countOnly)]) {
      if (a.isDateRange || _activityIsDeleted(a) || !seen.add(a.id)) continue;
      pool.add(a);
    }
    pool.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return pool;
  }

  /// Reconnaissance automatique par le nom, pour les aliments sans choix explicite : un aliment n'a jamais qu'un repère.
  Map<String, String> _pnnsAutoAssignments(List<_PnnsRef> refs) {
    final ordered = <_PnnsRef>[
      ...refs.where((r) => r.custom),
      for (final id in _pnnsAutoPriority)
        for (final r in refs)
          if (r.id == id) r,
    ];
    final out = <String, String>{};
    for (final a in _pnnsPool()) {
      if (_pnnsAttach.containsKey(a.id)) continue;
      for (final ref in ordered) {
        if (ref.pattern.isEmpty || !_pnnsRegex(ref.pattern).hasMatch(a.name)) continue;
        if (ref.exclude.isNotEmpty && _pnnsRegex(ref.exclude).hasMatch(a.name)) continue;
        out[a.id] = ref.id;
        break;
      }
    }
    return out;
  }

  /// Aliments qui alimentent un repère : ceux rattachés à la main, puis ceux reconnus automatiquement.
  List<Activity> _pnnsHabits(_PnnsRef ref, {List<_PnnsRef>? refs}) {
    final result = <Activity>[];
    for (final e in _pnnsAttach.entries) {
      if (e.value != ref.id) continue;
      final a = findActivity(e.key);
      if (a != null && !a.isFrozen && !a.isDateRange) result.add(a);
    }
    final auto = _pnnsAutoAssignments(refs ?? _pnnsAllRefs());
    for (final e in auto.entries) {
      if (e.value != ref.id) continue;
      final a = findActivity(e.key);
      if (a != null && !a.isFrozen && !result.any((x) => x.id == a.id)) result.add(a);
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  /// Réalisations de ces habitudes dans [from, toExclusive).
  int _pnnsHabitCount(List<Activity> habits, DateTime from, DateTime toExclusive) {
    if (habits.isEmpty) return 0;
    final ids = {for (final a in habits) a.id};
    final names = {for (final a in habits) a.name.trim().toLowerCase()};
    var n = 0;
    for (final l in logs) {
      if (!_logIsRealised(l) || l.date.isBefore(from) || !l.date.isBefore(toExclusive)) continue;
      final match = l.activityId != null ? ids.contains(l.activityId) : names.contains(l.title.trim().toLowerCase());
      if (match) n++;
    }
    return n;
  }

  /// Jours (yyyy-mm-dd) où au moins une habitude Nutrition a été réalisée dans [from, toExclusive).
  Set<String> _pnnsNutritionDays(DateTime from, DateTime toExclusive) {
    final nutrition = _nutritionActivitiesForChecklist();
    final ids = {for (final a in nutrition) a.id};
    final names = {for (final a in nutrition) a.name.trim().toLowerCase()};
    final days = <String>{};
    for (final l in logs) {
      if (!_logIsRealised(l) || l.date.isBefore(from) || !l.date.isBefore(toExclusive)) continue;
      final match = l.activityId != null ? ids.contains(l.activityId) : names.contains(l.title.trim().toLowerCase());
      if (match) days.add(_contractKey(l.date));
    }
    return days;
  }

  String _pnnsSource(List<Activity> habits, DateTime from, DateTime toExclusive, int manual) {
    final parts = <String>[];
    final names = <String>[];
    var habit = 0;
    for (final a in habits) {
      final n = _pnnsHabitCount([a], from, toExclusive);
      if (n > 0) {
        habit += n;
        names.add(a.name);
      }
    }
    if (habit > 0) parts.add('$habit depuis tes habitudes (${names.take(3).join(', ')})');
    if (manual > 0) parts.add('$manual ajouté${manual > 1 ? 's' : ''} à la main');
    return parts.join(' + ');
  }

  // ----- calculs -------------------------------------------------------------------------------

  /// Repères « chaque jour » du jour [day] : habitudes Nutrition réalisées + portions ajoutées à la main
  /// (aujourd'hui avant 19 h : en cours, pas encore manqué).
  List<_PnnsRow> _pnnsDayRows(DateTime day) {
    final now = _clockNow;
    final isToday = _contractKey(day) == _contractKey(now);
    final from = DateTime(day.year, day.month, day.day);
    final to = _addDays(from, 1);
    final rows = <_PnnsRow>[];
    final allRefs = _pnnsAllRefs();
    for (final ref in allRefs) {
      if (ref.cadence != 'jour' || !_pnnsIsEnabled(ref)) continue;
      final habits = _pnnsHabits(ref, refs: allRefs);
      final manual = _pnnsCount(day, ref.id);
      final value = _pnnsHabitCount(habits, from, to) + manual;
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
        activity: habits.isEmpty ? null : habits.first,
        source: _pnnsSource(habits, from, to, manual),
        manual: manual,
      ));
    }
    return rows;
  }

  /// Repères d'une semaine : quantités du jour (habitudes + ajouts) sur les jours suivis, habitudes pour le reste.
  /// [spanDays] = nombre de jours écoulés de la semaine (7 pour une semaine terminée).
  ({int met, int total, List<_PnnsRow> rows}) _pnnsWeek(DateTime monday, int spanDays) {
    final now = _clockNow;
    final today0 = DateTime(now.year, now.month, now.day);
    final end = _addDays(monday, spanDays);
    final isCurrent = !today0.isBefore(monday) && today0.isBefore(_addDays(monday, 7));
    final complete = !isCurrent || now.weekday == 7;
    final daysLeft = isCurrent ? 7 - (now.weekday - 1) : 0;
    final nutritionDays = _pnnsNutritionDays(monday, end);
    final rows = <_PnnsRow>[];
    final allRefs = _pnnsAllRefs();

    for (final ref in allRefs) {
      if (!_pnnsIsEnabled(ref)) continue;
      final target = ref.target(_pnnsProfile);
      final habits = _pnnsHabits(ref, refs: allRefs);
      var manualWeek = 0;
      for (var i = 0; i < spanDays; i++) {
        manualWeek += _pnnsCount(_addDays(monday, i), ref.id);
      }
      final manualToday = isCurrent ? _pnnsCount(today0, ref.id) : 0;
      if (ref.cadence == 'jour') {
        var tracked = 0;
        var metDays = 0;
        for (var i = 0; i < spanDays; i++) {
          final day = _addDays(monday, i);
          if (day.isAfter(today0)) break;
          final counts = _pnnsCounters[_contractKey(day)];
          final anyManual = counts != null && counts.values.any((v) => v > 0);
          final signal = anyManual || nutritionDays.contains(_contractKey(day));
          final todayInProgress = day == today0 && now.hour < 20;
          if (!signal && (day != today0 || todayInProgress)) continue;
          tracked++;
          final value = _pnnsHabitCount(habits, day, _addDays(day, 1)) + (counts?[ref.id] ?? 0);
          if (value >= target) metDays++;
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
          activity: habits.isEmpty ? null : habits.first,
          manual: manualToday,
        ));
      } else {
        final habitActual = _pnnsHabitCount(habits, monday, end);
        final actual = habitActual + manualWeek;
        if (habits.isEmpty && manualWeek == 0) {
          rows.add(_PnnsRow(ref: ref, value: 0, target: target, status: _PnnsStatus.untracked, detail: 'Aucune habitude reconnue : ajoute-la ou compte à la main', manual: manualToday));
          continue;
        }
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
        rows.add(_PnnsRow(
          ref: ref,
          value: actual,
          target: target,
          status: status,
          detail: detail,
          activity: habits.isEmpty ? null : habits.first,
          source: _pnnsSource(habits, monday, end, manualWeek),
          manual: manualToday,
        ));
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

  /// Ouvre l'éditeur d'activité prérempli ; le lien est posé tout de suite et ignoré tant que l'habitude n'existe pas.
  void _pnnsCreateHabit(_PnnsRef ref) {
    final id = 'nutrition_pnns_${ref.id}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _pnnsAttach[id] = ref.id);
    _queueLocalStatePersist();
    addOrEditActivity(
      prefill: Activity(
        id: id,
        name: ref.habitName.isEmpty ? ref.label : ref.habitName,
        emoji: ref.icon,
        category: 'Nutrition',
        duration: 1,
        frequency: ref.isMax ? 1 : ref.target(_pnnsProfile),
        priority: 3,
        countOnly: true,
      ),
    );
    _showFeedback('Enregistre l’habitude pour la relier au repère.');
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
          _activityIconWidget(row.ref.icon, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(row.ref.label, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textStrong))),
                Icon(_pnnsStatusIcon(row.status), size: 16, color: color),
              ]),
              Text(row.detail, style: TextStyle(fontSize: AppType.small, height: 1.25, color: color)),
              if (row.source.isNotEmpty)
                Text('Dont ${row.source}', style: TextStyle(fontSize: AppType.micro, height: 1.25, color: _colors.textMuted)),
              if (counters && row.activity == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      await _openPnnsFoods();
                      onChanged?.call();
                    },
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(vertical: 2), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Aucun aliment rattaché : en rattacher'),
                  ),
                ),
            ]),
          ),
          if (counters) ...[
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Retirer une portion ajoutée à la main',
              onPressed: row.manual > 0
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
              tooltip: 'Ajouter une portion à la main',
              onPressed: () {
                _pnnsAdjust(row.ref.id, 1);
                onChanged?.call();
              },
              icon: Icon(Icons.add_circle_rounded, color: _colors.accentIcon),
            ),
          ] else
            Text(
              row.ref.cadence == 'semaine' && row.status != _PnnsStatus.untracked ? '${row.value}/${row.target}' : '',
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
                    for (final row in weeklyRows) _pnnsRowTile(row, counters: true, onChanged: () => setSheetState(() {})),
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
          final refs = _pnnsAllRefs();
          final daily = refs.where((r) => r.cadence == 'jour').toList();
          final weekly = refs.where((r) => r.cadence == 'semaine').toList();
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
                Row(children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await _openPnnsRefEditor();
                        refresh();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter un repère'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _openPnnsFoods();
                        refresh();
                      },
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Mes aliments'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Text('Chaque jour', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                const SizedBox(height: 6),
                for (final ref in daily) _pnnsRefSettingTile(ref, refs, refresh),
                const SizedBox(height: 6),
                Text('Chaque semaine', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                const SizedBox(height: 6),
                for (final ref in weekly) _pnnsRefSettingTile(ref, refs, refresh),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _pnnsRefSettingTile(_PnnsRef ref, List<_PnnsRef> refs, VoidCallback refresh) {
    final habits = _pnnsHabits(ref, refs: refs);
    final target = ref.target(_pnnsProfile);
    final qty = '${ref.isMax ? 'au plus' : 'au moins'} $target par ${ref.cadence == 'jour' ? 'jour' : 'semaine'}';
    final modified = !ref.custom && ref.targetOverride != null;
    final activity = habits.isEmpty ? null : habits.first;
    final goal = (ref.cadence == 'semaine' && activity != null) ? _pnnsGoalFor(activity) : null;
    final aligned = goal != null && goal.target == target && goal.isMaximum == ref.isMax;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: _colors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: _colors.borderTint),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _activityIconWidget(ref.icon, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ref.label, style: TextStyle(fontWeight: FontWeight.w800, color: _colors.textStrong)),
                Text('$qty${modified ? ' · modifié' : ''}${ref.custom ? ' · ajouté par toi' : ''}', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
              ]),
            ),
            Switch(
              value: _pnnsIsEnabled(ref),
              onChanged: (value) {
                setState(() => _pnnsEnabled[ref.id] = value);
                _queueLocalStatePersist();
                refresh();
              },
            ),
          ]),
          if (ref.portion.isNotEmpty) Text(ref.portion, style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted)),
          const SizedBox(height: 3),
          Text(
            habits.isEmpty ? 'Aucun aliment rattaché.' : 'Aliments : ${habits.map((a) => '« ${a.name} »').join(', ')}',
            style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textStrong),
          ),
          if (ref.cadence == 'semaine' && activity != null) ...[
            Text(
              'Ma règle (« ${activity.name} ») : ${goal == null ? 'aucun objectif' : '${goal.isMaximum ? 'au plus' : 'au moins'} ${goal.target} par semaine'}',
              style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textStrong),
            ),
            const SizedBox(height: 4),
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
          ],
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () async {
                await _openPnnsRefEditor(ref: ref);
                refresh();
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Modifier'),
            ),
            TextButton.icon(
              onPressed: () async {
                await _openPnnsFoods();
                refresh();
              },
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('Aliments'),
            ),
            if (activity == null && ref.cadence == 'semaine')
              TextButton.icon(
                onPressed: () => _pnnsCreateHabit(ref),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Créer l’habitude'),
              ),
            if (ref.custom)
              TextButton.icon(
                onPressed: () async {
                  await _pnnsDeleteCustom(ref);
                  refresh();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Supprimer'),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _pnnsDeleteCustom(_PnnsRef ref) async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: navigationContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce repère ?'),
        content: Text('« ${ref.label} » et ses compteurs seront effacés. Les aliments rattachés redeviennent automatiques.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _pnnsCustom.removeWhere((c) => c['id'] == ref.id);
      _pnnsEnabled.remove(ref.id);
      _pnnsOverrides.remove(ref.id);
      _pnnsAttach.removeWhere((key, value) => value == ref.id);
      for (final counts in _pnnsCounters.values) {
        counts.remove(ref.id);
      }
      _pnnsCounters.removeWhere((key, value) => value.isEmpty);
    });
    _queueLocalStatePersist();
    _showFeedback('Repère supprimé.');
  }

  /// Ajoute un repère, ou modifie le titre, l'icône et la quantité d'un repère existant
  /// (un repère PNNS peut être rétabli ; un repère ajouté peut aussi changer de rythme, d'unité et de mots reconnus).
  Future<void> _openPnnsRefEditor({_PnnsRef? ref}) async {
    final navigationContext = _navigatorKey.currentContext;
    if (navigationContext == null || !mounted) return;
    final builtin = ref != null && !ref.custom;
    Map<String, Object?>? customMap;
    if (ref != null && ref.custom) {
      for (final c in _pnnsCustom) {
        if (c['id'] == ref.id) customMap = c;
      }
    }
    final titleController = TextEditingController(text: ref?.label ?? '');
    final unitController = TextEditingController(text: (customMap?['unit'] as String?) ?? 'portion');
    final keywordsController = TextEditingController(text: (customMap?['keywords'] as String?) ?? '');
    var icon = ref?.icon ?? 'pack://sprout';
    var cadence = ref?.cadence ?? 'jour';
    var isMax = ref?.isMax ?? false;
    var target = ref?.target(_pnnsProfile) ?? 1;

    final result = await showModalBottomSheet<String>(
      context: navigationContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ref == null ? 'Ajouter un repère' : 'Modifier le repère', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Titre'),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _chooseActivityIconValue(
                        name: titleController.text.trim().isEmpty ? 'Repère' : titleController.text.trim(),
                        category: 'Nutrition',
                        current: icon,
                      );
                      if (picked != null) setSheetState(() => icon = picked);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        _activityIconWidget(icon, size: 38),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Changer l’icône', style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong))),
                        Icon(Icons.chevron_right_rounded, color: _colors.textFaint),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Quantité', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                  Row(children: [
                    IconButton(
                      onPressed: target > 1 ? () => setSheetState(() => target--) : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    SizedBox(width: 40, child: Text('$target', textAlign: TextAlign.center, style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong))),
                    IconButton(
                      onPressed: target < 99 ? () => setSheetState(() => target++) : null,
                      icon: Icon(Icons.add_circle_rounded, color: _colors.accentIcon),
                    ),
                    Expanded(
                      child: Text(
                        '${isMax ? 'au plus' : 'au moins'} par ${cadence == 'jour' ? 'jour' : 'semaine'}',
                        style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                      ),
                    ),
                  ]),
                  if (builtin && ref.targetOverride == null)
                    Text('Repère PNNS actuel : $target. Tu peux le changer pour toi.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                  if (!builtin) ...[
                    const SizedBox(height: 10),
                    Text('Rythme', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                    const SizedBox(height: 4),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(value: 'jour', label: Text('Chaque jour')),
                        ButtonSegment<String>(value: 'semaine', label: Text('Chaque semaine')),
                      ],
                      selected: <String>{cadence},
                      onSelectionChanged: (s) => setSheetState(() => cadence = s.first),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(value: false, label: Text('Au moins')),
                        ButtonSegment<bool>(value: true, label: Text('Au plus')),
                      ],
                      selected: <bool>{isMax},
                      onSelectionChanged: (s) => setSheetState(() => isMax = s.first),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitController,
                      maxLength: 24,
                      decoration: const InputDecoration(labelText: 'Unité (portion, verre, fois…)'),
                    ),
                    TextField(
                      controller: keywordsController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Mots reconnus dans le nom des aliments',
                        helperText: 'Séparés par des virgules. Les aliments dont le nom les contient sont rattachés automatiquement.',
                        helperMaxLines: 3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'save'),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                  if (builtin && _pnnsOverrides.containsKey(ref.id))
                    Center(child: TextButton(onPressed: () => Navigator.pop(sheetContext, 'reset'), child: const Text('Rétablir le repère PNNS'))),
                ]),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || result == null) return;

    if (result == 'reset' && ref != null) {
      setState(() => _pnnsOverrides.remove(ref.id));
      _queueLocalStatePersist();
      _showFeedback('Repère PNNS rétabli.');
      return;
    }
    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showFeedback('Donne un titre au repère.');
      return;
    }
    if (builtin) {
      final original = _pnnsRefs.firstWhere((r) => r.id == ref.id);
      final override = <String, Object?>{};
      if (title != original.label) override['label'] = title;
      if (icon != original.icon) override['icon'] = icon;
      if (target != original.target(_pnnsProfile)) override['target'] = target;
      setState(() {
        if (override.isEmpty) {
          _pnnsOverrides.remove(ref.id);
        } else {
          _pnnsOverrides[ref.id] = override;
        }
      });
      _queueLocalStatePersist();
      _showFeedback('Repère modifié.');
      return;
    }
    if (ref == null && _pnnsCustom.length >= 20) {
      _showFeedback('20 repères ajoutés au maximum.');
      return;
    }
    final clean = _pnnsCleanCustom({
      'id': ref?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}',
      'label': title,
      'icon': icon,
      'cadence': cadence,
      'isMax': isMax,
      'target': target,
      'unit': unitController.text,
      'keywords': keywordsController.text,
    });
    if (clean == null) return;
    setState(() {
      final index = _pnnsCustom.indexWhere((c) => c['id'] == clean['id']);
      if (index >= 0) {
        _pnnsCustom[index] = clean;
      } else {
        _pnnsCustom.add(clean);
      }
    });
    _queueLocalStatePersist();
    _showFeedback(ref == null ? 'Repère ajouté : « $title ».' : 'Repère modifié.');
  }

  /// Rattachement de chaque aliment à un repère : automatique (reconnu par le nom), aucun repère, ou un repère précis.
  Future<void> _openPnnsFoods() async {
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
          final refs = _pnnsAllRefs();
          final auto = _pnnsAutoAssignments(refs);
          final pool = _pnnsPool();
          String labelOf(String id) => refs.where((r) => r.id == id).map((r) => r.label).firstWhere((_) => true, orElse: () => 'Repère supprimé');
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mes aliments', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900, color: _colors.textStrong)),
                  const SizedBox(height: 2),
                  Text(
                    'Rattache chaque aliment à un repère PNNS. « Automatique » le reconnaît par son nom.',
                    style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: pool.isEmpty
                        ? Center(child: Text('Aucune habitude Nutrition pour l’instant.', style: TextStyle(color: _colors.textMuted)))
                        : ListView.builder(
                            itemCount: pool.length,
                            itemBuilder: (context, index) {
                              final a = pool[index];
                              final explicit = _pnnsAttach[a.id];
                              final value = explicit == null ? 'auto' : (explicit.isEmpty ? 'none' : explicit);
                              final recognized = auto[a.id];
                              final validValue = value == 'auto' || value == 'none' || refs.any((r) => r.id == value) ? value : 'auto';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: _activityIconWidget(a.emoji, size: 28),
                                title: Text(a.name, style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong)),
                                subtitle: Text(
                                  explicit == null
                                      ? (recognized != null ? 'Reconnu : ${labelOf(recognized)}' : 'Aucun repère reconnu')
                                      : (explicit.isEmpty ? 'Hors bilan' : 'Rattaché à la main'),
                                  style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                                ),
                                trailing: SizedBox(
                                  width: 150,
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: validValue,
                                    underline: const SizedBox.shrink(),
                                    items: [
                                      const DropdownMenuItem<String>(value: 'auto', child: Text('Automatique')),
                                      const DropdownMenuItem<String>(value: 'none', child: Text('Aucun repère')),
                                      for (final r in refs) DropdownMenuItem<String>(value: r.id, child: Text(r.label, overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (choice) {
                                      if (choice == null) return;
                                      setState(() {
                                        if (choice == 'auto') {
                                          _pnnsAttach.remove(a.id);
                                        } else if (choice == 'none') {
                                          _pnnsAttach[a.id] = '';
                                        } else {
                                          _pnnsAttach[a.id] = choice;
                                        }
                                      });
                                      _queueLocalStatePersist();
                                      setSheetState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ]),
              ),
            ),
          );
        },
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
