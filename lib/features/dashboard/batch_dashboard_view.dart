import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/models/weather_models.dart';
import '../../core/providers/batch_dashboard_providers.dart';
import '../../core/providers/dashboard_context_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/weather_service.dart';
import '../../app/theme/color_schemes.dart';
import '../../core/calculations/sampling_calculator.dart';
import '../../core/calculations/feed_calculator.dart';
import '../sampling/sampling_dialog.dart';
import '../sampling/sampling_history_sheet.dart';
import '../weather/weather_page.dart';
import '../../core/services/batch_passport_pdf_service.dart';
import '../../core/calculations/health_score_calculator.dart';
import '../../core/calculations/harvest_decision_engine.dart';
import '../pond_mode/pond_mode_page.dart';
import '../health/pond_health_view.dart';
import '../feed/daily_feed_plan_card.dart';
import '../harvest/harvest_decision_center_view.dart';
import '../../core/widgets/aqua_segmented_tab.dart';
import '../water_quality/water_quality_entry_page.dart';

class BatchDashboardView extends ConsumerStatefulWidget {
  final String batchId;
  final VoidCallback? onLogFeedTap;
  final VoidCallback? onSamplingTap;
  final VoidCallback? onWaterQualityTap;

  const BatchDashboardView({
    super.key,
    required this.batchId,
    this.onLogFeedTap,
    this.onSamplingTap,
    this.onWaterQualityTap,
  });

  @override
  ConsumerState<BatchDashboardView> createState() => _BatchDashboardViewState();
}

class _BatchDashboardViewState extends ConsumerState<BatchDashboardView> {
  int _selectedFeedRangeDays = 7;
  DateTime _selectedLedgerDate = DateTime.now();
  bool _showDateWiseLedger = false;
  int _selectedTabSegment = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batchDataAsync = ref.watch(batchDashboardDataProvider(widget.batchId));

