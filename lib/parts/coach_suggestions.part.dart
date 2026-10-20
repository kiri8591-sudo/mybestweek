// V12.16.0 — Propositions du Coach : des décisions visibles et acceptables en un geste.
// Sources : temps réellement vécu (durée), absence prolongée, charge d'un jour, ressentis.

part of '../main.dart';

class _CoachSuggestion {
  final String id;
  final IconData icon;
  final String title;
  final String body;
  final List<(String, VoidCallback)> actions;

  const _CoachSuggestion({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });
}

extension _CoachSuggestionsPart on _MaBelleSemaineAppState {
  void _applyActivityDuration(Activity activity, int minutes) {
    _prepareUndoSnapshot();
    setState(() {
      activity.duration = minutes;
      for (final item in plan) {
        if (item.activityId == activity.id && !item.done && !_isDateRangePlanItem(item)) item.duration = minutes;
      }
    });
    _queueLocalStatePersist();
    _showFeedback('✓ « ${activity.name} » : $minutes min désormais.');
  }

  List<_CoachSuggestion> _coachSuggestions() {
    final result = <_CoachSuggestion>[];
    final now = DateTime.now();

    for (final a in activities) {
      if (a.isFrozen || a.isSportProgram || a.isDateRange) continue;
      final profile = _activityLearning(a);

      // 1) Durée prévue très différente du temps réellement vécu.
      if (profile.hasEnoughData && profile.averageRealisedMinutes > 0 && profile.durationGapRatio >= .25) {
        final suggested = max(5, (profile.averageRealisedMinutes / 5).round() * 5);
        if ((suggested - a.duration).abs() >= 5) {
          result.add(_CoachSuggestion(
            id: 'duration_${a.id}_$suggested',
            icon: Icons.timer_outlined,
            title: 'Ajuster le temps de « ${a.name} »',
            body: '${a.duration} min prévues, mais ${profile.averageRealisedMinutes.round()} min vécues en moyenne sur ${profile.realisedCount} réalisations.',
            actions: [('Passer à $suggested min', () => _applyActivityDuration(a, suggested))],
          ));
        }
      }

      // 2) Activité sans réalisation depuis 4 semaines.
      final mine = logs.where((l) => _logMatchesActivity(l, a) && l.realisedMinutes > 0).toList();
      if (mine.isNotEmpty && a.frequency >= 1) {
        final last = mine.map((l) => l.date).reduce((x, y) => x.isAfter(y) ? x : y);
        final days = _daysBetween(last, now);
        if (days >= 28) {
          result.add(_CoachSuggestion(
            id: 'idle_${a.id}',
            icon: Icons.hourglass_empty_rounded,
            title: '« ${a.name} » est en sommeil',
            body: 'Aucune réalisation depuis ${days ~/ 7} semaines alors qu’elle est prévue ${a.frequency}×/semaine.',
            actions: [
              ('Mettre en pause', () => _toggleActivityFrozen(a)),
              if (a.frequency > 1)
                ('Réduire à ${a.frequency - 1}×/sem.', () {
                  setState(() => a.frequency = a.frequency - 1);
                  _syncActivityToWeek(a, previous: null);
                  _queueLocalStatePersist();
                  _showFeedback('✓ « ${a.name} » : ${a.frequency}×/semaine.');
                }),
            ],
          ));
        }
      }

      // 3) Souvent vécue comme difficile.
      if (profile.hasEnoughData && profile.difficultCount >= 2 && profile.difficultRate >= .5 && a.duration > 10) {
        final reduced = a.duration - 5;
        result.add(_CoachSuggestion(
          id: 'hard_${a.id}_$reduced',
          icon: Icons.sentiment_dissatisfied_rounded,
          title: '« ${a.name} » est souvent difficile',
          body: '${profile.difficultCount} fois ressentie comme difficile récemment. Une séance plus courte peut aider à la tenir.',
          actions: [('Passer à $reduced min', () => _applyActivityDuration(a, reduced))],
        ));
      }
    }

    // 4) Jour de la semaine très chargé.
    final loads = <int, int>{};
    final counts = <int, int>{};
    for (var d = today; d < 7; d++) {
      final items = actionableItemsForDay(d).where((p) => !p.done).toList();
      loads[d] = items.fold<int>(0, (s, p) => s + p.duration);
      counts[d] = items.length;
    }
    for (final entry in loads.entries) {
      final others = loads.entries.where((e) => e.key != entry.key && e.value > 0).map((e) => e.value).toList();
      if (others.isEmpty) continue;
      final avg = others.fold<int>(0, (s, v) => s + v) / others.length;
      if (entry.value >= 240 && entry.value >= avg * 1.5) {
        result.add(_CoachSuggestion(
          id: 'load_${entry.key}_${entry.value}',
          icon: Icons.warning_amber_rounded,
          title: '${dayNames[entry.key]} est chargé',
          body: '${_minutesLabel(entry.value)} restent à vivre (${counts[entry.key]} moments), environ ${(entry.value / avg).toStringAsFixed(1).replaceAll('.', ',')} fois la moyenne des autres jours.',
          actions: [('Repenser la semaine', () => openGenerationCriteria())],
        ));
        break;
      }
    }

    return result.where((s) => !_coachDismissed.contains(s.id)).toList();
  }

  Future<void> _openCoachSuggestions() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheet) {
        final suggestions = _coachSuggestions();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
              children: [
                _SheetHeader(
                  leading: _uiIcon('coach', Icons.psychology_outlined, size: 24, color: _colors.accentIcon),
                  title: 'Le Coach propose',
                  subtitle: suggestions.isEmpty ? 'Rien à signaler pour le moment.' : '${suggestions.length} proposition${suggestions.length > 1 ? 's' : ''} d’après ton historique.',
                ),
                const SizedBox(height: AppSpace.m),
                if (suggestions.isEmpty)
                  _AppCard(tone: _CardTone.soft, child: Text('Les propositions apparaissent quand le Coach repère un écart entre le prévu et le vécu : temps, activité en sommeil, jour chargé.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted, height: 1.35))),
                for (final s in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s),
                    child: _AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(s.icon, size: 22, color: _colors.accentIcon),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.title, style: _sectionTitleStyle(context))),
                        ]),
                        const SizedBox(height: 6),
                        Text(s.body, style: TextStyle(fontSize: AppType.body, height: 1.35, color: _colors.textMuted)),
                        const SizedBox(height: AppSpace.m),
                        Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
                          for (final action in s.actions)
                            FilledButton.tonal(
                              onPressed: () {
                                action.$2();
                                _coachDismissed.add(s.id);
                                if (mounted) setSheet(() {});
                              },
                              child: Text(action.$1),
                            ),
                          TextButton(
                            onPressed: () {
                              _coachDismissed.add(s.id);
                              setSheet(() {});
                              if (mounted) setState(() {});
                            },
                            child: const Text('Plus tard'),
                          ),
                        ]),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
    if (mounted) setState(() {});
  }

  /// Carte de la semaine : visible seulement s'il y a des propositions.
  Widget _coachSuggestionsCard() {
    final suggestions = _coachSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _AppCard(
        tone: _CardTone.tint,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        onTap: _openCoachSuggestions,
        child: Row(children: [
          _uiIcon('coach', Icons.psychology_outlined, size: 24, color: _colors.accentIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Le Coach propose · ${suggestions.length}', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong)),
              const SizedBox(height: 2),
              Text(suggestions.first.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: _colors.textMuted),
        ]),
      ),
    );
  }
}
