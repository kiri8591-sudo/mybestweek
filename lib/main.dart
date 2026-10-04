// V12.0.0 — finale : socle Coach stabilisé + persistance/fichiers multiplateformes.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/universal_html.dart' as html;

part 'parts/models.part.dart';
part 'parts/default_data.part.dart';
part 'parts/state_persistence.part.dart';
part 'parts/planning_coach.part.dart';
part 'parts/state_sport_planning.part.dart';
part 'parts/activity_management.part.dart';
part 'parts/state_weather_home.part.dart';
part 'parts/history.part.dart';
part 'parts/today_planning_v925.part.dart';
part 'parts/weekly_review_v919.part.dart';
part 'parts/sport_ui.part.dart';
part 'parts/plan_interaction.part.dart';
part 'parts/main_screens_v925.part.dart';
part 'parts/reusable_sheets_v921.part.dart';
part 'parts/system_icons.part.dart';
part 'parts/daily_coach_summary.part.dart';
part 'parts/planning_helpers.part.dart';
part 'parts/plan_completion_v924.part.dart';
part 'parts/date_range_navigation.part.dart';
part 'parts/home_planning_v925.part.dart';
part 'parts/sport_runtime_ui.part.dart';
part 'parts/sport_engine_v920.part.dart';
part 'parts/app_core_helpers_v922.part.dart';
part 'parts/app_shell.part.dart';
part 'parts/completion_celebration.part.dart';
part 'parts/branding.part.dart';
part 'parts/app_lifecycle_v922.part.dart';
part 'parts/undo.part.dart';
part 'parts/home_adaptive_v927.part.dart';
part 'parts/priorities_v928.part.dart';
part 'parts/objectives_v929.part.dart';

void main() {
  if (kIsWeb) _installMascotBrowserIcon();
  runApp(const MaBelleSemaineApp());
}

class MaBelleSemaineApp extends StatefulWidget {
  const MaBelleSemaineApp({super.key});

  @override
  State<MaBelleSemaineApp> createState() => _MaBelleSemaineAppState();
}



class _MaBelleSemaineAppState extends State<MaBelleSemaineApp> {
  static const version = 'V12.3.13';
  static const buildVersion = '12.3.13+17';

  static const List<String> morningThoughts = [
    'Une belle journée n’a pas besoin d’être remplie pour être réussie.',
    'Aujourd’hui, avance tranquillement : un petit pas reste un pas.',
    'Prendre son temps n’est pas perdre son temps.',
    'Il y a toujours une bonne raison de profiter de la journée qui commence.',
    'La retraite, c’est aussi le plaisir de choisir ce qui mérite vraiment son temps.',
    'Pas besoin de tout faire aujourd’hui. Quelques bons moments suffisent.',
    'Une promenade, quelques notes de piano, un bon livre : voilà déjà une belle journée.',
    'Fais de la place aux choses qui te font du bien, sans chercher la perfection.',
    'Le meilleur programme reste celui qui laisse un peu de place à l’imprévu.',
    'Aujourd’hui n’est pas une course. C’est une journée à savourer.',
  ];

  late String _morningThought;
  late String _morningThoughtIcon;
  late String _focusIcon;
  late int _focusVariant;

  static const List<String> _morningThoughtIcons = ['☀️', '🌿', '🌸', '🧸', '✨'];
  static const List<String> _focusIcons = ['🎯', '🌿', '🧸', '💪', '🎵', '☕'];