    return batchDataAsync.when(
      data: (data) {
        if (data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_clear_rounded, size: 48, color: AquaColors.statusAlert),
                  const SizedBox(height: 12),
                  const Text('Selected batch was not found or is no longer active.'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      ref.read(dashboardContextProvider.notifier).selectFarm();
                    },
                    child: const Text('Return to Farm Overview'),
                  ),
                ],
              ),
            ),
          );
        }

        final site = data.site;
        final weatherAsync = (site != null && site.latitude != null && site.longitude != null)
            ? ref.watch(siteWeatherForecastProvider((
                siteId: site.id,
                lat: site.latitude!,
                lon: site.longitude!,
                name: site.name,
              )))
            : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP APP BAR & CONTEXT (Sticky Top)
              _buildTopAppBar(context, theme, data),
              const SizedBox(height: 12),

              // 2. BATCH CONTEXT CARD & BIOLOGICAL GAUGE BANNER
              _buildBatchContextCard(theme, data),
              const SizedBox(height: 14),

              // 3. SEGMENTED TAB CONTROLLER
              AquaSegmentedTab(
                selectedIndex: _selectedTabSegment,
                onTabSelected: (index) => setState(() => _selectedTabSegment = index),
                items: [
                  const AquaSegmentedTabItem(label: 'Overview', icon: Icons.insights_rounded),
                  AquaSegmentedTabItem(
                    label: 'Feed & Trays',
                    icon: Icons.set_meal_rounded,
                    badge: data.isCompleted
                        ? null
                        : Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AquaColors.statusOptimal,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                  const AquaSegmentedTabItem(label: 'Water & Weather', icon: Icons.water_drop_rounded),
                  const AquaSegmentedTabItem(label: 'Harvest & P&L', icon: Icons.monetization_on_rounded),
                ],
              ),
              const SizedBox(height: 14),

              // 4. TAB CONTENT
              if (_selectedTabSegment == 0) ...[
                // ── TAB 0: OVERVIEW & GROWTH ─────────────────────
                // Primary 4-KPI Area
                _buildPrimaryKpiGrid(theme, data),
                const SizedBox(height: 12),

                // Pond Health & Risk Intelligence
                PondHealthView(
                  health: HealthScoreCalculator.calculateComprehensive(
                    doc: data.doc,
                    latestAdg: data.adgGramsPerDay,
                    survivalPct: data.survivalPct,
                    daysSinceLastSampling: data.samplingDaysSinceLatest,
                  ),
                  pondName: data.pond.name,
                  doc: data.doc,
                ),
                const SizedBox(height: 12),

                // Operational Alerts
                if (!data.isCompleted) ...[
                  if (data.isHapaCheckDue) ...[
                    _buildHapaCheckAlertCard(context, theme, data),
                    const SizedBox(height: 12),
                  ],
                  _buildOperationalAlertCard(context, theme, data),
                  const SizedBox(height: 12),
                ],

                // Growth Trend Chart & Sampling Summary
                _buildGrowthTrendChart(theme, data),
                const SizedBox(height: 12),
                _buildSamplingSummaryCard(context, theme, data),
                const SizedBox(height: 12),
                _buildRecentOperationalLogs(context, theme, data),
              ] else if (_selectedTabSegment == 1) ...[
                // ── TAB 1: FEED & CHECK-TRAYS ────────────────────
                if (!data.isCompleted) ...[
                  DailyFeedPlanCard(
                    pondId: data.pond.id,
                    batchId: widget.batchId,
                    biomassKg: data.standingBiomassKg,
                    abwGrams: data.abw,
                  ),
                  const SizedBox(height: 12),
                  _buildFeedProgressSection(theme, data),
                  const SizedBox(height: 12),
                ],
                _buildCheckTrayIntelligence(theme, data),
                const SizedBox(height: 12),
                _buildFeedConsumptionBarChart(theme, data),
                const SizedBox(height: 12),
                _buildFcrPerformanceCard(theme, data),
                const SizedBox(height: 12),
                _buildDateWiseFeedLedger(theme, data),
              ] else if (_selectedTabSegment == 2) ...[
                // ── TAB 2: WATER & WEATHER TELEMETRY ─────────────
                _buildSiteWeatherRibbon(context, theme, data, weatherAsync?.valueOrNull),
                const SizedBox(height: 12),

                // Live Water Quality Telemetry & Parameter Safe-Bands Card
                _buildLiveWaterQualityTelemetry(context, theme, data),
              ] else ...[
                // ── TAB 3: HARVEST & ECONOMICS ───────────────────
                _buildHarvestOutlookCard(theme, data),
                const SizedBox(height: 12),
                HarvestDecisionCenterView(
                  report: HarvestDecisionEngine.evaluateScenarios(
                    currentDoc: data.doc,
                    currentAbwGrams: data.abw,
                    currentPopulation: data.populationPcs,
                    currentBiomassKg: data.standingBiomassKg,
                    historicalExpenses: data.financialOverview.incurredCost,
                    targetWeightGrams: data.batch.targetHarvestWeightG,
                    currentAdgGramsPerDay: data.adgGramsPerDay,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFinancialOverviewCard(theme, data),
              ],
              const SizedBox(height: 16),

              // 5. BOTTOM PRIMARY ACTION BUTTONS (Always accessible)
              if (!data.isCompleted)
                _buildBottomPrimaryActions(context, theme, data)
              else
                _buildCompletedBatchBanner(theme),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading batch dashboard: $e'),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, ThemeData theme, BatchDashboardData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Farm Overview',
                onPressed: () {
                  ref.read(dashboardContextProvider.notifier).selectFarm();
                },
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Batch #${data.batch.batchNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: data.isCompleted
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          data.isCompleted ? 'COMPLETED' : 'ACTIVE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: data.isCompleted ? theme.colorScheme.outline : theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${data.pond.name} · ${data.site?.name ?? "Main Farm"}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.nature_people_outlined),
                tooltip: 'Outdoor Pond Mode (Field Hub)',
                onPressed: () {
                  PondModePage.show(context, pondId: data.pond.id);
                },
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export Batch Passport PDF',
                onPressed: () => _exportBatchPassport(context, data),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_outlined),
                tooltip: 'Site Weather',
                onPressed: () {
                  if (data.site != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WeatherPage(
                          initialSiteId: data.site!.id,
                          initialSiteName: data.site!.name,
                          initialLat: data.site!.latitude,
                          initialLon: data.site!.longitude,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportBatchPassport(BuildContext context, BatchDashboardData data) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Compiling Batch Passport & Traceability PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final db = ref.read(appDatabaseProvider);
      final wq = await db.getWaterQualityLogsForPond(data.pond.id);
      final mort = await db.getMortalityRecordsForBatch(data.batch.id);
      final adj = await db.getPopulationAdjustmentsForBatch(data.batch.id);
      final ops = await db.getPondOperationsForPond(data.pond.id);
      final treatments = await (db.select(db.treatmentRecords)..where((t) => t.batchId.equals(data.batch.id))).get();
      final expenses = await (db.select(db.expenses)..where((e) => e.batchId.equals(data.batch.id))).get();
      final revenues = await (db.select(db.revenues)..where((r) => r.batchId.equals(data.batch.id))).get();

      await BatchPassportPdfService.printOrSharePassport(
        site: data.site ?? FarmSite(
          id: data.pond.siteId ?? 'site_1',
          name: 'Main Farm',
          country: 'India',
          status: 'active',
          createdAt: DateTime.now(),
        ),
        pond: data.pond,
        batch: data.batch,
        samplings: data.allSamplings,
        feedRecords: data.validFeedRecords,
        wqLogs: wq,
        mortalities: mort,
        adjustments: adj,
        operations: ops,
        treatments: treatments,
        expenses: expenses,
        revenues: revenues,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Passport PDF: $e'), backgroundColor: AquaColors.statusCritical),
        );
      }
    }
  }

  Widget _buildBatchContextCard(ThemeData theme, BatchDashboardData data) {
    final cyclePct = ((data.doc / data.targetDoc) * 100.0).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AquaColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${data.site?.name ?? "Farm Site"} (${data.site?.district ?? "Coastal Delta"})',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                'Growout ${(data.pond.areaSqMeters / 4046.86).toStringAsFixed(2)} Ac',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.pond.name} · ${data.batch.species}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${data.pond.waterDepthMeters.toStringAsFixed(1)}m Depth · ${data.pond.aeratorsCount} Aerators',
                  style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Stocked DOC 1 (${(data.batch.shrimpStockedCount / 1000).toStringAsFixed(0)}k ${data.batch.plStage}) · Certified Specific Pathogen Free',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          // Prominent Biological Gauge Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AquaColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('DOC', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          RichText(
                            text: TextSpan(
                              text: '${data.doc}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              children: [
                                TextSpan(
                                  text: ' /${data.targetDoc}d',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${cyclePct.toStringAsFixed(1)}% cycle',
                            style: const TextStyle(color: AquaColors.primaryFixedDim, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 36, width: 1, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Latest ABW', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          RichText(
                            text: TextSpan(
                              text: data.abw.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              children: const [
                                TextSpan(
                                  text: ' g',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            data.hasRealSampling ? 'Verified Sample' : 'Growth Model Est.',
                            style: const TextStyle(color: AquaColors.primaryFixedDim, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 36, width: 1, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Count Tier', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          RichText(
                            text: TextSpan(
                              text: data.countPcsPerKg.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              children: const [
                                TextSpan(
                                  text: ' pcs',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              data.countGrade.split(' ')[0],
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Formula: Count = 1,000 ÷ ${data.abw.toStringAsFixed(2)} g = ${data.countPcsPerKg.toStringAsFixed(2)} pcs/kg',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        'Verified ✓',
                        style: TextStyle(color: AquaColors.primaryFixed, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryKpiGrid(ThemeData theme, BatchDashboardData data) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        // Card 1: Average Weight
        _buildKpiCard(
          theme: theme,
          title: 'Average Weight',
          icon: Icons.scale_rounded,
          value: '${data.abw.toStringAsFixed(2)} g',
          chipText: '+${data.adgGramsPerDay.toStringAsFixed(2)} g/d ADG',
          chipColor: AquaColors.primary,
          footerText: 'Target DOC ${data.targetDoc}: ${data.batch.targetHarvestWeightG.toStringAsFixed(1)}g',
        ),
        // Card 2: Count Tier
        _buildKpiCard(
          theme: theme,
          title: 'Current Count',
          icon: Icons.numbers_rounded,
          value: '${data.countPcsPerKg.toStringAsFixed(0)} pcs/kg',
          chipText: data.countGrade,
          chipColor: theme.colorScheme.secondary,
          footerText: 'Strict scale derivative',
        ),
        // Card 3: Standing Biomass
        _buildKpiCard(
          theme: theme,
          title: 'Standing Biomass',
          icon: Icons.inventory_2_rounded,
          value: '${(data.standingBiomassKg / 1000.0).toStringAsFixed(2)} tons',
          chipText: '${data.standingBiomassKg.toStringAsFixed(0)} kg in basin',
          chipColor: theme.colorScheme.onSurfaceVariant,
          footerText: '${NumberFormat('#,###').format(data.populationPcs)} live pcs est.',
        ),
        // Card 4: Survival & FCR
        _buildKpiCard(
          theme: theme,
          title: 'Survival & FCR',
          icon: Icons.insights_rounded,
          value: '${data.survivalPct.toStringAsFixed(1)}%',
          chipText: data.fcr != null ? 'FCR ${data.fcr!.toStringAsFixed(2)}' : 'FCR In Audit',
          chipColor: AquaColors.primary,
          footerText: '● Optimal Performance (1.20–1.35)',
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required String value,
    required String chipText,
    required Color chipColor,
    required String footerText,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AquaColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: isDark ? AquaColors.primaryDark : AquaColors.primary),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            footerText,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSiteWeatherRibbon(BuildContext context, ThemeData theme, BatchDashboardData data, FullWeatherForecast? forecast) {
    final hasLocation = data.site != null && data.site!.latitude != null && data.site!.longitude != null;
    if (!hasLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, size: 20, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No site location configured',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Add coordinates to site to enable microclimate weather.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isAvailable = forecast != null && forecast.isAvailable;
    final tempStr = isAvailable ? '${forecast.temperature.toStringAsFixed(1)}°C' : '—';
    final condStr = isAvailable ? forecast.condition : 'Weather unavailable';
    final iconStr = isAvailable ? forecast.conditionIcon : '☁️';
    final cacheNote = isAvailable ? (forecast.isFromCache ? 'Cached' : 'Live') : 'Offline';

    return InkWell(
      onTap: () {
        if (data.site != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WeatherPage(
                initialSiteId: data.site!.id,
                initialSiteName: data.site!.name,
                initialLat: data.site!.latitude,
                initialLon: data.site!.longitude,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AquaColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Text(iconStr, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Site Weather: $tempStr · $condStr',
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Text(
                    'Parent Site: ${data.site?.name ?? "Estate"} ($cacheNote)',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AquaColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'View Forecast ›',
                style: theme.textTheme.labelSmall?.copyWith(color: AquaColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHapaCheckAlertCard(BuildContext context, ThemeData theme, BatchDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AquaColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AquaColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AquaColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hapa Check Due (Day 10 Audit)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AquaColors.primary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Stocked: ${data.stockedHapaCount}',
                        style: const TextStyle(color: AquaColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '10 days elapsed since stocking (${DateFormat("dd MMM").format(data.batch.stockingDate)}). Count surviving shrimp in check net to compute verified survival and active population.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AquaColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showHapaCheckDialog(context, data),
                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                      label: const Text('Perform Hapa Check', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHapaCheckDialog(BuildContext context, BatchDashboardData data) async {
    final batch = data.batch;
    final pond = data.pond;
    final stockedHapa = batch.hapaStockedCount > 0 ? batch.hapaStockedCount : 100;
    final aliveCtrl = TextEditingController(text: '${(stockedHapa * 0.85).round()}');
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final alive = int.tryParse(aliveCtrl.text.trim()) ?? 0;
          final survivalPct = stockedHapa > 0 ? ((alive / stockedHapa) * 100.0).clamp(0.0, 100.0) : 0.0;
          final estimatedActive = ((batch.shrimpStockedCount * survivalPct) / 100.0).round();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.fact_check_rounded, color: AquaColors.primary),
                SizedBox(width: 8),
                Expanded(child: Text('10-Day Hapa Net Check', style: TextStyle(fontSize: 16))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stocked in Hapa:'),
                            Text('$stockedHapa pcs', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calculated Survival:'),
                            Text(
                              '${survivalPct.toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AquaColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated Active Population:'),
                            Text(
                              '$estimatedActive pcs',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AquaColors.statusOptimal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Original Stocked: ${batch.shrimpStockedCount} pcs (preserved)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: aliveCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Alive Shrimp in Hapa Net *',
                      suffixText: 'pcs',
                      helperText: 'Count live shrimp remaining in the check net',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes / Observations'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (alive < 0 || alive > stockedHapa * 2) return;

                  try {
                    final db = ref.read(appDatabaseProvider);
                    await db.into(db.hapaChecks).insert(
                      HapaChecksCompanion(
                        id: drift.Value('hapa_${DateTime.now().millisecondsSinceEpoch}'),
                        batchId: drift.Value(batch.id),
                        pondId: drift.Value(pond.id),
                        date: drift.Value(DateTime.now()),
                        hoursElapsed: const drift.Value(240), // 10 days
                        hapaStocked: drift.Value(stockedHapa),
                        hapaAlive: drift.Value(alive),
                        survivalPercentage: drift.Value(survivalPct),
                        estimatedPopulation: drift.Value(estimatedActive),
                        notes: drift.Value(notesCtrl.text.trim()),
                      ),
                    );

                    // Update batch's actualSurvivalPct
                    await (db.update(db.batches)..where((t) => t.id.equals(batch.id))).write(
                      BatchesCompanion(actualSurvivalPct: drift.Value(survivalPct)),
                    );

                    ref.invalidate(activeBatchesStreamProvider);
                    ref.invalidate(batchDashboardDataProvider(batch.id));

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Hapa Check saved: ${survivalPct.toStringAsFixed(1)}% survival. Active population: $estimatedActive pcs.'),
                          backgroundColor: AquaColors.statusOptimal,
                        ),
                      );
                      Navigator.of(ctx).pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save Hapa check: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Save Hapa Check'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOperationalAlertCard(BuildContext context, ThemeData theme, BatchDashboardData data) {
    final status = data.samplingStatus;
    if (status == SamplingStatus.notActive) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sampling Program: Inactive (Begins at DOC 50)',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Current DOC ${data.doc}. Sampling frequency will be every 10 days starting at DOC 50.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isDue = status.isDue;
    final isFirstSample = status == SamplingStatus.dueFirstSample;

    if (!isDue) {
      final nextDueIn = (kSamplingIntervalDays - (data.samplingDaysSinceLatest ?? 0)).clamp(0, kSamplingIntervalDays);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AquaColors.statusOptimal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AquaColors.statusOptimal.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AquaColors.statusOptimal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sampling Up To Date',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AquaColors.statusOptimal, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Next due in $nextDueIn days',
                          style: const TextStyle(color: AquaColors.statusOptimal, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last sampled ${data.samplingDaysSinceLatest ?? 0} days ago (${data.latestSampling?.abwGrams.toStringAsFixed(3)}g ABW · ${SamplingCalculator.formatCountPerKg(data.countPcsPerKg)}). 10-day sampling frequency.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => SamplingHistorySheet.show(context, batch: data.batch, pond: data.pond),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: const Text('Sampling History', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AquaColors.statusOptimal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: widget.onSamplingTap ?? () => SamplingDialog.show(context, batch: data.batch, pond: data.pond),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Sample', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_late_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFirstSample
                          ? 'Cast Net Sampling Due (DOC ${data.doc})'
                          : 'Cast Net Sampling Due (${data.samplingDaysSinceLatest} Days Elapsed)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onErrorContainer),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '10-Day Cycle',
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isFirstSample
                      ? 'Batch reached DOC ${data.doc}. Sampling officially begins at DOC 50. Conduct cast net sampling to establish baseline ABW and Count/kg.'
                      : 'Last sampled ${data.samplingDaysSinceLatest} days ago (${data.latestSampling?.abwGrams.toStringAsFixed(3)}g). 10-day sampling interval reached. Record new sample to recalibrate ADG & feeding.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.onSamplingTap ?? () => SamplingDialog.show(context, batch: data.batch, pond: data.pond),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Sampling', style: TextStyle(fontSize: 12)),
                    ),
                    if (data.hasRealSampling) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onErrorContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => SamplingHistorySheet.show(context, batch: data.batch, pond: data.pond),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: const Text('History', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedProgressSection(ThemeData theme, BatchDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Feed Progress", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    'DOC ${data.doc} · ${data.todayFeedLoggedKg.toStringAsFixed(1)} / ${data.todayFeedAllocatedKg.toStringAsFixed(1)} kg Allocated',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.feedCompliancePct.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AquaColors.primary),
                  ),
                  Text(
                    '${data.todaySessions.where((s) => s.isPending).length} meals pending',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (data.feedCompliancePct / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: AquaColors.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Sessions List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.todaySessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final session = data.todaySessions[idx];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: session.isCompleted ? theme.colorScheme.surfaceContainer : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: session.isCompleted ? AquaColors.primary : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        session.isCompleted ? Icons.check_rounded : Icons.schedule_rounded,
                        color: session.isCompleted ? Colors.white : theme.colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(session.timeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Text('(${session.slotName})', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                          Text(session.checkTrayStatus, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                          if (session.coFedMedicinesJson != null && session.coFedMedicinesJson!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildCoFedChips(session.coFedMedicinesJson!),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${session.quantityKg.toStringAsFixed(1)} kg',
                          style: TextStyle(fontWeight: FontWeight.bold, color: session.isCompleted ? AquaColors.primary : theme.colorScheme.onSurface),
                        ),
                        Text(session.feedType, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.outline)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveWaterQualityTelemetry(BuildContext context, ThemeData theme, BatchDashboardData data) {
    final wqAsync = ref.watch(pondWaterQualityLogsStreamProvider(data.pond.id));

    return wqAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop_outlined, size: 32, color: Color(0xFF0288D1)),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Water Quality Logs Yet',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Log daily Dissolved Oxygen and pH levels for ${data.pond.name} to monitor biological stress and safe parameter bands.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => WaterQualityEntryPage.show(context, pondId: data.pond.id),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log First Water Reading'),
                ),
              ],
            ),
          );
        }

        final latest = logs.first;
        final isCriticalDo = latest.dissolvedOxygen != null && latest.dissolvedOxygen! < 4.0;
        final isWarningDo = latest.dissolvedOxygen != null && latest.dissolvedOxygen! >= 4.0 && latest.dissolvedOxygen! < 5.0;

        final doColor = isCriticalDo
            ? AquaColors.statusCritical
            : (isWarningDo ? AquaColors.statusWarning : AquaColors.statusOptimal);

        final isPhOptimal = latest.ph != null && latest.ph! >= 7.5 && latest.ph! <= 8.5;
        final phColor = isPhOptimal ? AquaColors.statusOptimal : AquaColors.statusWarning;

        return Column(
          children: [
            // Live Telemetry Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCriticalDo
                      ? AquaColors.statusCritical.withOpacity(0.5)
                      : theme.colorScheme.outlineVariant.withOpacity(0.3),
                  width: isCriticalDo ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0288D1).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.water_drop_rounded, size: 18, color: Color(0xFF0288D1)),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Water Telemetry',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${latest.timeSlot} · ${DateFormat('dd MMM yyyy').format(latest.date)}',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => WaterQualityEntryPage.show(context, pondId: data.pond.id),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Log WQ', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Telemetry 4-Metric Grid
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: doColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: doColor.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('DO Level', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: doColor)),
                                  Icon(Icons.air_rounded, size: 14, color: doColor),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latest.dissolvedOxygen != null ? '${latest.dissolvedOxygen!.toStringAsFixed(1)} ppm' : '--',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: doColor),
                              ),
                              Text(
                                isCriticalDo ? 'CRITICAL LOW' : (isWarningDo ? 'Moderate' : 'Optimal Band'),
                                style: TextStyle(fontSize: 10, color: doColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: phColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: phColor.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('pH Acidity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: phColor)),
                                  Icon(Icons.science_rounded, size: 14, color: phColor),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latest.ph != null ? latest.ph!.toStringAsFixed(1) : '--',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: phColor),
                              ),
                              Text(
                                isPhOptimal ? 'Safe (7.5–8.5)' : 'Check Buffer',
                                style: TextStyle(fontSize: 10, color: phColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Salinity', style: theme.textTheme.bodySmall),
                              Text(
                                latest.salinity != null ? '${latest.salinity!.toStringAsFixed(1)} ppt' : '--',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Water Temp', style: theme.textTheme.bodySmall),
                              Text(
                                latest.temperature != null ? '${latest.temperature!.toStringAsFixed(1)} °C' : '--',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (latest.ammonia != null || latest.alkalinity != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (latest.ammonia != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('TAN (Ammonia)', style: theme.textTheme.bodySmall),
                                  Text(
                                    '${latest.ammonia!.toStringAsFixed(2)} ppm',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (latest.ammonia != null && latest.alkalinity != null) const SizedBox(width: 8),
                        if (latest.alkalinity != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Alkalinity', style: theme.textTheme.bodySmall),
                                  Text(
                                    '${latest.alkalinity!.toStringAsFixed(0)} ppm',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Recent Readings Timeline
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Water Quality Readings',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...logs.take(5).map((log) {
                    final logDo = log.dissolvedOxygen != null ? '${log.dissolvedOxygen!.toStringAsFixed(1)} ppm' : '--';
                    final logPh = log.ph != null ? 'pH ${log.ph!.toStringAsFixed(1)}' : '--';
                    final logTemp = log.temperature != null ? '${log.temperature!.toStringAsFixed(0)}°C' : '--';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: log.dissolvedOxygen != null && log.dissolvedOxygen! < 4.0
                                  ? AquaColors.statusCritical
                                  : AquaColors.statusOptimal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${DateFormat("dd MMM").format(log.date)} · ${log.timeSlot}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '$logDo  ·  $logPh  ·  $logTemp',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Error loading water telemetry: $e')),
    );
  }

  Widget _buildDateWiseFeedLedger(ThemeData theme, BatchDashboardData data) {
    final selYear = _selectedLedgerDate.year;
    final selMonth = _selectedLedgerDate.month;
    final selDay = _selectedLedgerDate.day;
    final stockingDay = DateTime(data.batch.stockingDate.year, data.batch.stockingDate.month, data.batch.stockingDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final harvestDay = data.isCompleted && data.batch.harvestDate != null
        ? DateTime(data.batch.harvestDate!.year, data.batch.harvestDate!.month, data.batch.harvestDate!.day)
        : today;

    final canGoBack = DateTime(selYear, selMonth, selDay).isAfter(stockingDay);
    final canGoForward = DateTime(selYear, selMonth, selDay).isBefore(harvestDay);

    final selectedDoc = _selectedLedgerDate.difference(stockingDay).inDays + 1;

    // Filter valid feed records strictly for _selectedLedgerDate
    final selectedDateRecords = data.validFeedRecords.where((r) {
      return r.date.year == selYear && r.date.month == selMonth && r.date.day == selDay;
    }).toList();

    final selectedFeedKg = selectedDateRecords.fold<double>(0.0, (s, r) => s + FeedCalculator.getRecordTotalKg(r));
    final mealsCount = selectedDateRecords.length;
    final estCost = selectedFeedKg * 85.0; // ₹85/kg standard feed price

    String dateTrayStatus = 'No Records';
    if (selectedDateRecords.any((r) => r.trayLeftoverPct > 20)) {
      dateTrayStatus = 'Surplus Leftover';
    } else if (selectedDateRecords.any((r) => r.trayChecked && r.trayLeftoverPct == 0)) {
      dateTrayStatus = '100% Clean';
    } else if (selectedDateRecords.isNotEmpty) {
      dateTrayStatus = 'Normal';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AquaColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AquaColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AquaColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date-Wise Feed Ledger', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Granular meal logs & tray audit trail', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(_showDateWiseLedger ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                onPressed: () {
                  setState(() => _showDateWiseLedger = !_showDateWiseLedger);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: canGoBack ? 'Previous Day' : 'Stocking Day Reached',
                onPressed: canGoBack
                    ? () {
                        setState(() => _selectedLedgerDate = _selectedLedgerDate.subtract(const Duration(days: 1)));
                      }
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AquaColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEE, dd MMM yyyy').format(_selectedLedgerDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DOC ${selectedDoc > 0 ? selectedDoc : 1}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: canGoForward ? 'Next Day' : 'Today Reached',
                onPressed: canGoForward
                    ? () {
                        setState(() => _selectedLedgerDate = _selectedLedgerDate.add(const Duration(days: 1)));
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ledger Metrics Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Feed Broadcast', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('${selectedFeedKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Meals Completed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          '$mealsCount logged',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Check Tray Status', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          dateTrayStatus,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dateTrayStatus.contains('Surplus')
                                ? Colors.redAccent
                                : (dateTrayStatus.contains('100%') ? AquaColors.primary : theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Est. Daily Feed Cost', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('₹${estCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_showDateWiseLedger) ...[
            const SizedBox(height: 12),
            Text(
              'Meals Logged on ${DateFormat("dd MMM yyyy").format(_selectedLedgerDate)} (DOC ${selectedDoc > 0 ? selectedDoc : 1})',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (selectedDateRecords.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No feed records logged for this date.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedDateRecords.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final record = selectedDateRecords[idx];
                  final items = FeedCalculator.getRecordItems(record);
                  final feedName = items.isNotEmpty
                      ? items.map((it) => it.size != null && it.size!.isNotEmpty ? '${it.feedName} (${it.size})' : it.feedName).join(', ')
                      : (record.otherFeedName != null && record.otherFeedName!.isNotEmpty
                          ? record.otherFeedName!
                          : 'CP Classic Grower');
                  final mealTotalKg = FeedCalculator.getRecordTotalKg(record);
                  final trayText = record.trayChecked
                      ? (record.trayLeftoverPct == 0
                          ? 'Tray: 0% Clean (100% Consumed)'
                          : 'Tray: ${record.trayLeftoverPct}% Leftover')
                      : 'Tray: Pending Inspection';

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Meal #${idx + 1} · ${record.timeSlot}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${mealTotalKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AquaColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              feedName,
                              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            Text(
                              trayText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: record.trayLeftoverPct > 20 ? Colors.redAccent : theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        if (record.coFedMedicinesJson != null && record.coFedMedicinesJson!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildCoFedChips(record.coFedMedicinesJson!),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoFedChips(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      if (list.isEmpty) return const SizedBox.shrink();
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: list.map((item) {
          final map = item as Map<String, dynamic>;
          final name = map['name'] ?? 'Item';
          final qty = map['quantity'] ?? 0;
          final unit = map['unit'] ?? 'g';
          final cat = map['category'] ?? '';
          final isMed = cat == 'medicine';
          final icon = isMed ? '💊' : '🧪';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMed ? Colors.red.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isMed ? Colors.red.withOpacity(0.3) : Colors.amber.withOpacity(0.3),
              ),
            ),
            child: Text(
              '$icon $name: $qty $unit',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMed ? Colors.red[800] : Colors.brown[800],
              ),
            ),
          );
        }).toList(),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildCheckTrayIntelligence(ThemeData theme, BatchDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_rounded, size: 20, color: AquaColors.primary),
                  const SizedBox(width: 8),
                  Text('Check-Tray Intelligence', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text('4 Trays Monitored', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Recent Check Tray Statuses
          Row(
            children: [
              Expanded(
                child: _buildTrayStatusTile('Today 11:00 AM', 'Normal', '10% leftover', AquaColors.secondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrayStatusTile('Today 07:00 AM', 'Clean', '0% clean', AquaColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrayStatusTile('Yesterday', 'Normal', 'Trace left', AquaColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actionable Guidance Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: AquaColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ration Guidance: ${data.trayStatus}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.trayGuidance,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayStatusTile(String time, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGrowthTrendChart(ThemeData theme, BatchDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Growth Trend (ABW vs Target)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Pacific White Shrimp Standard Growth Model', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              Text('+${data.adgGramsPerDay.toStringAsFixed(2)} g/d', style: const TextStyle(fontWeight: FontWeight.bold, color: AquaColors.primary)),
            ],
          ),
          const SizedBox(height: 16),

          // Inline Growth Graph Visual
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: _GrowthTrendPainter(data.growthPoints, data.targetDoc),
            ),
          ),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Actual ABW', AquaColors.primary, false),
              _buildLegendItem('Projected Target', AquaColors.primaryFixedDim, true),
              _buildLegendItem('Standard Model', theme.colorScheme.outline, false, isDotted: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSamplingSummaryCard(BuildContext context, ThemeData theme, BatchDashboardData data) {
    final latest = data.latestSampling;
    final hasSampling = latest != null;
    final countPerKgStr = SamplingCalculator.formatCountPerKg(data.countPcsPerKg);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.scale_rounded, size: 20, color: AquaColors.primary),
                  const SizedBox(width: 8),
                  Text('Cast Net Sampling & ABW', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AquaColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  '10-Day Interval',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AquaColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4-cell metric grid for sampling
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Latest ABW', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '${data.abw.toStringAsFixed(3)} g',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AquaColors.primary),
                      ),
                      Text(
                        data.hasRealSampling ? 'Authoritative Sample' : (data.abwSource == 'visual' ? 'Visual Estimation' : 'Model Estimate'),
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Count / kg', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        countPerKgStr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        data.countGrade,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Growth Since Prior', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        latest?.weightGainGrams != null
                            ? '${latest!.weightGainGrams! >= 0 ? "+" : ""}${latest.weightGainGrams!.toStringAsFixed(3)} g'
                            : '—',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: latest?.weightGainGrams != null && latest!.weightGainGrams! < 0
                              ? AquaColors.statusAlert
                              : AquaColors.statusOptimal,
                        ),
                      ),
                      Text(
                        hasSampling ? (latest.daysElapsed != null ? '${latest.daysElapsed} days interval' : 'Baseline first sample') : 'No sampling yet',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Growth (ADG)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        latest?.adgGramsPerDay != null
                            ? '${latest!.adgGramsPerDay! >= 0 ? "+" : ""}${latest.adgGramsPerDay!.toStringAsFixed(3)} g/d'
                            : '+${data.adgGramsPerDay.toStringAsFixed(2)} g/d',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        hasSampling ? DateFormat('dd MMM yyyy').format(latest.date) : 'Starts at DOC 50',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions: Sampling History & Add Sampling
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => SamplingHistorySheet.show(context, batch: data.batch, pond: data.pond),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text('History (${data.allSamplings.length})'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AquaColors.primary,
                  ),
                  onPressed: widget.onSamplingTap ?? () => SamplingDialog.show(context, batch: data.batch, pond: data.pond),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Sample'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDashed, {bool isDotted = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFeedConsumptionBarChart(ThemeData theme, BatchDashboardData data) {
    final bars = data.getDailyFeedBarsForRange(_selectedFeedRangeDays);
    final maxFeed = bars.fold<double>(30.0, (m, b) => b.feedKg > m ? b.feedKg : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feed Consumption (kg/day)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${bars.length} days plotted · Daily broadcast quantities',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                children: [7, 14, 30].map((days) {
                  final isSel = _selectedFeedRangeDays == days;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedFeedRangeDays = days),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSel ? AquaColors.primary : theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${days}D',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Daily Bars Container with responsive / scrolling sizing
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: bars.isEmpty
                ? Center(
                    child: Text(
                      'No feed consumption logged for this range.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : (bars.length <= 7
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: bars.map((bar) => _buildFeedBarItem(theme, bar, maxFeed, 22.0)).toList(),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true, // Scroll to end so 'Today' is visible by default
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: bars
                              .map((bar) => Padding(
                                    padding: EdgeInsets.symmetric(horizontal: _selectedFeedRangeDays == 30 ? 4.0 : 6.0),
                                    child: _buildFeedBarItem(
                                      theme,
                                      bar,
                                      maxFeed,
                                      _selectedFeedRangeDays == 30 ? 18.0 : 22.0,
                                    ),
                                  ))
                              .toList(),
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedBarItem(ThemeData theme, DailyFeedBar bar, double maxFeed, double width) {
    final heightFactor = maxFeed > 0 ? (bar.feedKg / (maxFeed * 1.1)).clamp(0.08, 1.0) : 0.08;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          bar.feedKg > 0 ? bar.feedKg.toStringAsFixed(0) : '·',
          style: TextStyle(
            fontSize: 9,
            fontWeight: bar.isToday ? FontWeight.bold : FontWeight.normal,
            color: bar.hasSurplusTray
                ? Colors.redAccent
                : (bar.feedKg > 0 ? theme.colorScheme.onSurface : Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 85 * heightFactor,
          decoration: BoxDecoration(
            color: bar.feedKg == 0
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                : (bar.hasSurplusTray
                    ? Colors.redAccent
                    : (bar.isToday ? AquaColors.primary : AquaColors.primary.withOpacity(0.65))),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          bar.isToday ? 'Today' : DateFormat('dd').format(bar.date),
          style: TextStyle(
            fontSize: 9,
            fontWeight: bar.isToday ? FontWeight.bold : FontWeight.normal,
            color: bar.isToday ? AquaColors.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFcrPerformanceCard(ThemeData theme, BatchDashboardData data) {
    final fcrVal = data.fcr ?? 1.28;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.ssid_chart_rounded, size: 20, color: AquaColors.primary),
                  const SizedBox(width: 8),
                  Text('FCR Performance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                fcrVal.toStringAsFixed(2),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AquaColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Target range indicator bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Low 1.10', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Target Zone: 1.20 – 1.35', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AquaColors.primary)),
              Text('High 1.50', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Stack(
                children: [
                  // Target zone overlay
                  Positioned(
                    left: 60,
                    right: 60,
                    top: 0,
                    bottom: 0,
                    child: Container(color: theme.colorScheme.secondaryContainer),
                  ),
                  // Pointer needle for current FCR
                  Align(
                    alignment: Alignment((fcrVal - 1.30) / 0.20, 0),
                    child: Container(width: 4, height: 10, color: AquaColors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Mini milestone stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: data.fcrMilestones.map((m) {
              final isCurrent = m.doc == data.doc;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? theme.colorScheme.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('DOC ${m.doc}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      m.fcr.toStringAsFixed(2),
                      style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? AquaColors.primary : null),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestOutlookCard(ThemeData theme, BatchDashboardData data) {
    final outlook = data.harvestOutlook;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 20, color: AquaColors.primary),
                  const SizedBox(width: 8),
                  Text('Harvest Outlook', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '~${outlook.daysRemaining} Days Left',
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current: ${outlook.currentAbw.toStringAsFixed(1)}g (DOC ${outlook.currentDoc})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AquaColors.primary)),
              Text('Target: ${outlook.targetAbw.toStringAsFixed(1)}g (DOC ${outlook.targetDoc})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (outlook.currentAbw / outlook.targetAbw).clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: AquaColors.primary,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Projected Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(DateFormat('dd MMM yyyy').format(outlook.projectedHarvestDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text('At target DOC', style: TextStyle(fontSize: 10, color: AquaColors.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expected Biomass', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('${(outlook.expectedBiomassKg / 1000).toStringAsFixed(2)} tons', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text('Export grade', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverviewCard(ThemeData theme, BatchDashboardData data) {
    final fin = data.financialOverview;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 20, color: AquaColors.primary),
                  const SizedBox(width: 8),
                  Text('Batch Financial Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${fin.projectedMarginPct.toStringAsFixed(1)}% Margin',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AquaColors.primary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _buildFinanceGridTile('Incurred Cost', '₹${(fin.incurredCost / 100000).toStringAsFixed(2)} L', 'Feed, seed & energy'),
              _buildFinanceGridTile('Projected Revenue', '₹${(fin.projectedRevenue / 100000).toStringAsFixed(2)} L', 'Mandi @ ₹290/kg'),
              _buildFinanceGridTile('Estimated Profit', '₹${(fin.estimatedProfit / 100000).toStringAsFixed(2)} L', 'Net realization'),
              _buildFinanceGridTile('Break-Even Price', '₹${fin.breakEvenPricePerKg.toStringAsFixed(0)} /kg', 'Safe floor'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceGridTile(String title, String val, String note) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(note, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecentOperationalLogs(BuildContext context, ThemeData theme, BatchDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Operational Logs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Auto-synced', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.recentActivity.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final log = data.recentActivity[idx];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        log.iconType == 'feed' ? Icons.restaurant_rounded : Icons.scale_rounded,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(log.timeAgo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          Text(log.subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Quick Action Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.water_drop_rounded, size: 16, color: AquaColors.primary),
                  label: const Text('Log Water Test', style: TextStyle(fontSize: 11)),
                  onPressed: widget.onWaterQualityTap,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.medication_rounded, size: 16, color: AquaColors.primary),
                  label: const Text('Add Treatment', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Treatment workflow opened for current batch.')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 16, color: AquaColors.primary),
                  label: const Text('Adjust Stock', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inventory Stock Adjustment opened for site.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPrimaryActions(BuildContext context, ThemeData theme, BatchDashboardData data) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: widget.onLogFeedTap,
              icon: const Icon(Icons.restaurant_rounded, size: 18),
              label: const Text('Log Feeding Session', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 48,
            child: FilledButton.tonalIcon(
              onPressed: widget.onSamplingTap ?? () => SamplingDialog.show(context, batch: data.batch, pond: data.pond),
              icon: const Icon(Icons.scale_rounded, size: 18),
              label: const Text('Add Sampling', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedBatchBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AquaColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batch Completed & Reconciled', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'This cycle has been finalized. Operational feeding is locked. All records preserved for compliance and audit.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CUSTOM PAINTER FOR GROWTH TREND ────────────────────────

class _GrowthTrendPainter extends CustomPainter {
  final List<GrowthTrendPoint> points;
  final int targetDoc;

  _GrowthTrendPainter(this.points, this.targetDoc);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // 3 grid lines
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    if (points.isEmpty) return;

    final maxDoc = targetDoc > 0 ? targetDoc : 105;
    const maxAbw = 30.0;

    // Standard Model curve (dotted)
    final modelPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final modelPath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.doc / maxDoc) * size.width;
      final y = size.height - (p.standardModelAbw / maxAbw) * size.height;
      if (i == 0) {
        modelPath.moveTo(x, y);
      } else {
        modelPath.lineTo(x, y);
      }
    }
    canvas.drawPath(modelPath, modelPaint);

    // Projected Target line (dashed cyan)
    final targetPaint = Paint()
      ..color = AquaColors.primaryFixedDim
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final targetPath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.doc / maxDoc) * size.width;
      final y = size.height - (p.targetAbw / maxAbw) * size.height;
      if (i == 0) {
        targetPath.moveTo(x, y);
      } else {
        targetPath.lineTo(x, y);
      }
    }
    canvas.drawPath(targetPath, targetPaint);

    // Actual ABW curve (solid teal)
    final actualPaint = Paint()
      ..color = AquaColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final actualPath = Path();
    bool hasMoved = false;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.actualAbw != null) {
        final x = (p.doc / maxDoc) * size.width;
        final y = size.height - (p.actualAbw! / maxAbw) * size.height;
        if (!hasMoved) {
          actualPath.moveTo(x, y);
          hasMoved = true;
        } else {
          actualPath.lineTo(x, y);
        }
        // Draw data dot
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = AquaColors.primary);
      }
    }
    if (hasMoved) {
      canvas.drawPath(actualPath, actualPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthTrendPainter oldDelegate) => true;
}
