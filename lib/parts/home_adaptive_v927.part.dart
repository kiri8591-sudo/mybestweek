// V9.27 — Accueil réellement adaptatif
// La présentation de l’Accueil varie selon le moment et ce qu’il reste à vivre.
// Aucune mécanique de décision n’est exposée à l’utilisateur.

part of '../main.dart';

extension _AdaptiveHomeV927Part on _MaBelleSemaineAppState {
  int _homePeriodRank(String period) {
    switch (period) {
      case 'Matin':
        return 0;
      case 'Après-midi':
      case 'Midi':
        return 1;
      case 'Soir':
        return 2;
    }
    return 3;
  }

  bool _homePeriodIsPast(String period) {
    final current = _clockNow.hour < 12
        ? 0
        : _clockNow.hour < 18
            ? 1
            : 2;
    return _homePeriodRank(period) < current;
  }

  bool _homePeriodHasUnfinishedItems(String period, List<PlanItem> todayItems) {
    return todayItems.any((item) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      return item.period == period &&
          !_isDateRangePlanItem(item) &&
          !item.done &&
          !(activity != null && _isSportActivity(activity));
    });
  }

  bool _homeShouldShowPeriod(String period, List<PlanItem> periodItems, List<PlanItem> todayItems) {
    // Garder l’en-tête visible même lorsque le créneau est passé et entièrement réalisé,
    // afin de permettre son dépliage manuel. Le contenu sera automatiquement replié.
    if (periodItems.isNotEmpty) return true;
    if (!_homePeriodIsPast(period)) return true;
    return _homePeriodHasUnfinishedItems(period, todayItems);
  }

  Widget _adaptiveHomeContextCard({
    required List<PlanItem> todayActionItems,
    required int todayDone,
    required bool todayCompleted,
    required double weekProgress,
    required int weekCompleted,
    required int weekTotal,
  }) {
    final remaining = todayActionItems.where((item) => !item.done).toList();
    final remainingMinutes = remaining.fold<int>(0, (sum, item) => sum + max(0, item.duration));
    final todayWeather = _weatherForWeekDay(today);
    final outdoorRemaining = remaining.any((item) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      return activity != null && _isOutdoorPlanningActivity(activity);
    });
    final hasSport = remaining.any((item) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      return activity != null && _isSportActivity(activity);
    });
    final hasMusic = remaining.any((item) {
      final activity = item.activityId == null ? null : findActivity(item.activityId!);
      return activity != null && activity.name.toLowerCase().contains('piano');
    });

    final hour = _clockNow.hour;
    final morning = hour < 12;
    final afternoon = hour >= 12 && hour < 18;
    final evening = hour >= 18 && hour < 22;
    final night = hour >= 22;

    final lightDay = todayActionItems.length <= 2;
    final busyDay = todayActionItems.length >= 5 || remainingMinutes >= 150;
    final weatherBad = outdoorRemaining && todayWeather?.outdoorBad == true;

    String title;
    String message;
    String icon;
    Color background;
    Color border;

    if (todayCompleted) {
      title = night ? 'La journée est derrière toi' : 'Ta journée est accomplie';
      message = night
          ? 'Tout est fait. Tu peux simplement profiter de la soirée.'
          : 'Tout ce qui était prévu est fait. Garde maintenant un peu de place pour toi ✨';
      icon = night ? '🌙' : '✨';
      background = _colors.tintStrong;
      border = _colors.borderTint;
    } else if (weatherBad) {
      title = evening ? 'Pour la suite' : 'Un petit ajustement de rythme';
      message = evening
          ? 'La sortie prévue peut attendre un moment plus favorable. Le reste de la journée reste ouvert.'
          : 'La météo est moins accueillante pour sortir. Garde les activités extérieures pour le bon moment.';
      icon = todayWeather?.icon ?? '🌦️';
      background = _colors.tintStrong;
      border = _colors.borderTint;
    } else if (night) {
      title = 'Pour demain';
      message = remaining.isEmpty
          ? 'La journée se termine doucement. Rien ne presse maintenant.'
          : '${remaining.length} moment${remaining.length > 1 ? 's' : ''} reste${remaining.length > 1 ? 'nt' : ''}, mais tu peux les laisser vivre à leur rythme.';
      icon = '🌙';
      background = _colors.surfaceSoft;
      border = _colors.borderTint;
    } else if (evening) {
      title = busyDay ? 'La journée avance bien' : 'Pour terminer la journée';
      message = remaining.isEmpty
          ? 'Il ne reste rien d’essentiel à accomplir. Profite de ton temps.'
          : remaining.length == 1
              ? 'Il reste un dernier moment à vivre tranquillement.${hasMusic ? ' 🎵' : hasSport ? ' 💪' : ''}'
              : '${remaining.length} moments restent à vivre · ${remainingMinutes} min environ.';
      icon = remaining.isEmpty ? '🌙' : '☕';
      background = _colors.surfaceSunken;
      border = _colors.borderStrong;
    } else if (afternoon) {
      title = todayDone > 0 ? 'La journée est bien lancée' : (busyDay ? 'Une journée bien remplie' : 'L’après-midi est à toi');
      message = weatherBad
          ? 'La suite peut rester souple. Tu as déjà donné son rythme à la journée.'
          : remaining.isEmpty
              ? 'Le programme du jour est déjà largement derrière toi. Garde de la place pour l’imprévu.'
              : '${remaining.length} moment${remaining.length > 1 ? 's' : ''} à vivre encore'
                  '${remainingMinutes > 0 ? ' · environ $remainingMinutes min' : ''}'
                  '${outdoorRemaining ? ' · le plein air peut trouver sa place' : ''}';
      icon = outdoorRemaining ? '🌿' : (hasSport ? '💪' : (hasMusic ? '🎵' : '🌤️'));
      background = _colors.tintStrong;
      border = _colors.borderTint;
    } else {
      title = busyDay ? 'Une belle journée se prépare' : (lightDay ? 'Une journée légère' : 'Pour bien commencer');
      message = weatherBad
          ? 'Commence tranquillement : la météo invitera peut-être à garder la sortie pour plus tard.'
          : remaining.length == 1
              ? 'Un premier moment suffit pour donner le ton à la journée.'
              : '${remaining.length} moments t’attendent aujourd’hui.'
                  '${outdoorRemaining ? ' Le plein air pourra apporter une vraie respiration.' : ''}';
      icon = outdoorRemaining ? '🌿' : (hasMusic ? '🎵' : (hasSport ? '💪' : '☀️'));
      background = lightDay ? _colors.peachBg : _colors.peachBg;
      border = lightDay ? _colors.goldBorder : _colors.goldBorder;
    }

    final progressLabel = weekTotal == 0
        ? 'La semaine peut commencer à son rythme.'
        : weekCompleted >= weekTotal
            ? 'Ta semaine est accomplie ✨'
            : '${weekTotal - weekCompleted} moment${weekTotal - weekCompleted > 1 ? 's' : ''} restent à vivre cette semaine.';

    return softCard(
      color: background,
      borderColor: border,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _colors.card.withValues(alpha: .74),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: AppType.h1)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700, color: _colors.textStrong)),
                    const SizedBox(height: 3),
                    Text(message, style: TextStyle(fontSize: AppType.small, height: 1.28, fontWeight: FontWeight.w700, color: _colors.accentIcon)),
                  ],
                ),
              ),
              if (todayActionItems.isNotEmpty) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _colors.card.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('$todayDone/${todayActionItems.length}', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.accentIcon)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(progressLabel, style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.accentIcon)),
              ),
              const SizedBox(width: 8),
              Text('${(weekProgress * 100).round()} %', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: _colors.accentIcon)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: weekProgress,
              minHeight: 4,
              backgroundColor: _colors.tintStrong,
              valueColor: AlwaysStoppedAnimation<Color>(_colors.accentOutline),
            ),
          ),
        ],
      ),
    );
  }
}
