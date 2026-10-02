// V9.21 — Composants UI réutilisables et feuilles secondaires
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

class _InfoSheet extends StatelessWidget {
  final PlanItem item;
  const _InfoSheet({required this.item});


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
          width: 30, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? const Color(0xFFE3F0E7) : const Color(0xFFF1EEE8),
            shape: BoxShape.circle,
          ),
          child: done ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF62806E)) : _uiIcon(iconKey, icon, size: 16, color: const Color(0xFF847A6D)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF4C5952))),
          const SizedBox(height: 1),
          Text(text, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.8, height: 1.22, color: Color(0xFF737A76))),
        ])),
      ],
    );
  }

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
              : '${item.period}${item.optional ? ' · optionnel' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF526B78))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Très bien'))),
        ]),
      ),
    );
  }
}

class _DataPage extends StatelessWidget {
  final VoidCallback onExport;
  final Future<void> Function() onICloudExport;
  final Future<bool> Function() onImport;
  final Future<void> Function() onReset;
  final String cloudBackupStatus;
  final int cloudReminderDays;

  const _DataPage({
    required this.onExport,
    required this.onICloudExport,
    required this.onImport,
    required this.onReset,
    required this.cloudBackupStatus,
    required this.cloudReminderDays,
  });

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
            color: done ? const Color(0xFFE3F0E7) : const Color(0xFFF1EEE8),
            shape: BoxShape.circle,
          ),
          child: done ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF62806E)) : _uiIcon(iconKey, icon, size: 16, color: const Color(0xFF847A6D)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4C5952),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.8,
                  height: 1.22,
                  color: Color(0xFF737A76),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context) async {
    final ok = await onImport();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    await onReset();
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
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? Text(emoji, style: const TextStyle(fontSize: 23))
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 7),
            color: Color(0x12000000),
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
                    Text(eyebrow.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6, color: Color(0xFF78807D))),
                    const SizedBox(height: 2),
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF394640))),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(fontSize: 11.5, height: 1.3, color: Color(0xFF66706B))),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
              icon: systemKey == null ? Icon(icon, size: 18) : _uiIcon(systemKey!, icon, size: 18, color: Colors.white),
              label: Text(buttonLabel),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(footer, style: const TextStyle(fontSize: 9.8, height: 1.25, color: Color(0xFF7A827E))),
          ],
        ],
      ),
    );
  }

  Widget _statusPill() {
    final noBackup = cloudBackupStatus.startsWith('Aucune');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: noBackup ? const Color(0xFFFFF4DE) : const Color(0xFFE7F2EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: noBackup ? const Color(0xFFE8D7B4) : const Color(0xFFC7DDCE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _uiIcon(noBackup ? 'backupDue' : 'backupOk', noBackup ? Icons.schedule_rounded : Icons.check_circle_outline_rounded, size: 14, color: noBackup ? const Color(0xFF9A7541) : const Color(0xFF62806E)),
          const SizedBox(width: 5),
          Flexible(child: Text(noBackup ? 'À faire' : 'À jour', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: noBackup ? const Color(0xFF87663B) : const Color(0xFF5E7566)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Fermer',
          icon: _uiIcon('close', Icons.close_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: const Text('Sauvegarde', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF3F4B45))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEAF3EE), Color(0xFFF4EFE8)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFD8E3DC)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBF8),
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x12000000))],
                  ),
                  alignment: Alignment.center,
                  child: const Text('☁️', style: TextStyle(fontSize: 29)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tes données, au calme.', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF415048))),
                      SizedBox(height: 3),
                      Text('La sauvegarde locale est automatique. Garde une copie à portée de main pour retrouver MyBestWeek facilement.', style: TextStyle(fontSize: 10.8, height: 1.3, color: Color(0xFF68736D))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5F1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDE5DE)),
            ),
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🛡️', style: TextStyle(fontSize: 19)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Ton filet de sécurité',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF4A5850)),
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
                _backupStep(
                  icon: Icons.cloud_done_outlined, iconKey: 'backupCloud',
                  title: 'Copie iCloud',
                  text: cloudBackupStatus,
                  done: !cloudBackupStatus.startsWith('Aucune'),
                ),
                const SizedBox(height: 6),
                _backupStep(
                  icon: Icons.archive_outlined, iconKey: 'backupFile',
                  title: 'Fichier .json',
                  text: 'À conserver où tu veux pour une restauration complète.',
                  done: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _primaryCard(
            context: context,
            background: const Color(0xFFFFFCF7),
            border: const Color(0xFFE5DDD2),
            accent: const Color(0xFF718D7F),
            icon: Icons.download_rounded, systemKey: 'backupDownload',
            eyebrow: 'Copie locale',
            title: 'Sauvegarder',
            description: 'Crée un fichier .json complet avec tes activités, ton planning, tes validations, ton historique et tes bilans.',
            buttonLabel: 'Créer ma sauvegarde',
            onPressed: onExport,
            footer: 'Le fichier est conservé par ton navigateur / appareil jusqu’à l’endroit où tu choisis de l’enregistrer.',
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD7E1F0)),
            ),
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _iconBubble(Icons.cloud_outlined, systemKey: 'backupCloud', background: const Color(0xFFDDE8F7), foreground: const Color(0xFF58708C)),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COPIE EXTERNE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6, color: Color(0xFF7B8795))),
                          SizedBox(height: 2),
                          Text('iCloud Drive', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF46596C))),
                        ],
                      ),
                    ),
                    _statusPill(),
                  ],
                ),
                const SizedBox(height: 9),
                const Text('Volontaire et simple : crée le fichier, enregistre-le dans Fichiers → iCloud Drive, puis confirme l’opération.', style: TextStyle(fontSize: 11.5, height: 1.3, color: Color(0xFF687584))),
                const SizedBox(height: 7),
                Text(cloudBackupStatus, style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF788696))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: onICloudExport,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF627A93),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                    ),
                    icon: _uiIcon('backupUpload', Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Créer une copie iCloud'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text('Rappel conseillé tous les $cloudReminderDays jours', style: const TextStyle(fontSize: 9.8, color: Color(0xFF788696)))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4EE),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD0E2D7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconBubble(Icons.upload_file_rounded, systemKey: 'restore', background: const Color(0xFFD9EBDD), foreground: const Color(0xFF628070)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RETROUVER', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6, color: Color(0xFF789084))),
                      const SizedBox(height: 2),
                      const Text('Restaurer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF465C50))),
                      const SizedBox(height: 4),
                      const Text('Choisis une sauvegarde .json créée par MyBestWeek pour retrouver ton état précédent.', style: TextStyle(fontSize: 11.5, height: 1.3, color: Color(0xFF68766F))),
                      const SizedBox(height: 11),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _import(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5E7667),
                            backgroundColor: const Color(0xFFF8FCF9),
                            side: const BorderSide(color: Color(0xFFB9D0C0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
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
                const Text('ZONE SENSIBLE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6, color: Color(0xFF9A7566))),
                const SizedBox(height: 4),
                const Text('Réinitialisation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF6C5146))),
                const SizedBox(height: 3),
                const Text('Efface le planning, les validations, l’historique et le bilan. Tes activités restent conservées.', style: TextStyle(fontSize: 10.5, height: 1.3, color: Color(0xFF837067))),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: TextButton.icon(
                    onPressed: () => _reset(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9B6555),
                      backgroundColor: const Color(0xFFF8EDE8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
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
            const Text(
              'Personnaliser la mascotte',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3F4B45)),
            ),
            const SizedBox(height: 5),
            const Text(
              'L’Ourson reste le choix par défaut. Tu peux choisir n’importe quelle icône, une icône personnelle ou conserver une photo.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6F7777)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, const _HomeMascotChoice(kind: 'ourson', emoji: '🧸')),
                icon: const Text('🧸', style: TextStyle(fontSize: 21)),
                label: const Align(alignment: Alignment.centerLeft, child: Text('Ourson MyBestWeek')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  side: BorderSide(
                    color: currentKind == 'ourson' ? const Color(0xFF7D988D) : const Color(0xFFD9D5CB),
                    width: currentKind == 'ourson' ? 1.7 : 1,
                  ),
                  backgroundColor: currentKind == 'ourson' ? const Color(0xFFEAF6EE) : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Icônes et icônes personnelles',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF5E6B65)),
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
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFEAF6EE) : const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? const Color(0xFF7D988D) : const Color(0xFFE2DCD3),
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
            const Text('Personnaliser l’accueil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3F4B45))),
            const SizedBox(height: 6),
            const Text('Ces informations servent uniquement à personnaliser ton accueil et la météo affichée.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6F7777))),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
            const Text('✨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 7),
            Expanded(child: Text('Petit bilan · ${widget.dayLabel}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF3F5047)))),
            Text(_selectedMood, style: const TextStyle(fontSize: 28)),
          ]),
          const SizedBox(height: 5),
          const Text('Un souvenir léger de la journée, utile aussi au Coach pour apprendre ton rythme.', style: TextStyle(fontSize: 11.2, color: Color(0xFF6D7772), height: 1.25)),
          const SizedBox(height: 13),
          if (summary != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              decoration: BoxDecoration(color: const Color(0xFFF5F0E7), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(summary.summary, style: const TextStyle(fontSize: 12.2, fontWeight: FontWeight.w800, color: Color(0xFF5B625E), height: 1.28)),
                if (summary.activityTitles.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: summary.activityTitles.map((title) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                      child: Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF68716D)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    )).toList(),
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          const Text('Comment as-tu vécu ta journée ?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF4F5B55))),
          const SizedBox(height: 7),
          Row(children: moods.map((entry) {
            final selected = _selectedMood == entry.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedMood = entry.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE7F1EA) : const Color(0xFFF7F5F0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? const Color(0xFF9FBCAB) : const Color(0xFFE3DED5), width: selected ? 1.5 : 1),
                    ),
                    child: Column(children: [
                      Text(entry.$1, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 2),
                      Text(entry.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.4, fontWeight: FontWeight.w800, color: Color(0xFF68716D))),
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
            icon: _uiIcon('confirm', Icons.check, size: 18, color: const Color(0xFF60786B)),
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
                color: const Color(0xFFFFFBF4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Choisir dans mes activités', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    const Text('Thème', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF6F7777))),
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
                            labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
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
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _selectActivity(a.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFEAF2EC) : const Color(0xFFFCFAF6),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: selected ? const Color(0xFFABC5B2) : const Color(0xFFE3DDD4)),
                            ),
                            child: Row(children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(18),
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
                                    fontSize: 11.5,
                                    color: a.isFrozen ? const Color(0xFF8A8178) : const Color(0xFF707775),
                                  ),
                                ),
                              ])),
                              IconButton(
                                tooltip: 'Modifier l’icône',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                onPressed: () => widget.onEditActivityIcon(a),
                                icon: _uiIcon('edit', Icons.edit_outlined, size: 17, color: const Color(0xFF718077)),
                              ),
                              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 22, color: selected ? const Color(0xFF6F8E80) : const Color(0xFFA8ADA9)),
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
                color: const Color(0xFFFFFBF4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _uiIcon('add', Icons.add_task_rounded, size: 18, color: const Color(0xFF60786B)),
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
              const Text('Thème', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF6F7777))),
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
                      labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(14),
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
                icon: _uiIcon('confirm', Icons.check_circle_outline, size: 18, color: const Color(0xFF6F8E80)),
                label: Text(useExisting ? 'Ajouter cette activité' : 'Créer et ajouter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
