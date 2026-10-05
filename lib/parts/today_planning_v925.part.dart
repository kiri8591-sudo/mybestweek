// V8.95 — Vue du jour : périodes et cartes du planning
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _TodayPlanningPart on _MaBelleSemaineAppState {
  Future<void> _moveTodayGenericActivityPeriod(PlanItem item, String targetPeriod) async {
    if (!_isGenericActivityItem(item) || item.day != today) return;
    if (item.period == targetPeriod) return;
    final fromPeriod = item.period == 'Midi' ? 'Après-midi' : item.period;
    setState(() {
      item.period = targetPeriod;
      item.manualPlacement = true;
      _recordActivityMove(item, fromDay: item.day, fromPeriod: fromPeriod, toDay: item.day, toPeriod: targetPeriod);
      _sortPlan();
    });
    _queueLocalStatePersist();
    _showFeedback('« ${item.title} » déplacée vers $targetPeriod.');
  }

  Widget _todayPeriodSection(String label, List<PlanItem> items) {
    final isDropPeriod = const ['Matin', 'Après-midi', 'Soir'].contains(label);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DragTarget<PlanItem>(
        onWillAcceptWithDetails: (details) => isDropPeriod && _isGenericActivityItem(details.data) && details.data.day == today && details.data.period != label,
        onAcceptWithDetails: (details) => _moveTodayGenericActivityPeriod(details.data, label),
        builder: (context, candidateData, rejectedData) {
          final highlighted = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.all(highlighted ? 7 : 0),
            decoration: BoxDecoration(
              color: highlighted ? _colors.tintStrong : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: highlighted ? Border.all(color: _colors.accentSoftBorder, width: 1.5) : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: _colors.tintStrong,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    boxShadow: [BoxShadow(color: _colors.shadow, blurRadius: 5, offset: Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label == 'Matin' ? '🌤️' : label == 'Après-midi' ? '🌿' : '🌙', style: const TextStyle(fontSize: AppType.title, height: 1)),
                    const SizedBox(width: 6),
                    Text(label, style: GoogleFonts.nunitoSans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: _colors.textStrong, letterSpacing: .05)),
                  ]),
                ),
                if (highlighted) ...[
                  const SizedBox(width: 7),
                  _systemIconWidget('dragDown', fallback: '↓', size: 16),
                  const SizedBox(width: 3),
                  Text('Déposer ici', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.accentIcon)),
                ],
              ]),
              const SizedBox(height: 4),
              if (items.isEmpty && highlighted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .65), borderRadius: BorderRadius.circular(AppRadius.m)),
                  child: Center(child: Text('Déposer l’activité ici', style: TextStyle(fontWeight: FontWeight.w700, color: _colors.accentIcon))),
                )
              else
                ...items.map(todayCard),
            ]),
          );
        },
      ),
    );
  }

  Widget todayCard(PlanItem item) {
    final activity = item.activityId == null ? null : findActivity(item.activityId!);
    final category = activity?.category ?? (item.customCategory ?? 'Autre');
    final bg = item.optional ? _colors.surfaceSunken : _pastelFor(category);
    final card = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 9, 6, 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.l), boxShadow: [BoxShadow(color: _colors.shadowSoft, blurRadius: 5, offset: Offset(0, 2))]),
        child: Row(
          children: [
            Checkbox(
              value: item.done,
              onChanged: (value) {
                openPlanItem(item);
              },
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
            ),
            const SizedBox(width: 2),
            if (activity != null || item.customEmoji != null) ...[
              _activityIconWidget(_planItemIconValue(item, activities), size: 30),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.m),
                onTap: () { final a = item.activityId == null ? null : findActivity(item.activityId!); if (a != null && _isSportActivity(a)) { addOrEditActivity(original: a); } else if (_isGenericActivityItem(item)) { _openGenericActivity(item); } else { openItemActions(item); } },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Row(children: [
                        Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _detailTitleStyle(decoration: item.done ? TextDecoration.lineThrough : null))),
                        _frozenActivityMarker(activity),
                      ])),
                      if (_isGenericActivityItem(item)) ...[
                        if (plan.where((p) => p.day == item.day && p.activityId == item.activityId).length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Builder(builder: (_) {
                              final sameDay = plan.where((p) => p.day == item.day && p.activityId == item.activityId).toList();
                              final occurrence = sameDay.indexWhere((p) => p.id == item.id) + 1;
                              return Text('$occurrence/${sameDay.length}', style: _detailMetaStyle());
                            }),
                          ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    if (activity == null || activity.category == 'Sport')
                      Text(item.done ? '${item.realisedMinutes ?? item.duration} / ${item.duration} min · ✓ validé' : '${item.duration} min', style: _detailMetaStyle())
                    else if (item.done)
                      Text('✓ validé', style: _detailMetaStyle()),
                  ]),
                ),
              ),
            ),
            if (_isGenericActivityItem(item) && item.details != null)
              IconButton(
                tooltip: 'Pourquoi le coach a choisi ce moment ?',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showPlanItemCoachReason(item),
                icon: _uiIcon('coach', Icons.psychology_alt_outlined, size: 18, color: _colors.accentIcon),
              ),
            IconButton(
              tooltip: _isGenericActivityItem(item) ? 'Déplacer' : 'Voir / modifier',
              visualDensity: VisualDensity.compact,
              onPressed: () { final a = item.activityId == null ? null : findActivity(item.activityId!); if (a != null && _isSportActivity(a)) { addOrEditActivity(original: a); } else if (_isGenericActivityItem(item)) { _movePlanItemDay(item); } else { openItemActions(item); } },
              icon: _isGenericActivityItem(item) ? _uiIcon('calendar', Icons.event_outlined, size: 18) : _uiIcon('planOpen', Icons.chevron_right_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Retirer du jour',
              visualDensity: VisualDensity.standard,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: EdgeInsets.zero,
              onPressed: () => _removePlanOccurrence(item),
              icon: _systemIconWidget('remove', fallback: '➖', size: 20),
            ),
          ],
        ),
      ),
    );
    if (!_isGenericActivityItem(item) || item.day != today) return card;
    final feedback = Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Opacity(opacity: .88, child: card),
      ),
    );
    if (kIsWeb) {
      return Draggable<PlanItem>(
        data: item,
        maxSimultaneousDrags: 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: .32, child: card),
        child: card,
      );
    }
    return LongPressDraggable<PlanItem>(
      data: item,
      hapticFeedbackOnStart: true,
      maxSimultaneousDrags: 1,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: .32, child: card),
      child: card,
    );
  }

  void _showPlanItemCoachReason(PlanItem item) {
    final reason = item.details?.trim();
    if (reason == null || reason.isEmpty) {
      _showFeedback('Le coach n’a pas enregistré de raison particulière pour ce moment.');
      return;
    }
    showModalBottomSheet<void>(
      context: _navigatorKey.currentContext!,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _uiIcon('coach', Icons.psychology_alt_rounded, size: 21, color: _colors.accentIcon),
                const SizedBox(width: 8),
                Expanded(child: Text('Pourquoi ce choix ?', style: GoogleFonts.lora(fontSize: AppType.h2, fontWeight: FontWeight.w700, color: _colors.textStrong))),
              ]),
              const SizedBox(height: 12),
              Text(item.title, style: _detailTitleStyle()),
              const SizedBox(height: 7),
              Text(reason.replaceFirst('Coach : ', ''), style: _detailParagraphStyle()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodBadge(String period) {
    return Container(
      width: 67,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(color: _colors.card, borderRadius: BorderRadius.circular(AppRadius.m)),
      child: Text(period, textAlign: TextAlign.center, style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w800, color: _colors.accentText)),
    );
  }

  Color _pastelFor(String category) {
    switch (category) {
      case 'Sport': return _darkMode ? const Color(0xFF2A3C32) : const Color(0xFFE3ECE7);
      case 'Bien-être': return _darkMode ? const Color(0xFF2B3638) : const Color(0xFFE7EAEA);
      case 'Loisir': return _darkMode ? const Color(0xFF38342C) : const Color(0xFFE9E5DD);
      case 'Culture': return _darkMode ? const Color(0xFF3A3524) : const Color(0xFFF0E9D8);
      case 'Sortie': return _darkMode ? const Color(0xFF3A2D28) : const Color(0xFFF1E3DC);
      case 'Social': return _darkMode ? const Color(0xFF2A3440) : const Color(0xFFE2E8EC);
      default: return _darkMode ? const Color(0xFF303330) : const Color(0xFFEEECE7);
    }
  }

}
