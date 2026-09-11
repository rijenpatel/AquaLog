import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/dashboard_context_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/calculations/calculations.dart';
import '../../core/widgets/aqua_status_chip.dart';
import '../../core/widgets/aqua_metric_card.dart';
import '../../app/theme/color_schemes.dart';
import 'batch_dashboard_view.dart';
import '../manage/site_creation_page.dart';
import '../manage/pond_creation_page.dart';
import '../manage/widgets/first_pond_user_guide.dart';
import '../manage/widgets/first_pond_tutorial_page.dart';
import '../comparison/batch_comparison_page.dart';
import '../action_center/action_center_page.dart';
import '../inventory/procurement_assistant_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  final VoidCallback? onLogFeedTap;
  final VoidCallback? onManageTap;
  final VoidCallback? onInventoryTap;

  const DashboardPage({
    super.key,
    this.onLogFeedTap,
    this.onManageTap,
    this.onInventoryTap,
  });

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isFarmSelectorExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    final dashboardContext = ref.watch(dashboardContextProvider);
    final selectedBatchId = dashboardContext is BatchDashboardContext ? dashboardContext.batchId : null;

    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final sitesAsync = ref.watch(allSitesStreamProvider);
    final allBatchesAsync = ref.watch(allBatchesMasterStreamProvider);
    final pondsAsync = ref.watch(allPondsMasterStreamProvider);
    final feedRecordsAsync = ref.watch(feedRecordsStreamProvider);
    final samplingsAsync = ref.watch(samplingEntriesStreamProvider);
    final hapaChecksAsync = ref.watch(allHapaChecksStreamProvider);
    final pendingTasksAsync = ref.watch(pendingFarmTasksStreamProvider);

    final userProfile = userProfileAsync.valueOrNull;
    final allBatches = allBatchesAsync.valueOrNull ?? [];
    final ponds = pondsAsync.valueOrNull ?? [];
    final pondMap = {for (final p in ponds) p.id: p};
    final sites = sitesAsync.valueOrNull ?? [];
    final siteMap = {for (final s in sites) s.id: s};
    final activeBatches = allBatches.where((b) => b.status == 'active').toList();
    final hapaChecks = hapaChecksAsync.valueOrNull ?? [];
    final pendingTasks = pendingTasksAsync.valueOrNull ?? [];

    // Validate batch existence if batch is selected
    if (selectedBatchId != null && allBatchesAsync.hasValue) {
      if (allBatches.isNotEmpty && !allBatches.any((b) => b.id == selectedBatchId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(dashboardContextProvider.notifier).selectFarm();
        });
      }
    }

    // ── BATCH DASHBOARD VIEW ─────────────────────────────────
    if (selectedBatchId != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildContextSwitcherBar(
              theme,
              allBatches,
              pondMap,
              siteMap,
              selectedBatchId,
            ),
          ),
          Expanded(
            child: BatchDashboardView(
              batchId: selectedBatchId,
              onLogFeedTap: widget.onLogFeedTap,
            ),
          ),
        ],
      );
    }

    // ── ALL FARM OVERVIEW ────────────────────────────────────
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_isFarmSelectorExpanded) {
          setState(() => _isFarmSelectorExpanded = false);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dual-Context Switcher Bar (Substantial Expandable Panel)
            _buildContextSwitcherBar(
              theme,
              allBatches,
              pondMap,
              siteMap,
              selectedBatchId,
            ),
            const SizedBox(height: 16),

          // 2. Bilingual Greeting & Hero Feed Card
          feedRecordsAsync.when(
            data: (records) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final todayRecords = records.where((r) {
                final d = DateTime(r.date.year, r.date.month, r.date.day);
                return d == today;
              }).toList();

              final todayTotalKg = todayRecords.fold<double>(0.0, (sum, r) => sum + FeedCalculator.getRecordTotalKg(r));
              final todayTotalGrams = todayTotalKg * 1000.0;
              final sessionsCount = todayRecords.length;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userProfile != null && userProfile.name.isNotEmpty
                                    ? 'Welcome, ${userProfile.name}'
                                    : settings.tr('greeting'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.tr('greeting_sub'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          todayTotalKg >= 1.0
                              ? todayTotalKg.toStringAsFixed(1)
                              : todayTotalGrams.toStringAsFixed(0),
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          todayTotalKg >= 1.0 ? 'kg' : 'grams',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AquaColors.statusOptimal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$sessionsCount feeds logged today',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.tr('todays_feed'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // 3. Dashboard KPI Grid (Pond Occupancy & Action Center)
          _buildDashboardKpiGrid(
            theme,
            settings,
            activeBatches: activeBatches,
            ponds: ponds,
            pendingTasks: pendingTasks,
          ),
          const SizedBox(height: 16),

          // 3. Sampling Overdue Alert Banner
          samplingsAsync.when(
            data: (samplings) {
              final now = DateTime.now();
              Batch? overdueBatch;
              int daysElapsed = 0;
              bool isFirstSample = false;

              for (final b in activeBatches) {
                final batchSamples = samplings.where((s) => s.batchId == b.id).toList();
                final latest = batchSamples.isNotEmpty ? batchSamples.first : null;
                final status = SamplingCalculator.getSamplingStatus(
                  batchStatus: b.status,
                  stockingDate: b.stockingDate,
                  latestSamplingDate: latest?.date,
                  today: now,
                );

                if (status.isDue) {
                  overdueBatch = b;
                  if (latest == null) {
                    isFirstSample = true;
                    daysElapsed = DocCalculator.calculate(stockingDate: b.stockingDate, targetDate: now).doc;
                  } else {
                    daysElapsed = SamplingCalculator.calendarDaysBetween(latest.date, now);
                  }
                  break;
                }
              }

              if (overdueBatch == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onError, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sampling Due: Batch #${overdueBatch.batchNumber}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFirstSample
                                    ? 'Reached DOC $daysElapsed (sampling program starts at DOC 50). Record baseline cast net sampling.'
                                    : 'Last sampled $daysElapsed days ago. 10-day sampling interval reached. Recalibrate ABW & ADG.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () {
                            ref.read(dashboardContextProvider.notifier).selectBatch(overdueBatch!.id);
                          },
                          child: Text(settings.tr('sample_now')),
                        ),
                      ],
                    ),
                  );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 4. Active Batches Stack (Excludes Completed Batches)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                settings.tr('active_batches'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BatchComparisonPage()),
                      );
                    },
                    icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                    label: const Text('Compare Batches', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.onManageTap,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: Text(settings.tr('view_all')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ponds.isEmpty) ...[
            FirstPondUserGuideCard(
              onStartTutorial: () {
                final sites = sitesAsync.valueOrNull ?? [];
                if (sites.isEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                  );
                } else {
                  FirstPondTutorialPage.show(context, site: sites.first);
                }
              },
              onApplyPreset: (preset) {
                final sites = sitesAsync.valueOrNull ?? [];
                if (sites.isEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PondCreationPage(site: sites.first)),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF006876),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final sites = sitesAsync.valueOrNull ?? [];
                if (sites.isEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                  );
                } else {
                  FirstPondTutorialPage.show(context, site: sites.first);
                }
              },
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: Text((sitesAsync.valueOrNull ?? []).isEmpty
                  ? 'Step 1: Setup Farm Site Location'
                  : 'Start Step-by-Step Pond Tutorial (${(sitesAsync.valueOrNull ?? []).first.name})'),
            ),
          ] else if (activeBatches.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.water_rounded, size: 36, color: Color(0xFF006876)),
                      const SizedBox(height: 8),
                      const Text(
                        'Ponds configured! No active batches currently stocked.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock a pond basin with shrimp post-larvae to start automated feeding and DOC monitoring.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: widget.onManageTap,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                        label: const Text('Stock a Pond Now'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: activeBatches.map((b) {
                final pond = pondMap[b.pondId];
                final site = siteMap[pond?.siteId];
                return _buildActiveBatchCard(
                  context: context,
                  theme: theme,
                  settings: settings,
                  batch: b,
                  pond: pond,
                  site: site,
                  samplings: samplingsAsync.valueOrNull ?? [],
                  hapaChecks: hapaChecks,
                  pendingTasks: pendingTasks,
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // 5. Smart Decision Support Widgets: Weather, Health Score, Tasks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Operational Intelligence & Tasks',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActionCenterPage()),
                  );
                },
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Action Center', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWeatherSection(theme, settings, sitesAsync),
          const SizedBox(height: 12),
          _buildHealthScoreCard(
            theme,
            settings,
            activeBatches,
            feedRecordsAsync.valueOrNull ?? [],
            samplingsAsync.valueOrNull ?? [],
          ),
          const SizedBox(height: 14),
          ProcurementAssistantCard(
            onAddPurchaseTap: widget.onInventoryTap,
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}


  Widget _buildWeatherSection(
    ThemeData theme,
    AppSettingsState settings,
    AsyncValue<List<FarmSite>> sitesAsync,
  ) {
    return sitesAsync.when(
      data: (sites) {
        if (sites.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Weather Telemetry',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'No site location configured.\nCreate a site and add a location to enable weather.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SiteCreationPage()),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                  label: const Text('Create Site'),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sites.map((site) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSingleSiteWeatherCard(theme, settings, site),
          )).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSingleSiteWeatherCard(
    ThemeData theme,
    AppSettingsState settings,
    FarmSite site,
  ) {
    if (site.latitude == null || site.longitude == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_off_outlined, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${site.name} Weather · Location Missing',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Site coordinates are not configured. Edit site details in Manage to link Open-Meteo forecasts.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final weatherAsync = ref.watch(siteWeatherStreamProvider(site.id));
    return weatherAsync.when(
      data: (obs) {
        if (obs == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${site.name} Weather · Unavailable',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Connect device to internet to synchronize live weather observations.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final rec = WeatherFeedEngine.evaluate(
          temperature: obs.temperature,
          humidity: obs.humidity ?? 70.0,
          rainProbability: obs.rainProbability ?? 0.0,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${site.name} (${obs.temperature.toStringAsFixed(1)}°C)',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AquaStatusChip(label: rec.title, level: AquaStatusLevel.optimal),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${obs.condition} · Feels ${obs.feelsLike?.toStringAsFixed(0) ?? obs.temperature.toStringAsFixed(0)}°C · Humidity ${obs.humidity?.toInt() ?? 70}% · Rain Risk ${obs.rainProbability?.toInt() ?? 0}%',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                rec.message,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHealthScoreCard(
    ThemeData theme,
    AppSettingsState settings,
    List<Batch> batches,
    List<FeedRecord> feedRecords,
    List<SamplingEntry> samplings,
  ) {
    if (batches.isEmpty || (feedRecords.isEmpty && samplings.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '—',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pond Health Index — Not available',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    batches.isEmpty
                        ? 'Requires an active cultivated batch to evaluate pond health.'
                        : 'Requires feed logging or sampling records to calculate the 4-pillar health score.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final last7DaysFeeds = feedRecords.where((r) => now.difference(r.date).inDays <= 7).length;
    final loggedToday = feedRecords.any((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return d == today;
    });
    final loggedYesterday = feedRecords.any((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return d == yesterday;
    });
    final loggedTwoDaysAgo = feedRecords.any((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return d == twoDaysAgo;
    });

    double? latestAdg;
    if (samplings.isNotEmpty) {
      final lastSampling = samplings.first; // sorted desc
      latestAdg = lastSampling.adgGramsPerDay;
      if (latestAdg == null && samplings.length >= 2) {
        final prev = samplings[1];
        final days = lastSampling.date.difference(prev.date).inDays;
        if (days > 0) {
          latestAdg = (lastSampling.abwGrams - prev.abwGrams) / days;
        }
      }
    }

    final activeBatch = batches.first;
    final hapaSurvival = activeBatch.actualSurvivalPct;

    final health = HealthScoreCalculator.calculate(
      sessionsLoggedLast7Days: last7DaysFeeds,
      loggedToday: loggedToday,
      loggedYesterday: loggedYesterday,
      loggedTwoDaysAgo: loggedTwoDaysAgo,
      latestAdg: latestAdg,
      hapaSurvivalPct: hapaSurvival,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AquaColors.statusOptimal.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${health.totalScore}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AquaColors.statusOptimal,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pond Health Index: ${health.grade}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  health.status,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: health.totalScore / 100.0,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AquaColors.statusOptimal),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardKpiGrid(
    ThemeData theme,
    AppSettingsState settings, {
    required List<Batch> activeBatches,
    required List<Pond> ponds,
    required List<FarmActionTask> pendingTasks,
  }) {
    final totalPonds = ponds.length;
    final occupiedPonds = ponds.where((p) => p.status == 'active' || activeBatches.any((b) => b.pondId == p.id)).length;
    final occupancyPct = totalPonds > 0 ? ((occupiedPonds / totalPonds) * 100).round() : 0;
    final pendingCount = pendingTasks.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AquaMetricCard(
            title: settings.tr('pond_occupancy'),
            value: '$occupiedPonds / $totalPonds',
            unit: 'Ponds',
            subtitle: totalPonds > 0 ? '$occupancyPct% Active Capacity' : 'No ponds configured',
            leadingIcon: const Icon(Icons.water_rounded),
            accentColor: const Color(0xFF006876),
            onTap: widget.onManageTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AquaMetricCard(
            title: settings.tr('action_center'),
            value: '$pendingCount',
            unit: pendingCount == 1 ? 'Task' : 'Tasks',
            subtitle: pendingCount == 0 ? 'All tasks complete' : '$pendingCount need attention',
            leadingIcon: const Icon(Icons.bolt_rounded),
            accentColor: pendingCount > 0 ? AquaColors.statusWarning : AquaColors.statusOptimal,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActionCenterPage()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBatchCard({
    required BuildContext context,
    required ThemeData theme,
    required AppSettingsState settings,
    required Batch batch,
    required Pond? pond,
    required FarmSite? site,
    required List<SamplingEntry> samplings,
    required List<HapaCheck> hapaChecks,
    required List<FarmActionTask> pendingTasks,
  }) {
    final now = DateTime.now();
    final isDark = theme.brightness == Brightness.dark;
    final doc = DocCalculator.calculate(stockingDate: batch.stockingDate, targetDate: now).doc;

    // Latest sample for this batch
    final batchSamples = samplings.where((s) => s.batchId == batch.id).toList();
    batchSamples.sort((a, b) => b.date.compareTo(a.date));
    final latestSample = batchSamples.firstOrNull;

    // Sampling schedule via 10-day cycle calculation
    final samplingSchedule = SamplingCalculator.calculateSchedule(
      batchStatus: batch.status,
      stockingDate: batch.stockingDate,
      latestSamplingDate: latestSample?.date,
      today: now,
    );

    // Happa check verification
    final hasHapaCheck = batch.actualSurvivalPct != null || hapaChecks.any((c) => c.batchId == batch.id);
    final hapaCheckRecord = hapaChecks.where((c) => c.batchId == batch.id).firstOrNull;
    final effectiveSurvivalPct = batch.actualSurvivalPct ?? hapaCheckRecord?.survivalPercentage ?? 85.0;

    // Biomass calculation
    final abwGrams = latestSample?.abwGrams ?? (doc * 0.28).clamp(1.0, 35.0);
    final calculatedBiomass = SamplingCalculator.calculateBiomass(
      stockedShrimp: batch.shrimpStockedCount,
      hapaSurvivalPct: effectiveSurvivalPct,
      abwGrams: abwGrams,
    );

    final String biomassText;
    final String biomassUnit;
    if (calculatedBiomass != null) {
      if (calculatedBiomass >= 1000.0) {
        biomassText = (calculatedBiomass / 1000.0).toStringAsFixed(2);
        biomassUnit = 'tons';
      } else {
        biomassText = calculatedBiomass.toStringAsFixed(0);
        biomassUnit = 'kg';
      }
    } else {
      biomassText = '—';
      biomassUnit = '';
    }

    // Species concise display
    String speciesDisplay = batch.species;
    if (speciesDisplay.contains('vannamei')) {
      speciesDisplay = 'L. vannamei';
    } else if (speciesDisplay.contains('monodon')) {
      speciesDisplay = 'P. monodon';
    }

    // Operational warnings
    final warnings = <String>[];
    if (samplingSchedule.state == SamplingScheduleState.overdue) {
      warnings.add('Sampling overdue (${samplingSchedule.detailLabel ?? "Action required"}). Sample to calibrate feed.');
    } else if (samplingSchedule.state == SamplingScheduleState.due) {
      warnings.add('Sampling due today. Conduct cast-net check.');
    }
    if (!hasHapaCheck && doc >= 10) {
      warnings.add('DOC $doc: Happa survival check pending. Update check to calibrate population.');
    }
    final batchTasks = pendingTasks.where((t) => (t.batchId != null && t.batchId == batch.id) || (pond != null && t.pondId != null && t.pondId == pond.id)).take(1);
    for (final t in batchTasks) {
      warnings.add('${t.title}${t.description != null ? ": ${t.description}" : ""}');
    }


    final hasCriticalWarning = samplingSchedule.state == SamplingScheduleState.overdue || (!hasHapaCheck && doc >= 14);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasCriticalWarning
              ? theme.colorScheme.error.withOpacity(0.4)
              : (isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000)),
          width: hasCriticalWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            ref.read(dashboardContextProvider.notifier).selectBatch(batch.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PRIMARY IDENTIFICATION: Site Name, Pond Name, Batch Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.water_drop_rounded,
                        size: 20,
                        color: isDark ? AquaColors.primaryDark : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site?.name.toUpperCase() ?? 'FARM SITE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pond?.name ?? 'Pond',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Batch #${batch.batchNumber}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.colorScheme.outline.withOpacity(0.7),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0E000000),
                ),
                const SizedBox(height: 14),

                // 2. OPERATIONAL METRICS: DOC, Shrimp Species, Current Biomass
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'DOC',
                        value: '$doc',
                        unit: 'days',
                        icon: Icons.calendar_today_rounded,
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'SPECIES',
                        value: speciesDisplay,
                        unit: null,
                        icon: Icons.bubble_chart_rounded,
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'BIOMASS',
                        value: biomassText,
                        unit: biomassUnit,
                        icon: Icons.scale_rounded,
                        theme: theme,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. OPERATIONAL STATUS: Happa Status & Sampling Status
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildHappaStatusBadge(
                      hasHapaCheck,
                      effectiveSurvivalPct,
                      doc,
                      theme,
                    ),
                    _buildSamplingStatusBadge(
                      samplingSchedule,
                      theme,
                    ),
                  ],
                ),

                // 4. OPERATIONAL WARNINGS (Surfaced only when data supports it)
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...warnings.map((w) => Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String? unit,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null && unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHappaStatusBadge(
    bool hasHapaCheck,
    double? survivalPct,
    int doc,
    ThemeData theme,
  ) {
    if (hasHapaCheck) {
      final pctText = survivalPct != null ? ' · ${survivalPct.toStringAsFixed(0)}%' : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AquaColors.statusOptimal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AquaColors.statusOptimal.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: AquaColors.statusOptimal),
            const SizedBox(width: 5),
            Text(
              '✓ Happa Updated$pctText',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AquaColors.statusOptimal,
              ),
            ),
          ],
        ),
      );
    }

    final isPendingWarning = doc >= 10;
    final color = isPendingWarning ? AquaColors.statusWarning : theme.colorScheme.onSurfaceVariant;
    final bgColor = isPendingWarning ? AquaColors.statusWarning.withOpacity(0.12) : theme.colorScheme.surfaceContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPendingWarning ? Icons.warning_amber_rounded : Icons.schedule_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            isPendingWarning ? 'Happa Check Pending' : 'Happa (Due DOC 10)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSamplingStatusBadge(SamplingSchedule schedule, ThemeData theme) {
    final Color badgeColor;
    final Color badgeBg;
    final IconData badgeIcon;
    final String label;

    switch (schedule.state) {
      case SamplingScheduleState.upToDate:
        badgeColor = AquaColors.statusOptimal;
        badgeBg = AquaColors.statusOptimal.withOpacity(0.12);
        badgeIcon = Icons.check_circle_rounded;
        label = schedule.detailLabel != null && schedule.detailLabel!.isNotEmpty
            ? '✓ Sampling Up to Date · ${schedule.detailLabel}'
            : '✓ Sampling Up to Date';
        break;
      case SamplingScheduleState.approaching:
        badgeColor = const Color(0xFF006876);
        badgeBg = const Color(0xFF006876).withOpacity(0.12);
        badgeIcon = Icons.upcoming_rounded;
        label = schedule.detailLabel != null && schedule.detailLabel!.isNotEmpty
            ? 'Next sampling coming · ${schedule.detailLabel}'
            : 'Next sampling coming';
        break;
      case SamplingScheduleState.due:
        badgeColor = AquaColors.statusWarning;
        badgeBg = AquaColors.statusWarning.withOpacity(0.15);
        badgeIcon = Icons.notifications_active_rounded;
        label = 'Sampling Due Today';
        break;
      case SamplingScheduleState.overdue:
        badgeColor = theme.colorScheme.error;
        badgeBg = theme.colorScheme.errorContainer.withOpacity(0.6);
        badgeIcon = Icons.warning_rounded;
        label = schedule.detailLabel != null && schedule.detailLabel!.isNotEmpty
            ? 'Sampling Overdue · ${schedule.detailLabel}'
            : 'Sampling Overdue';
        break;
      case SamplingScheduleState.notActive:
        badgeColor = theme.colorScheme.onSurfaceVariant;
        badgeBg = theme.colorScheme.surfaceContainer;
        badgeIcon = Icons.remove_circle_outline_rounded;
        label = 'Sampling Inactive';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextSwitcherBar(
    ThemeData theme,
    List<Batch> allBatches,
    Map<String, Pond> pondMap,
    Map<String, FarmSite> siteMap,
    String? selectedBatchId,
  ) {
    Batch? currentBatch;
    if (selectedBatchId != null) {
      currentBatch = allBatches.where((b) => b.id == selectedBatchId).firstOrNull;
    }
    final activeBatches = allBatches.where((b) => b.status == 'active').toList();
    final completedBatches = allBatches.where((b) => b.status == 'completed').toList();

    String currentTitle = 'All Farm Overview';
    String currentSubtitle = 'All Active Sites & Ponds';
    if (currentBatch != null) {
      final p = pondMap[currentBatch.pondId];
      final s = siteMap[p?.siteId];
      final isComp = currentBatch.status == 'completed';
      currentTitle = '${p?.name ?? "Pond"} · Batch #${currentBatch.batchNumber}${isComp ? " (Completed)" : ""}';
      currentSubtitle = '${s?.name ?? "Farm Site"} · ${currentBatch.species}';
    }

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isFarmSelectorExpanded = !_isFarmSelectorExpanded;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isFarmSelectorExpanded
                      ? theme.colorScheme.primary.withOpacity(0.5)
                      : (isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000)),
                  width: _isFarmSelectorExpanded ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      selectedBatchId == null ? Icons.grid_view_rounded : Icons.layers_rounded,
                      size: 20,
                      color: isDark ? AquaColors.primaryDark : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0x22FFFFFF) : const Color(0x12000000),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedBatchId == null ? 'All Farm' : 'Pond View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _isFarmSelectorExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // SUBSTANTIAL EXPANDED SELECTION PANEL
        if (_isFarmSelectorExpanded) ...[
          const SizedBox(height: 8),
          _buildExpandedSelectorPanel(
            theme: theme,
            allBatches: allBatches,
            activeBatches: activeBatches,
            completedBatches: completedBatches,
            pondMap: pondMap,
            siteMap: siteMap,
            selectedBatchId: selectedBatchId,
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedSelectorPanel({
    required ThemeData theme,
    required List<Batch> allBatches,
    required List<Batch> activeBatches,
    required List<Batch> completedBatches,
    required Map<String, Pond> pondMap,
    required Map<String, FarmSite> siteMap,
    required String? selectedBatchId,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x2AFFFFFF) : const Color(0x1F000000),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT FARM VIEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isFarmSelectorExpanded = false),
                  borderRadius: BorderRadius.circular(100),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),

          // Option: All Farm Overview
          _buildSelectorOption(
            theme: theme,
            isSelected: selectedBatchId == null,
            icon: Icons.public_rounded,
            title: 'All Farm Overview',
            subtitle: 'Combined metrics across all active ponds & batches',
            onTap: () {
              ref.read(dashboardContextProvider.notifier).selectFarm();
              setState(() => _isFarmSelectorExpanded = false);
            },
          ),

          // Active Batches Section
          if (activeBatches.isNotEmpty) ...[
            const Divider(height: 1, thickness: 0.6),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                'ACTIVE BATCHES (${activeBatches.length})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            ...activeBatches.map((b) {
              final p = pondMap[b.pondId];
              final s = siteMap[p?.siteId];
              final doc = DocCalculator.calculate(stockingDate: b.stockingDate).doc;
              return _buildSelectorOption(
                theme: theme,
                isSelected: selectedBatchId == b.id,
                icon: Icons.water_drop_rounded,
                title: '${p?.name ?? "Pond"} · Batch #${b.batchNumber}',
                subtitle: '${s?.name ?? "Farm"} · DOC $doc · ${b.species}',
                onTap: () {
                  ref.read(dashboardContextProvider.notifier).selectBatch(b.id);
                  setState(() => _isFarmSelectorExpanded = false);
                },
              );
            }),
          ],

          // Completed Batches Section
          if (completedBatches.isNotEmpty) ...[
            const Divider(height: 1, thickness: 0.6),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                'COMPLETED BATCHES (${completedBatches.length})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            ...completedBatches.map((b) {
              final p = pondMap[b.pondId];
              final s = siteMap[p?.siteId];
              return _buildSelectorOption(
                theme: theme,
                isSelected: selectedBatchId == b.id,
                icon: Icons.check_circle_outline_rounded,
                title: '${p?.name ?? "Pond"} · Batch #${b.batchNumber}',
                subtitle: '${s?.name ?? "Farm"} · Completed',
                onTap: () {
                  ref.read(dashboardContextProvider.notifier).selectBatch(b.id);
                  setState(() => _isFarmSelectorExpanded = false);
                },
              );
            }),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildSelectorOption({
    required ThemeData theme,
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.18)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

}
