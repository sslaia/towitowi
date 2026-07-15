import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' show Font;
import 'package:workmanager/workmanager.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'services/ai_content_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void _prefetchPdfFonts() {
  // Prefetch Hanken Grotesk and EB Garamond fonts in the background.
  // This downloads and caches them so they are ready for PDF printing.
  Future.wait([
    PdfGoogleFonts.hankenGroteskRegular(),
    PdfGoogleFonts.hankenGroteskBold(),
    PdfGoogleFonts.hankenGroteskItalic(),
    PdfGoogleFonts.hankenGroteskBoldItalic(),
    PdfGoogleFonts.eBGaramondRegular(),
    PdfGoogleFonts.eBGaramondBold(),
    PdfGoogleFonts.eBGaramondItalic(),
    PdfGoogleFonts.eBGaramondBoldItalic(),
  ]).catchError((e) {
    // Ignore prefetch failures (e.g. offline). PDF rendering will retry or fallback.
    return <Font>[];
  });
}

const String dailySyncTaskName = 'towitowi_daily_sync_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('Workmanager executing background task: $taskName');
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final notesProvider = NotesProvider();
      final settingsProvider = SettingsProvider();

      // Await providers async database/preferences initialization
      while (notesProvider.isLoading || !settingsProvider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final signedIn = await SyncService.isSignedIn();
      if (signedIn) {
        await SyncService.syncNotes(
          notesProvider,
          (local, remote) async {
            debugPrint('Sync conflict in background execution. Aborting.');
            return null;
          },
          settingsProvider: settingsProvider,
        );
        debugPrint('Background sync completed successfully.');
      } else {
        debugPrint('Background sync skipped: user not signed in.');
      }
      return true;
    } catch (e) {
      debugPrint('Background sync failed with error: $e');
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Trigger background prefetching
  _prefetchPdfFonts();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
      await Workmanager().registerPeriodicTask(
        "1",
        dailySyncTaskName,
        frequency: const Duration(hours: 24),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } catch (e) {
      debugPrint('Failed to initialize Workmanager: $e');
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('id')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          Provider(create: (_) => AiContentService()),
        ],
        child: const MainApp(),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          title: 'TowiTowi',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          home: !settings.isInitialized
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryContainer,
                    ),
                  ),
                )
              : (settings.isOnboardingCompleted
                  ? const HomeScreen()
                  : const OnboardingScreen()),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
