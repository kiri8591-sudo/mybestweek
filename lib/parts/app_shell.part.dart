// V9.11 — Shell principal de l'application.
// Extraction architecturale uniquement : comportement conservé.

part of '../main.dart';

extension _AppShellPart on _MaBelleSemaineAppState {

  Widget _buildAppShell(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyBestWeek',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        platform: TargetPlatform.iOS,
        fontFamily: GoogleFonts.nunitoSans().fontFamily,
        textTheme: _farmhouseTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A9384),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF60786B),
          onPrimary: Colors.white,
          secondary: const Color(0xFFA9C8B2),
          onSecondary: Colors.white,
          tertiary: const Color(0xFFD98F72),
          onTertiary: Colors.white,
          surface: const Color(0xFFFFFCF5),
          onSurface: const Color(0xFF3B4842),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8EF),
        iconTheme: const IconThemeData(size: 18, color: Color(0xFF66736D)),
        pageTransitionsTheme: PageTransitionsTheme(
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
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF33414A),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          toolbarHeight: 52,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF33414A),
            fontFamily: GoogleFonts.lora().fontFamily,
            fontFamilyFallback: ['Times New Roman', 'serif'],
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFEFB),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shadowColor: const Color(0x14000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: Color(0xFFE8DED2)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFCF7),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: TextStyle(
            fontFamily: GoogleFonts.lora().fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF33414A),
          ),
          contentTextStyle: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: Color(0xFF4D5954),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFFFBF5),
          modalBackgroundColor: Color(0xFFFFFBF5),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
        ),
        listTileTheme: const ListTileThemeData(
          minVerticalPadding: 7,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(44, 44)),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: Color(0xFFDCCFC1)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          isDense: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCD5CC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCD5CC)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF789082), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD98F72), width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD98F72), width: 1.5),
          ),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF68736F)),
          floatingLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF60786B)),
          hintStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF9A9D99)),
          helperStyle: const TextStyle(fontSize: 10.5, height: 1.2, color: Color(0xFF848A87)),
          errorStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFC47B68)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFBF5),
          indicatorColor: const Color(0xFFDCEBDD),
          height: 70,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelTextStyle: WidgetStatePropertyAll(GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF52616A))),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: Color(0xFFE0D8CF)),
          backgroundColor: const Color(0xFFFAF8F3),
          selectedColor: const Color(0xFFDCE5E7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
        checkboxTheme: CheckboxThemeData(
          materialTapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: const BorderSide(color: Color(0xFFB8B9B4), width: 1.3),
        ),
      ),
      home: Scaffold(
        key: ValueKey('root-$_resetGeneration'),
        body: SafeArea(
          bottom: false,
          child: KeyedSubtree(
            key: ValueKey('content-$_resetGeneration'),
            child: IndexedStack(index: tab, children: [buildHome(), buildWeek(), buildActivities()]),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 5, 12, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3DED5)),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
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
