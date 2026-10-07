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
      {'key': 'navPriorities', 'label': 'Priorités', 'fallback': '⭐'},
      {'key': 'priority', 'label': 'Priorité / étoile', 'fallback': '⭐'},
      {'key': 'navObjectives', 'label': 'Objectifs', 'fallback': '🎯'},
      {'key': 'search', 'label': 'Recherche', 'fallback': '🔎'},
      {'key': 'challenge', 'label': 'Challenge du jour', 'fallback': '🎯'},
      {'key': 'objective', 'label': 'Objectif / réalisation', 'fallback': '🎯'},
      {'key': 'objectiveDetail', 'label': 'Détail d’un objectif', 'fallback': '🎯'},
      {'key': 'objectiveSave', 'label': 'Enregistrer un objectif', 'fallback': '✅'},
      {'key': 'objectiveDelete', 'label': 'Supprimer un objectif', 'fallback': '🗑️'},
      {'key': 'objectiveState', 'label': 'État d’un objectif', 'fallback': '🏅'},
      {'key': 'streak', 'label': 'Streak Sport', 'fallback': '🔥'},
      {'key': 'history', 'label': 'Historique / journal', 'fallback': '📖'},
            {'key': 'reviewBack', 'label': 'Retour du bilan', 'fallback': '←'},
      {'key': 'undo', 'label': 'Annuler la dernière action', 'fallback': '↩️'},
      {'key': 'histTrend', 'label': 'Historique · à faire évoluer', 'fallback': '📉'},
      {'key': 'histStable', 'label': 'Historique · rythme installé', 'fallback': '✅'},
      {'key': 'histSortUp', 'label': 'Historique · tri croissant', 'fallback': '↑'},
      {'key': 'histSortDown', 'label': 'Historique · tri décroissant', 'fallback': '↓'},
      {'key': 'histEmpty', 'label': 'Historique · aucun élément', 'fallback': '📖'},
      {'key': 'periodMorning', 'label': 'En-tête Matin', 'fallback': '🌤️'},

      {'key': 'periodAfternoon', 'label': 'En-tête Après-midi', 'fallback': '🌿'},
      {'key': 'periodEvening', 'label': 'En-tête Soir', 'fallback': '🌙'},
      {'key': 'sport', 'label': 'Sport', 'fallback': '💪'},
      {'key': 'sportWeek', 'label': 'Semaine Sport', 'fallback': '🗓️'},
      {'key': 'sportTimer', 'label': 'Sport · minuteur', 'fallback': '⏱️'},
      {'key': 'sportActive', 'label': 'Sport · activités actives', 'fallback': '🏃'},
      {'key': 'sportMinutes', 'label': 'Sport · minutes', 'fallback': '⏳'},
      {'key': 'sportRate', 'label': 'Sport · taux de réalisation', 'fallback': '✅'},
      {'key': 'sportMissing', 'label': 'Sport · non pris en compte', 'fallback': '⚠️'},
      {'key': 'sportFilter', 'label': 'Sport · filtre', 'fallback': '🔎'},
      {'key': 'sportBack', 'label': 'Sport · jour précédent', 'fallback': '‹'},
      {'key': 'sportNext', 'label': 'Sport · jour suivant', 'fallback': '›'},
      {'key': 'sportReactivate', 'label': 'Sport · réactiver', 'fallback': '🔄'},
      {'key': 'sportWarning', 'label': 'Sport · avertissement', 'fallback': '⚠️'},
      {'key': 'frozen', 'label': 'Activité gelée', 'fallback': '🧊'},
      {'key': 'backupDevice', 'label': 'Sauvegarde · appareil', 'fallback': '📱'},
      {'key': 'backupCloud', 'label': 'Sauvegarde · iCloud', 'fallback': '☁️'},
      {'key': 'backupFile', 'label': 'Sauvegarde · fichier', 'fallback': '🗃️'},
      {'key': 'backupShield', 'label': 'Sauvegarde · filet de sécurité', 'fallback': '🛡️'},
      {'key': 'backupDownload', 'label': 'Sauvegarde · exporter', 'fallback': '⬇️'},
      {'key': 'backupUpload', 'label': 'Sauvegarde · envoyer', 'fallback': '☁️'},
      {'key': 'backupFolder', 'label': 'Sauvegarde · choisir un fichier', 'fallback': '📁'},
      {'key': 'backupReset', 'label': 'Sauvegarde · réinitialiser', 'fallback': '♻️'},
      {'key': 'backupDue', 'label': 'Sauvegarde · à faire', 'fallback': '🕒'},
      {'key': 'backupOk', 'label': 'Sauvegarde · à jour', 'fallback': '✅'},
      {'key': 'reviewMoments', 'label': 'Bilan · moments réalisés', 'fallback': '✅'},
      {'key': 'reviewRegularity', 'label': 'Bilan · régularité', 'fallback': '📅'},
      {'key': 'reviewPlanned', 'label': 'Bilan · prévu', 'fallback': '🗓️'},
      {'key': 'reviewRealized', 'label': 'Bilan · réalisé', 'fallback': '▶️'},
      {'key': 'reviewRemaining', 'label': 'Bilan · à faire', 'fallback': '⌛'},
      {'key': 'reviewMoved', 'label': 'Bilan · déplacées', 'fallback': '↔️'},
      {'key': 'reviewValidated', 'label': 'Bilan · temps validé', 'fallback': '⏱️'},
      {'key': 'reviewUnexpected', 'label': 'Bilan · imprévus', 'fallback': '✨'},
      {'key': 'reviewActiveDays', 'label': 'Bilan · jours actifs', 'fallback': '📅'},
      {'key': 'reviewTime', 'label': 'Bilan · temps vécu', 'fallback': '⏱️'},
      {'key': 'reviewPiano', 'label': 'Bilan · piano', 'fallback': '🎹'},
      {'key': 'reviewDifficult', 'label': 'Bilan · moments difficiles', 'fallback': '🔋'},
      {'key': 'reviewMood', 'label': 'Bilan · ressenti', 'fallback': '🙂'},
      {'key': 'nextWeekDirections', 'label': 'Diriger le Coach', 'fallback': '🎛️'},
      {'key': 'dragDown', 'label': 'Déposer ici', 'fallback': '↓'},
      {'key': 'expandMore', 'label': 'Développer', 'fallback': '⌄'},
      {'key': 'planOpen', 'label': 'Ouvrir le détail d’un moment', 'fallback': '›'},
      {'key': 'missionDone', 'label': 'Mission terminée', 'fallback': '✅'},

      {'key': 'coach', 'label': 'Coach', 'fallback': '🧠'},
      {'key': 'add', 'label': 'Ajouter', 'fallback': '➕'},
      {'key': 'edit', 'label': 'Modifier', 'fallback': '✏️'},
      {'key': 'remove', 'label': 'Retirer', 'fallback': '➖'},
      {'key': 'delete', 'label': 'Supprimer', 'fallback': '🗑️'},
      {'key': 'confirm', 'label': 'Valider / fermer', 'fallback': '✅'},
      {'key': 'help', 'label': 'Aide / information', 'fallback': '💡'},
      {'key': 'photo', 'label': 'Photo / image', 'fallback': '🖼️'},
      {'key': 'emoji', 'label': 'Emoji', 'fallback': '😀'},
      {'key': 'manageIcons', 'label': 'Gérer les icônes', 'fallback': '🎨'},
      {'key': 'save', 'label': 'Sauvegarder', 'fallback': '💾'},
      {'key': 'restore', 'label': 'Restaurer / importer', 'fallback': '↩️'},
      {'key': 'calendar', 'label': 'Calendrier / moment', 'fallback': '📅'},
      {'key': 'week', 'label': 'Vue 7 jours', 'fallback': '🗓️'},
      {'key': 'duration', 'label': 'Durée / temps', 'fallback': '⏱️'},
      {'key': 'move', 'label': 'Déplacer', 'fallback': '↕️'},
      {'key': 'repeat', 'label': 'Répéter', 'fallback': '🔁'},
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
      backgroundColor: _colors.card,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _systemIconWidget('system', fallback: '⚙️', size: 24),
                const SizedBox(width: 9),
                Expanded(child: Text('Système · personnalisation', style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _colors.textStrong))),
              ]),
              const SizedBox(height: 5),
              Text('Personnalise les icônes de navigation, de rubriques, d’actions et des principaux menus. Les icônes d’action, de rubrique, de statistique et de détail sont personnalisables. Les indicateurs d’état purs (case cochée, radio, progression) restent fixes.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.25)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(color: _colors.tintSoft, borderRadius: BorderRadius.circular(AppRadius.m)),
                child: Text('Signature commune : icônes d’action 18 px · icônes de détail 16–18 px · icônes d’en-tête 20–22 px. Les indicateurs d’état purs restent sémantiques.', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted, height: 1.25)),
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
                      color: _colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                        leading: Container(
                          width: 39,
                          height: 39,
                          decoration: BoxDecoration(
                            color: _colors.card,
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          alignment: Alignment.center,
                          child: _systemIconWidget(key, fallback: fallback, size: 23),
                        ),
                        title: Text(label, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                        subtitle: Text(_systemIconOverrides.containsKey(key) ? 'Personnalisée' : 'Par défaut', style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                        trailing: Icon(Icons.chevron_right_rounded, color: _colors.textMuted),
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
                Expanded(child: FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _applyIconPackToSystem();
                    if (mounted) await _openSystemMenu();
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Appliquer le pack'),
                )),
              ]),
              const SizedBox(height: 4),
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
