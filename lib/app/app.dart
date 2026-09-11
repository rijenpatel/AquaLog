import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/database_provider.dart';
import '../core/widgets/aqua_scaffold.dart';
import '../core/widgets/aqua_search_dialog.dart';
import '../features/onboarding/onboarding_page.dart';
import 'theme/app_theme.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/manage/manage_page.dart';
import '../features/inventory/inventory_hub_page.dart';
import '../features/feed/feed_logging_page.dart';
import '../features/finance/finance_page.dart';
import '../features/reports/reports_page.dart';
import '../features/settings/settings_page.dart';

class AquaLogApp extends ConsumerWidget {
  const AquaLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    final lightTheme = settings.outdoorMode
        ? AquaTheme.outdoor(isHindi: settings.isHindi)
        : AquaTheme.light(isHindi: settings.isHindi);

    final darkTheme = settings.outdoorMode
        ? AquaTheme.outdoor(isHindi: settings.isHindi)
        : AquaTheme.dark(isHindi: settings.isHindi);

    final themeMode = settings.outdoorMode ? ThemeMode.light : settings.themeMode;

    final userProfileAsync = ref.watch(userProfileStreamProvider);

    return MaterialApp(
      title: 'AquaLog',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontScale),
          ),
          child: child!,
        );
      },
      home: userProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            return OnboardingPage(
              onOnboardingComplete: () {
                ref.invalidate(userProfileStreamProvider);
              },
            );
          }
          return const AppMainNavigation();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const AppMainNavigation(),
      ),
    );
  }
}

class AppMainNavigation extends StatefulWidget {
  const AppMainNavigation({super.key});

  @override
  State<AppMainNavigation> createState() => _AppMainNavigationState();
}

class _AppMainNavigationState extends State<AppMainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        onLogFeedTap: () => setState(() => _currentIndex = 3),
        onManageTap: () => setState(() => _currentIndex = 1),
        onInventoryTap: () => setState(() => _currentIndex = 2),
      ),
      const ManagePage(),
      const InventoryHubPage(),
      FeedLoggingPage(
        onFeedLogged: () => setState(() => _currentIndex = 0),
      ),
      const FinancePage(),
      const ReportsPage(),
      const SettingsPage(),
    ];

    return AquaScaffold(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() => _currentIndex = index);
      },
      onSearchTap: () => AquaSearchDialog.show(context),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
    );
  }
}
