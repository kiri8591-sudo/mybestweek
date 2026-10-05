// V12.4.2 — Pack d'icônes MyBestWeek (52 illustrations PNG dans assets/icons/pack/).
// Une icône du pack est stockée comme valeur texte « pack://<id> », exactement comme un emoji ou
// « customicon://… » : aucune modification de la sauvegarde, de l'export ou de l'import.
// Régénération : python3 tools/build_icon_pack.py

part of '../main.dart';

class _PackIcon {
  const _PackIcon(this.id, this.label, this.keywords);
  final String id;
  final String label;
  final String keywords;
  String get value => 'pack://$id';
}

const List<_PackIcon> _packIcons = [
  _PackIcon('taichi', 'Tai Chi', 'tai chi taichi qi gong qigong souplesse equilibre arts martiaux'),
  _PackIcon('walk', 'Marche', 'marche promenade balade randonnee walk pas'),
  _PackIcon('run', 'Course', 'course running jogging footing courir'),
  _PackIcon('yoga', 'Yoga', 'yoga meditation relaxation lotus zen detente respiration pilates'),
  _PackIcon('stretch', 'Étirements', 'etirement stretching gym gymnastique souplesse echauffement mouvement'),
  _PackIcon('bike', 'Vélo', 'velo bicyclette cyclisme bike'),
  _PackIcon('swim', 'Natation', 'natation piscine nager swim eau aquagym'),
  _PackIcon('dumbbell', 'Renforcement', 'muscu renforcement musculation haltere force fitness poids'),
  _PackIcon('piano', 'Piano', 'piano clavier musique touches gamme'),
  _PackIcon('book', 'Lecture', 'lecture livre lire roman bibliotheque etude'),
  _PackIcon('basket', 'Marché', 'marche panier courses legumes fruits approvisionnement sarlat'),
  _PackIcon('coffee', 'Pause café', 'cafe the pause boisson tasse petit dejeuner gouter'),
  _PackIcon('toast', 'Apéro entre amis', 'ami amis apero convivial soiree moment social sortie fete trinquer'),
  _PackIcon('music', 'Musique', 'musique note chant ecoute melodie'),
  _PackIcon('sun', 'Soleil', 'soleil beau temps ete lumiere matin ete chaleur'),
  _PackIcon('moon', 'Lune', 'lune nuit soir coucher dormir'),
  _PackIcon('heart', 'Cœur', 'coeur amour famille affection ami bonheur'),
  _PackIcon('house', 'Maison', 'maison domicile bricolage menage interieur rangement habitat'),
  _PackIcon('flower', 'Fleur', 'fleur jardin printemps bouquet jardinage floral'),
  _PackIcon('tree', 'Arbre', 'arbre foret bois nature promenade bois jardin'),
  _PackIcon('dog', 'Chien', 'chien promenade animal compagnon toutou'),
  _PackIcon('paw', 'Patte', 'patte animal chien chat empreinte'),
  _PackIcon('camera', 'Photo', 'photo appareil photographie image souvenir cliche'),
  _PackIcon('cooking', 'Cuisine', 'cuisine cuisiner recette repas chef gateau plat'),
  _PackIcon('film', 'Cinéma', 'film cinema video serie spectacle soiree tele'),
  _PackIcon('mountain', 'Randonnée', 'randonnee montagne sentier rando paysage nature sortie'),
  _PackIcon('calendar', 'Calendrier', 'calendrier agenda date rendez-vous planning semaine jour'),
  _PackIcon('star', 'Étoile', 'etoile priorite favori important reussite'),
  _PackIcon('target', 'Objectif', 'objectif cible but defi challenge mission'),
  _PackIcon('trophy', 'Trophée', 'trophee coupe victoire record medaille reussite palmares'),
  _PackIcon('flame', 'Flamme', 'flamme feu serie streak motivation energie'),
  _PackIcon('timer', 'Minuteur', 'minuteur chrono temps duree horloge minutes'),
  _PackIcon('check', 'Validé', 'valide fait termine ok check reussi realise'),
  _PackIcon('bulb', 'Idée', 'idee astuce conseil coach lumiere conseil'),
  _PackIcon('gift', 'Cadeau', 'cadeau anniversaire surprise fete present'),
  _PackIcon('cake', 'Gourmandise', 'gateau dessert gourmandise cupcake anniversaire patisserie sucre'),
  _PackIcon('watering', 'Arrosage', 'arrosage jardin arroser plantes jardinage potager'),
  _PackIcon('sprout', 'Pousse', 'pousse plante semis potager planter jardin croissance'),
  _PackIcon('bear', 'Nounours', 'nounours ours mascotte peluche doudou coach'),
  _PackIcon('sleep', 'Sieste', 'sieste repos dormir sommeil detente pause lit'),
  _PackIcon('weather', 'Météo', 'meteo temps nuage ciel pluie soleil'),
  _PackIcon('mail', 'Message', 'message lettre courrier mail contact appel nouvelles famille'),
  _PackIcon('palette', 'Peinture', 'peinture dessin art creation couleurs atelier aquarelle loisir creatif'),
  _PackIcon('yarn', 'Tricot', 'tricot laine couture aiguilles loisir creatif ouvrage broderie'),
  _PackIcon('headphones', 'Écoute', 'ecoute casque musique podcast radio audio'),
  _PackIcon('suitcase', 'Voyage', 'voyage valise vacances week-end sejour escapade'),
  _PackIcon('restaurant', 'Repas', 'repas restaurant diner dejeuner manger table cuisine sortie'),
  _PackIcon('broom', 'Ménage', 'menage balai nettoyage entretien rangement propre'),
  _PackIcon('notebook', 'Journal', 'journal carnet notes ecrire bilan historique cahier'),
  _PackIcon('pin', 'Lieu', 'lieu endroit adresse localisation carte sortie position'),
  _PackIcon('leaf', 'Feuille', 'feuille nature ecologie bien-etre plante vert'),
  _PackIcon('smile', 'Bonne humeur', 'humeur ressenti sourire content bien emotion plaisir'),
];

