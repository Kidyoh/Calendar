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

class GlassCalendarApp extends StatelessWidget {
  const GlassCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
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
      // Remount the root screen when the language flips so every string
      // re-renders in the new language.
      home: KeyedSubtree(
        key: ValueKey(repo.language),
        child: repo.onboarded ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }
}
