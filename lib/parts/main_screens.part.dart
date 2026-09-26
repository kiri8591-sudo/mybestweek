// V8.99 — Écrans principaux
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _MainScreensPart on _MaBelleSemaineAppState {
  Widget _kawaiiNavIcon(String emoji, Color bg, Color fg, {bool selected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 42 : 38,
      height: selected ? 34 : 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(selected ? 14 : 12),
        border: Border.all(color: fg.withOpacity(selected ? .20 : .13), width: 1),
        boxShadow: selected
            ? [const BoxShadow(color: Color(0x12000000), blurRadius: 7, offset: Offset(0, 2))]
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
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: GoogleFonts.lora().fontFamily, fontWeight: FontWeight.w700, color: const Color(0xFF3B4842), letterSpacing: -0.35, fontSize: 21, height: 1.12)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunitoSans(fontSize: 12.2, color: const Color(0xFF747B75), height: 1.28)),
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
        color: const Color(0xFFFFF4EA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE7D4C6), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * .025),
        child: Image.memory(_bearHeadBytes, fit: BoxFit.contain, filterQuality: FilterQuality.medium, gaplessPlayback: true),
      ),
    );
  }

  Widget buildHome() {
    final todayItems = itemsForDay(today);
    final todaySportItems = _sportItemsForDay(today);
    final todayOtherItems = todayItems.where((item) {
      if (item.activityId == null) return true;
      final activity = findActivity(item.activityId!);
      return activity == null || !_isSportActivity(activity);
    }).toList();
    final trackableItems = plan.where((p) => p.activityId != null && !_isDateRangePlanItem(p)).toList();
    final completed = trackableItems.where((x) => x.done).length;
    final progress = trackableItems.isEmpty ? 0.0 : completed / trackableItems.length;
    final todayActionItems = todayItems.where((x) => !_isDateRangePlanItem(x)).toList();
    final todayCompleted = todayActionItems.isNotEmpty && todayActionItems.every((x) => x.done);
    final todayDone = todayActionItems.where((x) => x.done).length;
    final sportBudget = _sportBudgetForDay(today);

    Widget softCard({
      required Widget child,
      required Color color,
      EdgeInsetsGeometry padding = const EdgeInsets.all(15),
      double radius = 26,
      Color? borderColor,
    }) => Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? const Color(0xFFE8DED2)),
        boxShadow: const [BoxShadow(color: Color(0x0E000000), blurRadius: 16, offset: Offset(0, 5))],
      ),
      padding: padding,
      child: child,
    );

    Widget pill(String text, {Color bg = const Color(0xFFFFFCF7), Color fg = const Color(0xFF60786B)}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFE6DBCF))),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg)),
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
                color: highlighted ? const Color(0xFFDCEBE5) : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                border: highlighted ? Border.all(color: const Color(0xFF8EAD9F), width: 1.5) : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0EB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD2E1D8)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _systemIconWidget(period == 'Matin' ? 'periodMorning' : period == 'Après-midi' ? 'periodAfternoon' : 'periodEvening', fallback: period == 'Matin' ? '🌤️' : period == 'Après-midi' ? '🌿' : '🌙', size: 20),
                      const SizedBox(width: 6),
                      Text(period, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF41514A), letterSpacing: .05)),
                    ]),
                  ),
                  if (highlighted) ...[
                    const SizedBox(width: 7),
                    const Icon(Icons.south, size: 15, color: Color(0xFF6F8E80)),
                    const SizedBox(width: 3),
                    const Text('Déposer ici', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6F8E80))),
                  ],
                ]),
                if (periodItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
                    child: Text(
                      highlighted ? 'Déposer l’activité ici' : 'Temps libre',
                      style: TextStyle(fontSize: 12.5, color: highlighted ? const Color(0xFF6F8E80) : const Color(0xFF7A807D), fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal),
                    ),
                  )
                else
                  ...periodItems.map(planRow),
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
              color: const Color(0xFFFFF1DE),
              borderColor: const Color(0xFFF0D7B6),
              radius: 28,
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _homeMascotAvatar(size: 56),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _userName.trim().isEmpty ? 'Bonjour 👋' : 'Bonjour ${_userName.trim()} 👋',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3F4B45), letterSpacing: -0.3),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFCF7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_MaBelleSemaineAppState.version, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF7A807D))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dateText()} · ${_clockText()} · ${_dayMoment()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF756E67)),
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
                        icon: _uiIcon('refresh', Icons.autorenew_rounded, size: 18, color: const Color(0xFF6F8E80)),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Réglages',
                        padding: EdgeInsets.zero,
                        icon: _uiIcon('settings', Icons.more_horiz_rounded, size: 18, color: const Color(0xFF6F7B74)),
                        onSelected: (value) {
                          if (value == 'data') openDataManager();
                          if (value == 'identity') _editHomeIdentity();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'data',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _uiIcon('save', Icons.save_outlined, size: 18),
                              title: const Text('Sauvegarde & données'),
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_weatherCity.trim().isEmpty ? '🌤️' : _weatherIcon, style: const TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _weatherCity.trim().isEmpty
                              ? 'Ajoute ta ville pour la météo'
                              : '${_weatherCity.trim()}${_weatherTemperature.isEmpty ? '' : ' · ${_weatherTemperature}'}${_weatherText.isEmpty ? '' : ' · ${_weatherText.toLowerCase()}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w900, color: Color(0xFF536660)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💭', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _morningThought,
                          maxLines: 3,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(fontSize: 10.1, height: 1.16, fontStyle: FontStyle.italic, color: Color(0xFF5D554B)),
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: refreshMorningThought,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1, left: 3),
                          child: _uiIcon('coach', Icons.auto_awesome_rounded, size: 14, color: const Color(0xFF9C8866)),
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
                          borderRadius: BorderRadius.circular(10),
                          onTap: _openTodayDailySummary,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(summary.moodEmoji, style: const TextStyle(fontSize: 17)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _todayMoodComment(summary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9.7, height: 1.16, fontWeight: FontWeight.w800, color: Color(0xFF6B756F)),
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
        if (_cloudBackupReminderDue)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 1, 16, 5),
              child: softCard(
                color: const Color(0xFFF4EFE4),
                borderColor: const Color(0xFFE4D6B9),
                radius: 18,
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                child: Row(
                  children: [
                    const Text('☁️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Pense à faire une sauvegarde iCloud : ta dernière copie confirmée date de plus de ${_MaBelleSemaineAppState._cloudBackupReminderDays} jours.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.w800, color: Color(0xFF6F624E), height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: exportBackupToICloud,
                      child: const Text('Sauvegarder'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_showMondayRegenerationPrompt)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 1, 16, 5),
              child: softCard(
                color: const Color(0xFFEAF3EE),
                borderColor: const Color(0xFFD3E3D9),
                radius: 19,
                padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'C’est lundi 🌱. Tu peux repenser ta semaine à partir de ton historique et de tes critères.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.7, fontWeight: FontWeight.w800, color: Color(0xFF526A5E), height: 1.22),
                      ),
                    ),
                    const SizedBox(width: 5),
                    FilledButton.tonalIcon(
                      onPressed: openGenerationCriteria,
                      icon: _uiIcon('coach', Icons.auto_awesome_outlined, size: 15),
                      label: const Text('Repenser'),
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pas maintenant',
                      visualDensity: VisualDensity.compact,
                      onPressed: _dismissMondayRegenerationPrompt,
                      icon: _uiIcon('close', Icons.close_rounded, size: 17),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_lastPlanningRegeneratedWeekKey == _currentWeekKey() && _lastPlanningRegeneratedDays.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 1, 16, 5),
              child: softCard(
                color: const Color(0xFFE8F0EA),
                borderColor: const Color(0xFFD2E0D6),
                radius: 18,
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _uiIcon('refresh', Icons.autorenew_rounded, size: 18, color: const Color(0xFF6F8E80)),
                    const SizedBox(width: 7),
                    Expanded(child: Text(
                      'Planning régénéré : ${_regeneratedDaysMessage()}. Le passé et aujourd’hui ont été conservés.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.3, fontWeight: FontWeight.w800, color: Color(0xFF526A5E), height: 1.2),
                    )),
                  ]),
                  if (_lastPlanningCoachExplanation.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.only(left: 25),
                      child: Text(
                        _lastPlanningCoachExplanation,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.8, color: Color(0xFF6A756F), height: 1.2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: openPlanningCoachDecisions,
                      icon: _uiIcon('coach', Icons.psychology_outlined, size: 15, color: const Color(0xFF6F8E80)),
                      label: const Text('Pourquoi ?'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 1, 16, 5),
            child: softCard(
              color: const Color(0xFFEAF6EE),
              borderColor: const Color(0xFFD5E7DA),
              radius: 20,
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
              child: Row(
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trackableItems.isEmpty
                          ? 'Ma semaine démarre doucement.'
                          : completed == trackableItems.length
                              ? 'Ma semaine est accomplie ✨'
                              : 'Ma semaine avance · ${trackableItems.length - completed} moment(s) restent à vivre.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.1, height: 1.2, fontWeight: FontWeight.w800, color: Color(0xFF5E7168)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${(progress * 100).round()} %', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF527061))),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: const Color(0xFFDCE9DF), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF88AE98))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 1, 16, 8),
            child: softCard(
              color: const Color(0xFFF0F7F3),
              borderColor: const Color(0xFFD7E6DE),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          todayCompleted
                              ? SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: _CompletionCelebration(
                                    key: ValueKey('completion-${todayActionItems.length}'),
                                  ),
                                )
                              : Text(_focusIcon, style: const TextStyle(fontSize: 19)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('FOCUS DU JOUR', style: TextStyle(fontSize: 7.7, fontWeight: FontWeight.w900, color: Color(0xFF9A7758), letterSpacing: .35)),
                                const SizedBox(height: 1),
                                Text(_todayFocus(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.1, fontWeight: FontWeight.w900, color: Color(0xFF564944), height: 1.12)),
                                if (todayCompleted) ...[
                                  const SizedBox(height: 3),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _openTodayDailySummary,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text(_todayDailySummary()?.moodEmoji ?? '🙂', style: const TextStyle(fontSize: 13)),
                                        const SizedBox(width: 4),
                                        const Text('Voir le petit bilan', style: TextStyle(fontSize: 9.4, fontWeight: FontWeight.w900, color: Color(0xFF718079))),
                                      ]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 19)),
                        const SizedBox(width: 5),
                        const Text('Aujourd’hui', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF3F5047))),
                        if (todayActionItems.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          pill('$todayDone/${todayActionItems.length}', bg: const Color(0xFFF9FCFA)),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(todayItems.isEmpty ? 'Journée libre. Profite-en.' : 'Tes petits moments de la journée.', style: const TextStyle(fontSize: 10.2, color: Color(0xFF6C7771))),
                const SizedBox(height: 9),
                if (todayOtherItems.where(_isDateRangePlanItem).isNotEmpty)
                  _multiDaySection(todayOtherItems.where(_isDateRangePlanItem).toList(), day: today),
                if (sportBudget > 0 || todaySportItems.isNotEmpty) _sportDayCard(today),
                if (sportBudget > 0 || todaySportItems.isNotEmpty) const SizedBox(height: 5),
                ...const ['Matin', 'Après-midi', 'Soir'].map(todayPeriod),
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 1, 16, 8),
            child: softCard(
              color: const Color(0xFFEAF1F8),
              borderColor: const Color(0xFFD8E1EC),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  mascotAvatar(size: 42),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('Coach Sport', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF4A5864)))),
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'Journal du coach Sport', onPressed: openSportCoachJournal, icon: _uiIcon('history', Icons.menu_book_rounded, size: 18, color: const Color(0xFF6B7884))),
                ]),
                const SizedBox(height: 5),
                Text(sportCoachLastAnalysis.isEmpty ? 'Je veille à garder une semaine souple et agréable.' : sportCoachLastAnalysis, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, height: 1.34, color: Color(0xFF596670), fontWeight: FontWeight.w600)),
                if (sportCoachSuggestion.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 7, 8),
                    decoration: BoxDecoration(color: const Color(0xFFF8FBFE), borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(sportCoachSuggestion, style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF52616B)))),
                      const SizedBox(width: 5),
                      FilledButton.tonalIcon(onPressed: applySportCoachSuggestion, icon: _uiIcon('apply', Icons.bolt_rounded, size: 14, color: const Color(0xFF60786B)), label: const Text('Appliquer'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 1, 16, 12),
            child: Row(children: [
              Expanded(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: openWeeklyReview, child: softCard(color: const Color(0xFFF5ECFF), borderColor: const Color(0xFFE4D7EF), radius: 22, padding: const EdgeInsets.fromLTRB(11, 11, 9, 11), child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFE7D6F0), borderRadius: BorderRadius.circular(13)), child: const Center(child: Text('📊', style: TextStyle(fontSize: 20)))),
                const SizedBox(width: 8),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Bilan', style: TextStyle(fontSize: 12.3, fontWeight: FontWeight.w900, color: Color(0xFF5C5165))), SizedBox(height: 2), Text('Ma semaine', style: TextStyle(fontSize: 9.4, color: Color(0xFF756B7D)))])),
                const Icon(Icons.chevron_right_rounded, size: 19, color: Color(0xFF8A7D94)),
              ])))),
              const SizedBox(width: 9),
              Expanded(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: openSportWeekOverview, child: softCard(color: const Color(0xFFEAF7EF), borderColor: const Color(0xFFD7E9DD), radius: 22, padding: const EdgeInsets.fromLTRB(11, 11, 9, 11), child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFD8EEDC), borderRadius: BorderRadius.circular(13)), child: Center(child: _activityIconWidget(_sportProgram?.emoji ?? '🏃', size: 22))),
                const SizedBox(width: 8),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sport', style: TextStyle(fontSize: 12.3, fontWeight: FontWeight.w900, color: Color(0xFF4D6858))), SizedBox(height: 2), Text('Semaine Sport', style: TextStyle(fontSize: 9.4, color: Color(0xFF68796E)))])),
                const Icon(Icons.chevron_right_rounded, size: 19, color: Color(0xFF789082)),
              ])))),
            ]),
          ),
        ),
      ],
    );
  }

  Widget buildWeek() {
    final trackable = plan.where((p) => p.activityId != null).toList();
    final totalMinutes = trackable.fold<int>(0, (sum, p) => sum + p.duration);
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
                        color: const Color(0xFFE7EDF0),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: _uiIcon('calendar', Icons.event_note_outlined, size: 20, color: const Color(0xFF526B78)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalMinutes min prévues', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('${completedCount()} moment(s) validé(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF6F7777))),
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
        if (_lastPlanningRegeneratedWeekKey == _currentWeekKey() && _lastPlanningRegeneratedDays.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Card(
                color: const Color(0xFFE8F0EA),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _uiIcon('refresh', Icons.autorenew_rounded, size: 18, color: const Color(0xFF6F8E80)),
                    const SizedBox(width: 7),
                    Expanded(child: Text('Régénération : ${_regeneratedDaysMessage()}. Le passé et aujourd’hui restent inchangés.', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF526A5E)))),
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
                            ? const Color(0xFFDCE5E7)
                            : const Color(0xFFFFFDF9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF9FB2B8)
                              : const Color(0xFFE0DDD5),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNames[day].substring(0, 3),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? const Color(0xFF526B78) : const Color(0xFF727977),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _weekDateShortLabel(day),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: isToday ? const Color(0xFFC67E67) : const Color(0xFF8A8D88),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dayItems.length}',
                            style: TextStyle(
                              fontSize: 18,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? const Color(0xFF33414A) : const Color(0xFF596563),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_lastPlanningRegeneratedWeekKey == _currentWeekKey() && _lastPlanningRegeneratedDays.contains(day))
                            const Text(
                              'régénéré',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 7.6, fontWeight: FontWeight.w900, color: Color(0xFF6F8E80)),
                            )
                          else
                            Text(
                              done == 0 ? (isToday ? 'aujourd’hui' : 'à faire') : '$done ✓',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: done > 0 ? const Color(0xFF6F8E80) : const Color(0xFF8A8D88),
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
              color: const Color(0xFFE5EEE9),
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
                      color: const Color(0xFF6F8E80),
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _weeklyPlanningMessage(selectedDay),
                        style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600),
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
              color: const Color(0xFFE7EDF0),
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
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21, color: Color(0xFF33414A)),
                          ),
                        ),
                        if (selectedDay == today)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCE5E7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'AUJOURD’HUI',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF526B78)),
                            ),
                          ),
                        const SizedBox(width: 3),
                        IconButton(
                          tooltip: 'Ajouter un moment',
                          onPressed: () => addUnplannedToDay(selectedDay),
                          icon: _uiIcon('add', Icons.add_circle_outline, size: 18, color: const Color(0xFF526B78)),
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF65706D)),
                          ),
                        ),
                        if (_sportBudgetForDay(selectedDay) > 0)
                          Text(
                            'Sport ${_sportBudgetForDay(selectedDay)} min',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF6F8E80)),
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
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF718079)),
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
                                color: highlighted ? const Color(0xFFDCEBE5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(13),
                                border: highlighted ? Border.all(color: const Color(0xFF8EAD9F), width: 1.5) : null,
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F0EB),
                                      borderRadius: BorderRadius.circular(13),
                                      boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 5, offset: Offset(0, 2))],
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      _systemIconWidget(period == 'Matin' ? 'periodMorning' : period == 'Après-midi' ? 'periodAfternoon' : 'periodEvening', fallback: period == 'Matin' ? '🌤️' : period == 'Après-midi' ? '🌿' : '🌙', size: 19),
                                      const SizedBox(width: 6),
                                      Text(period, style: GoogleFonts.nunitoSans(fontSize: 15.5, fontWeight: FontWeight.w900, color: const Color(0xFF405049), letterSpacing: .05)),
                                    ]),
                                  ),
                                  if (highlighted) ...[
                                    const SizedBox(width: 7), const Icon(Icons.south, size: 15, color: Color(0xFF6F8E80)),
                                    const SizedBox(width: 3), const Text('Déposer ici', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6F8E80))),
                                  ],
                                ]),
                                if (periodItems.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
                                    child: Text(highlighted ? 'Déposer l’activité ici' : 'Temps libre', style: TextStyle(fontSize: 12.5, color: highlighted ? const Color(0xFF6F8E80) : const Color(0xFF7A807D), fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal)),
                                  )
                                else ...periodItems.map(planRow),
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
    final filtered = categoryFilter == 'Toutes'
        ? activities
        : activities.where((a) => a.category == categoryFilter).toList();

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mes activités',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontFamily: GoogleFonts.lora().fontFamily,
                              fontFamilyFallback: const ['Times New Roman', 'serif'],
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF33414A),
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${activities.length} activités',
                        style: GoogleFonts.nunitoSans(fontSize: 13, color: const Color(0xFF6F7777)),
                      ),
                    ],
                  ),
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
                    icon: _systemIconWidget('sport', fallback: '💪', size: 21),
                  ),
                FilledButton(
                  onPressed: () => addOrEditActivity(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _systemIconWidget('add', fallback: '➕', size: 22),
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
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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
              final sportWaiting = a.category == 'Sport' && !a.isSportProgram && !a.activeInSportRotation;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: this._pastelFor(a.category),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: a.category == 'Sport'
                        ? const BorderSide(color: Color(0xFFDCE5E0), width: 1)
                        : const BorderSide(color: Color(0xFFF0EDE7), width: 0.45),
                  ),
                  child: InkWell(
                    onTap: () => addOrEditActivity(original: a),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 9, 12),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
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
                                    if (sportWaiting)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1EEE8),
                                          borderRadius: BorderRadius.circular(9),
                                        ),
                                        child: const Text(
                                          'PLUS TARD',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF8E756A)),
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
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6F7777)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF899398)),
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
