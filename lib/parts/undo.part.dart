// V9.25.3 — Annuler la dernière action de données.
// Une seule annulation, sans historique permanent ni modification du format
// de sauvegarde utilisateur.

part of '../main.dart';

extension _UndoPart on _MaBelleSemaineAppState {

  // Capture l'état réel en mémoire juste avant une mutation utilisateur.
  // Cela évite de dépendre de la dernière écriture localStorage, qui peut
  // être légèrement en retard sur l'état affiché.
  void _prepareUndoSnapshot() {
    if (_undoInProgress || !mounted || _isHydratingLocalState) return;
    try {
      final root = jsonDecode(_backupJson()) as Map<String, dynamic>;
      root['weekKey'] = _currentWeekKey();
      root['savedAt'] = DateTime.now().toIso8601String();
      _undoSnapshotJson = const JsonEncoder.withIndent('  ').convert(root);
      _undoActionDescription = 'la dernière action';
      _undoIconActivityId = null;
      _undoIconPreviousValue = null;
      _undoIconActivityName = null;
      _undoActionPrepared = true;
      setState(() {});
    } catch (_) {
      // Le mécanisme d'annulation reste facultatif si le snapshot échoue.
    }
  }

  bool get _canUndoLastAction =>
      !_undoInProgress &&
      _undoSnapshotJson != null &&
      _undoSnapshotJson!.trim().isNotEmpty;

  Future<void> _undoLastAction() async {
    if (!_canUndoLastAction || !mounted) return;

    // Une modification d’icône est une action locale et ciblée.
    // Ne pas restaurer tout le snapshot : certains écrans Sport peuvent
    // conserver une référence vers l’Activity affichée. On restaure donc
    // directement la valeur précédente sur l’objet actuellement en mémoire.
    final iconActivityId = _undoIconActivityId;
    final iconPreviousValue = _undoIconPreviousValue;
    final iconActivityName = _undoIconActivityName;
    final isIconUndo = iconActivityId != null && iconPreviousValue != null;
    final snapshot = _undoSnapshotJson!;

    _undoInProgress = true;
    _persistenceGeneration++;
    try {
      if (isIconUndo) {
        final activity = activities.cast<Activity?>().firstWhere(
          (a) => a?.id == iconActivityId,
          orElse: () => null,
        );
        if (activity == null) {
          if (mounted) _showFeedback('Impossible de retrouver l’activité à restaurer.');
          return;
        }

        setState(() {
          activity.emoji = iconPreviousValue!;
          for (var i = 0; i < logs.length; i++) {
            final log = logs[i];
            if (log.activityId != iconActivityId) continue;
            logs[i] = ActivityLog(
              date: log.date,
              title: log.title,
              emoji: iconPreviousValue,
              category: log.category,
              period: log.period,
              day: log.day,
              plannedMinutes: log.plannedMinutes,
              realisedMinutes: log.realisedMinutes,
              feeling: _normalizeFeeling(log.feeling),
              unplanned: log.unplanned,
              planItemId: log.planItemId,
              activityId: log.activityId,
            );
          }
          _resetGeneration++;
        });

        final restoredName = iconActivityName ?? activity.name;
        _undoSnapshotJson = null;
        _undoActionPrepared = false;
        _undoActionDescription = null;
        _undoIconActivityId = null;
        _undoIconPreviousValue = null;
        _undoIconActivityName = null;
        _persistLocalState(recordUndo: false);
        await HapticFeedback.lightImpact();
        if (mounted) {
          _showFeedback('↶ Retour arrière : l’icône de « $restoredName » a été restaurée en $iconPreviousValue.');
        }
        return;
      }

      final restored = restoreBackup(snapshot);
      if (!restored || !mounted) {
        if (mounted) _showFeedback('Impossible d’annuler la dernière action.');
        return;
      }

      final restoredDescription = _undoActionDescription ?? 'la dernière action';
      _undoSnapshotJson = null;
      _undoActionPrepared = false;
      _undoActionDescription = null;
      _undoIconActivityId = null;
      _undoIconPreviousValue = null;
      _undoIconActivityName = null;
      if (mounted) setState(() => _resetGeneration++);
      await HapticFeedback.lightImpact();
      _persistLocalState(recordUndo: false);
      if (mounted) _showFeedback('↶ Retour arrière : $restoredDescription a été restaurée.');
    } catch (_) {
      if (mounted) _showFeedback('Impossible d’annuler la dernière action.');
    } finally {
      _undoInProgress = false;
      if (mounted) setState(() {});
    }
  }
}
