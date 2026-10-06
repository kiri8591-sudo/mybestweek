// V9.21 — Composants UI réutilisables et feuilles secondaires
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

class _InfoSheet extends StatelessWidget {
  final PlanItem item;
  const _InfoSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: _detailTitleStyle()),
          const SizedBox(height: 8),
          Text(item.details ?? 'Un temps libre à organiser comme bon te semble.', style: _detailParagraphStyle()),
          const SizedBox(height: 10),
          Text((item.activityId == null || (item.activityId?.startsWith('sport-') ?? false))
              ? '${item.period} · ${item.duration} min${item.optional ? ' · optionnel' : ''}'
              : '${item.period}${item.optional ? ' · optionnel' : ''}', style: TextStyle(fontWeight: FontWeight.w700, color: _colors.accentText)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Très bien'))),
        ]),
      ),
    );
  }
}

class _DataPage extends StatefulWidget {
  final Future<void> Function() onICloudExport;
  final Future<bool> Function() onImport;
  final Future<void> Function() onReset;
  final String Function() getCloudBackupStatus;
  final int cloudReminderDays;

  const _DataPage({
    required this.onICloudExport,
    required this.onImport,
    required this.onReset,
    required this.getCloudBackupStatus,
    required this.cloudReminderDays,
  });

  @override
  State<_DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<_DataPage> {
  Widget _backupStep({
    required IconData icon,
    required String iconKey,
    required String title,
    required String text,
    required bool done,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? _colors.tintStrong : _colors.surfaceSunken,
            shape: BoxShape.circle,
          ),
          child: done ? Icon(Icons.check_rounded, size: 16, color: _colors.accentIcon) : _uiIcon(iconKey, icon, size: 16, color: _colors.textWarm),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppType.label,
                  fontWeight: FontWeight.w700,
                  color: _colors.textStrong,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppType.caption,
                  height: 1.22,
                  color: _colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context) async {
    final ok = await widget.onImport();
    if (mounted) setState(() {});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        content: Text(ok ? 'Sauvegarde restaurée avec succès.' : 'Aucune sauvegarde valide restaurée.'),
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _reset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialiser les données ?'),
        content: const Text(
          'Le planning, les validations, l’historique et le bilan seront effacés. Tes activités seront conservées telles qu’elles sont. Le planning restera vide jusqu’à ce que tu appuies sur « Repenser ».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await widget.onReset();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _iconBubble(IconData icon, {required Color background, required Color foreground, String? emoji, String? systemKey}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? _activityIconWidget(emoji, size: 26)
          : (systemKey == null ? Icon(icon, color: foreground, size: 23) : _uiIcon(systemKey!, icon, size: 23, color: foreground)),
    );
  }

  Widget _primaryCard({
    required BuildContext context,
    required Color background,
    required Color border,
    required Color accent,
    required IconData icon,
    String? emoji,
    String? systemKey,
    required String eyebrow,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? footer,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 7),
            color: _colors.shadow,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBubble(icon, systemKey: systemKey, background: border.withValues(alpha: .42), foreground: accent, emoji: emoji),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow.toUpperCase(), style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, letterSpacing: .6, color: _colors.textMuted)),
                    const SizedBox(height: 2),
                    Text(title, style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: AppType.label, height: 1.3, color: _colors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
                textStyle: const TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700),
              ),
              icon: systemKey == null ? Icon(icon, size: 18) : _uiIcon(systemKey!, icon, size: 18, color: Colors.white),
              label: Text(buttonLabel),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(footer, style: TextStyle(fontSize: AppType.caption, height: 1.25, color: _colors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _statusPill() {
    final cloudDone = !widget.getCloudBackupStatus().startsWith('Aucune');
    final label = cloudDone ? 'À jour' : 'À faire';
    final due = !cloudDone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: due ? _colors.goldBg : _colors.tintStrong,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: due ? _colors.goldBorder : _colors.borderTint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _uiIcon(due ? 'backupDue' : 'backupOk', due ? Icons.schedule_rounded : Icons.check_circle_outline_rounded, size: 14, color: due ? _colors.textWarm : _colors.accentIcon),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: due ? _colors.textWarm : _colors.accentIcon))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: _colors.surfaceSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Fermer',
          icon: _uiIcon('close', Icons.close_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text('Sauvegarde', style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _colors.textStrong)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_colors.tintSoft, _colors.surfaceSoft],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: _colors.borderTint),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _colors.card,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: _colors.shadow)],
                  ),
                  alignment: Alignment.center,
                  child: const Text('☁️', style: TextStyle(fontSize: AppType.hero)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tes données, au calme.', style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      SizedBox(height: 3),
                      Text('La sauvegarde sur cet appareil est automatique. La copie de sécurité se fait dans iCloud.', style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _colors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: _colors.borderTint),
            ),
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🛡️', style: TextStyle(fontSize: AppType.h2)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Ton filet de sécurité',
                      style: _sectionTitleStyle(context),
                    ),
                  ),
                  _statusPill(),
                ]),
                const SizedBox(height: 9),
                _backupStep(
                  icon: Icons.smartphone_rounded, iconKey: 'backupDevice',
                  title: 'Sur cet appareil',
                  text: 'Automatique après les modifications.',
                  done: true,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _colors.tintSoft,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: _colors.borderTint),
            ),
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _iconBubble(Icons.cloud_outlined, systemKey: 'backupCloud', background: _colors.tintStrong, foreground: _colors.accentText),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SAUVEGARDE', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, letterSpacing: .6, color: _colors.textMuted)),
                        SizedBox(height: 2),
                        Text('iCloud', style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.accentText)),
                      ],
                    ),
                  ),
                  _statusPill(),
                ]),
                const SizedBox(height: 9),
                Text('Une seule sauvegarde de sécurité : enregistre le fichier dans Fichiers → iCloud Drive.', style: TextStyle(fontSize: AppType.label, height: 1.3, color: _colors.accentText)),
                const SizedBox(height: 7),
                Text(widget.getCloudBackupStatus(), style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () async { await widget.onICloudExport(); if (mounted) setState(() {}); },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF627A93),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
                      textStyle: const TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700),
                    ),
                    icon: _uiIcon('backupUpload', Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Sauvegarder dans iCloud'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text('Rappel conseillé tous les ${widget.cloudReminderDays} jours', style: TextStyle(fontSize: AppType.caption, color: _colors.textMuted))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
            decoration: BoxDecoration(
              color: _colors.tintStrong,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: _colors.borderTint),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBubble(Icons.upload_file_rounded, systemKey: 'restore', background: _colors.tintStrong, foreground: _colors.accentIcon),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RETROUVER', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, letterSpacing: .6, color: _colors.accentIcon)),
                      const SizedBox(height: 2),
                      Text('Restaurer', style: TextStyle(fontSize: AppType.titleL, fontWeight: FontWeight.w800, color: _colors.textStrong)),
                      const SizedBox(height: 4),
                      Text('Choisis une sauvegarde .json créée par MyBestWeek pour retrouver ton état précédent.', style: TextStyle(fontSize: AppType.label, height: 1.3, color: _colors.accentIcon)),
                      const SizedBox(height: 11),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _import(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _colors.accentIcon,
                            backgroundColor: _colors.card,
                            side: BorderSide(color: _colors.accentSoftBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
                            textStyle: const TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700),
                          ),
                          icon: _uiIcon('backupFolder', Icons.folder_open_rounded, size: 18),
                          label: const Text('Choisir un fichier'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ZONE SENSIBLE', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, letterSpacing: .6, color: _colors.warnText)),
                const SizedBox(height: 4),
                Text('Réinitialisation', style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w800, color: _colors.danger)),
                const SizedBox(height: 3),
                Text('Efface le planning, les validations, l’historique et le bilan. Tes activités restent conservées.', style: TextStyle(fontSize: AppType.small, height: 1.3, color: _colors.danger)),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: TextButton.icon(
                    onPressed: () => _reset(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _colors.textWarm,
                      backgroundColor: _colors.peachBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
                      textStyle: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700),
                    ),
                    icon: _uiIcon('backupReset', Icons.restart_alt_rounded, size: 17),
                    label: const Text('Réinitialiser les données'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomActivityEmoji {
  final String value;
  const _CustomActivityEmoji(this.value);
}

class _CustomActivityIcon {
  final String id;
  final String label;
  final String data;
  const _CustomActivityIcon({required this.id, required this.label, required this.data});
}

class _HomeMascotChoice {
  final String kind;
  final String emoji;

  const _HomeMascotChoice({required this.kind, this.emoji = '🧸'});
}

class _HomeMascotSheet extends StatelessWidget {
  final String currentKind;
  final String currentEmoji;
  final List<String> emojiOptions;

  const _HomeMascotSheet({
    required this.currentKind,
    required this.currentEmoji,
    required this.emojiOptions,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personnaliser la mascotte',
              style: TextStyle(fontSize: AppType.h1, fontWeight: FontWeight.w800, color: _colors.textStrong),
            ),
            const SizedBox(height: 5),
            Text(
              'L’Ourson reste le choix par défaut. Tu peux choisir n’importe quelle icône, une icône personnelle ou conserver une photo.',
              style: TextStyle(fontSize: AppType.body, color: _colors.textMuted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, const _HomeMascotChoice(kind: 'ourson', emoji: '🧸')),
                icon: const Text('🧸', style: TextStyle(fontSize: AppType.h1)),
                label: const Align(alignment: Alignment.centerLeft, child: Text('Ourson MyBestWeek')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: BorderSide(
                    color: currentKind == 'ourson' ? _colors.accentFill : _colors.borderStrong,
                    width: currentKind == 'ourson' ? 1.7 : 1,
                  ),
                  backgroundColor: currentKind == 'ourson' ? _colors.tintStrong : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Icônes et icônes personnelles',
              style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.accentIcon),
            ),
            const SizedBox(height: 7),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: emojiOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final value = emojiOptions[index];
                final selected = currentKind == 'emoji' && currentEmoji == value;
                return InkWell(
                  onTap: () => Navigator.pop(context, _HomeMascotChoice(kind: 'emoji', emoji: value)),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? _colors.tintStrong : _colors.card,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      border: Border.all(
                        color: selected ? _colors.accentFill : _colors.borderStrong,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _activityIconWidget(value, size: 23),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, const _HomeMascotChoice(kind: 'photo')),
                icon: _uiIcon('photo', Icons.photo_library_outlined, size: 18),
                label: const Text('Choisir / conserver une photo sur l’appareil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeIdentityResult {
  final String name;
  final String city;

  const _HomeIdentityResult({required this.name, required this.city});
}

class _HomeIdentitySheet extends StatefulWidget {
  final String initialName;
  final String initialCity;

  const _HomeIdentitySheet({required this.initialName, required this.initialCity});

  @override
  State<_HomeIdentitySheet> createState() => _HomeIdentitySheetState();
}

class _HomeIdentitySheetState extends State<_HomeIdentitySheet> {
  late final TextEditingController nameController;
  late final TextEditingController cityController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    cityController = TextEditingController(text: widget.initialCity);
  }

  @override
  void dispose() {
    nameController.dispose();
    cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personnaliser l’accueil', style: TextStyle(fontSize: AppType.h1, fontWeight: FontWeight.w800, color: _colors.textStrong)),
            const SizedBox(height: 6),
            Text('Ces informations servent uniquement à personnaliser ton accueil et la météo affichée.', style: TextStyle(fontSize: AppType.body, color: _colors.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Prénom ou nom affiché',
                hintText: 'Ex. Alain',
                prefixIcon: _uiIcon('identity', Icons.person_outline_rounded, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.l), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cityController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Ville pour la météo',
                hintText: 'Ex. Sarlat-la-Canéda',
                prefixIcon: _uiIcon('location', Icons.location_on_outlined, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.l), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, _HomeIdentityResult(name: nameController.text.trim(), city: cityController.text.trim())), child: const Text('Enregistrer'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySummarySheet extends StatefulWidget {
  final DailySummary? summary;
  final String dayLabel;

  const _DailySummarySheet({required this.summary, required this.dayLabel});

  @override
  State<_DailySummarySheet> createState() => _DailySummarySheetState();
}

class _DailySummarySheetState extends State<_DailySummarySheet> {
  static const moods = [
    ('😄', 'Très bien'),
    ('🙂', 'Bien'),
    ('😌', 'Serein'),
    ('😐', 'Neutre'),
    ('😓', 'Fatigué'),
  ];

  late String _selectedMood;

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.summary?.moodEmoji ?? '🙂';
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _activityIconWidget('pack://star', size: 24),
            const SizedBox(width: 7),
            Expanded(child: Text('Petit bilan · ${widget.dayLabel}', style: TextStyle(fontSize: AppType.h2, fontWeight: FontWeight.w800, color: _colors.textStrong))),
            Text(_selectedMood, style: const TextStyle(fontSize: AppType.hero)),
          ]),
          const SizedBox(height: 5),
          Text('Un souvenir léger de la journée, utile aussi au Coach pour apprendre ton rythme.', style: TextStyle(fontSize: AppType.label, color: _colors.textMuted, height: 1.25)),
          const SizedBox(height: 13),
          if (summary != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              decoration: BoxDecoration(color: _colors.surfaceSunken, borderRadius: BorderRadius.circular(AppRadius.l)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(summary.summary, style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textMuted, height: 1.28)),
                if (summary.activityTitles.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: summary.activityTitles.map((title) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Text(title, style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    )).toList(),
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          Text('Comment as-tu vécu ta journée ?', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700, color: _colors.textStrong)),
          const SizedBox(height: 7),
          Row(children: moods.map((entry) {
            final selected = _selectedMood == entry.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  onTap: () => setState(() => _selectedMood = entry.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected ? _colors.tintStrong : _colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      border: Border.all(color: selected ? _colors.accentSoftBorder : _colors.border, width: selected ? 1.5 : 1),
                    ),
                    child: Column(children: [
                      Text(entry.$1, style: const TextStyle(fontSize: AppType.h1)),
                      const SizedBox(height: 2),
                      Text(entry.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                    ]),
                  ),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))),
            const SizedBox(width: 9),
            Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(context, _selectedMood), icon: _uiIcon('confirm', Icons.check_rounded, size: 17), label: const Text('Conserver'))),
          ]),
        ]),
      ),
    );
  }
}

