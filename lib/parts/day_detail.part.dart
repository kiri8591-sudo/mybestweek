// V12.22.0 — Détail d'un jour (vues mensuelles, calendriers de statistiques) et détail d'une catégorie.

part of '../main.dart';

String _longDayLabel(DateTime d) => '${_frWeekdaysLong[d.weekday - 1]} ${d.day} ${_frMonthsLong[d.month - 1]} ${d.year}';

/// Feuille « détail d'un jour » : réalisations du jour, avec actions quand une activité est ciblée.
Future<void> _showDayDetailSheet(
  BuildContext context, {
  required DateTime date,
  required List<ActivityLog> dayLogs,
  Activity? activity,
  VoidCallback? onToggle,
  VoidCallback? onEditAmount,
  Future<void> Function(ActivityLog log)? onEditLog,
  void Function(ActivityLog log)? onOpenLog,
}) {
  final sorted = [...dayLogs]..sort((a, b) => a.date.compareTo(b.date));
  final timeMinutes = _timeMinutesOf(sorted);
  final countLogs = sorted.where(_logIsCount).toList();
  final repsTotal = _repsTotal(sorted);
  final isRepsOnly = activity != null && _isRepsOnly(activity);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .78),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
          children: [
            _SheetHeader(
              leading: activity != null
                  ? _activityIconWidget(activity.emoji, size: 26)
                  : _uiIcon('calendar', Icons.event_note_outlined, size: 24, color: _colors.accentIcon),
              title: activity?.name ?? 'Détail du jour',
              subtitle: _longDayLabel(date),
            ),
            const SizedBox(height: AppSpace.m),
            if (sorted.isEmpty)
              _AppCard(
                tone: _CardTone.soft,
                child: Text('Aucune réalisation ce jour.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
              )
            else ...[
              Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
                if (timeMinutes > 0) _Pill(_minutesLabel(timeMinutes)),
                if (countLogs.isNotEmpty && repsTotal == 0) _Pill('${countLogs.length}×'),
                if (repsTotal > 0) _Pill('$repsTotal rép.'),
                _Pill('${sorted.length} réalisation${sorted.length > 1 ? 's' : ''}', background: _colors.surfaceSunken, foreground: _colors.textMuted),
              ]),
              const SizedBox(height: AppSpace.m),
              for (final log in sorted)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s),
                  child: _AppCard(
                    tone: _CardTone.soft,
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    onTap: onOpenLog == null
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            onOpenLog(log);
                          },
                    child: Row(children: [
                      _activityIconWidget(log.emoji, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(log.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (log.feeling.isNotEmpty) ...[
                              Container(width: 9, height: 9, decoration: BoxDecoration(color: _feelingColor(_normalizeFeeling(log.feeling)), shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(_normalizeFeeling(log.feeling), style: TextStyle(fontSize: AppType.small, color: _colors.textMuted)),
                              const SizedBox(width: 8),
                            ],
                            if (log.unplanned) Text('imprévu', style: TextStyle(fontSize: AppType.small, color: _colors.goldText)),
                          ]),
                        ]),
                      ),
                      _Pill(_logAmountLabel(log)),
                      if (onEditLog != null)
                        IconButton(
                          tooltip: 'Modifier',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await onEditLog(log);
                          },
                          icon: Icon(Icons.edit_outlined, size: 18, color: _colors.textMuted),
                        )
                      else
                        const SizedBox(width: 8),
                    ]),
                  ),
                ),
            ],
            if (activity != null && (onToggle != null || onEditAmount != null)) ...[
              const SizedBox(height: AppSpace.s),
              Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
                if (onToggle != null)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onToggle();
                    },
                    icon: Icon(sorted.isEmpty ? Icons.check_rounded : Icons.undo_rounded, size: 18),
                    label: Text(sorted.isEmpty ? 'Marquer comme fait' : 'Retirer ce jour'),
                  ),
                if (onEditAmount != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onEditAmount();
                    },
                    icon: Icon(isRepsOnly || _isRepsActivity(activity) ? Icons.repeat_rounded : Icons.timer_outlined, size: 18),
                    label: Text(isRepsOnly ? 'Répétitions' : 'Saisir le temps'),
                  ),
              ]),
            ],
          ],
        ),
      ),
    ),
  );
}

extension _CategoryDetailPart on _StatsOverviewPageState {
  /// Détail d'une catégorie de l'anneau « Total investi » : activités, parts, dernières réalisations.
  void _openCategoryDetail(String title, List<String> categories, List<ActivityLog> periodLogs) {
    final catSet = categories.toSet();
    final inCat = periodLogs.where((l) => catSet.contains(l.category.trim().isEmpty ? 'Autre' : l.category.trim())).toList();
    if (inCat.isEmpty) return;
    final totals = _activityTotals(inCat);
    final timeTotal = _timeMinutesOf(inCat);
    final countTotal = inCat.where(_logIsCount).length;
    final recent = [...inCat]..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpace.l, 0, AppSpace.l, AppSpace.l),
            children: [
              _SheetHeader(
                leading: _uiIcon('insights', Icons.donut_large_rounded, size: 24, color: _colors.accentIcon),
                title: title,
                subtitle: _period == 'Tout' ? 'Toute la période' : _period,
              ),
              const SizedBox(height: AppSpace.m),
              Wrap(spacing: AppSpace.s, runSpacing: 6, children: [
                if (timeTotal > 0) _Pill(_minutesLabel(timeTotal)),
                if (countTotal > 0) _Pill('$countTotal occurrence${countTotal > 1 ? 's' : ''}'),
                _Pill('${totals.length} activité${totals.length > 1 ? 's' : ''}', background: _colors.surfaceSunken, foreground: _colors.textMuted),
                _Pill('${inCat.length} réalisation${inCat.length > 1 ? 's' : ''}', background: _colors.surfaceSunken, foreground: _colors.textMuted),
              ]),
              const SizedBox(height: AppSpace.l),
              Text('Par activité', style: _sectionTitleStyle(sheetContext)),
              const SizedBox(height: AppSpace.s),
              for (final item in totals)
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openActivity(item.activity);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: _colors.tintStrong, child: _activityIconWidget(item.activity.emoji, size: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item.activity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong))),
                        Text(
                          item.isCount ? '${item.minutes} ${_amountUnit(item.activity)}' : _minutesLabel(item.minutes),
                          style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w800, color: _colors.textStrong),
                        ),
                        if (!item.isCount && timeTotal > 0)
                          SizedBox(width: 44, child: Text('${(item.minutes * 100 / timeTotal).round()} %', textAlign: TextAlign.right, style: TextStyle(fontSize: AppType.small, color: _colors.textMuted))),
                        Icon(Icons.chevron_right_rounded, size: 18, color: _colors.textMuted),
                      ]),
                      if (!item.isCount && timeTotal > 0) ...[
                        const SizedBox(height: 5),
                        _MeterBar(value: item.minutes / timeTotal, height: 6),
                      ],
                    ]),
                  ),
                ),
              const SizedBox(height: AppSpace.m),
              Text('Dernières réalisations', style: _sectionTitleStyle(sheetContext)),
              const SizedBox(height: AppSpace.s),
              for (final log in recent.take(6))
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await widget.onEditLog(log);
                    if (mounted) setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Expanded(child: Text('${log.title} · ${_friendlyDayLabel(log.date, now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.body, color: _colors.textStrong))),
                      Text(_logAmountLabel(log), style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 14, color: _colors.textFaint),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
