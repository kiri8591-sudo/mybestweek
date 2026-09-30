// V8.92 — Gestion des activités et synchronisation du planning
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _ActivityManagementPart on _MaBelleSemaineAppState {
  List<String> _uniqueStrings(Iterable<String> source) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in source) {
      if (seen.add(value)) result.add(value);
    }
    return result;
  }

  List<String> _suggestedEmojisForName(String label, String category) {
    final text = label.trim().toLowerCase();
    final matches = <String>[];
    void addAll(Iterable<String> values) {
      for (final value in values) {
        if (!matches.contains(value)) matches.add(value);
      }
    }

    if (RegExp(r'road\s*trip|voyage|route|déplacement|deplacement|voiture|camping').hasMatch(text)) {
      addAll(['🚗', '🗺️', '🧳', '🏕️']);
    }
    if (RegExp(r'dessin|peinture|aquarelle|croquis|artist|atelier').hasMatch(text)) {
      addAll(['🎨', '🖌️', '✏️', '🧵']);
    }
    if (RegExp(r'stage|cours|formation|apprentissage').hasMatch(text)) {
      addAll(['📚', '✏️', '🎨', '📝']);
    }
    if (RegExp(r'piano|musique|guitare|chant').hasMatch(text)) {
      addAll(['🎹', '🎵', '🎶', '🎧']);
    }
    if (RegExp(r'lecture|livre|roman').hasMatch(text)) {
      addAll(['📖', '📚', '☕', '🛋️']);
    }
    if (RegExp(r'ciné|cinema|film|série|serie').hasMatch(text)) {
      addAll(['🎬', '📺', '🍿', '🎭']);
    }
    if (RegExp(r'photo|photographie|vidéo|video').hasMatch(text)) {
      addAll(['📷', '🎥', '🗺️']);
    }
    if (RegExp(r'marché|marche|randonnée|randonnee|promenade|balade').hasMatch(text)) {
      addAll(['🚶', '🥾', '🌳', '🏞️']);
    }
    if (RegExp(r'jardin|jardinage|plante').hasMatch(text)) {
      addAll(['🌱', '🪴', '🌿', '🌸']);
    }
    if (RegExp(r'restaurant|repas|cuisine|cuisiner').hasMatch(text)) {
      addAll(['🍽️', '🥐', '🍵', '🍰']);
    }
    if (RegExp(r'amis|famille|convivial|anniversaire|fête|fete').hasMatch(text)) {
      addAll(['🥂', '🎁', '💌', '🫶']);
    }
    if (RegExp(r'repos|détente|detente|méditation|meditation|bien-être|bien etre').hasMatch(text)) {
      addAll(['🌿', '🕯️', '🛀', '🌸']);
    }
    if (RegExp(r'ours|ourson|mascotte').hasMatch(text)) addAll(['🧸']);

    switch (category) {
      case 'Sport': addAll(['🏃', '🚶', '🧘', '🥾']); break;
      case 'Bien-être': addAll(['🌿', '🌸', '🕯️', '🛀']); break;
      case 'Culture': addAll(['📖', '🎨', '🎬', '🎭']); break;
      case 'Sortie': addAll(['🗺️', '🚗', '🌳', '🏞️']); break;
      case 'Social': addAll(['🥂', '💌', '🫶', '☕']); break;
      default: addAll(['✨', '🌿', '😊', '🧸']);
    }

    return _uniqueStrings(matches).take(6).toList();
  }

  void _syncActivityToWeek(Activity activity, {Activity? previous}) {
    final linked = plan.where((p) => p.activityId == activity.id).toList();

    // Les éléments du planning modèle (lundi piano 2 h, vendredi grande marche,
    // etc.) restent des piliers de la semaine. Une modification de la fiche
    // activité met à jour leur nom et leur durée, mais ne les supprime pas au
    // seul motif que la fréquence a changé.
    for (final item in linked) {
      if (_isSportActivity(activity) || activity.isSportProgram) item.duration = activity.duration;
      if (!_isSportActivity(activity) && !activity.isSportProgram && !item.manualPlacement) item.period = _periodForActivity(activity, item.day);
      if (previous != null && item.title.contains(previous.name)) {
        item.title = item.title.replaceFirst(previous.name, activity.name);
      }
      _syncCompletedValidationDuration(item);
    }

    final rangeChanged = previous == null
        ? activity.isDateRange
        : previous.isDateRange != activity.isDateRange ||
            !_sameDateValue(previous.rangeStart, activity.rangeStart) ||
            !_sameDateValue(previous.rangeEnd, activity.rangeEnd);

    // Une activité « sur une période » ignore la fréquence hebdomadaire :
    // elle est placée chaque jour compris entre les deux dates. Lors d’une
    // modification de période, on reconstruit uniquement ses occurrences
    // courantes ; les validations supprimées restent dans l’historique.
    if (activity.isDateRange && !_isSportActivity(activity) && !activity.isSportProgram) {
      if (rangeChanged) {
        plan.removeWhere((item) => item.activityId == activity.id && !item.fixedInWeeklyTemplate);
        _ensureDateRangeActivityInCurrentWeek(activity);
      } else if (previous == null) {
        _ensureDateRangeActivityInCurrentWeek(activity);
      }
      _sortPlan();
      return;
    }

    // Passage d’une activité sur période vers une activité hebdomadaire.
    if (previous?.isDateRange == true && !activity.isDateRange) {
      plan.removeWhere((item) => item.activityId == activity.id && !item.fixedInWeeklyTemplate);
    }

    // Changer de catégorie ne doit jamais créer une occurrence de planning.
    // Une activité qui n’était pas prévue cette semaine reste dans la
    // bibliothèque seulement. Les occurrences déjà prévues conservent leur
    // jour ; seule leur rubrique d’affichage évolue (Sport ou Matin/Midi/Soir).
    final categoryChanged = previous != null && previous.category != activity.category;
    if (categoryChanged && linked.isEmpty) {
      _sortPlan();
      return;
    }

    // Les activités Sport réelles sont des composants du programme générique
    // « Sport ». Elles ne doivent pas être ajoutées une par une dans le
    // planning : leur fréquence et leur rotation sont recalculées au prochain
    // clic sur « Repenser ».
    if (_isSportActivity(activity) || activity.isSportProgram) {
      _sortPlan();
      return;
    }

    // Seuls les créneaux ajoutés automatiquement depuis la fiche activité
    // peuvent être déplacés ou ajustés par la fréquence / les jours préférés.
    final generated = linked.where((p) => p.userAdded && !p.fixedInWeeklyTemplate).toList();

    if (previous != null && !_sameDays(previous.preferredDays, activity.preferredDays)) {
      final preferred = activity.preferredDays.where((d) => d >= 0 && d < 7).toList()..sort();
      final movable = generated.where((item) => !item.done).toList()
        ..sort((a, b) => _dayLoadMinutes(b.day).compareTo(_dayLoadMinutes(a.day)));
      for (final desiredDay in preferred) {
        if (generated.any((item) => item.day == desiredDay)) continue;
        if (movable.isEmpty) break;
        final old = movable.removeAt(0);
        final replacement = PlanItem(
          id: old.id,
          day: desiredDay,
          period: _periodForActivity(activity, desiredDay),
          timeLabel: old.timeLabel,
          activityId: old.activityId,
          title: old.title,
          details: old.details,
          customEmoji: old.customEmoji,
          customCategory: old.customCategory,
          duration: old.duration,
          optional: old.optional,
          userAdded: old.userAdded,
          fixedInWeeklyTemplate: old.fixedInWeeklyTemplate,
          manualPlacement: old.manualPlacement,
          done: old.done,
          realisedMinutes: old.realisedMinutes,
          feeling: old.feeling,
        );
        final index = plan.indexWhere((item) => item.id == old.id);
        if (index >= 0) plan[index] = replacement;
      }
    }

    // Une nouvelle activité personnelle apparaît immédiatement dans la semaine.
    // La fréquence hebdomadaire signifie un NOMBRE DE JOURS ; « plusieurs
    // réalisations par jour » est un second réglage indépendant (2 ou 3
    // occurrences sur chacun des jours retenus).
    final frequencyChanged = previous == null || previous.frequency != activity.frequency;
    final repetitionChanged = previous == null ||
        previous.allowMultiplePerDay != activity.allowMultiplePerDay ||
        previous.maxDailyOccurrences != activity.maxDailyOccurrences;

    // Lors d’un simple changement de catégorie, ne pas recalculer la fréquence
    // ou les occurrences : on requalifie uniquement les éléments déjà présents.
    if (categoryChanged) {
      _sortPlan();
      return;
    }

    if (frequencyChanged || repetitionChanged || linked.isEmpty) {
      final targetDays = activity.frequency.clamp(1, 7).toInt();
      final dailyTarget = activity.allowMultiplePerDay
          ? activity.maxDailyOccurrences.clamp(2, 3).toInt()
          : 1;

      final allDayItems = <int, List<PlanItem>>{};
      for (final item in plan.where((p) =>
          p.activityId == activity.id &&
          !p.fixedInWeeklyTemplate)) {
        allDayItems.putIfAbsent(item.day, () => <PlanItem>[]).add(item);
      }

      // Les placements manuels et les réalisations déjà faites sont respectés.
      final coveredDays = allDayItems.keys.toSet();
      final managed = plan.where((p) =>
          p.activityId == activity.id &&
          p.userAdded &&
          !p.fixedInWeeklyTemplate &&
          !p.manualPlacement).toList();

      // Désactivation de la répétition : on conserve au maximum une occurrence
      // automatique par jour. Une occurrence déjà réalisée n'est jamais retirée.
      if (!activity.allowMultiplePerDay) {
        for (final entry in allDayItems.entries) {
          final auto = entry.value.where((p) =>
              p.userAdded && !p.manualPlacement && !p.fixedInWeeklyTemplate).toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          if (auto.length <= 1) continue;
          for (final extra in auto.skip(1).toList()) {
            if (!extra.done) plan.removeWhere((p) => p.id == extra.id);
          }
        }
      }

      // Si la fréquence diminue, on retire d'abord des jours automatiques
      // non réalisés. Les jours contenant une réalisation terminée restent.
      final removableDays = <int>[];
      for (final entry in allDayItems.entries) {
        final hasManual = entry.value.any((p) => p.manualPlacement || !p.userAdded);
        final hasDone = entry.value.any((p) => p.done);
        final hasAuto = entry.value.any((p) => p.userAdded && !p.manualPlacement && !p.fixedInWeeklyTemplate);
        if (hasAuto && !hasManual && !hasDone) removableDays.add(entry.key);
      }
      if (coveredDays.length > targetDays) {
        removableDays.sort((a, b) => _dayLoadMinutes(b).compareTo(_dayLoadMinutes(a)));
        var excess = coveredDays.length - targetDays;
        for (final day in removableDays) {
          if (excess <= 0) break;
          plan.removeWhere((p) =>
              p.activityId == activity.id &&
              p.day == day &&
              p.userAdded &&
              !p.manualPlacement &&
              !p.fixedInWeeklyTemplate &&
              !p.done);
          excess--;
        }
      }

      final refreshedCoveredDays = plan.where((p) =>
          p.activityId == activity.id && !p.fixedInWeeklyTemplate).map((p) => p.day).toSet();

      // Nouvelle activité ou fréquence augmentée : on réserve de nouveaux jours.
      var safety = 0;
      while (refreshedCoveredDays.length < targetDays && safety < 30) {
        final candidates = _planningCandidates(activity)
            .where((day) => !refreshedCoveredDays.contains(day))
            .toList();
        if (candidates.isEmpty) break;
        final day = candidates.first;
        for (var occurrence = 0; occurrence < dailyTarget; occurrence++) {
          plan.add(PlanItem(
            id: 'activity_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_${safety}_$occurrence',
            day: day,
            period: _generationPeriodForOccurrence(
              activity,
              day,
              occurrence,
              dailyTarget,
              _periodForActivity(activity, day),
            ),
            activityId: activity.id,
            title: activity.name,
            duration: activity.duration,
            userAdded: true,
            manualPlacement: false,
          ));
        }
        refreshedCoveredDays.add(day);
        safety++;
      }

      // Une activité déjà planifiée sur un jour reçoit immédiatement ses
      // occurrences supplémentaires lorsque l'option est activée. On ne
      // touche pas aux occurrences manuelles : elles sont sous le contrôle
      // de l'utilisateur.
      if (activity.allowMultiplePerDay) {
        final daysToComplete = plan.where((p) =>
            p.activityId == activity.id && !p.fixedInWeeklyTemplate).map((p) => p.day).toSet().toList()..sort();
        for (final day in daysToComplete) {
          final dayItems = plan.where((p) =>
              p.activityId == activity.id &&
              p.day == day &&
              !p.fixedInWeeklyTemplate).toList();
          // Toutes les occurrences déjà présentes sur ce jour comptent dans
          // la cible quotidienne, y compris une occurrence créée dans la
          // version précédente, une occurrence manuelle ou une occurrence
          // déjà réalisée. On ne doit ajouter que le complément manquant.
          final currentOccurrenceCount = dayItems.length;
          var missing = dailyTarget - currentOccurrenceCount;
          if (missing <= 0) continue;
          var occ = currentOccurrenceCount;
          while (missing > 0) {
            plan.add(PlanItem(
              id: 'activity_repeat_${activity.id}_${DateTime.now().microsecondsSinceEpoch}_${day}_$occ',
              day: day,
              period: _generationPeriodForOccurrence(
                activity,
                day,
                occ,
                dailyTarget,
                _periodForActivity(activity, day),
              ),
              activityId: activity.id,
              title: activity.name,
              duration: activity.duration,
              userAdded: true,
              manualPlacement: false,
            ));
            occ++;
            missing--;
          }
        }
      }

      // Silence l'analyseur concernant le regroupement préparé pour expliciter
      // que les éléments automatiques existants sont volontairement conservés.
      managed.length;
    }

    _sortPlan();
  }

  Future<String?> _compressCustomActivityIconDataUrl(String dataUrl) async {
    try {
      final image = html.ImageElement();
      final loaded = image.onLoad.first.then<bool>((_) => true);
      final failed = image.onError.first.then<bool>((_) => false);
      image.src = dataUrl;
      final ok = await Future.any<bool>([loaded, failed]);
      if (!ok) return null;
      final sourceWidth = image.naturalWidth;
      final sourceHeight = image.naturalHeight;
      if (sourceWidth <= 0 || sourceHeight <= 0) return null;

      const maxDimension = 192;
      final scale = min(1.0, maxDimension / max(sourceWidth, sourceHeight));
      final targetWidth = max(1, (sourceWidth * scale).round());
      final targetHeight = max(1, (sourceHeight * scale).round());

      // Conversion systématique en PNG : cela évite de stocker un GIF/WebP/HEIC
      // que Flutter Web pourrait ne pas réussir à décoder ensuite.
      final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
      canvas.context2D.drawImageScaled(image, 0, 0, targetWidth, targetHeight);
      final compressed = canvas.toDataUrl('image/png');
      return compressed.isEmpty ? null : compressed;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _pickCustomActivityIconImage() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;
    input.style
      ..position = 'fixed'
      ..left = '-10000px'
      ..top = '0'
      ..width = '1px'
      ..height = '1px'
      ..opacity = '0';
    html.document.body?.children.add(input);
    try {
      try {
        input.click();
        await input.onChange.first;
      } catch (_) {
        _showFeedback('Impossible d’ouvrir le sélecteur d’image dans ce navigateur.');
        return null;
      }

      final files = input.files;
      if (files == null || files.isEmpty) {
        _showFeedback('Aucune image n’a été sélectionnée.');
        return null;
      }
      final file = files.first;
      final mime = file.type.toLowerCase();
      if (mime.isNotEmpty && !mime.startsWith('image/')) {
        _showFeedback('Ce fichier n’est pas une image compatible.');
        return null;
      }
      if (file.size > 512 * 1024) {
        _showFeedback('Icône trop lourde. Choisis une image de moins de 512 Ko.');
        return null;
      }

      final reader = html.FileReader();
      try {
        reader.readAsDataUrl(file);
        await reader.onLoad.first;
      } catch (_) {
        _showFeedback('Impossible de lire cette image. Essaie un fichier PNG ou JPEG.');
        return null;
      }

      final originalData = reader.result?.toString();
      if (originalData == null || originalData.isEmpty || !originalData.startsWith('data:image/')) {
        _showFeedback('Le fichier sélectionné n’a pas pu être converti en image.');
        return null;
      }

      final data = await _compressCustomActivityIconDataUrl(originalData);
      if (data == null || data.isEmpty) {
        _showFeedback('Cette image ne peut pas être importée comme icône. Essaie un PNG ou JPEG.');
        return null;
      }
      final finalData = data;
      final bytes = _decodeCustomIconData(finalData);
      if (bytes == null || bytes.isEmpty) {
        _showFeedback('Cette image ne peut pas être utilisée comme icône personnelle.');
        return null;
      }

      final id = 'icon_${DateTime.now().microsecondsSinceEpoch}';
      final label = file.name.isEmpty ? 'Icône personnelle' : file.name;
      final entry = _CustomActivityIcon(id: id, label: label, data: finalData);
      _customActivityIcons.add(entry);
      _customActivityIconData[id] = entry.data;
      _customActivityIconBytes[id] = bytes;
      _queueLocalStatePersist();
      return 'customicon://$id';
    } catch (_) {
      _showFeedback('L’importation de cette image a échoué. Essaie un PNG ou JPEG de moins de 512 Ko.');
      return null;
    } finally {
      input.remove();
    }
  }

  Future<String?> _addCustomActivityEmoji() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: _navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un emoji'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'Colle ou saisis un emoji'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    if (!_customActivityEmojis.any((e) => e.value == v)) {
      _customActivityEmojis.add(_CustomActivityEmoji(v));
      _queueLocalStatePersist();
    }
    return v;
  }

  int _activityIconUsage(String value) => activities.where((a) => a.emoji == value).length;

  List<String> _activityIconPalette(Activity activity) {
    final values = <String>[
      // Ambiance / quotidien
      '🌞', '☀️', '🌤️', '⛅', '🌅', '🌄', '🌇', '🌙', '🌛', '🌜',
      '⭐', '🌟', '✨', '💫', '🌈', '☁️', '❄️', '🔥', '💧',
      // Bien-être / nature
      '🍎', '🍐', '🍊', '🍋', '🍓', '🍒', '🍇', '🍉', '🥑', '🥗',
      '🍵', '☕', '🫖', '🥐', '🍞', '🍯', '🛀', '🧴', '🕯️', '🌿',
      '🌱', '🌸', '🌷', '🌻', '🌼', '🌺', '🪻', '🍀', '🪴', '🌵',
      // Culture / loisirs
      '🎹', '🎸', '🎻', '🎺', '🥁', '🎵', '🎶', '🎤', '🎨', '🖌️',
      '📖', '📚', '📕', '📔', '✏️', '🖊️', '🧩', '♟️', '🎬', '🎧',
      '🎮', '📺', '📷', '🎥', '🎭', '🧶', '🪡', '🧵',
      // Sport / mouvement
      '🚶', '🚶‍♂️', '🚶‍♀️', '🏊', '🚴', '🥾', '🏃', '🏃‍♂️', '🏃‍♀️',
      '🏋️', '💪', '🤸', '🤸‍♀️', '🧘', '🧘‍♀️', '🧘‍♂️', '🧗', '⛹️',
      '⚽', '🏀', '🎾', '🏸', '🥎', '🛼', '🛴', '☯️',
      // Maison / organisation
      '🏠', '🏡', '🛋️', '🛏️', '🧹', '🧺', '🧼', '🧽', '🪣', '🛒',
      '🛍️', '🧳', '🍽️', '🍿', '📅', '📝', '📌', '📍', '💻', '📱', '🗂️', '🗃️',
      // Social / plaisir
      '❤️', '🧡', '💛', '💚', '💙', '💜', '💕', '💖', '💝', '💞',
      '🥂', '🍰', '🎁', '😊', '😄', '🥰', '😌', '🤗', '🙏', '💌', '☀️', '👋', '🫶',
      // Mascottes / animaux
      '🧸', '🐻', '🐼', '🐰', '🐱', '🦊', '🐨', '🐶', '🐹', '🐸',
      '🐧', '🐥', '🦋', '🐝', '🐢', '🐠', '🦄',
      // Nature / sorties
      '🌳', '🌲', '🌴', '🏞️', '🌊', '🏖️', '⛰️', '🏕️', '🌍', '🗺️',
      '⚡', '💗', '😴', '💤',
      ..._suggestedEmojisForName(activity.name, activity.category),
      ..._customActivityEmojis.map((e) => e.value),
      ..._customActivityIcons.map((e) => 'customicon://${e.id}'),
      activity.emoji,
    ];
    return _uniqueStrings(values);
  }

  Future<String?> _chooseActivityIconValue({
    required String name,
    required String category,
    required String current,
  }) async {
    final probe = Activity(
      id: '_icon_picker_probe',
      name: name,
      emoji: current,
      category: category,
      duration: 1,
      frequency: 1,
      priority: 1,
    );
    final picked = await showModalBottomSheet<String>(
      context: _navigatorKey.currentContext!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (pickerContext) => StatefulBuilder(
        builder: (pickerContext, setPickerState) {
          final values = _activityIconPalette(probe);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(pickerContext).size.height * .70,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('Choisir une icône · $name', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                      _activityIconWidget(current, size: 30),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await _pickCustomActivityIconImage();
                            if (value != null && pickerContext.mounted) Navigator.pop(pickerContext, value);
                          },
                          icon: _uiIcon('photo', Icons.add_photo_alternate_outlined, size: 18),
                          label: const Text('Image'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final value = await _addCustomActivityEmoji();
                            if (value != null && pickerContext.mounted) Navigator.pop(pickerContext, value);
                          },
                          icon: _uiIcon('emoji', Icons.emoji_emotions_outlined, size: 18),
                          label: const Text('Emoji'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton(
                        tooltip: 'Gérer mes icônes',
                        onPressed: () async {
                          await _manageCustomActivityIcons();
                          if (pickerContext.mounted) setPickerState(() {});
                        },
                        icon: _uiIcon('manageIcons', Icons.tune_rounded, size: 18),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(3),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 7,
                          crossAxisSpacing: 7,
                          childAspectRatio: 1,
                        ),
                        itemCount: values.length,
                        itemBuilder: (_, index) {
                          final value = values[index];
                          final selected = value == current;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(pickerContext, value),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFEAF2ED) : const Color(0xFFF8F5EF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? const Color(0xFFB9CCBF) : const Color(0xFFE7E1D8), width: selected ? 1.2 : .6),
                              ),
                              child: _activityIconWidget(value, size: 28),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (picked == null || picked.isEmpty) return null;
    return picked;
  }

  Future<void> _editActivityIcon(Activity activity) async {
    final picked = await _chooseActivityIconValue(
      name: activity.name,
      category: activity.category,
      current: activity.emoji,
    );
    if (picked == null || !mounted || picked == activity.emoji) return;
    _prepareUndoSnapshot();
    setState(() {
      activity.emoji = picked;
      for (var i = 0; i < logs.length; i++) {
        if (logs[i].activityId != activity.id) continue;
        final log = logs[i];
        logs[i] = ActivityLog(
          date: log.date,
          title: log.title,
          emoji: picked,
          category: log.category,
          period: log.period,
          day: log.day,
          plannedMinutes: log.plannedMinutes,
          realisedMinutes: log.realisedMinutes,
          feeling: _normalizeFeeling(log.feeling),
          unplanned: log.unplanned,
          planItemId: log.planItemId,
          activityId: log.activityId,
        );
      }
    });
    _queueLocalStatePersist();
    _showFeedback('Icône de « ${activity.name} » modifiée.');
  }

  Future<void> _manageCustomActivityIcons() async {
    await showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final customIcons = [..._customActivityIcons];
          final customEmojis = [..._customActivityEmojis];
          return AlertDialog(
            title: const Text('Mes icônes personnelles'),
            content: SizedBox(
              width: 430,
              height: 430,
              child: (customIcons.isEmpty && customEmojis.isEmpty)
                  ? const Center(child: Text('Aucune icône ou emoji personnel enregistré.'))
                  : ListView(
                      children: [
                        if (customIcons.isNotEmpty) ...[
                          const Text('Images', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          ...customIcons.map((icon) {
                            final token = 'customicon://${icon.id}';
                            final usage = _activityIconUsage(token);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: _activityIconWidget(token, size: 34),
                                title: Text(icon.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(usage == 0 ? 'Disponible dans la palette' : 'Utilisée par $usage activité${usage > 1 ? 's' : ''}'),
                                trailing: IconButton(
                                  tooltip: usage == 0 ? 'Supprimer' : 'Utilisée',
                                  onPressed: usage > 0
                                      ? null
                                      : () {
                                          setDialogState(() {
                                            _customActivityIcons.removeWhere((e) => e.id == icon.id);
                                            _customActivityIconData.remove(icon.id);
                                            _customActivityIconBytes.remove(icon.id);
                                          });
                                          _queueLocalStatePersist();
                                        },
                                  icon: _uiIcon('delete', Icons.delete_outline, size: 18, color: const Color(0xFFC27D68)),
                                ),
                              ),
                            );
                          }),
                        ],
                        if (customEmojis.isNotEmpty) ...[
                          if (customIcons.isNotEmpty) const SizedBox(height: 8),
                          const Text('Emojis personnels', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          ...customEmojis.map((entry) {
                            final usage = _activityIconUsage(entry.value);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: Text(entry.value, style: const TextStyle(fontSize: 28)),
                                title: Text(usage == 0 ? 'Emoji personnel' : 'Utilisé par $usage activité${usage > 1 ? 's' : ''}'),
                                trailing: IconButton(
                                  tooltip: 'Retirer de la palette',
                                  onPressed: () {
                                    setDialogState(() => _customActivityEmojis.removeWhere((e) => e.value == entry.value));
                                    _queueLocalStatePersist();
                                  },
                                  icon: _uiIcon('delete', Icons.delete_outline, size: 18, color: const Color(0xFFC27D68)),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
            ],
          );
        },
      ),
    );
  }

  void addOrEditActivity({Activity? original}) {
    final edit = original != null;
    final draft = original?.copy() ?? Activity(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      emoji: '✨',
      category: 'Loisir',
      duration: 30,
      frequency: 1,
      priority: 3,
    );
    final name = TextEditingController(text: draft.name);
    final duration = TextEditingController(text: '${draft.duration}');
    var category = draft.category;
    var period = ['Matin', 'Après-midi', 'Soir'].contains(draft.period) ? draft.period : 'Après-midi';
    var emoji = draft.emoji;
    var frequency = draft.frequency;
    var priority = draft.priority;
    var sportWeight = draft.sportWeight;
    var allowMultiplePerDay = draft.allowMultiplePerDay;
    var maxDailyOccurrences = draft.maxDailyOccurrences.clamp(2, 3).toInt();
    var preferred = Set<int>.from(draft.preferredDays);
    final sportGroup = draft.sportGroup;
    final sportGroupFrequency = draft.sportGroupFrequency;
    var activeInSportRotation = draft.activeInSportRotation;
    var dateRangeEnabled = draft.isDateRange && draft.category != 'Sport' && !draft.isSportProgram;
    DateTime? rangeStart = draft.rangeStart == null ? null : _dateOnly(draft.rangeStart!);
    DateTime? rangeEnd = draft.rangeEnd == null ? null : _dateOnly(draft.rangeEnd!);
    final sportDailyDurations = {...draft.sportDailyDurations};

    // Toujours inclure la valeur actuellement enregistrée dans les listes
    // déroulantes. Cela évite l'assertion Flutter si une ancienne sauvegarde
    // contient une icône ou une catégorie qui n'est plus proposée aujourd'hui.
    final categoryOptions = <String>[
      'Sport', 'Bien-être', 'Loisir', 'Culture', 'Sortie', 'Social'
    ];
    if (!categoryOptions.contains(category)) {
      categoryOptions.insert(0, category);
    }

    final emojiOptions = <String>[
      // 🌞 Journée / ambiance
      '🌞', '☀️', '🌤️', '⛅', '🌅', '🌄', '🌇', '🌙', '🌛', '🌜',
      '⭐', '🌟', '✨', '💫', '🌈', '☁️', '❄️', '🔥', '💧',
      // 🍎 Bien-être / quotidien
      '🍎', '🍐', '🍊', '🍋', '🍓', '🍒', '🍇', '🍉', '🥑', '🥗',
      '🍵', '☕', '🫖', '🥐', '🍞', '🍯', '🛀', '🧴', '🕯️', '🌿',
      '🌱', '🌸', '🌷', '🌻', '🌼', '🌺', '🪻', '🍀', '🪴', '🌵',
      // 🎨 Loisirs / culture
      '🎹', '🎸', '🎻', '🎺', '🥁', '🎵', '🎶', '🎤', '🎨', '🖌️',
      '📖', '📚', '📕', '📔', '✏️', '🖊️', '🧩', '♟️', '🎬', '🎧',
      '🎮', '📺', '📷', '🎥', '🎭', '🧶', '🪡', '🧵',
      // 🏃 Sport / mouvement
      '🚶', '🚶‍♂️', '🚶‍♀️', '🏊', '🚴', '🥾', '🏃', '🏃‍♂️', '🏃‍♀️',
      '🏋️', '💪', '🤸', '🤸‍♀️', '🧘', '🧘‍♀️', '🧘‍♂️', '🧗', '⛹️',
      '⚽', '🏀', '🎾', '🏸', '🥎', '🛼', '🛴', '🧘‍♂️', '☯️',
      // 🏠 Maison / organisation
      '🏠', '🏡', '🛋️', '🛏️', '🧹', '🧺', '🧼', '🧽', '🪣', '🧴',
      '🛒', '🛍️', '🧳', '🍽️', '🍿', '📅', '📝', '📌', '📍', '💻', '📱', '🗂️', '🗃️',
      // ❤️ Social / petits plaisirs
      '❤️', '🧡', '💛', '💚', '💙', '💜', '💕', '💖', '💝', '💞',
      '🥂', '🍰', '🎁', '😊', '😄', '🥰', '😌', '🤗', '🙏', '💌',
      '☀️', '👋', '🫶',
      // 🐻 Mascottes / animaux
      '🧸', '🐻', '🐼', '🐰', '🐱', '🦊', '🐨', '🐶', '🐹', '🐸',
      '🐧', '🐥', '🦋', '🐝', '🐢', '🐠', '🦄',
      // Nature / sorties
      '🌳', '🌲', '🌴', '🏞️', '🌊', '🏖️', '⛰️', '🏕️', '🌍', '🗺️',
      // Quelques icônes déjà utilisées / compatibles avec les anciennes fiches
      '⚡', '💗', '🌺', '😴', '💤'
    ];
    final dedupedEmojiOptions = _uniqueStrings(emojiOptions);
    if (!dedupedEmojiOptions.contains(emoji)) {
      dedupedEmojiOptions.insert(0, emoji);
    }

    void showSportHelp(String title, String message) {
      showDialog<void>(
        context: _navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris'))],
        ),
      );
    }

    showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(edit ? 'Modifier l’activité' : 'Nouvelle activité'),
          insetPadding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  scrollPadding: const EdgeInsets.only(bottom: 220),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    hintText: 'Nom de l’activité',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 7),
                Builder(
                  builder: (_) {
                    final suggestions = _suggestedEmojisForName(name.text, category);
                    if (suggestions.isEmpty) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7EC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF0E0C7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Icônes suggérées', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF7C6B59))),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: suggestions.map((value) => ActionChip(
                              label: value == '🧸' ? Row(mainAxisSize: MainAxisSize.min, children: [mascotChoiceAvatar(size: 20), const SizedBox(width: 4), const Text('Ourson')]) : Text(value, style: const TextStyle(fontSize: 19)),
                              onPressed: () => setDialogState(() => emoji = value),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            )).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 9),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categoryOptions
                      .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    category = v ?? category;
                    if (category == 'Sport') dateRangeEnabled = false;
                  }),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final picked = await showDialog<String>(
                      context: context,
                      builder: (pickerContext) => StatefulBuilder(
                        builder: (pickerContext, setPickerState) {
                          final customValues = _customActivityEmojis.map((e) => e.value).toList();
                          final values = [...dedupedEmojiOptions, ...customValues, ..._customActivityIcons.map((e) => 'customicon://${e.id}')];
                          final uniqueValues = <String>[];
                          for (final v in values) {
                            if (!uniqueValues.contains(v)) uniqueValues.add(v);
                          }
                          return AlertDialog(
                            title: const Text('Choisir une icône'),
                            content: SizedBox(
                              width: 420,
                              height: 410,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final value = await _pickCustomActivityIconImage();
                                            if (value != null && pickerContext.mounted) Navigator.pop(pickerContext, value);
                                          },
                                          icon: _uiIcon('photo', Icons.add_photo_alternate_outlined, size: 18),
                                          label: const Text('Importer une image'),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            final value = await _addCustomActivityEmoji();
                                            if (value != null && pickerContext.mounted) Navigator.pop(pickerContext, value);
                                          },
                                          icon: _uiIcon('emoji', Icons.emoji_emotions_outlined, size: 18),
                                          label: const Text('Ajouter un emoji'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await _manageCustomActivityIcons();
                                        if (pickerContext.mounted) setPickerState(() {});
                                      },
                                      icon: _uiIcon('manageIcons', Icons.tune, size: 16),
                                      label: const Text('Gérer mes icônes'),
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Expanded(
                                    child: GridView.builder(
                                      padding: const EdgeInsets.all(4),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 6,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        childAspectRatio: 1,
                                      ),
                                      itemCount: uniqueValues.length,
                                      itemBuilder: (_, index) {
                                        final value = uniqueValues[index];
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(13),
                                          onTap: () => Navigator.pop(pickerContext, value),
                                          child: Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: value == emoji ? const Color(0xFFEAF2ED) : const Color(0xFFF8F5EF),
                                              borderRadius: BorderRadius.circular(13),
                                              border: Border.all(color: value == emoji ? const Color(0xFFB9CCBF) : const Color(0xFFE4DED5)),
                                            ),
                                            child: _activityIconWidget(value, size: 30),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                    if (picked != null) setDialogState(() => emoji = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Icône',
                      helperText: 'Appuie pour ouvrir la palette d’icônes.',
                    ),
                    child: Row(children: [
                      _activityIconWidget(emoji, size: 26),
                      const SizedBox(width: 9),
                      const Expanded(child: Text('Choisir une icône')),
                      const Icon(Icons.expand_more_rounded),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),                if (category == 'Sport' || draft.isSportProgram) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Durée de référence (min)'),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: period,
                    decoration: const InputDecoration(labelText: 'Moment habituel'),
                    items: const ['Matin', 'Après-midi', 'Soir'].map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setDialogState(() => period = v ?? period),
                  ),
                ],
                if (category != 'Sport' && !draft.isSportProgram) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                    decoration: BoxDecoration(
                      color: dateRangeEnabled ? const Color(0xFFEFF5F1) : const Color(0xFFF6F4EF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: dateRangeEnabled ? const Color(0xFFCFE0D5) : const Color(0xFFE2DED6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('🗓️', style: TextStyle(fontSize: 19)),
                          const SizedBox(width: 7),
                          const Expanded(child: Text('Activité quotidienne sur une période', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5))),
                          Switch.adaptive(
                            value: dateRangeEnabled,
                            onChanged: (value) {
                              setDialogState(() {
                                dateRangeEnabled = value;
                                if (value && rangeStart == null) {
                                  rangeStart = _dateOnly(DateTime.now());
                                  rangeEnd = rangeStart;
                                }
                              });
                            },
                          ),
                        ]),
                        if (dateRangeEnabled) ...[
                          const SizedBox(height: 3),
                          const Text('Exemple : road trip, stage ou atelier réalisé chaque jour du début à la fin.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF606A66), height: 1.30)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final initial = rangeStart ?? _dateOnly(DateTime.now());
                                  final picked = await showDatePicker(
                                    context: _navigatorKey.currentContext!,
                                    initialDate: initial,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                    helpText: 'Début de la période',
                                    cancelText: 'Annuler',
                                    confirmText: 'Choisir',
                                  );
                                  if (picked == null) return;
                                  setDialogState(() {
                                    rangeStart = _dateOnly(picked);
                                    if (rangeEnd == null || rangeEnd!.isBefore(rangeStart!)) rangeEnd = rangeStart;
                                  });
                                },
                                icon: _uiIcon('calendar', Icons.event_outlined, size: 18),
                                label: Text(rangeStart == null ? 'Date début' : _shortDate(rangeStart!)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('→', style: TextStyle(fontWeight: FontWeight.w900))),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final initial = rangeEnd ?? rangeStart ?? _dateOnly(DateTime.now());
                                  final picked = await showDatePicker(
                                    context: _navigatorKey.currentContext!,
                                    initialDate: initial.isBefore(rangeStart ?? DateTime(2020)) ? (rangeStart ?? initial) : initial,
                                    firstDate: rangeStart ?? DateTime(2020),
                                    lastDate: DateTime(2100),
                                    helpText: 'Fin de la période',
                                    cancelText: 'Annuler',
                                    confirmText: 'Choisir',
                                  );
                                  if (picked == null) return;
                                  setDialogState(() => rangeEnd = _dateOnly(picked));
                                },
                                icon: _uiIcon('calendar', Icons.event_available_outlined, size: 18),
                                label: Text(rangeEnd == null ? 'Date fin' : _shortDate(rangeEnd!)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                              ),
                            ),
                          ]),
                          if (rangeStart != null && rangeEnd != null && rangeEnd!.isBefore(rangeStart!))
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Text('La date de fin doit être postérieure ou égale à la date de début.', style: TextStyle(fontSize: 10.5, color: Color(0xFFB56A5A), fontWeight: FontWeight.w700)),
                            )
                          else if (rangeStart != null && rangeEnd != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(_dateRangeLabel(Activity(id: '_tmp', name: '', emoji: '', category: category, duration: 1, frequency: 1, priority: 1, isDateRange: true, rangeStart: rangeStart, rangeEnd: rangeEnd)), style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F7777), fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (draft.isSportProgram) ...[
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text('Durée Sport par jour', style: TextStyle(fontWeight: FontWeight.w900))),
                  const SizedBox(height: 4),
                  const Align(alignment: Alignment.centerLeft, child: Text('Le curseur fixe le plafond quotidien. Les activités Sport restent à l’intérieur de ce budget.', style: TextStyle(fontSize: 12, color: Color(0xFF6F7777)))),
                  const SizedBox(height: 6),
                  ...List.generate(7, (day) => _SportDailySlider(
                    label: dayNames[day],
                    value: sportDailyDurations[day] ?? 0,
                    onChanged: (v) => setDialogState(() => sportDailyDurations[day] = v),
                  )),
                ],
                if (!dateRangeEnabled || category == 'Sport') ...[
                  const SizedBox(height: 10),
                  _StepperLine(
                    label: category == 'Sport' ? 'Jours avec cette activité / semaine' : 'Fréquence / semaine',
                    value: frequency,
                    min: 1,
                    max: 7,
                    onChanged: (v) => setDialogState(() => frequency = v),
                  ),
                ],
                if (category == 'Sport')
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Les jours/semaine et les occurrences dans une même journée sont deux réglages indépendants.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6F7777)),
                    ),
                  ),
                if (category == 'Sport') ...[
                  Row(children: [
                    Expanded(child: _StepperLine(label: 'Priorité', value: priority, min: 1, max: 5, onChanged: (v) => setDialogState(() => priority = v))),
                    IconButton(icon: _uiIcon('help', Icons.info_outline, size: 18), tooltip: 'Expliquer la priorité', onPressed: () => showSportHelp('Priorité', 'La priorité indique l’importance de cette activité dans tes choix Sport. Plus elle est élevée, plus le coach la favorise lorsqu’il doit arbitrer entre plusieurs possibilités.')),
                  ]),
                  Row(children: [
                    Expanded(child: _StepperLine(label: 'Poids dans la rotation sport', value: sportWeight, min: 1, max: 10, onChanged: (v) => setDialogState(() => sportWeight = v))),
                    IconButton(icon: _uiIcon('help', Icons.info_outline, size: 18), tooltip: 'Expliquer le poids', onPressed: () => showSportHelp('Poids dans la rotation', 'Le poids est un réglage plus fin du choix automatique. Un poids élevé donne davantage de préférence à cette activité, sans imposer qu’elle soit choisie à chaque fois.')),
                  ]),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F4F1), borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Expanded(child: Text('Plusieurs fois dans la même journée', style: TextStyle(fontWeight: FontWeight.w800))),
                        IconButton(icon: _uiIcon('help', Icons.info_outline, size: 18), tooltip: 'Expliquer', onPressed: () => showSportHelp('Plusieurs fois par jour', 'Cette option demande à la même activité Sport d’apparaître plusieurs fois le même jour. Le nombre d’occurrences est réglable de 2 à 3 et chaque séance reste indépendante. Si le budget du jour ne suffit pas, le planning ne peut pas toutes les placer.')),
                        Switch.adaptive(value: allowMultiplePerDay, onChanged: (v) => setDialogState(() => allowMultiplePerDay = v)),
                      ]),
                      if (allowMultiplePerDay) ...[
                        _StepperLine(label: "Nombre d'occurrences par jour", value: maxDailyOccurrences, min: 2, max: 3, onChanged: (v) => setDialogState(() => maxDailyOccurrences = v)),
                        const Text('Exemple : 2 occurrences = 20 min le matin + 20 min en fin de journée.', style: TextStyle(fontSize: 11, color: Color(0xFF6F7777))),
                      ],
                    ]),
                  ),
                ] else ...[
                  _StepperLine(label: 'Priorité', value: priority, min: 1, max: 5, onChanged: (v) => setDialogState(() => priority = v)),
                  if (!dateRangeEnabled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0E7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5D8C7)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          _uiIcon('repeat', Icons.repeat_rounded, size: 18, color: const Color(0xFF7A6A59)),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Plusieurs réalisations dans la même journée', style: TextStyle(fontWeight: FontWeight.w800))),
                          IconButton(
                            icon: _uiIcon('help', Icons.info_outline, size: 18),
                            tooltip: 'Expliquer',
                            onPressed: () => showSportHelp(
                              'Plusieurs réalisations par jour',
                              'Cette option permet d’enregistrer plusieurs réalisations de la même activité le même jour. Tu peux demander jusqu’à 3 occurrences. Elles restent indépendantes dans le planning et l’historique.',
                            ),
                          ),
                          Switch.adaptive(value: allowMultiplePerDay, onChanged: (v) => setDialogState(() => allowMultiplePerDay = v)),
                        ]),
                        if (allowMultiplePerDay) ...[
                          _StepperLine(label: "Nombre maximal de réalisations par jour", value: maxDailyOccurrences, min: 2, max: 3, onChanged: (v) => setDialogState(() => maxDailyOccurrences = v)),
                          const Text('Exemple : 2 réalisations = 20 min le matin + 20 min le soir.', style: TextStyle(fontSize: 11, color: Color(0xFF6F7777))),
                        ],
                      ]),
                    ),
                  ],
                ],
                if (category == 'Sport' && !draft.isSportProgram) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: activeInSportRotation ? const Color(0xFFEAF1ED) : const Color(0xFFF1EEE8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: activeInSportRotation ? const Color(0xFFC9D9CF) : const Color(0xFFDCD8CF),
                      ),
                    ),
                    child: Row(
                      children: [
                        _activityIconWidget(draft.emoji, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeInSportRotation ? 'Dans la rotation Sport' : 'Mise en attente · « Plus tard »',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeInSportRotation
                                    ? 'L’activité pourra être proposée cette semaine.'
                                    : 'L’activité reste enregistrée et pourra être réactivée depuis Semaine Sport.',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F7777)),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: activeInSportRotation,
                          onChanged: (value) => setDialogState(() => activeInSportRotation = value),
                        ),
                      ],
                    ),
                  ),
                ],
                if (category == 'Sport' && sportGroup != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      activeInSportRotation
                          ? 'Rotation : ${sportGroup!} · cible ${sportGroupFrequency ?? frequency}×/semaine'
                          : 'Rotation : ${sportGroup!} · mise en attente (« plus tard »)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                if (!dateRangeEnabled) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Jours préférés', style: Theme.of(context).textTheme.labelLarge),
                  ),
                const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (day) {
                      final selected = preferred.contains(day);
                      return FilterChip(
                        selected: selected,
                        label: Text(dayNames[day].substring(0, 3)),
                        onSelected: (_) => setDialogState(() {
                          if (selected) {
                            preferred.remove(day);
                          } else {
                            preferred.add(day);
                          }
                        }),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            if (edit)
              TextButton(
                onPressed: () {
                  setState(() {
                    activities.removeWhere((a) => a.id == original.id);
                    plan.removeWhere((p) => p.activityId == original.id);
                  });
                  _queueLocalStatePersist();
                  Navigator.pop(context);
                },
                child: const Text('Supprimer'),
              ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                if (dateRangeEnabled && (rangeStart == null || rangeEnd == null || rangeEnd!.isBefore(rangeStart!))) {
                  _showFeedback('Choisis une période valide pour cette activité.');
                  return;
                }
                final updated = Activity(
                  id: draft.id,
                  name: name.text.trim(),
                  emoji: emoji,
                  category: category,
                  period: category == 'Sport' || draft.isSportProgram ? draft.period : period,
                  duration: category == 'Sport' || draft.isSportProgram ? (int.tryParse(duration.text) ?? 30) : draft.duration,
                  frequency: frequency,
                  priority: priority,
                  preferredDays: preferred.toList()..sort(),
                  isDateRange: dateRangeEnabled && category != 'Sport' && !draft.isSportProgram,
                  rangeStart: dateRangeEnabled && category != 'Sport' && !draft.isSportProgram ? rangeStart : null,
                  rangeEnd: dateRangeEnabled && category != 'Sport' && !draft.isSportProgram ? rangeEnd : null,
                  sportWeight: sportWeight,
                  allowMultiplePerDay: !dateRangeEnabled ? allowMultiplePerDay : false,
                  maxDailyOccurrences: !dateRangeEnabled ? maxDailyOccurrences : 2,
                  sportGroup: sportGroup,
                  sportGroupFrequency: sportGroupFrequency,
                  activeInSportRotation: activeInSportRotation,
                  isSportProgram: draft.isSportProgram,
                  sportDailyDurations: draft.isSportProgram ? {...sportDailyDurations} : draft.sportDailyDurations,
                );
                final changedSportDays = <int>[];
                if (draft.isSportProgram) {
                  for (var day = 0; day < 7; day++) {
                    final before = draft.sportDailyDurations[day] ?? 0;
                    final after = sportDailyDurations[day] ?? 0;
                    if (before != after) changedSportDays.add(day);
                  }
                }
                setState(() {
                  if (edit) {
                    final index = activities.indexWhere((a) => a.id == original.id);
                    if (index >= 0) activities[index] = updated;
                    for (var i = 0; i < logs.length; i++) {
                      final log = logs[i];
                      if (log.activityId != updated.id) continue;
                      logs[i] = ActivityLog(
                        date: log.date,
                        title: log.title,
                        emoji: updated.emoji,
                        category: updated.category,
                        period: log.period,
                        day: log.day,
                        plannedMinutes: log.plannedMinutes,
                        realisedMinutes: log.realisedMinutes,
                        feeling: _normalizeFeeling(log.feeling),
                        unplanned: log.unplanned,
                        planItemId: log.planItemId,
                        activityId: log.activityId,
                      );
                    }
                    _syncActivityToWeek(updated, previous: original);
                  } else {
                    activities.add(updated);
                    _syncActivityToWeek(updated);
                  }
                  if (updated.isSportProgram) {
                    for (final day in changedSportDays) {
                      _refreshSportDay(day);
                    }
                    _sortPlan();
                  }
                });
                _queueLocalStatePersist();
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  // La fiche doit se fermer immédiatement. Le réglage Sport
                  // (notamment plusieurs occurrences par jour) est appliqué
                  // après fermeture, sans lancer de gros recalcul dans
                  // setState de la boîte de dialogue.
                  if (_isSportActivity(updated)) {
                    _applyEditedSportActivityOccurrences(updated);
                    _queueLocalStatePersist();
                  }
                  if (!mounted) return;
                  _scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(edit
                          ? '« ${updated.name} » modifiée.'
                          : '« ${updated.name} » ajoutée.'),
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

}
