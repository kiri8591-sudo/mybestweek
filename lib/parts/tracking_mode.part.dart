// V12.17.0 — Suivi par occurrence (au lieu du temps) et catégories personnalisées.
// Une activité « occurrence » (ex. visiter un site) se compte en fois, sans durée :
// l'historique et les statistiques l'affichent en « ×  », hors des totaux d'heures.

part of '../main.dart';

/// Registre des activités (mis à jour à chaque rendu) : permet aux écrans et aux
/// statistiques de savoir, depuis une ligne d'historique ou un moment, comment l'activité est suivie.
List<Activity> _activityRegistry = const <Activity>[];

Activity? _registeredActivity({String? id, String? title}) {
  if (id != null) {
    for (final a in _activityRegistry) {
      if (a.id == id) return a;
    }
    return null;
  }
  final t = title?.trim().toLowerCase();
  if (t == null || t.isEmpty) return null;
  for (final a in _activityRegistry) {
    if (a.name.trim().toLowerCase() == t) return a;
  }
  return null;
}

bool _logIsCount(ActivityLog log) => _registeredActivity(id: log.activityId, title: log.activityId == null ? log.title : null)?.countOnly == true;

bool _itemIsCount(PlanItem item) => item.activityId != null && _registeredActivity(id: item.activityId)?.countOnly == true;

/// « 1× » pour une occurrence, « 25 min » pour un temps.
String _logAmountLabel(ActivityLog log) => _logIsCount(log) ? '1×' : '${log.realisedMinutes} min';

/// « Occurrence » ou « 30 min » selon le mode de suivi de l'activité.
String _durationOrCount(Activity a) => a.countOnly ? 'Occurrence' : '${a.duration} min';

const List<int> _countMilestones = [5, 10, 25, 50, 100, 250, 500, 1000];

int? _nextCountMilestone(int count) {
  for (final m in _countMilestones) {
    if (m > count) return m;
  }
  return null;
}

/// Temps réalisé cumulé d'une liste de réalisations, hors activités suivies en occurrences.
int _timeMinutesOf(Iterable<ActivityLog> logs) =>
    logs.where((l) => !_logIsCount(l)).fold<int>(0, (s, l) => s + l.realisedMinutes);

// ---------------------------------------------------------------------------
// Catégories
// ---------------------------------------------------------------------------

const List<String> kBaseCategories = ['Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social'];

/// Catégories créées par l'utilisateur (sauvegardées avec les activités).
final List<String> _customCategories = <String>[];

/// Catégories de base + personnalisées + celles déjà utilisées par une activité.
List<String> _allCategoryNames() {
  final list = <String>[...kBaseCategories];
  for (final c in _customCategories) {
    if (!list.contains(c)) list.add(c);
  }
  for (final a in _activityRegistry) {
    final c = a.category.trim();
    if (c.isNotEmpty && !list.contains(c)) list.add(c);
  }
  return list;
}

/// Couleur de fond d'une catégorie personnalisée (palette stable selon son rang).
Color _customCategoryPastel(String category, bool dark) {
  const light = [Color(0xFFE6EEF2), Color(0xFFF0E4EA), Color(0xFFE9F0E0), Color(0xFFF2EBDD), Color(0xFFE8E6F2), Color(0xFFEBE3DC)];
  const night = [Color(0xFF2A3640), Color(0xFF3A2D34), Color(0xFF2F3A28), Color(0xFF3B3526), Color(0xFF302D40), Color(0xFF38302A)];
  final index = _allCategoryNames().indexOf(category);
  final i = index < 0 ? 0 : index % light.length;
  return dark ? night[i] : light[i];
}

extension _CategoriesPart on _MaBelleSemaineAppState {
  /// Demande le nom d'une nouvelle catégorie ; l'ajoute et la sauvegarde.
  Future<String?> askNewCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(builder: (context, setDialogState) {
          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setDialogState(() => error = 'Donne un nom à la catégorie.');
              return;
            }
            if (_allCategoryNames().any((c) => c.toLowerCase() == value.toLowerCase())) {
              setDialogState(() => error = 'Cette catégorie existe déjà.');
              return;
            }
            Navigator.pop(dialogContext, value);
          }

          return AlertDialog(
            title: const Text('Nouvelle catégorie'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 24,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Nom', hintText: 'ex. Jardin, Voyage, Famille', errorText: error),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
              FilledButton(onPressed: submit, child: const Text('Créer')),
            ],
          );
        });
      },
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return null;
    final created = name.trim();
    setState(() => _customCategories.add(created));
    _queueLocalStatePersist();
    _showFeedback('✓ Catégorie « $created » créée.');
    return created;
  }
}
