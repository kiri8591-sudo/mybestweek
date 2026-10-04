// V9.22 — Cycle de vie de l'application.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _AppLifecyclePart on _MaBelleSemaineAppState {
  void _initializeAppLifecycle() {
    WidgetsBinding.instance.addObserver(this);
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
    if (kIsWeb) {
      _visibilitySubscription = html.document.onVisibilityChange.listen((_) {
        if (html.document.visibilityState == 'hidden') {
          _persistLocalState(recordUndo: false);
        }
      });
      _pageHideSubscription = html.window.onPageHide.listen((_) {
        _persistLocalState(recordUndo: false);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLocalState();
      if (mounted && _weatherCity.trim().isNotEmpty) {
        await _loadWeather();
      }
      if (mounted) {
        // Après restauration de l'état et de la météo, le message du matin
        // reflète à nouveau la journée réellement proposée.
        refreshMorningThought();
        // Le recalcul initial de la pensée est une mise à jour automatique,
        // pas une action utilisateur : il ne doit pas armer « Annuler ».
        _undoSnapshotJson = null;
        if (mounted) setState(() {});
      }
    });
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Sur iPhone, quitter l'application par balayage peut interrompre
      // une écriture SharedPreferences encore en attente. On force ici une
      // nouvelle sauvegarde de l'état courant et on attend la fin de la
      // chaîne d'écritures tant que le cycle de vie nous laisse du temps.
      unawaited(_persistForAppLifecycle());
    }
  }

  Future<void> _persistForAppLifecycle() async {
    if (!mounted || _isHydratingLocalState) return;
    _persistenceGeneration++;
    _persistLocalState(recordUndo: false);
    await _flushPersistenceWrites();
  }

  void _disposeAppLifecycle() {
    // Dernière tentative avant destruction du State. La sauvegarde de cycle
    // de vie est prioritaire sur l'ancien simple appel best-effort.
    if (!_isHydratingLocalState) {
      _persistLocalState(recordUndo: false);
    }
    WidgetsBinding.instance.removeObserver(this);
    _visibilitySubscription?.cancel();
    _pageHideSubscription?.cancel();
    _clockTimer?.cancel();
  }
}
