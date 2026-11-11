// V12.17.0 — Suivi par occurrence (au lieu du temps) et catégories personnalisées.
// Une activité « occurrence » (ex. visiter un site) se compte en fois, sans durée :
// l'historique et les statistiques l'affichent en « ×  », hors des totaux d'heures.

part of '../main.dart';

/// Registre des activités (mis à jour à chaque rendu) : permet aux écrans et aux
/// statistiques de savoir, depuis une ligne d'historique ou un moment, comment l'activité est suivie.
List<Activity> _activityRegistry = const <Activity>[];
List<ActivityLog> _logRegistry = const <ActivityLog>[];

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
String _logAmountLabel(ActivityLog log) => log.reps != null
    ? (_logIsCount(log) ? '${log.reps} rép.' : '${log.realisedMinutes} min · ${log.reps} rép.')
    : (_logIsCount(log) ? '1×' : '${log.realisedMinutes} min');

/// « Occurrence » ou « 30 min » selon le mode de suivi de l'activité.
String _durationOrCount(Activity a) => a.countOnly
    ? (a.repsTarget != null ? 'Objectif ${a.repsTarget} rép.' : 'Occurrence')
    : (a.repsTarget != null ? '${a.duration} min · objectif ${a.repsTarget} rép.' : '${a.duration} min');

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

/// Vrai si l'activité n'existe plus dans la liste (supprimée) : son historique reste consultable.
bool _activityIsDeleted(Activity activity) => _registeredActivity(id: activity.id) == null;

// ---------------------------------------------------------------------------
// Suppression d'une activité
// ---------------------------------------------------------------------------

