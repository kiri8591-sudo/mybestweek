// V12.1.0 — Accueil iPhone : hiérarchie recentrée sur Aujourd’hui et Mission du jour
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _MainScreensPart on _MaBelleSemaineAppState {


  Future<void> _evo8OpenActivityMiniHistory(Activity activity) async {
    final recent = logs.where((log) => _logMatchesActivity(log, activity)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final shown = recent.take(6).toList();
    final totalMinutes = recent.fold<int>(0, (sum, log) => sum + log.realisedMinutes);

    String durationLabel(int minutes) {
      if (minutes < 60) return '$minutes min';
      final hours = minutes ~/ 60;
      final remainder = minutes % 60;
      return remainder == 0 ? '${hours} h' : '${hours} h ${remainder}';
    }

    String dateLabel(ActivityLog log) {
      final date = log.date;
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }

    String feelingEmoji(String raw) {
      final feeling = _normalizeFeeling(raw);
      switch (feeling) {
        case 'Très bien':
          return '😄';
        case 'Bien':
          return '🙂';
        case 'Difficile':
          return '😕';
        default:
          return '';
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _activityIconWidget(activity.emoji, size: 28),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Historique de l’activité',
                          style: TextStyle(
                            fontSize: AppType.titleL,
                            fontWeight: FontWeight.w800,
                            color: _colors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          activity.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppType.label,
                            color: _colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                recent.isEmpty
                    ? 'Aucune réalisation enregistrée pour le moment.'
                    : '${recent.length} réalisation${recent.length > 1 ? 's' : ''} · $totalMinutes min réalisées au total',
                style: TextStyle(fontSize: AppType.label, color: _colors.textMuted),
              ),
              if (shown.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...shown.map(
                  (log) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            dateLabel(log),
                            style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _uiIcon('missionDone', Icons.check_circle_outline_rounded, size: 17, color: _colors.accentIcon),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            durationLabel(log.realisedMinutes),
                            style: TextStyle(fontSize: AppType.label, color: _colors.textMuted),
                          ),
                        ),
                        if (feelingEmoji(log.feeling).isNotEmpty)
                          Text(
                            feelingEmoji(log.feeling),
                            style: const TextStyle(fontSize: AppType.title),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (recent.length > shown.length) ...[
                const SizedBox(height: 4),
                Text(
                  '${recent.length - shown.length} autre${recent.length - shown.length > 1 ? 's' : ''} réalisation${recent.length - shown.length > 1 ? 's' : ''} dans l’historique général.',
                  style: TextStyle(fontSize: AppType.small, color: _colors.textMuted),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _nonSportWeeklyIndicator(Activity activity) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final itemsForDay = <int, List<PlanItem>>{
      for (var day = 0; day < 7; day++)
        day: plan.where((item) => item.day == day && item.activityId == activity.id).toList(),
    };

    void toggle(int day) {
      final items = itemsForDay[day] ?? const <PlanItem>[];

      // Cycle volontairement simple : vide → prévu → réalisé → vide.
      if (items.isEmpty) {
        setState(() {
          _clearManualDayRemoval(activity.id, day);
          plan.add(PlanItem(
            id: 'activity_week_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_$day',
            day: day,
            period: _periodForActivity(activity, day),
            activityId: activity.id,
            title: activity.name,
            duration: activity.duration,
            userAdded: true,
            manualPlacement: true,
          ));
          _sortPlan();
        });
        _queueLocalStatePersist();
        return;
      }

      if (items.any((item) => item.done)) {
        setState(() {
          for (final item in items) {
            _recordManualDayRemoval(activity.id, day);
          }
          plan.removeWhere((item) => item.activityId == activity.id && item.day == day);
          _sortPlan();
        });
        _queueLocalStatePersist();
        return;
      }

      // Passage prévu → réalisé : on valide toutes les occurrences de ce jour.
      setState(() {
        for (final item in items) {
          item.done = true;
        }
        _sortPlan();
      });
      _queueLocalStatePersist();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              '1 clic : prévu  ·  2e clic : réalisé ✓  ·  3e clic : retirer',
              style: TextStyle(fontSize: AppType.micro, color: _colors.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
          Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Semaine',
            style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.accentIcon),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(7, (day) {
                final items = itemsForDay[day] ?? const <PlanItem>[];
                final done = items.any((item) => item.done);
                final planned = items.isNotEmpty;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: day == 6 ? 0 : 5),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => toggle(day),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                        child: Container(
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: done
                                ? _colors.accentFill
                                : planned
                                    ? _colors.tintStrong
                                    : _colors.surfaceSoft,
                            borderRadius: BorderRadius.circular(AppRadius.s),
                            border: Border.all(
                              color: done ? _colors.accentFillBorder : _colors.borderTint,
                            ),
                          ),
                          child: done
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text(
                                  labels[day],
                                  style: TextStyle(
                                    fontSize: AppType.small,
                                    fontWeight: FontWeight.w800,
                                    color: planned ? _colors.accentText : _colors.textMuted,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      ],
      ),
    );
  }

  int _nextWeekDirectionActivityScore(Activity activity) {
    if (_nextWeekCoachDirections.isEmpty) return 0;
    var score = 0;
    final category = activity.category.toLowerCase();
    if (_nextWeekCoachDirections.contains('outdoor') && category == 'sortie') {
      score += 4;
    }
    if (_nextWeekCoachDirections.contains('culture') && category == 'culture') {
      score += 4;
    }
    if (_nextWeekCoachDirections.contains('social') && category == 'social') {
      score += 4;
    }
    if (_nextWeekCoachDirections.contains('wellness') && category == 'bien-être') {
      score += 4;
    }
    return score;
  }

  Map<int, List<Activity>> _nextWeekProjection() {
    final result = {for (var day = 0; day < 7; day++) day: <Activity>[]};
    final load = {for (var day = 0; day < 7; day++) day: 0};
    final candidates = activities.where((a) => !_isSportActivity(a) && !a.isSportProgram && !a.isDateRange && !_generationShouldAvoid(a)).toList()
      ..sort((a, b) {
        final direction = _nextWeekDirectionActivityScore(b).compareTo(_nextWeekDirectionActivityScore(a));
        if (direction != 0) return direction;
        return b.frequency.compareTo(a.frequency);
      });
    for (final activity in candidates) {
      final target = activity.frequency.clamp(1, 7).toInt();
      final available = List<int>.generate(7, (day) => day)
        ..sort((a, b) {
          final ap = activity.preferredDays.contains(a) ? 0 : 1;
          final bp = activity.preferredDays.contains(b) ? 0 : 1;
          if (ap != bp) return ap.compareTo(bp);
          return load[a]!.compareTo(load[b]!);
        });
      for (final day in available.take(target)) {
        result[day]!.add(activity);
        load[day] = load[day]! + min(activity.duration, 60);
      }
    }
    return result;
  }

  Future<void> _openNextWeekCoachDirections() async {
    final local = <String>{..._nextWeekCoachDirections};
    const labels = <String, String>{
      'outdoor': '🌿 Plus de plein air',
      'culture': '🎵 Plus de musique / culture',
      'social': '🫶 Plus de vie sociale',
      'wellness': '🌸 Plus de bien-être',
    };
    await showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _colors.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Donner une direction au Coach', style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _colors.textStrong)),
            const SizedBox(height: 5),
            Text('Ces indications seront prises en compte lors de la régénération du lundi. Rien ne change aujourd’hui.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.3)),
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: labels.entries.map((entry) => FilterChip(
              label: Text(entry.value, style: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800)),
              selected: local.contains(entry.key),
              onSelected: (selected) => setSheetState(() => selected ? local.add(entry.key) : local.remove(entry.key)),
            )).toList()),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () {
                _setNextWeekCoachDirections(local);
                _queueLocalStatePersist();
                Navigator.of(sheetContext).pop();
              },
              icon: _uiIcon('coach', Icons.auto_awesome_outlined, size: 18),
              label: Text(local.isEmpty ? 'Ne rien préciser' : 'Enregistrer mes directions'),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _sundayNextWeekPreview({bool allowSelectedSunday = false}) {
    if (today != 6 && !(allowSelectedSunday && _weekSelectedDay == 6)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final projection = _nextWeekProjection();
    const names = ['plein air', 'musique / culture', 'vie sociale', 'bien-être'];
    final directionKeys = ['outdoor', 'culture', 'social', 'wellness'];
    final activeDirections = <String>[];
    for (var i = 0; i < directionKeys.length; i++) {
      if (_nextWeekCoachDirections.contains(directionKeys[i])) activeDirections.add(names[i]);
    }
    final directionLabel = activeDirections.isEmpty ? 'Aucune direction particulière.' : 'Directions : ${activeDirections.join(' · ')}.';
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 1, 16, 6),
        child: softCard(
          color: _colors.surfaceSoft,
          borderColor: _colors.borderTint,
          radius: 20,
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🔭', style: TextStyle(fontSize: AppType.h2)),
              const SizedBox(width: 7),
              Expanded(child: Text('Aperçu de la semaine prochaine', style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong))),
              TextButton.icon(onPressed: _openNextWeekCoachDirections, icon: _systemIconWidget('nextWeekDirections', fallback: '🎛️', size: 15), label: const Text('Diriger le Coach'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), minimumSize: const Size(0, 30))),
            ]),
            const SizedBox(height: 4),
            Text(directionLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted, height: 1.2)),
            const SizedBox(height: 7),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(7, (day) {
              final items = projection[day]!;
              return Container(
                width: 76,
                margin: EdgeInsets.only(right: day == 6 ? 0 : 6),
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.m), border: Border.all(color: _colors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][day], style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                  const SizedBox(height: 3),
                  if (_sportProgram != null && _configuredSportBaseBudgetForDay(day) > 0)
                    const Padding(padding: EdgeInsets.only(bottom: 2), child: Text('💪 Sport', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800))),
                  if (items.isEmpty)
                    Text('Temps libre', style: TextStyle(fontSize: AppType.micro, color: _colors.textMuted))
                  else
                    ...items.take(3).map((a) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.accentIcon)))),
                  if (items.length > 3) Text('+${items.length - 3}', style: TextStyle(fontSize: AppType.micro, color: _colors.textMuted)),
                ]),
              );
            }))),
          ]),
        ),
      ),
    );
  }

  PlanItem? _homeCoachMission() {
    final remaining = actionableItemsForDay(today).where((item) => !item.done).toList();
    if (remaining.isEmpty) return null;
    remaining.sort((a, b) {
      final dailyA = _isDailyPriorityActivityId(a.activityId) ? 0 : 1;
      final dailyB = _isDailyPriorityActivityId(b.activityId) ? 0 : 1;
      final dailyCompare = dailyA.compareTo(dailyB);
      if (dailyCompare != 0) return dailyCompare;
      final pa = a.activityId == null ? 1 : (findActivity(a.activityId!)?.priority ?? 1);
      final pb = b.activityId == null ? 1 : (findActivity(b.activityId!)?.priority ?? 1);
      final priorityCompare = pb.compareTo(pa);
      if (priorityCompare != 0) return priorityCompare;
      const periodOrder = {'Matin': 0, 'Midi': 1, 'Après-midi': 2, 'Soir': 3};
      final periodCompare = (periodOrder[a.period] ?? 9).compareTo(periodOrder[b.period] ?? 9);
      if (periodCompare != 0) return periodCompare;
      return a.duration.compareTo(b.duration);
    });
    return remaining.first;
  }

  Widget _homePlanningBanner() {
    final regenerationVisible = _lastPlanningRegeneratedWeekKey == _currentWeekKey() &&
        _lastPlanningRegeneratedDays.isNotEmpty &&
        _lastPlanningRegeneratedAt != null &&
        DateTime.now().difference(_lastPlanningRegeneratedAt!).inHours < 24 &&
        _planningReportReadAt == null;
    if (regenerationVisible) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 1, 16, 6),
          child: softCard(
            color: _colors.tintStrong,
            borderColor: _colors.borderTint,
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                _uiIcon('refresh', Icons.autorenew_rounded, size: 16, color: _colors.accentIcon),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Planning mis à jour · ${_regeneratedDaysMessage()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.accentIcon),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _planningReportReadAt = DateTime.now());
                    _queueLocalStatePersist();
                    openPlanningCoachDecisions();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Pourquoi ?', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_showMondayRegenerationPrompt) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 1, 16, 6),
          child: softCard(
            color: _colors.tintStrong,
            borderColor: _colors.borderTint,
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                const Text('🌿', style: TextStyle(fontSize: AppType.titleL)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'C’est lundi 🌱. Repenser la semaine à partir de ton historique ?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.accentIcon, height: 1.2),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: openGenerationCriteria,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Repenser', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Pas maintenant',
                  visualDensity: VisualDensity.compact,
                  onPressed: _dismissMondayRegenerationPrompt,
                  icon: _uiIcon('close', Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  String _periodLabelIcon(String period) {
    switch (period) {
      case 'Matin':
        return _systemIconValue('periodMorning', '🌤️');
      case 'Après-midi':
        return _systemIconValue('periodAfternoon', '🌿');
      case 'Soir':
        return _systemIconValue('periodEvening', '🌙');
      default:
        return '•';
    }
  }

  Widget _kawaiiNavIcon(String emoji, Color bg, Color fg, {bool selected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 42 : 38,
      height: selected ? 34 : 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(selected ? AppRadius.l : AppRadius.m),
        border: Border.all(color: fg.withValues(alpha: selected ? .20 : .13), width: 1),
        boxShadow: selected
            ? [BoxShadow(color: _colors.shadow, blurRadius: 7, offset: Offset(0, 2))]
            : const [],
      ),
      alignment: Alignment.center,
      child: _activityIconWidget(emoji, size: selected ? 20 : 18),
    );
  }

  Widget pageTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          mascotAvatar(size: 48),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: GoogleFonts.lora().fontFamily, fontWeight: FontWeight.w700, color: _colors.textStrong, letterSpacing: -0.35, fontSize: AppType.h1, height: 1.12)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunitoSans(fontSize: AppType.body, color: _colors.textMuted, height: 1.28)),
          ])),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Système · personnaliser',
            onPressed: _openSystemMenu,
            visualDensity: VisualDensity.compact,
            icon: _systemIconWidget('system', fallback: '⚙️', size: 22),
          ),
        ]),
      );

  Widget mascotAvatar({double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colors.peachBg,
        shape: BoxShape.circle,
        border: Border.all(color: _colors.peachBorder, width: 1.5),
        boxShadow: [BoxShadow(color: _colors.shadow, blurRadius: 8, offset: Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * .025),
        child: Image.memory(_bearHeadBytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      ),
    );
  }

  Widget softCard({
      required Widget child,
      required Color color,
      EdgeInsetsGeometry padding = const EdgeInsets.all(16),
      double radius = 24,
      Color? borderColor,
    }) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, const Color(0xFFFFFFFF), .28) ?? color,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? _colors.borderTint, width: 1.15),
        boxShadow: [
          BoxShadow(color: _colors.shadow, blurRadius: 20, offset: Offset(0, 7)),
          BoxShadow(color: _colors.shadowSoft, blurRadius: 2, offset: Offset(0, -1)),
        ],
      ),
      padding: padding,
      child: child,
    );

  String _backupMenuStatusLabel() {
    final local = _lastFileBackupAt != null;
    final cloud = _lastICloudBackupAt != null;
    if (local && cloud) return 'À jour';
    if (local || cloud) return '1/2 copie';
    return 'À faire';
  }

  Widget buildHome() {
    final todayItems = itemsForDay(today);
    final todaySportItems = _sportItemsForDay(today);
    final todayOtherItems = todayItems.where((item) {
      if (item.activityId == null) return true;
      final activity = findActivity(item.activityId!);
      return activity == null || !_isSportActivity(activity);
    }).toList();
    final todayActionItems = todayItems.where((x) => !_isDateRangePlanItem(x)).toList();
    final todayCompleted = todayActionItems.isNotEmpty && todayActionItems.every((x) => x.done);
    final todayDone = todayActionItems.where((x) => x.done).length;
    final homeMission = _homeCoachMission();
    final sportBudget = _sportBudgetForDay(today);
    final todayWeather = _weatherForWeekDay(today);
    final hasOutdoorRemaining = todayActionItems.where((x) => !x.done).any((item) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      return activity != null && _isOutdoorPlanningActivity(activity);
    });
    final headerWeatherSensitive = hasOutdoorRemaining && todayWeather?.outdoorBad == true;
    final headerColor = _darkMode
        ? (headerWeatherSensitive
            ? const Color(0xFF253137)
            : _clockNow.hour < 12
                ? const Color(0xFF302A22)
                : _clockNow.hour < 18
                    ? const Color(0xFF223028)
                    : const Color(0xFF292533))
        : headerWeatherSensitive
            ? const Color(0xFFEEF4F7)
            : _clockNow.hour < 12
                ? const Color(0xFFFFF1DE)
                : _clockNow.hour < 18
                    ? const Color(0xFFEAF6F0)
                    : const Color(0xFFF1EEF6);
    final headerBorderColor = _darkMode
        ? const Color(0xFF46504B)
        : headerWeatherSensitive
            ? const Color(0xFFD9E5EB)
            : _clockNow.hour < 12
                ? const Color(0xFFF0D7B6)
                : _clockNow.hour < 18
                    ? const Color(0xFFD3E5DB)
                    : const Color(0xFFDED8EA);

    Widget pill(String text, {Color bg = const Color(0xFFFFFCF7), Color fg = const Color(0xFF60786B)}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: _colors.borderStrong)),
      child: Text(text, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: fg)),
    );

    Widget todayPeriod(String period) {
      final periodItems = todayItems.where((item) {
        if (item.period != period) return false;
        if (_isDateRangePlanItem(item)) return false;
        if (item.activityId != null) {
          final activity = findActivity(item.activityId!);
          if (activity != null && _isSportActivity(activity)) return false;
        }
        return true;
      }).toList();
      final trackedPeriodItems = periodItems
          .where((item) => item.activityId != null)
          .toList();
      // Un créneau devient repliable lorsque toutes ses activités réelles
      // sont réalisées. Les blocs de temps libre ne bloquent pas le repli.
      final allDone = trackedPeriodItems.isNotEmpty && trackedPeriodItems.every((item) => item.done);
      final collapsed = allDone && !_homeExpandedPeriods.contains(period);

      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: DragTarget<PlanItem>(
          onWillAcceptWithDetails: (details) => _canDropGenericInWeeklyPeriod(details.data, today, period),
          onAcceptWithDetails: (details) => _moveGenericActivityWeekly(details.data, today, period),
          builder: (context, candidateData, rejectedData) {
            final highlighted = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.all(highlighted ? 7 : 0),
              decoration: BoxDecoration(
                color: highlighted ? _colors.tintStrong : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: highlighted ? Border.all(color: _colors.accentSoftBorder, width: 1.5) : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  onTap: allDone
                      ? () => setState(() {
                            if (_homeExpandedPeriods.contains(period)) {
                              _homeExpandedPeriods.remove(period);
                            } else {
                              _homeExpandedPeriods.add(period);
                            }
                          })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      _systemIconWidget(period == 'Matin' ? 'periodMorning' : period == 'Après-midi' ? 'periodAfternoon' : 'periodEvening', fallback: period == 'Matin' ? '🌤️' : period == 'Après-midi' ? '🌿' : '🌙', size: 17),
                      const SizedBox(width: 6),
                      Text(period, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      if (allDone) ...[
                        const SizedBox(width: 7),
                        Text('✓', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.accentIcon),),
                        const Spacer(),
                        _uiIcon(collapsed ? 'chevronDown' : 'chevronUp', collapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, size: 18, color: _colors.textMuted),
                      ] else ...[
                        const SizedBox(width: 9),
                        Expanded(child: Divider(height: 1, thickness: .8, color: _colors.borderTint)),
                      ],
                      if (highlighted) ...[
                        const SizedBox(width: 7),
                        _systemIconWidget('dragDown', fallback: '↓', size: 15),
                        const SizedBox(width: 3),
                        Text('Déposer ici', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.accentIcon)),
                      ],
                    ]),
                  ),
                ),
                if (!collapsed) ...[
                  if (periodItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
                      child: Text(
                        highlighted ? 'Déposer l’activité ici' : 'Temps libre',
                        style: TextStyle(fontSize: AppType.body, color: highlighted ? _colors.accentIcon : _colors.textMuted, fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal),
                      ),
                    )
                  else
                    ...periodItems.map((item) => planRow(
                          item,
                          highlightMission: homeMission?.id == item.id,
                          showPastQuickActions: true,
                        )),
                ],
              ]),
            );
          },
        ),
      );
    }


    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 5),
            child: softCard(
              color: headerColor,
              borderColor: headerBorderColor,
              radius: 26,
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _homeMascotAvatar(size: 60),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${dateText()} · ${_clockText()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800, color: _darkMode ? const Color(0xFFB9C3BD) : const Color(0xFF756E67)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_greetingLabel()} 👋',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _darkMode ? const Color(0xFFE2E9E4) : const Color(0xFF3F4B45), letterSpacing: -0.25),
                                ),
                                if (_userName.trim().isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    _userName.trim(),
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _darkMode ? const Color(0xFFE2E9E4) : const Color(0xFF3F4B45), letterSpacing: -0.2, height: 1.05),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  _MaBelleSemaineAppState.version,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _darkMode ? const Color(0xFFA5B2AB) : const Color(0xFF79877F), letterSpacing: .1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Repenser le planning',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        onPressed: openGenerationCriteria,
                        icon: _uiIcon('refresh', Icons.autorenew_rounded, size: 18, color: _colors.accentIcon),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Menu',
                        padding: EdgeInsets.zero,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _uiIcon('settings', Icons.more_horiz_rounded, size: 19, color: _colors.accentIcon),
                            if (_cloudBackupReminderDue)
                              Positioned(
                                right: -1,
                                top: -2,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _colors.danger,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: headerColor, width: 1.2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onSelected: (value) {
                          if (value == 'data') openDataManager();
                          if (value == 'identity') _editHomeIdentity();
                          if (value == 'darkMode') _toggleDarkMode();

                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'data',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _uiIcon('save', Icons.save_outlined, size: 18),
                              title: const Text('Sauvegarde & données'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _backupMenuStatusLabel() == 'À faire'
                                      ? _colors.goldBg
                                      : _colors.tintStrong,
                                  borderRadius: BorderRadius.circular(AppRadius.s),
                                ),
                                child: Text(
                                  _backupMenuStatusLabel(),
                                  style: const TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'identity',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _uiIcon('settings', Icons.tune_rounded, size: 18),
                              title: const Text('Personnaliser l’accueil'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'darkMode',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(_darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 18),
                              title: const Text('Mode sombre'),
                              trailing: Text(_darkMode ? 'Activé' : 'Désactivé', style: const TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_weatherCity.trim().isEmpty ? '🌤️' : _weatherIcon, style: const TextStyle(fontSize: AppType.titleL)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _weatherCity.trim().isEmpty
                              ? 'Ajoute ta ville pour la météo'
                              : '${_weatherCity.trim()}${_weatherTemperature.isEmpty ? '' : ' · ${_weatherTemperature}'}${_weatherText.isEmpty ? '' : ' · ${_weatherText.toLowerCase()}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.accentIcon),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_morningThoughtIcon, style: const TextStyle(fontSize: AppType.body)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _morningThought,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: TextStyle(fontSize: AppType.small, height: 1.16, fontStyle: FontStyle.italic, color: _darkMode ? const Color(0xFFD0D8D3) : const Color(0xFF5D554B)),
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: refreshMorningThought,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1, left: 3),
                          child: _uiIcon('coach', Icons.auto_awesome_rounded, size: 14, color: _colors.goldText),
                        ),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      final summary = _todayDailySummary();
                      if (summary == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          onTap: _openTodayDailySummary,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(summary.moodEmoji, style: const TextStyle(fontSize: AppType.titleL)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _todayMoodComment(summary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: AppType.caption, height: 1.16, fontWeight: FontWeight.w800, color: _darkMode ? const Color(0xFFB8C3BD) : const Color(0xFF6B756F)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        _homePlanningBanner(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 1, 16, 8),
            child: softCard(
              color: _darkMode ? const Color(0xFF202B25) : const Color(0xFFF0F7F3),
              borderColor: _darkMode ? const Color(0xFF3B4D43) : const Color(0xFFD7E6DE),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: AppType.h2)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Aujourd’hui',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong),
                        ),
                      ),
                    ),
                    if (todayActionItems.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      pill('$todayDone/${todayActionItems.length}', bg: _colors.card),
                    ],
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Challenge · Mes priorités',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      onPressed: _editDailyPriorities,
                      icon: _systemIconWidget('challenge', fallback: '🎯', size: 20),
                    ),
                  ],
                ),
                if (_todayFocus().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(_focusIcon, style: const TextStyle(fontSize: AppType.title)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _todayFocus(),
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            style: TextStyle(fontSize: AppType.caption, height: 1.18, fontWeight: FontWeight.w800, color: _darkMode ? const Color(0xFFC6D0CA) : const Color(0xFF6E6860)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 9),
                if (todayOtherItems.where(_isDateRangePlanItem).isNotEmpty)
                  _multiDaySection(todayOtherItems.where(_isDateRangePlanItem).toList(), day: today),
                ...const ['Matin', 'Après-midi', 'Soir']
                    .where((period) {
                      final periodItems = todayItems.where((item) {
                        if (item.period != period || _isDateRangePlanItem(item)) return false;
                        if (item.activityId != null) {
                          final activity = findActivity(item.activityId!);
                          if (activity != null && _isSportActivity(activity)) return false;
                        }
                        return true;
                      }).toList();
                      return _homeShouldShowPeriod(period, periodItems, todayItems);
                    })
                    .map(todayPeriod),
                if (sportBudget > 0 || todaySportItems.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _sportDayCard(today, compactHome: true),
                  const SizedBox(height: 1),
                ],
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => addUnplannedToDay(today),
                    icon: _uiIcon('add', Icons.add, size: 18),
                    label: const Text('Ajouter autre chose'),
                  ),
                ),
              ]),
            ),
          ),
        ),
        if (sportCoachSuggestion.isNotEmpty)
          SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 1, 16, 8),
            child: softCard(
              color: _colors.tintStrong,
              borderColor: _colors.borderTint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  mascotAvatar(size: 42),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Coach Sport', style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.accentText))),
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'Journal du coach Sport', onPressed: openSportCoachJournal, icon: _uiIcon('history', Icons.menu_book_rounded, size: 18, color: _colors.accentText)),
                ]),
                const SizedBox(height: 5),
                Text(sportCoachLastAnalysis.isEmpty ? 'Je veille à garder une semaine souple et agréable.' : sportCoachLastAnalysis, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.label, height: 1.34, color: _colors.accentText, fontWeight: FontWeight.w600)),
                if (sportCoachSuggestion.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 7, 8),
                    decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.l)),
                    child: Row(children: [
                      const Text('💡', style: TextStyle(fontSize: AppType.titleL)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(sportCoachSuggestion, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.accentText))),
                      const SizedBox(width: 5),
                      FilledButton.tonalIcon(onPressed: applySportCoachSuggestion, icon: _uiIcon('apply', Icons.bolt_rounded, size: 14, color: _colors.accentIcon), label: const Text('Appliquer'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _weekNonSportIndicators(List<PlanItem> items) {
    final unique = <String, Activity>{};
    for (final item in items) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      if (activity != null && !_isSportActivity(activity) && !activity.isDateRange && !activity.isSportProgram) {
        unique[activity.id] = activity;
      }
    }
    if (unique.isEmpty) return const <Widget>[];
    return unique.values.map((activity) => Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, bottom: 2),
      child: _nonSportWeeklyIndicator(activity),
    )).toList();
  }

  void _toggleNonSportWeekDay(Activity activity, int day) {
    final items = plan.where((item) => item.day == day && item.activityId == activity.id).toList();
    if (items.isEmpty) {
      setState(() {
        _clearManualDayRemoval(activity.id, day);
        plan.add(PlanItem(
          id: 'activity_week_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_$day',
          day: day,
          period: _periodForActivity(activity, day),
          activityId: activity.id,
          title: activity.name,
          duration: activity.duration,
          userAdded: true,
          manualPlacement: true,
        ));
        _sortPlan();
      });
      _queueLocalStatePersist();
      return;
    }
    if (items.any((item) => item.done)) {
      setState(() {
        for (final item in items) {
          _recordManualDayRemoval(activity.id, day);
        }
        plan.removeWhere((item) => item.activityId == activity.id && item.day == day);
        _sortPlan();
      });
      _queueLocalStatePersist();
      return;
    }
    setState(() {
      for (final item in items) {
        item.done = true;
      }
      _sortPlan();
    });
    _queueLocalStatePersist();
  }

  Widget _weekNonSportPlanCard(PlanItem item, Activity activity) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    Widget weeklyChecks() => Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(7, (day) {
            final dayItems = plan.where((candidate) => candidate.day == day && candidate.activityId == activity.id).toList();
            final done = dayItems.any((candidate) => candidate.done);
            final planned = dayItems.isNotEmpty;
            return Padding(
              padding: EdgeInsets.only(right: day == 6 ? 0 : 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(labels[day], style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.textMuted)),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => _toggleNonSportWeekDay(activity, day),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: done ? _colors.border : planned ? _colors.tintStrong : _colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: done ? _colors.borderStrong : _colors.borderTint),
                      ),
                      child: done
                          ? Icon(Icons.check_rounded, size: 12, color: _colors.textMuted)
                          : planned
                              ? Text('.', style: TextStyle(fontSize: AppType.title, height: .8, fontWeight: FontWeight.w800, color: _colors.accentIcon))
                              : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.fromLTRB(7, 6, 4, 6),
        decoration: BoxDecoration(
          color: _colors.card,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: _colors.border),
          boxShadow: [BoxShadow(color: _colors.shadowSoft, blurRadius: 5, offset: Offset(0, 2))],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 500;
            final title = Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: _detailTitleStyle(decoration: item.done ? TextDecoration.lineThrough : null),
                    ),
                  ),
                  _frozenActivityMarker(activity),
                  if (item.day == today && _isDailyPriorityActivityId(item.activityId)) ...[
                    const SizedBox(width: 4),
                    _uiIcon('priority', Icons.star_rounded, size: 12, color: _colors.goldText),
                  ],
                ],
              ),
            );

            final header = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: item.done,
                  onChanged: (_) => openPlanItem(item),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                ),
                const SizedBox(width: 2),
                _activityIconWidget(_planItemIconValue(item, activities), size: 28),
                const SizedBox(width: 7),
                title,
                PopupMenuButton<String>(
                  tooltip: 'Autres actions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                  icon: _uiIcon('settings', Icons.more_horiz_rounded, size: 19, color: _colors.textMuted),
                  onSelected: (value) {
                    if (value == 'why') _showPlanItemCoachReason(item);
                    if (value == 'edit') openItemActions(item);
                    if (value == 'remove') _removePlanOccurrence(item);
                  },
                  itemBuilder: (context) => [
                    if (item.details != null) const PopupMenuItem<String>(value: 'why', child: Text('Pourquoi ce moment ?')),
                    const PopupMenuItem<String>(value: 'edit', child: Text('Voir / modifier')),
                    const PopupMenuItem<String>(value: 'remove', child: Text('Retirer du jour')),
                  ],
                ),
              ],
            );

            if (!narrow) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 7),
                  weeklyChecks(),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.only(left: 39, top: 3),
                  child: weeklyChecks(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildWeek() {
    final trackable = plan.where((p) => p.activityId != null && !_isDateRangePlanItem(p)).toList();
    final totalMinutes = trackable.fold<int>(0, (sum, p) => sum + p.duration);
    final weekCompleted = trackable.where((p) => p.done).length;
    final weekProgress = trackable.isEmpty ? 0.0 : weekCompleted / trackable.length;
    final selectedDay = _weekSelectedDay >= 0 && _weekSelectedDay < 7 ? _weekSelectedDay : today;
    final selectedItems = itemsForDay(selectedDay);
    final selectedActionItems = selectedItems.where((item) => !_isDateRangePlanItem(item)).toList();
    final selectedDone = selectedActionItems.where((item) => item.done).length;
    const periods = ['Matin', 'Après-midi', 'Soir'];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: pageTitle(
            'Ma semaine',
            'Choisis un jour. Le détail s’affiche juste en dessous.',
          ),
        ),
        _sundayNextWeekPreview(allowSelectedSunday: true),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _colors.tintStrong,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                      child: _uiIcon('calendar', Icons.event_note_outlined, size: 20, color: _colors.accentText),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalMinutes min prévues', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.bodyL)),
                          const SizedBox(height: 2),
                          Text('$weekCompleted / ${trackable.length} moment(s) validé(s)', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: weekProgress,
                              minHeight: 4,
                              backgroundColor: _colors.tintStrong,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF88AE98)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: openWeeklyReview,
                      icon: _uiIcon('insights', Icons.insights_outlined, size: 17),
                      label: const Text('Bilan'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        minimumSize: const Size(0, 42),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _adaptiveHomeContextCard(
              todayActionItems: plan
                  .where((item) => item.day == today && !_isDateRangePlanItem(item))
                  .toList(),
              todayDone: plan
                  .where((item) => item.day == today && !_isDateRangePlanItem(item) && item.done)
                  .length,
              todayCompleted: plan.any((item) => item.day == today && !_isDateRangePlanItem(item)) &&
                  plan.where((item) => item.day == today && !_isDateRangePlanItem(item)).every((item) => item.done),
              weekProgress: weekProgress,
              weekCompleted: weekCompleted,
              weekTotal: trackable.length,
            ),
          ),
        ),
        if (_lastPlanningRegeneratedWeekKey == _currentWeekKey() && _lastPlanningRegeneratedDays.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Card(
                color: _colors.tintStrong,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _uiIcon('refresh', Icons.autorenew_rounded, size: 18, color: _colors.accentIcon),
                    const SizedBox(width: 7),
                    Expanded(child: Text('Régénération : ${_regeneratedDaysMessage()}. ${_lastPlanningWasFullWeek ? 'La semaine entière a été reconstruite après la réinitialisation.' : 'Le passé et aujourd’hui restent inchangés.'}', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.accentIcon))),
                    TextButton(
                      onPressed: openPlanningCoachDecisions,
                      child: const Text('Pourquoi ?'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, day) {
                  final isSelected = day == selectedDay;
                  final isToday = day == today;
                  final dayItems = actionableItemsForDay(day);
                  final done = dayItems.where((item) => item.done).length;
                  return GestureDetector(
                    onTap: () => setState(() => _weekSelectedDay = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _colors.tintStrong
                            : _colors.card,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                        border: Border.all(
                          color: isSelected
                              ? _colors.borderStrong
                              : _colors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNames[day].substring(0, 3),
                            style: TextStyle(
                              fontSize: AppType.small,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? _colors.accentText : _colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _weekDateShortLabel(day),
                            style: TextStyle(
                              fontSize: AppType.micro,
                              fontWeight: FontWeight.w800,
                              color: isToday ? _colors.danger : _colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dayItems.length}',
                            style: TextStyle(
                              fontSize: AppType.h2,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? _colors.textStrong : _colors.accentIcon,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_lastPlanningRegeneratedWeekKey == _currentWeekKey() && _lastPlanningRegeneratedDays.contains(day))
                            Text(
                              'régénéré',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.accentIcon),
                            )
                          else
                            Text(
                              done == 0 ? (isToday ? 'aujourd’hui' : 'à faire') : '$done ✓',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppType.micro,
                                fontWeight: FontWeight.w800,
                                color: done > 0 ? _colors.accentIcon : _colors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              color: _colors.tintStrong,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selectedDay == today && _weatherText.isNotEmpty
                          ? (_weatherText.toLowerCase().contains('pluie') || _weatherText.toLowerCase().contains('averse') || _weatherText.toLowerCase().contains('orage') || _weatherText.toLowerCase().contains('neige')
                              ? Icons.umbrella_outlined
                              : Icons.self_improvement_outlined)
                          : Icons.self_improvement_outlined,
                      color: _colors.accentIcon,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _weeklyPlanningMessage(selectedDay),
                        style: const TextStyle(fontSize: AppType.body, height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              color: _colors.tintStrong,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dayNames[selectedDay],
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.h1, color: _colors.textStrong),
                          ),
                        ),
                        if (selectedDay == today)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: _colors.tintStrong,
                              borderRadius: BorderRadius.circular(AppRadius.m),
                            ),
                            child: Text(
                              'AUJOURD’HUI',
                              style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.accentText),
                            ),
                          ),
                        const SizedBox(width: 3),
                        IconButton(
                          tooltip: 'Ajouter un moment',
                          onPressed: () => addUnplannedToDay(selectedDay),
                          icon: _uiIcon('add', Icons.add_circle_outline, size: 18, color: _colors.accentText),
                        ),
                      ],
                    ),
                    if (selectedItems.where(_isDateRangePlanItem).isNotEmpty)
                      _multiDaySection(selectedItems.where(_isDateRangePlanItem).toList(), day: selectedDay),
                    const SizedBox(height: 2),
                    _dayMood(selectedDay),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedItems.isEmpty
                                ? 'Journée libre'
                                : '$selectedDone / ${selectedActionItems.length} moment(s) validé(s)',
                            style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _colors.textMuted),
                          ),
                        ),
                        if (_sportBudgetForDay(selectedDay) > 0)
                          Text(
                            'Sport ${_sportBudgetForDay(selectedDay)} min',
                            style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.accentIcon),
                          ),
                      ],
                    ),
                    if (_sportProgram != null || _sportItemsForDay(selectedDay).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sportDayCard(selectedDay),
                    ],
                    const SizedBox(height: 8),
                    if (selectedActionItems.any(_isGenericActivityItem))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '↕ Glisser-déposer : une occurrence peut être déplacée dans un créneau qui contient déjà une autre occurrence.',
                          style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.accentIcon),
                        ),
                      ),
                    ...periods.map((period) {
                      final periodItems = selectedItems.where((item) {
                        if (item.period != period) return false;
                        if (_isDateRangePlanItem(item)) return false;
                        if (item.activityId != null) {
                          final activity = findActivity(item.activityId!);
                          if (activity != null && _isSportActivity(activity)) return false;
                        }
                        return true;
                      }).toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: DragTarget<PlanItem>(
                          onWillAcceptWithDetails: (details) => _canDropGenericInWeeklyPeriod(details.data, selectedDay, period),
                          onAcceptWithDetails: (details) => _moveGenericActivityWeekly(details.data, selectedDay, period),
                          builder: (context, candidateData, rejectedData) {
                            final highlighted = candidateData.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: EdgeInsets.all(highlighted ? 7 : 0),
                              decoration: BoxDecoration(
                                color: highlighted ? _colors.tintStrong : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.m),
                                border: highlighted ? Border.all(color: _colors.accentSoftBorder, width: 1.5) : null,
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  _systemIconWidget(period == 'Matin' ? 'periodMorning' : period == 'Après-midi' ? 'periodAfternoon' : 'periodEvening', fallback: period == 'Matin' ? '🌤️' : period == 'Après-midi' ? '🌿' : '🌙', size: 16),
                                  const SizedBox(width: 6),
                                  Text(period, style: GoogleFonts.nunitoSans(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                                  const SizedBox(width: 9),
                                  Expanded(child: Divider(height: 1, thickness: .8, color: _colors.borderTint)),
                                  if (highlighted) ...[
                                    const SizedBox(width: 7), _systemIconWidget('dragDown', fallback: '↓', size: 15),
                                    const SizedBox(width: 3), Text('Déposer ici', style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _colors.accentIcon)),
                                  ],
                                ]),
                                if (periodItems.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
                                    child: Text(highlighted ? 'Déposer l’activité ici' : 'Temps libre', style: TextStyle(fontSize: AppType.body, color: highlighted ? _colors.accentIcon : _colors.textMuted, fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal)),
                                  )
                                else ...[
                                  ...periodItems.map((item) {
                                    final activity = item.activityId == null ? null : findActivity(item.activityId!);
                                    if (activity != null && !_isSportActivity(activity)) {
                                      return _weekNonSportPlanCard(item, activity);
                                    }
                                    return planRow(item);
                                  }),
                                ],
                              ]),
                            );
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => addUnplannedToDay(selectedDay),
                        icon: _uiIcon('add', Icons.add, size: 18),
                        label: const Text('Ajouter autre chose'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 18)),
      ],
    );
  }

  Widget buildActivities() {
    final cats = <String>['Toutes', 'Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social'];
    final query = _activitySearchQuery.trim().toLowerCase();
    final filtered = activities.where((a) {
      final matchesCategory = categoryFilter == 'Toutes' || a.category == categoryFilter;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return a.name.toLowerCase().contains(query) || a.category.toLowerCase().contains(query);
    }).toList();

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: _showActivitySearch
                      ? TextField(
                          autofocus: true,
                          onChanged: _updateActivitySearch,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Rechercher une activité',
                            prefixIcon: _systemIconWidget('search', fallback: '🔎', size: 20),
                            suffixIcon: IconButton(
                              tooltip: 'Fermer la recherche',
                              onPressed: _closeActivitySearch,
                              icon: _uiIcon('close', Icons.close_rounded, size: 19),
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: _colors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.l),
                              borderSide: BorderSide(color: _colors.borderStrong),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.l),
                              borderSide: BorderSide(color: _colors.borderStrong),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.l),
                              borderSide: BorderSide(color: _colors.accentSoftBorder),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mes activités',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontFamily: GoogleFonts.lora().fontFamily,
                                    fontFamilyFallback: const ['Times New Roman', 'serif'],
                                    fontWeight: FontWeight.w700,
                                    color: _colors.textStrong,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _activitySearchQuery.trim().isEmpty
                                  ? '${activities.length} activités'
                                  : '${filtered.length} résultat(s) sur ${activities.length}',
                              style: GoogleFonts.nunitoSans(fontSize: AppType.bodyL, color: _colors.textMuted),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  tooltip: 'Rechercher',
                  onPressed: _openActivitySearch,
                  icon: _systemIconWidget('search', fallback: '🔎', size: 21),
                ),
                IconButton(
                  onPressed: openHistory,
                  tooltip: 'Historique',
                  icon: _systemIconWidget('history', fallback: '📖', size: 21),
                ),
                if (activities.any(_isSportActivity))
                  IconButton(
                    onPressed: openSportWeekOverview,
                    tooltip: 'Semaine Sport',
                    icon: _systemIconWidget('sportWeek', fallback: '🗓️', size: 21),
                  ),
                IconButton(
                  tooltip: 'Ajouter une activité',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => addOrEditActivity(),
                  icon: _systemIconWidget('add', fallback: '➕', size: 22),
                ),
                IconButton(
                  tooltip: 'Système · personnaliser',
                  onPressed: _openSystemMenu,
                  icon: _systemIconWidget('system', fallback: '⚙️', size: 21),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 1, 18, 7),
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(cats[i]),
                selected: categoryFilter == cats[i],
                onSelected: (_) => setState(() => categoryFilter = cats[i]),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.body),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final a = filtered[index];
              final frozen = a.isFrozen;
              final sportWaiting = a.category == 'Sport' && !a.isSportProgram && !a.activeInSportRotation;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: this._pastelFor(a.category),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    side: a.category == 'Sport'
                        ? BorderSide(color: _colors.borderTint, width: 1)
                        : BorderSide(color: _colors.border, width: 0.45),
                  ),
                  child: InkWell(
                    onTap: () => addOrEditActivity(original: a),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 9, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            onTap: () => _editActivityIcon(a),
                            child: Tooltip(
                              message: 'Modifier l’icône',
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: this._pastelFor(a.category),
                                child: _activityIconWidget(a.emoji, size: 30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: _detailTitleStyle(),
                                      ),
                                    ),
                                    if (frozen)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Tooltip(
                                          message: 'Activité gelée',
                                          child: _systemIconWidget('frozen', fallback: '🧊', size: 17),
                                        ),
                                      ),
                                    if (frozen || sportWaiting)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _colors.surfaceSunken,
                                          borderRadius: BorderRadius.circular(AppRadius.s),
                                        ),
                                        child: Text(
                                          frozen ? 'GELÉE' : 'PLUS TARD',
                                          style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: _colors.danger),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                if (a.isSportProgram || a.isDateRange || a.category == 'Sport')
                                  Text(
                                    a.isSportProgram
                                        ? 'Programme Sport · ${a.sportDailyDurations.values.where((v) => v > 0).fold<int>(0, (s, v) => s + v)} min/sem.'
                                        : a.isDateRange
                                            ? '${a.category} · ${_dateRangeLabel(a)}'
                                            : '${a.category} · ${a.duration} min · ${a.frequency}×/sem.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: AppType.label, color: _colors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: frozen ? 'Reprendre l’activité' : 'Geler l’activité',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => _toggleActivityFrozen(a),
                            icon: _uiIcon(frozen ? 'add' : 'remove', frozen ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded, size: 19, color: _colors.textMuted),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            tooltip: 'Voir l’historique',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => _evo8OpenActivityMiniHistory(a),
                            icon: _systemIconWidget('history', fallback: '📖', size: 19),
                          ),
                          _uiIcon('planOpen', Icons.chevron_right_rounded, size: 20, color: _colors.textMuted),
                            ],
                          ),
                          if (a.category != 'Sport' && !a.isSportProgram && !a.isDateRange)
                            _nonSportWeeklyIndicator(a),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}
