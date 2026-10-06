// V12.4.2 — Pack d'icônes MyBestWeek (52 illustrations PNG dans assets/icons/pack/).
// Une icône du pack est stockée comme valeur texte « pack://<id> », exactement comme un emoji ou
// « customicon://… » : aucune modification de la sauvegarde, de l'export ou de l'import.
// Régénération : python3 tools/make_pack.py

part of '../main.dart';

class _PackIcon {
  const _PackIcon(this.id, this.label, this.keywords);
  final String id;
  final String label;
  final String keywords;
  String get value => 'pack://$id';
}

const List<_PackIcon> _packIcons = [
  _PackIcon('taichi', 'Tai Chi', 'tai chi taichi qi gong qigong souplesse equilibre arts martiaux sport'),
  _PackIcon('walk', 'Marche', 'marche promenade balade randonnee walk pas sport'),
  _PackIcon('run', 'Course', 'course running jogging footing courir sport'),
  _PackIcon('yoga', 'Yoga', 'yoga meditation relaxation lotus zen detente respiration pilates sport'),
  _PackIcon('stretch', 'Étirements', 'etirement stretching gym gymnastique souplesse echauffement mouvement sport'),
  _PackIcon('bike', 'Vélo', 'velo bicyclette cyclisme bike sport'),
  _PackIcon('swim', 'Natation', 'natation piscine nager swim eau aquagym sport'),
  _PackIcon('dumbbell', 'Renforcement', 'muscu renforcement musculation haltere force fitness poids sport'),
  _PackIcon('piano', 'Piano', 'piano clavier musique touches gamme loisirs   culture'),
  _PackIcon('book', 'Lecture', 'lecture livre lire roman bibliotheque etude loisirs   culture'),
  _PackIcon('basket', 'Marché', 'marche panier courses legumes fruits approvisionnement sarlat repas   marche'),
  _PackIcon('coffee', 'Pause café', 'cafe the pause boisson tasse petit dejeuner gouter repas   marche'),
  _PackIcon('toast', 'Apéro entre amis', 'ami amis apero convivial soiree moment social sortie fete trinquer social   famille'),
  _PackIcon('music', 'Musique', 'musique note chant ecoute melodie loisirs   culture'),
  _PackIcon('sun', 'Soleil', 'soleil beau temps ete lumiere matin ete chaleur temps   meteo'),
  _PackIcon('moon', 'Lune', 'lune nuit soir coucher dormir temps   meteo'),
  _PackIcon('heart', 'Cœur', 'coeur amour famille affection ami bonheur social   famille'),
  _PackIcon('house', 'Maison', 'maison domicile bricolage menage interieur rangement habitat maison   jardin'),
  _PackIcon('flower', 'Fleur', 'fleur jardin printemps bouquet jardinage floral maison   jardin'),
  _PackIcon('tree', 'Arbre', 'arbre foret bois nature promenade bois jardin nature   animaux'),
  _PackIcon('dog', 'Chien', 'chien promenade animal compagnon toutou nature   animaux'),
  _PackIcon('paw', 'Patte', 'patte animal chien chat empreinte nature   animaux'),
  _PackIcon('camera', 'Photo', 'photo appareil photographie image souvenir cliche loisirs   culture'),
  _PackIcon('cooking', 'Cuisine', 'cuisine cuisiner recette repas chef gateau plat repas   marche'),
  _PackIcon('film', 'Cinéma', 'film cinema video serie spectacle soiree tele loisirs   culture'),
  _PackIcon('mountain', 'Randonnée', 'randonnee montagne sentier rando paysage nature sortie voyage   sorties'),
  _PackIcon('calendar', 'Calendrier', 'calendrier agenda date rendez-vous planning semaine jour symboles'),
  _PackIcon('star', 'Étoile', 'etoile priorite favori important reussite symboles'),
  _PackIcon('target', 'Objectif', 'objectif cible but defi challenge mission symboles'),
  _PackIcon('trophy', 'Trophée', 'trophee coupe victoire record medaille reussite palmares symboles'),
  _PackIcon('flame', 'Flamme', 'flamme feu serie streak motivation energie symboles'),
  _PackIcon('timer', 'Minuteur', 'minuteur chrono temps duree horloge minutes symboles'),
  _PackIcon('check', 'Validé', 'valide fait termine ok check reussi realise symboles'),
  _PackIcon('bulb', 'Idée', 'idee astuce conseil coach lumiere conseil symboles'),
  _PackIcon('gift', 'Cadeau', 'cadeau anniversaire surprise fete present social   famille'),
  _PackIcon('cake', 'Gourmandise', 'gateau dessert gourmandise cupcake anniversaire patisserie sucre repas   marche'),
  _PackIcon('watering', 'Arrosage', 'arrosage jardin arroser plantes jardinage potager maison   jardin'),
  _PackIcon('sprout', 'Pousse', 'pousse plante semis potager planter jardin croissance maison   jardin'),
  _PackIcon('bear', 'Nounours', 'nounours ours mascotte peluche doudou coach social   famille'),
  _PackIcon('sleep', 'Sieste', 'sieste repos dormir sommeil detente pause lit bien etre'),
  _PackIcon('weather', 'Météo', 'meteo temps nuage ciel pluie soleil temps   meteo'),
  _PackIcon('mail', 'Message', 'message lettre courrier mail contact appel nouvelles famille social   famille'),
  _PackIcon('palette', 'Peinture', 'peinture dessin art creation couleurs atelier aquarelle loisir creatif loisirs   culture'),
  _PackIcon('yarn', 'Tricot', 'tricot laine couture aiguilles loisir creatif ouvrage broderie loisirs   culture'),
  _PackIcon('headphones', 'Écoute', 'ecoute casque musique podcast radio audio loisirs   culture'),
  _PackIcon('suitcase', 'Voyage', 'voyage valise vacances week-end sejour escapade voyage   sorties'),
  _PackIcon('restaurant', 'Repas', 'repas restaurant diner dejeuner manger table cuisine sortie repas   marche'),
  _PackIcon('broom', 'Ménage', 'menage balai nettoyage entretien rangement propre maison   jardin'),
  _PackIcon('notebook', 'Journal', 'journal carnet notes ecrire bilan historique cahier loisirs   culture'),
  _PackIcon('pin', 'Lieu', 'lieu endroit adresse localisation carte sortie position voyage   sorties'),
  _PackIcon('leaf', 'Feuille', 'feuille nature ecologie bien-etre plante vert bien etre'),
  _PackIcon('smile', 'Bonne humeur', 'humeur ressenti sourire content bien emotion plaisir bien etre'),
  _PackIcon('petanque', 'Pétanque', 'petanque boules cochonnet jeu de boules apero sortie sport'),
  _PackIcon('tennis', 'Tennis', 'tennis raquette balle sport jeu sport'),
  _PackIcon('golf', 'Golf', 'golf drapeau trou balle parcours green sport'),
  _PackIcon('dance', 'Danse', 'danse dancer bal musique soiree rythme sport'),
  _PackIcon('football', 'Football', 'football foot ballon sport match sport'),
  _PackIcon('spa', 'Bain détente', 'bain baignoire spa detente relaxation douche bulles bien etre'),
  _PackIcon('stones', 'Galets zen', 'galets pierres zen massage equilibre detente meditation bien etre'),
  _PackIcon('tea', 'Thé', 'the tisane infusion theiere boisson pause bien etre'),
  _PackIcon('candle', 'Bougie', 'bougie ambiance detente relaxation soiree lumiere bien etre'),
  _PackIcon('health', 'Santé', 'sante medecin rendez-vous docteur soin pharmacie consultation bien etre'),
  _PackIcon('water', 'Eau', 'eau hydratation boire goutte pluie verre bien etre'),
  _PackIcon('mower', 'Tondeuse', 'tondeuse pelouse gazon jardin tonte robot maison   jardin'),
  _PackIcon('hammer', 'Bricolage', 'bricolage marteau outil reparation travaux atelier maison   jardin'),
  _PackIcon('roller', 'Peinture murs', 'peinture rouleau murs travaux renovation decoration maison   jardin'),
  _PackIcon('firewood', 'Bois de chauffage', 'bois buches chauffage cheminee hiver stockage fendre maison   jardin'),
  _PackIcon('fireplace', 'Cheminée', 'cheminee feu foyer hiver soiree chaleur maison   jardin'),
  _PackIcon('laundry', 'Lessive', 'lessive linge machine laver menage buanderie maison   jardin'),
  _PackIcon('vacuum', 'Aspirateur robot', 'aspirateur robot menage nettoyage sol poussiere maison   jardin'),
  _PackIcon('rake', 'Râteau', 'rateau jardin feuilles automne ramasser nettoyer maison   jardin'),
  _PackIcon('wheelbarrow', 'Brouette', 'brouette jardin terre transport compost travaux maison   jardin'),
  _PackIcon('greenhouse', 'Serre', 'serre potager culture semis jardin tomates maison   jardin'),
  _PackIcon('deer', 'Cerf', 'cerf chevreuil biche faune foret animal sauvage nature   animaux'),
  _PackIcon('bird', 'Oiseau', 'oiseau rouge-gorge mesange faune jardin nid chant nature   animaux'),
  _PackIcon('owl', 'Hibou', 'hibou chouette nuit faune foret oiseau nature   animaux'),
  _PackIcon('squirrel', 'Écureuil', 'ecureuil faune foret noisette animal arbre nature   animaux'),
  _PackIcon('hedgehog', 'Hérisson', 'herisson faune jardin animal nuit automne nature   animaux'),
  _PackIcon('fox', 'Renard', 'renard faune foret animal sauvage roux nature   animaux'),
  _PackIcon('butterfly', 'Papillon', 'papillon insecte jardin printemps fleurs nature nature   animaux'),
  _PackIcon('bee', 'Abeille', 'abeille miel ruche pollen jardin insecte butinage nature   animaux'),
  _PackIcon('mushroom', 'Champignon', 'champignon cepe cueillette foret automne bois ceuillette nature   animaux'),
  _PackIcon('walnut', 'Noix', 'noix noyer perigord recolte automne fruit sec nature   animaux'),
  _PackIcon('sunflower', 'Tournesol', 'tournesol fleur ete jardin champ soleil nature   animaux'),
  _PackIcon('cat', 'Chat', 'chat animal compagnon felin maison nature   animaux'),
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
