import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';
import 'services/calendar_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  final repo = CalendarRepository();
  await repo.init();
  runApp(
    ChangeNotifierProvider.value(value: repo, child: const GlassCalendarApp()),
  );
}

class GlassCalendarApp extends StatefulWidget {
  const GlassCalendarApp({super.key});

  @override
  State<GlassCalendarApp> createState() => _GlassCalendarAppState();
}

class _GlassCalendarAppState extends State<GlassCalendarApp> {
  String? _lang;
  bool? _eth;

  /// Language / calendar changed: redraw every widget in place. Nothing is
  /// remounted, so open sheets, the current tab and scroll positions all
  /// survive and the layout stays exactly the same, just re-labelled.
  void _rebuildEverything() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    final changed =
        (_lang != null && _lang != repo.language) ||
        (_eth != null && _eth != repo.ethiopian);
    _lang = repo.language;
    _eth = repo.ethiopian;
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildEverything();
      });
    }
    return MaterialApp(
      title: 'Glass Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(repo.language),
      supportedLocales: const [Locale('en'), Locale('am')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: repo.onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
