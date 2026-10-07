// V12.10.0 — Familles d'activités Sport : évite de cumuler le même jour deux activités
// de même nature (deux séances de renforcement, deux pratiques de mouvement doux…).
// Distinct du groupe de rotation (sportGroup), qui sert à partager une fréquence entre variantes.

part of '../main.dart';

const List<String> kSportFamilies = [
  'Renforcement',
  'Cardio',
  'Mouvement doux',
  'Souplesse',
  'Calme',
  'Périnée',
  'Stimulation',
];

/// Familles courtes et discrètes : peuvent se combiner avec n'importe quelle autre.
const Set<String> kSportFamiliesCombinable = {'Calme', 'Périnée', 'Stimulation'};

/// Valeur enregistrée quand l'utilisateur choisit explicitement « Aucune ».
const String kSportFamilyNone = 'none';

/// Famille déduite du nom (null si aucun mot-clé ne correspond : aucune contrainte).
String? _guessSportFamily(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['tai chi', 'taichi', 'tai-chi', 'qi gong', 'qigong', 'yang', 'tibétain', 'tibetain', 'minutes chi'])) return 'Mouvement doux';
  if (has(['yoga', 'stretch', 'étirement', 'etirement', 'souplesse'])) return 'Souplesse';
  if (has(['médit', 'medit', 'cohérence', 'coherence', 'respir', 'relax'])) return 'Calme';
  if (has(['kegel', 'périnée', 'perinee'])) return 'Périnée';
  if (has(['bluetens', 'électrostim', 'electrostim'])) return 'Stimulation';
  if (has(['vélo', 'velo', 'bike', 'marche', 'course', 'running', 'jogging', 'nordique', 'rando', 'natation', 'elliptique', 'rameur'])) return 'Cardio';
  if (has(['gym', 'pompe', 'abdo', 'muscu', 'betterme', 'fit on', 'fiton', 'foodvisor', 'renfo', 'pilates', 'gainage', 'haltère', 'haltere'])) return 'Renforcement';
  return null;
}

/// Famille effective d'une activité : choix explicite, sinon déduction depuis le nom.
String? _sportFamilyOf(Activity activity) {
  final stored = activity.sportFamily;
  if (stored == kSportFamilyNone) return null;
  if (stored != null && stored.isNotEmpty) return stored;
  return _guessSportFamily(activity.name);
}

bool _isCombinableFamily(String? family) => family == null || kSportFamiliesCombinable.contains(family);

/// Vrai si [activity] ne peut pas rejoindre [chosen] : une autre activité de la même
/// famille (non combinable) y figure déjà. Les répétitions de la même activité,
/// demandées explicitement (plusieurs fois par jour), restent autorisées.
bool _sportFamilyClash(Activity activity, Iterable<Activity> chosen) {
  final family = _sportFamilyOf(activity);
  if (family == null || _isCombinableFamily(family)) return false;
  return chosen.any((other) => other.id != activity.id && _sportFamilyOf(other) == family);
}

/// Noms des activités déjà prévues ce jour-là dans la même famille que [selected].
List<String> _sameFamilyNames(Activity selected, Iterable<PlanItem> items, List<Activity> all) {
  final family = _sportFamilyOf(selected);
  if (family == null || _isCombinableFamily(family)) return const [];
  final names = <String>[];
  for (final item in items) {
    final id = item.activityId;
    if (id == null || id == selected.id) continue;
    for (final a in all) {
      if (a.id == id && _sportFamilyOf(a) == family && !names.contains(a.name)) names.add(a.name);
    }
  }
  return names;
}

/// Indication affichée dans les listes : « Renforcement · déjà prévu : X · ».
String _familyHint(Activity activity, Iterable<PlanItem> items, List<Activity> all) {
  final family = _sportFamilyOf(activity);
  if (family == null) return '';
  final same = _sameFamilyNames(activity, items, all);
  return same.isEmpty ? '$family · ' : '$family · déjà prévu : ${same.join(', ')} · ';
}
