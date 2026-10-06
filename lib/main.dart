import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glass Calendar',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: context.read<CalendarRepository>().onboarded
        ? const HomeShell()
        : const OnboardingScreen(),
  );
}
