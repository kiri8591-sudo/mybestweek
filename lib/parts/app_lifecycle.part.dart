// V9.14 — Cycle de vie de l'application.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _AppLifecyclePart on _MaBelleSemaineAppState {
  void _initializeAppLifecycle() {
    final random = Random();
    _morningThought = _MaBelleSemaineAppState.morningThoughts[random.nextInt(_MaBelleSemaineAppState.morningThoughts.length)];
    _morningThoughtIcon = _MaBelleSemaineAppState._morningThoughtIcons[random.nextInt(_MaBelleSemaineAppState._morningThoughtIcons.length)];
    _focusIcon = _MaBelleSemaineAppState._focusIcons[random.nextInt(_MaBelleSemaineAppState._focusIcons.length)];
    _focusVariant = random.nextInt(3);
    generateWeek(showSnack: false);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _clockNow = DateTime.now());
    });

    // iPhone / Safari / PWA : sauvegarde synchrone dès que la page passe
    // en arrière-plan ou qu'elle est masquée. Cela complète la sauvegarde
    // immédiate faite après chaque modification de données.
    _visibilitySubscription = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'hidden') {
        _persistLocalState();
      }
    });
    _pageHideSubscription = html.window.onPageHide.listen((_) {
      _persistLocalState();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadLocalState();
      if (mounted && _weatherCity.trim().isNotEmpty) {
        await _loadWeather();
      }
    });
  }

  void _disposeAppLifecycle() {
    // Dernière tentative synchrone avant destruction du State.
    _persistLocalState();
    _visibilitySubscription?.cancel();
    _pageHideSubscription?.cancel();
    _clockTimer?.cancel();
  }
}