  final dayNames = const [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  int tab = 0;
  String categoryFilter = 'Toutes';

  // Recherche dans « Mes activités » (V9.18)
  bool _showActivitySearch = false;
  String _activitySearchQuery = '';

  void _openActivitySearch() {
    setState(() => _showActivitySearch = true);
  }

  void _closeActivitySearch() {
    setState(() {
      _showActivitySearch = false;
      _activitySearchQuery = '';
    });
  }

  void _updateActivitySearch(String value) {
    setState(() => _activitySearchQuery = value);
  }
  int _weekSelectedDay = -1;
  int _resetGeneration = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  SharedPreferencesWithCache? _preferences;
  static const String _localStateKey = 'ma_belle_semaine_local_state_v2';
  static const String _localStateMirrorKey = 'ma_belle_semaine_local_state_v2_last_good';
  static const int _cloudBackupReminderDays = 7;
  bool _persistenceQueued = false;
  // Toutes les écritures locales sont sérialisées. Un ancien setString ne peut
  // ainsi plus terminer après une réinitialisation et remettre l'ancien état.
  Future<void> _persistenceWriteChain = Future<void>.value();
  // Numéro de génération des écritures différées : un Undo invalide
  // toute écriture programmée avant sa restauration.
  int _persistenceGeneration = 0;
  final Set<String> _sportValidationInProgress = <String>{};
  bool _homeSportExpanded = false;
  final Set<String> _homeExpandedPeriods = <String>{};

  // Critères utilisés uniquement pour les nouvelles occurrences générées.
  // Ils n'autorisent jamais « Repenser » à modifier les jours passés ni aujourd'hui.
  bool _generationRespectPriorities = true;
  bool _generationUseHistory = true;
  bool _generationBalanceLoad = true;
  bool _generationRespectPreferredDays = true;
  bool _generationAlternateActivities = true;
  bool _generationLearnHabits = true;
  String _lastPlanningRegeneratedWeekKey = '';
  List<int> _lastPlanningRegeneratedDays = [];
  DateTime? _lastPlanningRegeneratedAt;
  DateTime? _planningReportReadAt;
  String _lastPlanningCoachExplanation = '';
  List<String> _lastPlanningDecisionDetails = [];
  final Map<String, String> _generationActivityRules = {};
  // Budgets Sport temporaires attribués à des jours futurs lors d'une
  // régénération, lorsque les jours Sport configurés sont déjà passés.
  // Ils ne modifient pas la configuration récurrente de l'activité Sport.
  final Map<int, int> _regeneratedSportBudgets = {};
  bool _mondayRegenPromptDismissed = false;
  // Après une réinitialisation complète, la prochaine régénération repart
  // du lundi de la semaine courante au lieu de préserver le passé.
  bool _regenerateWholeWeekAfterReset = false;
  bool _lastPlanningWasFullWeek = false;
  bool _isHydratingLocalState = true;

  // Une seule annulation, valable pour la dernière modification de données.
  // Le snapshot reste en mémoire uniquement : il ne fait pas partie de la
  // sauvegarde utilisateur.
  String? _undoSnapshotJson;
  bool _undoInProgress = false;
  bool _undoActionPrepared = false;
  String? _undoActionDescription;
  // Contexte ciblé pour une restauration d’icône. Le snapshot global reste
  // la source de vérité, mais cette information garantit que l’objet affiché
  // reprend explicitement son ancienne icône après un Undo.
  String? _undoIconActivityId;
  String? _undoIconPreviousValue;
  String? _undoIconActivityName;
  DateTime? _lastICloudBackupAt;
  DateTime? _lastFileBackupAt;
  String _userName = '';
  String _weatherCity = '';
  String _todayNameday = '';
  String _todayNamedayDateKey = '';
  String _weatherText = '';
  String _weatherIcon = '🌤️';
  String _weatherTemperature = '';
  String _weatherError = '';
  bool _weatherLoading = false;
  final Map<String, _DayWeather> _weatherForecast = {};
  String _homeMascotKind = 'ourson'; // ourson | emoji | photo
  String _homeMascotEmoji = '🧸';
  String _homeMascotImageData = '';
  final List<_CustomActivityEmoji> _customActivityEmojis = [];
  final List<_CustomActivityIcon> _customActivityIcons = [];

  // V9.28 — Priorités du jour : 1 à 5 activités choisies par l'utilisateur.
  final Set<String> _dailyPriorityActivityIds = <String>{};
  String _priorityBonusAwardedDateKey = '';
  bool _priorityBonusAwarded = false;
  int _priorityBonusTotal = 0;
  String _priorityRewardText = 'un moment plaisir';
  // V9.29 — Objectifs de réalisation et streak Sport.
  final List<RealizationGoal> _realizationGoals = <RealizationGoal>[];

  // Icônes personnalisables de l'interface (en-têtes, navigation et boutons).
  // La valeur peut être un emoji ou un token customicon:// existant.
  final Map<String, String> _systemIconOverrides = {};
  DateTime _clockNow = DateTime.now();
  Timer? _clockTimer;
  StreamSubscription? _visibilitySubscription;
  StreamSubscription? _pageHideSubscription;

  bool get _cloudBackupReminderDue =>
      _lastICloudBackupAt == null ||
      DateTime.now().difference(_lastICloudBackupAt!).inHours >= _cloudBackupReminderDays * 24;

  List<Activity> activities = _defaultActivities();

  List<PlanItem> plan = [];
  List<ActivityLog> logs = [];
  List<DailySummary> dailySummaries = [];
  List<ActivityMoveLog> activityMoveLogs = [];
  // Nombre d'occurrences retirées manuellement pour chaque activité et jour.
  // Ces exceptions sont prises en compte par les prochaines générations.
  Map<String, Map<int, int>> _manualDayRemovals = {};
  // Les retraits manuels sont valables uniquement pour la semaine où ils ont
  // été effectués. Cela évite qu'un retrait du lundi reste actif la semaine suivante.
  String _manualDayRemovalsWeekKey = '';
  String weeklyNote = '';

  // Directions choisies le dimanche pour guider la régénération du lundi.
  final Set<String> _nextWeekCoachDirections = <String>{};

  // Permet aux extensions UI de modifier l’état sans appeler directement le
  // membre protégé State.setState depuis une extension.
  void _setNextWeekCoachDirections(Iterable<String> directions) {
    setState(() {
      _nextWeekCoachDirections
        ..clear()
        ..addAll(directions);
    });
  }

  void _setMorningThoughtState({
    required String thought,
    required String thoughtIcon,
    required String focusIcon,
  }) {
    if (!mounted) return;
    setState(() {
      _morningThought = thought;
      _morningThoughtIcon = thoughtIcon;
      _focusIcon = focusIcon;
    });
  }

  // Coach Sport : une analyse unique, lisible depuis l’Accueil, puis un
  // éventuel ajustement du prochain jour Sport sans créer un second programme.
  String sportCoachLastAnalysis = '';
  DateTime? sportCoachLastAnalysisAt;
  String sportCoachSuggestion = '';
  int sportCoachSuggestionDelta = 0;
  List<SportCoachLog> sportCoachLogs = [];
  Map<int, int> sportCoachDailyAdjustments = {};
  // Ajustements proposés par le coach Sport avant validation par l'utilisateur :
  // + sur le(s) jour(s) dépassé(s), - sur un ou plusieurs autres jours.
  Map<int, int> _pendingSportCoachSuggestionDeltas = {};
  // Jours où l'utilisateur a explicitement accepté de dépasser le budget
  // Sport. Le coach peut alors proposer une compensation sur d'autres jours.
  Set<int> _manualSportBudgetOverrideDays = {};


  @override
  void initState() {
    super.initState();
    _initializeAppLifecycle();
  }





  @override
  void dispose() {
    _disposeAppLifecycle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildAppShell(context);








String _formatCoachDateTime(DateTime value) {
  final d = value.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm · $hh:$min';
}




}



