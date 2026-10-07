// V9.30.2 — Shell visuel renforcé.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _AppShellPart on _MaBelleSemaineAppState {

  /// Thème Material unique, piloté par la palette AppColors : clair et sombre
  /// partagent les mêmes formes, tailles et graisses ; seules les couleurs changent.
  ThemeData _buildTheme(AppColors c, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFF789A87) : const Color(0xFF7A9384),
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: dark ? const Color(0xFF98B5A4) : const Color(0xFFB9CCBF),
      onSecondary: dark ? const Color(0xFF13251B) : const Color(0xFF2F3F36),
      tertiary: dark ? const Color(0xFFE2AA91) : const Color(0xFFC98268),
      onTertiary: dark ? const Color(0xFF351A10) : Colors.white,
      surface: c.card,
      onSurface: c.textStrong,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.borderStrong,
    );
    final text = _farmhouseTextTheme().apply(bodyColor: c.textStrong, displayColor: c.textStrong);
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: c.border, width: 1),
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppFonts.sans,
    ).copyWith(
      platform: TargetPlatform.iOS,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: c.scaffold,
      canvasColor: c.scaffold,
      iconTheme: IconThemeData(size: 18, color: c.textMuted),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.appBar,
        foregroundColor: c.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 62,
        titleTextStyle: TextStyle(
          fontSize: AppType.titleL,
          fontWeight: FontWeight.w700,
          color: c.textStrong,
          fontFamily: AppFonts.serif,
          fontFamilyFallback: const ['Times New Roman', 'serif'],
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shadowColor: c.shadow,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: AppType.titleL,
          fontWeight: FontWeight.w700,
          color: c.textStrong,
        ),
        contentTextStyle: TextStyle(fontSize: AppType.bodyL, height: 1.35, color: c.textMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        modalBackgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        showDragHandle: true,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 9,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.l))),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(44, 44)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          textStyle: const TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          side: BorderSide(color: c.borderStrong),
          textStyle: const TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          textStyle: const TextStyle(fontSize: AppType.bodyL, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: false,
        border: inputBorder(c.borderStrong),
        enabledBorder: inputBorder(c.borderStrong),
        disabledBorder: inputBorder(c.border),
        focusedBorder: inputBorder(c.accentOutline, 1.5),
        errorBorder: inputBorder(c.danger, 1.2),
        focusedErrorBorder: inputBorder(c.danger, 1.5),
        labelStyle: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: c.textMuted),
        floatingLabelStyle: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: c.accentStrongText),
        hintStyle: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w500, color: c.textFaint),
        helperStyle: TextStyle(fontSize: AppType.caption, height: 1.2, color: c.textWarm),
        errorStyle: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: c.danger),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        indicatorColor: c.navIndicator,
        height: 82,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => AppFonts.nunito(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected) ? c.accentStrongText : c.textMuted,
            )),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        side: BorderSide(color: c.border),
        backgroundColor: c.chipBg,
        selectedColor: c.tintStrong,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        labelStyle: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700, color: c.textStrong),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accentFill, linearTrackColor: c.border),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? c.chipBg : c.textStrong,
        contentTextStyle: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w600, color: dark ? c.textStrong : c.card),
        actionTextColor: dark ? c.accentStrongText : c.accentSoftBorder,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w700)),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
          backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? c.tintStrong : c.card),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? c.accentStrongText : c.textMuted),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
        side: BorderSide(color: c.borderStrong, width: 1.3),
      ),
    );
  }

  void _toggleDarkMode() {
    setState(() => _darkMode = !_darkMode);
    _queueLocalStatePersist();
  }

  Widget _buildAppShell(BuildContext context) {
    _colors = _darkMode ? AppColors.night : AppColors.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyBestWeek',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: _buildTheme(AppColors.light, Brightness.light),
      darkTheme: _buildTheme(AppColors.night, Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        key: ValueKey('root-$_resetGeneration'),
        body: SafeArea(
          bottom: false,
          child: KeyedSubtree(
            key: ValueKey('content-$_resetGeneration'),
            child: IndexedStack(index: tab, children: [buildHome(), buildWeek(), buildPriorities(), buildObjectives(), buildActivities()]),
          ),
        ),
        floatingActionButton: _canUndoLastAction
            ? FloatingActionButton.small(
                heroTag: 'undo-last-action',
                tooltip: 'Annuler la dernière action',
                onPressed: _undoLastAction,
                child: _systemIconWidget('undo', fallback: '↩️', size: 20),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 5, 10, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _colors.card,
              borderRadius: BorderRadius.circular(AppRadius.xxl + 2),
              border: Border.all(color: _colors.border, width: 1.2),
              boxShadow: [BoxShadow(color: _colors.shadow, blurRadius: 20, offset: const Offset(0, 5))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xxl + 1),
              child: NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (v) { setState(() => tab = v); },
                destinations: [
                  NavigationDestination(
                    icon: _kawaiiNavIcon(_systemIconValue('navHome', '🏡'), const Color(0xFFF5EBDD), const Color(0xFF8B735E)),
                    selectedIcon: _kawaiiNavIcon(_systemIconValue('navHome', '🏡'), const Color(0xFFEFD8C7), const Color(0xFF7B624E), selected: true),
                    label: 'Accueil',
                  ),
                  NavigationDestination(
                    icon: _kawaiiNavIcon(_systemIconValue('navWeek', '🌿'), const Color(0xFFE8F1EA), const Color(0xFF668272)),
                    selectedIcon: _kawaiiNavIcon(_systemIconValue('navWeek', '🌿'), const Color(0xFFD4E8DA), const Color(0xFF4F725C), selected: true),
                    label: 'Semaine',
                  ),
                  NavigationDestination(
                    icon: _kawaiiNavIcon(_systemIconValue('navPriorities', '⭐'), const Color(0xFFFFF0DA), const Color(0xFF8A745D)),
                    selectedIcon: _kawaiiNavIcon(_systemIconValue('navPriorities', '⭐'), const Color(0xFFFFE4B8), const Color(0xFF7D6346), selected: true),
                    label: 'Priorités',
                  ),
                  NavigationDestination(
                    icon: _kawaiiNavIcon(_systemIconValue('navObjectives', '🎯'), const Color(0xFFEAF0FA), const Color(0xFF647694)),
                    selectedIcon: _kawaiiNavIcon(_systemIconValue('navObjectives', '🎯'), const Color(0xFFDCE7F6), const Color(0xFF536884), selected: true),
                    label: 'Objectifs',
                  ),
                  NavigationDestination(
                    icon: _kawaiiNavIcon(_systemIconValue('navActivities', '🧸'), const Color(0xFFF2EAF5), const Color(0xFF806B88)),
                    selectedIcon: _kawaiiNavIcon(_systemIconValue('navActivities', '🧸'), const Color(0xFFE5D8EC), const Color(0xFF6E587A), selected: true),
                    label: 'Activités',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