class _NewMomentResult {
  final String title;
  final String period;
  final String category;
  final String emoji;
  final int duration;
  final String? activityId;
  final bool createActivity;

  const _NewMomentResult({
    required this.title,
    required this.period,
    required this.category,
    required this.emoji,
    required this.duration,
    this.activityId,
    this.createActivity = false,
  });
}

class _AddMomentPage extends StatefulWidget {
  final String dayName;
  final List<Activity> activities;
  final Future<void> Function(Activity) onEditActivityIcon;
  final Future<String?> Function({required String name, required String category, required String current}) onPickActivityIcon;

  const _AddMomentPage({required this.dayName, required this.activities, required this.onEditActivityIcon, required this.onPickActivityIcon});

  @override
  State<_AddMomentPage> createState() => _AddMomentPageState();
}

class _AddMomentPageState extends State<_AddMomentPage> {
  late final TextEditingController titleController;
  late final TextEditingController durationController;

  bool useExisting = true;
  String? selectedActivityId;
  String period = 'Après-midi';
  String category = 'Sortie';
  String emoji = '📍';
  String themeFilter = 'Toutes';

  static const _themeOptions = <String>[
    'Toutes', 'Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social', 'Autre'
  ];

  List<Activity> get availableActivities => widget.activities
      .where((a) => !a.isDateRange)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<Activity> get filteredAvailableActivities {
    if (themeFilter == 'Toutes') return availableActivities;
    return availableActivities.where((a) => a.category == themeFilter).toList();
  }

