// V9.01 — Gestion des icônes système
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _SystemIconsPart on _MaBelleSemaineAppState {
  String _systemIconValue(String key, String fallback) => _uiIconValue(key, fallback);

  Widget _systemIconWidget(String key, {required String fallback, double size = 22}) {
    return _activityIconWidget(_uiIconValue(key, fallback), size: size);
  }

  Future<void> _editSystemIcon(String key, String label, String fallback) async {
    final picked = await _chooseActivityIconValue(
      name: label,
      category: 'Autre',
      current: _systemIconValue(key, fallback),
    );
    if (picked == null || !mounted) return;
    setState(() { _systemIconOverrides[key] = picked; _systemUiIconOverrides[key] = picked; });
    _queueLocalStatePersist();
    _showFeedback('Icône « $label » modifiée.');
  }

  Future<void> _resetSystemIcons() async {
    if (_systemIconOverrides.isEmpty) return;
    final reset = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser les icônes ?'),
        content: const Text('Toutes les icônes personnalisées de l’interface retrouveront leur apparence par défaut.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (reset != true || !mounted) return;
    setState(() { _systemIconOverrides.clear(); _systemUiIconOverrides.clear(); });
    _queueLocalStatePersist();
    _showFeedback('Icônes de l’interface réinitialisées.');
  }

  Future<void> _openSystemMenu() async {
    final entries = <Map<String, String>>[
      {'key': 'navHome', 'label': 'Accueil', 'fallback': '🏡'},
      {'key': 'navWeek', 'label': 'Semaine', 'fallback': '🌿'},
      {'key': 'navActivities', 'label': 'Activités', 'fallback': '🧸'},
      {'key': 'periodMorning', 'label': 'En-tête Matin', 'fallback': '🌤️'},
      {'key': 'periodAfternoon', 'label': 'En-tête Après-midi', 'fallback': '🌿'},
      {'key': 'periodEvening', 'label': 'En-tête Soir', 'fallback': '🌙'},
      {'key': 'sport', 'label': 'Sport', 'fallback': '💪'},
      {'key': 'coach', 'label': 'Coach', 'fallback': '🧠'},
      {'key': 'add', 'label': 'Ajouter', 'fallback': '➕'},
      {'key': 'edit', 'label': 'Modifier', 'fallback': '✏️'},
      {'key': 'remove', 'label': 'Retirer', 'fallback': '➖'},
      {'key': 'delete', 'label': 'Supprimer', 'fallback': '🗑️'},
      {'key': 'confirm', 'label': 'Valider / fermer', 'fallback': '✅'},
      {'key': 'history', 'label': 'Historique / journal', 'fallback': '📖'},
      {'key': 'help', 'label': 'Aide / information', 'fallback': '💡'},
      {'key': 'photo', 'label': 'Photo / image', 'fallback': '🖼️'},
      {'key': 'emoji', 'label': 'Emoji', 'fallback': '😀'},
      {'key': 'manageIcons', 'label': 'Gérer les icônes', 'fallback': '🎨'},
      {'key': 'save', 'label': 'Sauvegarder', 'fallback': '💾'},
      {'key': 'backup', 'label': 'Sauvegarde', 'fallback': '☁️'},
      {'key': 'restore', 'label': 'Restaurer / importer', 'fallback': '↩️'},
      {'key': 'reset', 'label': 'Réinitialiser', 'fallback': '♻️'},
      {'key': 'filter', 'label': 'Filtrer', 'fallback': '🔎'},
      {'key': 'calendar', 'label': 'Calendrier / moment', 'fallback': '📅'},
      {'key': 'week', 'label': 'Vue 7 jours', 'fallback': '🗓️'},
      {'key': 'duration', 'label': 'Durée / temps', 'fallback': '⏱️'},
      {'key': 'move', 'label': 'Déplacer', 'fallback': '↕️'},
      {'key': 'repeat', 'label': 'Répéter', 'fallback': '🔁'},
      {'key': 'durationMinus', 'label': 'Diminuer une durée', 'fallback': '➖'},
      {'key': 'durationPlus', 'label': 'Augmenter une durée', 'fallback': '➕'},
      {'key': 'close', 'label': 'Fermer', 'fallback': '✕'},
      {'key': 'apply', 'label': 'Appliquer', 'fallback': '⚡'},
      {'key': 'settings', 'label': 'Réglages', 'fallback': '⚙️'},
      {'key': 'identity', 'label': 'Identité', 'fallback': '👤'},
      {'key': 'location', 'label': 'Lieu / météo', 'fallback': '📍'},
      {'key': 'refresh', 'label': 'Actualiser', 'fallback': '🔄'},
      {'key': 'insights', 'label': 'Statistiques', 'fallback': '📊'},
      {'key': 'system', 'label': 'Système', 'fallback': '⚙️'},
    ];
    await showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF5),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _systemIconWidget('system', fallback: '⚙️', size: 24),
                const SizedBox(width: 9),
                const Expanded(child: Text('Système · personnalisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF405049)))),
              ]),
              const SizedBox(height: 5),
              const Text('Personnalise les icônes de navigation, de rubriques, d’actions et des principaux menus. Les contrôles purement sémantiques (cases cochées, flèches de défilement) restent volontairement fixes.', style: TextStyle(fontSize: 11.5, color: Color(0xFF747B75), height: 1.25)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(color: const Color(0xFFF2F6F3), borderRadius: BorderRadius.circular(12)),
                child: const Text('Signature commune : icônes d’action 18 px · icônes de détail 16–18 px · icônes d’en-tête 20–22 px. Les coches, flèches et indicateurs d’état restent sémantiques.', style: TextStyle(fontSize: 10.5, color: Color(0xFF6E7872), height: 1.25)),
              ),
              const SizedBox(height: 9),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    final key = entry['key']!;
                    final label = entry['label']!;
                    final fallback = entry['fallback']!;
                    return Material(
                      color: const Color(0xFFF7F4EE),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                        leading: Container(
                          width: 39,
                          height: 39,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: _systemIconWidget(key, fallback: fallback, size: 23),
                        ),
                        title: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF47534E))),
                        subtitle: Text(_systemIconOverrides.containsKey(key) ? 'Personnalisée' : 'Par défaut', style: const TextStyle(fontSize: 10.5, color: Color(0xFF858B86))),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF899398)),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _editSystemIcon(key, label, fallback);
                          if (mounted) {
                            await _openSystemMenu();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextButton.icon(onPressed: _resetSystemIcons, icon: _systemIconWidget('remove', fallback: '➖', size: 18), label: const Text('Réinitialiser les icônes'))),
                TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Fermer')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

}
