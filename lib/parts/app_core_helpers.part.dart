// V9.11 — Helpers cœur de l'application.
// Réintroduit le noyau commun retiré de main.dart lors du découpage du shell.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _AppCoreHelpersPart on _MaBelleSemaineAppState {
  int get today => DateTime.now().weekday - 1;

  Activity byId(String id) => activities.firstWhere((a) => a.id == id);

  Activity? findActivity(String id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool _isSportPlanItem(PlanItem item) {
    if (item.activityId == null) return false;
    final activity = findActivity(item.activityId!);
    return activity != null && _isSportActivity(activity);
  }

  void refreshMorningThought() {
    final choices = _MaBelleSemaineAppState.morningThoughts.where((thought) => thought != _morningThought).toList();
    setState(() {
      _morningThought = choices[Random().nextInt(choices.length)];
      _morningThoughtIcon = _MaBelleSemaineAppState._morningThoughtIcons[Random().nextInt(_MaBelleSemaineAppState._morningThoughtIcons.length)];
    });
    _queueLocalStatePersist();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    final messenger = _scaffoldMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 900)),
    );
  }

  String _currentWeekKey() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final d = DateTime(monday.year, monday.month, monday.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void openDataManager() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _DataPage(
          onExport: exportBackupFile,
          onICloudExport: exportBackupToICloud,
          onImport: importBackupFile,
          onReset: resetDatabaseCompletely,
          cloudBackupStatus: _cloudBackupStatusText(),
          cloudReminderDays: _MaBelleSemaineAppState._cloudBackupReminderDays,
        ),
      ),
    );
  }
}