bool _isPackIconValue(String value) => value.startsWith('pack://');

String _foldAccents(String input) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString();
}

/// Icônes du pack, les plus pertinentes d'abord d'après le nom (et la catégorie) de l'activité.
List<String> _packIconValuesFor(String name, String category) {
  final words = _foldAccents('$name $category')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length >= 3)
      .toSet();
  final scored = <MapEntry<int, _PackIcon>>[];
  for (var i = 0; i < _packIcons.length; i++) {
    final icon = _packIcons[i];
    final haystack = ' ${_foldAccents(icon.label)} ${icon.keywords} ';
    var score = 0;
    for (final w in words) {
      if (haystack.contains(' $w')) {
        score += 2;
      } else if (haystack.contains(w)) {
        score += 1;
      }
    }
    scored.add(MapEntry(score * 1000 - i, icon));
  }
  scored.sort((a, b) => b.key.compareTo(a.key));
  return [for (final e in scored) e.value.value];
}

/// Rubriques de l'interface auxquelles « Appliquer le pack » associe une icône du pack.
const Map<String, String> _packSystemMap = {
  'navHome': 'house', 'navWeek': 'calendar', 'navActivities': 'bear', 'navPriorities': 'star',
  'navObjectives': 'target', 'priority': 'star', 'challenge': 'flame', 'objective': 'target',
  'objectiveDetail': 'target', 'objectiveSave': 'check', 'objectiveState': 'trophy', 'streak': 'flame',
  'history': 'notebook', 'histEmpty': 'notebook', 'histStable': 'check',
  'periodMorning': 'sun', 'periodAfternoon': 'weather', 'periodEvening': 'moon',
  'sport': 'dumbbell', 'sportWeek': 'calendar', 'sportTimer': 'timer', 'sportActive': 'run', 'sportRate': 'check',
  'calendar': 'calendar', 'week': 'calendar', 'duration': 'timer', 'location': 'pin',
  'help': 'bulb', 'coach': 'bulb', 'photo': 'camera', 'confirm': 'check', 'missionDone': 'check',
  'backupOk': 'check', 'reviewMoments': 'check', 'reviewRegularity': 'calendar', 'reviewPlanned': 'calendar',
  'reviewActiveDays': 'calendar', 'reviewTime': 'timer', 'reviewValidated': 'timer',
  'reviewPiano': 'piano', 'reviewMood': 'smile',
};

extension _IconPackPart on _MaBelleSemaineAppState {
  Future<void> _applyIconPackToSystem() async {
    final ok = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Appliquer le pack MyBestWeek ?'),
        content: Text('${_packSystemMap.length} icônes de l’interface (navigation, rubriques, bilan, sport) passent au pack. '
            'Tu pourras revenir aux icônes d’origine avec « Réinitialiser les icônes ».'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Appliquer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _packSystemMap.forEach((key, id) {
        _systemIconOverrides[key] = 'pack://$id';
        _systemUiIconOverrides[key] = 'pack://$id';
      });
    });
    _queueLocalStatePersist();
    _showFeedback('Pack d’icônes appliqué.');
  }
}
