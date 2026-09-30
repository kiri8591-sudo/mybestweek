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
    final snapshot = _undoSnapshotJson!;

    _undoInProgress = true;
    try {
      final restored = restoreBackup(snapshot);
      if (!restored || !mounted) {
        if (mounted) _showFeedback('Impossible d’annuler la dernière action.');
        return;
      }

      // L’annulation elle-même ne doit pas devenir une nouvelle action
      // annulable : on vide le bouton avant d’écrire l’état restauré.
      _undoSnapshotJson = null;
      _undoActionPrepared = false;
      await HapticFeedback.lightImpact();
      _persistLocalState(recordUndo: false);
      if (mounted) {
        _showFeedback('↶ Dernière action annulée.');
      }
    } catch (_) {
      if (mounted) _showFeedback('Impossible d’annuler la dernière action.');
    } finally {
      _undoInProgress = false;
      if (mounted) setState(() {});
    }
  }
}