  Activity? get selectedActivity {
    if (selectedActivityId == null) return null;
    for (final a in availableActivities) {
      if (a.id == selectedActivityId) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    durationController = TextEditingController(text: '60');
    if (availableActivities.isNotEmpty) {
      final a = availableActivities.firstWhere(
        (activity) => !activity.isFrozen,
        orElse: () => availableActivities.first,
      );
      selectedActivityId = a.id;
      period = a.period == 'Midi' ? 'Après-midi' : (['Matin', 'Après-midi', 'Soir'].contains(a.period) ? a.period : 'Après-midi');
      category = a.category;
      emoji = a.emoji;
      durationController.text = '${a.duration}';
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    durationController.dispose();
    super.dispose();
  }

  void _selectActivity(String id) {
    final a = availableActivities.firstWhere((a) => a.id == id);
    setState(() {
      selectedActivityId = id;
      period = a.period;
      category = a.category;
      emoji = a.emoji;
      durationController.text = '${a.duration}';
    });
  }

  void save() {
    final selected = selectedActivity;
    if (useExisting && selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une activité existante.')),
      );
      return;
    }

    final title = titleController.text.trim();
    if (!useExisting && title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique le nom de la nouvelle activité.')),
      );
      return;
    }

    final parsed = int.tryParse(durationController.text.trim());
    final duration = (parsed == null || parsed < 1)
        ? (selected?.duration ?? 60)
        : parsed;

    Navigator.of(context).pop(
      _NewMomentResult(
        title: useExisting ? selected!.name : title,
        period: period,
        category: useExisting ? selected!.category : category,
        emoji: useExisting ? selected!.emoji : emoji,
        duration: useExisting ? selected!.duration : duration,
        activityId: useExisting ? selected!.id : null,
        createActivity: !useExisting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter à ${widget.dayName}'),
        leading: IconButton(
          tooltip: 'Annuler',
          icon: _uiIcon('close', Icons.close, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: save,
            icon: _uiIcon('confirm', Icons.check, size: 18, color: _colors.accentIcon),
            label: const Text('Ajouter'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(value: true, icon: _uiIcon('history', Icons.library_books_outlined, size: 18), label: const Text('Activité existante')),
                ButtonSegment<bool>(value: false, icon: _uiIcon('add', Icons.add_circle_outline, size: 18), label: const Text('Créer')),
              ],
              selected: <bool>{useExisting},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                setState(() => useExisting = selection.first);
              },
            ),
            const SizedBox(height: 16),
            if (useExisting) ...[
              Card(
                color: _colors.card,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Choisir dans mes activités', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    Text('Thème', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _themeOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, index) {
                          final theme = _themeOptions[index];
                          return ChoiceChip(
                            label: Text(theme),
                            selected: themeFilter == theme,
                            onSelected: (_) => setState(() {
                              themeFilter = theme;
                              if (theme != 'Toutes' && selectedActivityId != null && !filteredAvailableActivities.any((a) => a.id == selectedActivityId)) {
                                selectedActivityId = filteredAvailableActivities.isEmpty ? null : filteredAvailableActivities.first.id;
                                final selectedActivity = selectedActivityId == null ? null : availableActivities.firstWhere((a) => a.id == selectedActivityId);
                                if (selectedActivity != null) {
                                  period = selectedActivity.period == 'Midi' ? 'Après-midi' : (['Matin', 'Après-midi', 'Soir'].contains(selectedActivity.period) ? selectedActivity.period : 'Après-midi');
                                  category = selectedActivity.category;
                                  emoji = selectedActivity.emoji;
                                  durationController.text = '${selectedActivity.duration}';
                                }
                              }
                            }),
                            labelStyle: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (availableActivities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('Aucune activité enregistrée. Passe sur « Créer ».'))
                    else if (filteredAvailableActivities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('Aucune activité dans ce thème.'))
                    else
                      ...filteredAvailableActivities.map((a) {
                        final selected = a.id == selectedActivityId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          onTap: () => _selectActivity(a.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? _colors.tintStrong : _colors.card,
                              borderRadius: BorderRadius.circular(AppRadius.l),
                              border: Border.all(color: selected ? _colors.accentSoftBorder : _colors.border),
                            ),
                            child: Row(children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                                onTap: () => widget.onEditActivityIcon(a),
                                child: Tooltip(message: 'Modifier l’icône', child: _activityIconWidget(a.emoji, size: 30)),
                              ),
                              const SizedBox(width: 9),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      a.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (a.isFrozen) ...[
                                    const SizedBox(width: 5),
                                    Tooltip(
                                      message: 'Activité gelée · ajout manuel autorisé',
                                      child: _activityIconWidget(_uiIconValue('frozen', '🧊'), size: 16),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  a.isFrozen
                                      ? '${a.category} · ${a.duration} min · gelée · ajout manuel possible'
                                      : '${a.category} · ${a.duration} min',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppType.label,
                                    color: a.isFrozen ? _colors.textWarm : _colors.textMuted,
                                  ),
                                ),
                              ])),
                              IconButton(
                                tooltip: 'Modifier l’icône',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                onPressed: () => widget.onEditActivityIcon(a),
                                icon: _uiIcon('edit', Icons.edit_outlined, size: 17, color: _colors.textMuted),
                              ),
                              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 22, color: selected ? _colors.accentIcon : _colors.textFaint),
                            ]),
                          ),
                        );
                      }),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Card(
                color: _colors.card,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _uiIcon('add', Icons.add_task_rounded, size: 18, color: _colors.accentIcon),
                    SizedBox(width: 10),
                    Expanded(child: Text('Cette option crée une vraie activité dans « Mes activités », puis la place immédiatement dans ta journée.', style: TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Nom de la nouvelle activité',
                  hintText: 'Ex. Visite du château, lecture, bricolage…',
                  prefixIcon: _uiIcon('edit', Icons.edit_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              Text('Thème', style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: _colors.textMuted)),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _themeOptions.where((v) => v != 'Toutes').map((theme) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(theme),
                      selected: category == theme,
                      onSelected: (_) => setState(() => category = theme),
                      labelStyle: const TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.l),
                onTap: () async {
                  final picked = await widget.onPickActivityIcon(name: titleController.text.trim().isEmpty ? 'Nouvelle activité' : titleController.text.trim(), category: category, current: emoji);
                  if (picked != null && mounted) setState(() => emoji = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Icône', helperText: 'Même palette que les autres menus.'),
                  child: Row(children: [
                    _activityIconWidget(emoji, size: 28),
                    const SizedBox(width: 9),
                    const Expanded(child: Text('Choisir ou modifier l’icône')),
                    _uiIcon('edit', Icons.edit_outlined, size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              value: period,
              decoration: InputDecoration(labelText: 'Moment de la journée', prefixIcon: _uiIcon('calendar', Icons.schedule_outlined, size: 18)),
              items: const ['Matin', 'Après-midi', 'Soir']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => period = v ?? period),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Durée (minutes)', prefixIcon: _uiIcon('duration', Icons.timer_outlined, size: 18)),
              enabled: !useExisting,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: save,
                icon: _uiIcon('confirm', Icons.check_circle_outline, size: 18, color: _colors.accentIcon),
                label: Text(useExisting ? 'Ajouter cette activité' : 'Créer et ajouter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