extension _ActivityDeletionPart on _MaBelleSemaineAppState {
  /// Explique les conséquences et demande quoi faire de l'historique.
  /// Retourne 'keep' (garder l'historique), 'all' (tout supprimer) ou null (annuler).
  Future<String?> confirmDeleteActivity(Activity activity) async {
    final mine = logs.where((l) => _logIsOfActivity(l, activity)).toList();
    final upcoming = plan.where((p) => p.activityId == activity.id && !p.done).length;
    final goals = _realizationGoals.where((g) => g.activityId == activity.id).length;
    final time = _timeMinutesOf(mine);
    final history = mine.isEmpty
        ? null
        : '${mine.length} réalisation${mine.length > 1 ? 's' : ''} dans l’historique${activity.countOnly || time == 0 ? '' : ' (${_minutesLabel(time)})'}';
    final consequences = <String>[
      if (upcoming > 0) '$upcoming moment${upcoming > 1 ? 's' : ''} à venir retiré${upcoming > 1 ? 's' : ''} du planning',
      if (goals > 0) '$goals objectif${goals > 1 ? 's' : ''} lié${goals > 1 ? 's' : ''} supprimé${goals > 1 ? 's' : ''}',
    ];
    return showDialog<String>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${activity.name} » ?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (history != null) ...[
            Text(history, style: TextStyle(fontWeight: FontWeight.w700, color: _colors.textStrong)),
            const SizedBox(height: 6),
            Text('« Garder l’historique » : les réalisations restent dans l’historique et les statistiques (activité marquée « supprimée »).', style: _hintStyle()),
            const SizedBox(height: 4),
            Text('« Tout supprimer » : elles sont aussi effacées.', style: _hintStyle()),
          ] else
            Text('Aucune réalisation enregistrée : rien à conserver.', style: _hintStyle()),
          if (consequences.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final line in consequences) Text('• $line', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          if (history != null) TextButton(onPressed: () => Navigator.pop(context, 'all'), style: TextButton.styleFrom(foregroundColor: _colors.danger), child: const Text('Tout supprimer')),
          FilledButton(onPressed: () => Navigator.pop(context, 'keep'), child: Text(history != null ? 'Garder l’historique' : 'Supprimer')),
        ],
      ),
    );
  }

  void performDeleteActivity(Activity activity, {required bool deleteHistory}) {
    _prepareUndoSnapshot();
    setState(() {
      activities.removeWhere((a) => a.id == activity.id);
      plan.removeWhere((p) => p.activityId == activity.id);
      _dailyPriorityActivityIds.remove(activity.id);
      _realizationGoals.removeWhere((g) => g.activityId == activity.id);
      if (deleteHistory) logs.removeWhere((l) => _logIsOfActivity(l, activity));
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback(deleteHistory
        ? '🗑️ « ${activity.name} » et son historique ont été supprimés.'
        : '🗑️ « ${activity.name} » supprimée. Son historique est conservé.');
  }
}

// ---------------------------------------------------------------------------
// Répétitions
// ---------------------------------------------------------------------------

/// Activité avec un suivi de répétitions (en plus du temps pour le Sport).
bool _isRepsActivity(Activity a) => a.repsTarget != null;

/// Suivi uniquement en répétitions (sans durée).
bool _isRepsOnly(Activity a) => a.countOnly && a.repsTarget != null;

bool _itemIsReps(PlanItem item) {
  final a = item.activityId == null ? null : _registeredActivity(id: item.activityId);
  return a != null && _isRepsActivity(a);
}

/// Dernière réalisation avec un nombre de répétitions.
ActivityLog? _lastRepsLog(Activity a) {
  ActivityLog? best;
  for (final l in _logRegistry) {
    if (l.reps == null || !_logIsOfActivity(l, a)) continue;
    if (best == null || l.date.isAfter(best.date)) best = l;
  }
  return best;
}

/// « Dernière : 42 rép. · Objectif : 100 rép. »
String _repsLine(Activity a) {
  final last = _lastRepsLog(a)?.reps;
  final target = a.repsTarget;
  return [
    if (last != null) 'Dernière : $last rép.',
    if (target != null) 'Objectif : $target rép.',
  ].join(' · ');
}

String _repsLineForItem(PlanItem item) {
  final a = item.activityId == null ? null : _registeredActivity(id: item.activityId);
  return a == null ? '' : _repsLine(a);
}

int _repsTotal(Iterable<ActivityLog> logs) => logs.fold<int>(0, (s, l) => s + (l.reps ?? 0));

/// Unité affichée pour une activité : heures, fois ou répétitions.
String _amountUnit(Activity a) => a.repsTarget != null && a.countOnly ? 'rép.' : (a.countOnly ? 'fois' : 'heures');

extension _HistoryRelinkPart on _MaBelleSemaineAppState {
  ActivityLog _logRelinked(ActivityLog log, Activity target) => ActivityLog(
        date: log.date,
        title: target.name,
        emoji: target.emoji,
        category: target.category,
        period: log.period,
        day: log.day,
        plannedMinutes: log.plannedMinutes,
        realisedMinutes: log.realisedMinutes,
        feeling: log.feeling,
        unplanned: log.unplanned,
        planItemId: log.planItemId,
        activityId: target.id,
        reps: log.reps,
      );

  void _relinkLogs(List<ActivityLog> orphans, Activity target) {
    _prepareUndoSnapshot();
    setState(() {
      for (final log in orphans) {
        final i = logs.indexOf(log);
        if (i >= 0) logs[i] = _logRelinked(log, target);
      }
    });
    _queueLocalStatePersist();
    _refreshGoalsAfterRealization();
    _showFeedback('✓ ${orphans.length} réalisation${orphans.length > 1 ? 's' : ''} reliée${orphans.length > 1 ? 's' : ''} à « ${target.name} ».');
  }

  /// À la création d'une activité : propose de relier l'historique orphelin de même nom.
  Future<void> _offerRelinkOrphanHistory(Activity created) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final name = created.name.trim().toLowerCase();
    final orphans = logs
        .where((l) => l.activityId != null && l.activityId != created.id && findActivity(l.activityId!) == null && l.title.trim().toLowerCase() == name)
        .toList();
    if (orphans.isEmpty) return;
    final time = _timeMinutesOf(orphans);
    final ok = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Relier l’historique ?'),
        content: Text(
          '${orphans.length} réalisation${orphans.length > 1 ? 's' : ''} passée${orphans.length > 1 ? 's' : ''} « ${created.name} »'
          '${time > 0 ? ' (${_minutesLabel(time)})' : ''} ne sont reliées à aucune activité (ancienne activité supprimée). Les relier à cette nouvelle activité ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Relier')),
        ],
      ),
    );
    if (ok == true && mounted) _relinkLogs(orphans, created);
  }

  /// Fiche d'une activité supprimée : relier son historique à une activité existante.
  Future<void> relinkDeletedActivity(Activity ghost) async {
    if (!mounted) return;
    final targets = activities.where((a) => !a.isSportProgram && !a.isDateRange).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (targets.isEmpty) {
      _showFeedback('Crée d’abord l’activité à laquelle relier cet historique.');
      return;
    }
    final picked = await showModalBottomSheet<Activity>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .72),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: _SheetHeader(
                  leading: _uiIcon('move', Icons.link_rounded, size: 24, color: _colors.accentIcon),
                  title: 'Relier à quelle activité ?',
                  subtitle: 'L’historique de « ${ghost.name} » sera rattaché à l’activité choisie.',
                ),
              ),
              for (final a in targets)
                _SheetPickRow(
                  leading: _activityIconWidget(a.emoji, size: 24),
                  title: a.name,
                  subtitle: '${a.category} · ${_durationOrCount(a)}',
                  onTap: () => Navigator.pop(sheetContext, a),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final orphans = logs.where((l) => _logIsOfActivity(l, ghost)).toList();
    if (orphans.isEmpty) return;
    _relinkLogs(orphans, picked);
  }

  /// Fiche d'une activité supprimée : la recréer avec le même identifiant (historique relié d'office).
  Future<void> recreateDeletedActivity(Activity ghost) async {
    if (!mounted) return;
    addOrEditActivity(prefill: ghost);
  }
}
