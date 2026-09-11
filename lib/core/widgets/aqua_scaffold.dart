import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';

class AquaScaffold extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSettingsTap;

  const AquaScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.title,
    this.actions,
    this.onSearchTap,
    this.onSettingsTap,
  });

  @override
  ConsumerState<AquaScaffold> createState() => _AquaScaffoldState();
}

class _AquaScaffoldState extends ConsumerState<AquaScaffold> {
  late Timer _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatted = DateFormat('hh:mm a').format(now);
    if (formatted != _currentTime && mounted) {
      setState(() => _currentTime = formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    final appBar = AppBar(
      titleSpacing: 16,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000),
          height: 1,
        ),
      ),
      title: widget.title != null
          ? Text(
              widget.title!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'AquaLog',
                  child: Image.asset(
                    'assets/images/aqualog_wordmark.png',
                    height: 28,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(
                  width: 0,
                  height: 0,
                  child: Text('AquaLog', style: TextStyle(fontSize: 0.001)),
                ),
              ],
            ),
      actions: [
        // Live Clock
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            _currentTime,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Global Search
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: widget.onSearchTap,
        ),
        if (widget.actions != null) ...widget.actions!,
        // Settings — always accessible from header
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: widget.onSettingsTap,
        ),
        const SizedBox(width: 4),
      ],
    );

    if (isCompact) {
      return Scaffold(
        appBar: appBar,
        body: widget.body,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              widget.onDestinationSelected(index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: settings.tr('overview'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.water_outlined),
                selectedIcon: const Icon(Icons.water_rounded),
                label: settings.tr('manage'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2_rounded),
                label: settings.tr('stock'),
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF006876), Color(0xFF00A2B8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
                label: settings.tr('log_feed'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
                label: settings.tr('finance'),
              ),
            ],
          ),
        ),
      );
    }

    // Medium / Expanded Layout (Tablets & Desktops)
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            leading: FloatingActionButton.small(
              elevation: 0,
              onPressed: () => widget.onDestinationSelected(3),
              backgroundColor: theme.colorScheme.primaryContainer,
              child: const Icon(Icons.add_rounded),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: Text(settings.tr('overview')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.water_outlined),
                selectedIcon: const Icon(Icons.water_rounded),
                label: Text(settings.tr('manage')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2_rounded),
                label: Text(settings.tr('stock')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.fastfood_outlined),
                selectedIcon: const Icon(Icons.fastfood_rounded),
                label: Text(settings.tr('log_feed')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
                label: Text(settings.tr('finance')),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.body),
        ],
      ),
    );
  }
}
