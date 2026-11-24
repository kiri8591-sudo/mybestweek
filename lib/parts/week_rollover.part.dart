// V12.33.0 — Nouvelle semaine : le planning se construit tout seul à la première ouverture.
// Le déclencheur ne dépend plus de la date de la dernière sauvegarde : on mémorise la semaine pour
// laquelle le planning a été construit (_planWeekKey). Ainsi une app restée ouverte ou en arrière-plan
// de dimanche à lundi reconstruit aussi sa semaine, au retour au premier plan ou au plus tard 30 s après.

part of '../main.dart';

extension _WeekRolloverPart on _MaBelleSemaineAppState {
  /// Construit le planning de la semaine qui commence : toute la semaine si on est lundi,
  /// sinon à partir d'aujourd'hui (les jours déjà passés ne sont pas planifiés).
  void _rollToNewWeekPlan() {
    final index = DateTime.now().weekday - 1;
    setState(() {
      plan.clear();
      _regeneratedSportBudgets.clear();
      _planWeekKey = _currentWeekKey();
      _homeExpandedPeriods.clear();
      _homeFoldedPeriods.clear();
    });
    generateWeek(
      showSnack: false,
      markAsRegenerated: true,
      fullWeekRebuildOverride: index == 0,
      cutoffDayOverride: index - 1,
    );
  }

  // ----- repli des créneaux de l'accueil (état propre à chaque jour) ---------------------------------

  /// Un créneau est replié si on l'a replié à la main, ou si tout y est réalisé (sauf ouverture manuelle).
  /// Les états d'un autre jour sont oubliés ; rouvrir un créneau « tout réalisé » ne bloque plus son repli
  /// lorsqu'il redevient incomplet puis complet.
  bool _homePeriodCollapsed(String period, bool allDone) {
    final dayKey = _contractKey(_clockNow);
    final stateKey = '$dayKey|$period';
    _homeExpandedPeriods.removeWhere((k) => !k.startsWith('$dayKey|'));
    _homeFoldedPeriods.removeWhere((k) => !k.startsWith('$dayKey|'));
    if (!allDone) _homeExpandedPeriods.remove(stateKey);
    return _homeFoldedPeriods.contains(stateKey) || (allDone && !_homeExpandedPeriods.contains(stateKey));
  }

  void _toggleHomePeriod(String period, {required bool collapsed, required bool allDone}) {
    final stateKey = '${_contractKey(_clockNow)}|$period';
    if (collapsed) {
      _homeFoldedPeriods.remove(stateKey);
      if (allDone) _homeExpandedPeriods.add(stateKey);
    } else {
      _homeExpandedPeriods.remove(stateKey);
      _homeFoldedPeriods.add(stateKey);
    }
  }

  // ----- petit bilan personnel : une note par semaine ------------------------------------------------

  /// Relit les notes d'une sauvegarde. Une ancienne sauvegarde (note unique) est rattachée à la semaine
  /// en cours ; elle repart ensuite à zéro chaque lundi.
  void _restoreWeeklyNotes(Map root) {
    weeklyNote = '';
    weeklyNotes.clear();
    if (root['weeklyNotes'] is Map) {
      (root['weeklyNotes'] as Map).forEach((key, value) {
        if (key is String && value is String && value.trim().isNotEmpty) weeklyNotes[key] = value;
      });
    } else {
      final legacyNote = (_asString(root['weeklyNote']) ?? '').trim();
      if (legacyNote.isNotEmpty) weeklyNotes[_reviewKey(_reviewMonday(_clockNow))] = legacyNote;
    }
    if (weeklyNotes.length > 26) {
      final keys = weeklyNotes.keys.toList()..sort();
      for (final k in keys.take(weeklyNotes.length - 26)) {
        weeklyNotes.remove(k);
      }
    }
  }

  void _startNewWeekPlanIfNeeded() {
    if (!mounted || _isHydratingLocalState) return;
    if (_planWeekKey.isEmpty || _planWeekKey == _currentWeekKey()) return;
    _rollToNewWeekPlan();
    _showFeedback('📅 Nouvelle semaine : ton planning est prêt.');
  }
}
