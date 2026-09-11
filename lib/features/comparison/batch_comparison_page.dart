import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/batch_comparison_models.dart';
import '../../core/providers/batch_comparison_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../app/theme/color_schemes.dart';

class BatchComparisonPage extends ConsumerStatefulWidget {
  final List<String>? initialBatchIds;

  const BatchComparisonPage({
    super.key,
    this.initialBatchIds,
  });

  @override
  ConsumerState<BatchComparisonPage> createState() => _BatchComparisonPageState();
}

class _BatchComparisonPageState extends ConsumerState<BatchComparisonPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialBatchIds != null && widget.initialBatchIds!.length >= 2) {
        ref.read(selectedComparisonBatchIdsProvider.notifier).state = widget.initialBatchIds!;
      } else {
        _autoSelectDefaultBatches();
      }
    });
  }

  void _autoSelectDefaultBatches() async {
    final currentSelected = ref.read(selectedComparisonBatchIdsProvider);
    if (currentSelected.length >= 2) return;

    final db = ref.read(appDatabaseProvider);
    final allBatches = await db.select(db.batches).get();
    if (allBatches.length >= 2) {
      // Pick first two batches (prioritizing active batches)
      final active = allBatches.where((b) => b.status == 'active').toList();
      final remaining = allBatches.where((b) => b.status != 'active').toList();
      final ordered = [...active, ...remaining];
      ref.read(selectedComparisonBatchIdsProvider.notifier).state = [ordered[0].id, ordered[1].id];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final comparisonAsync = ref.watch(batchComparisonResultProvider);
    final selectedBatchIds = ref.watch(selectedComparisonBatchIdsProvider);
    final currentMode = ref.watch(comparisonModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.isHindi ? 'बैच तुलना' : 'Batch Comparison',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.refresh(batchComparisonResultProvider),
          ),
        ],
      ),
      body: comparisonAsync.when(
        data: (result) {
          if (result == null || result.batches.length < 2) {
            return _buildEmptyState(theme, settings, selectedBatchIds);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Batch Selection Ribbons (Batch A, Batch B, + Add Batch C)
                _buildBatchSelectorRibbon(theme, result.batches),
                const SizedBox(height: 16),

                // 2. Comparison Mode Switcher (Same DOC vs Same Date)
                _buildModeSwitcher(theme, currentMode),
                const SizedBox(height: 16),

                // 3. Quick Comparison Summary Matrix
                _buildQuickComparisonSummary(theme, result),
                const SizedBox(height: 20),

                // 4. Growth Trajectory Graph (ABW vs DOC)
                _buildGrowthChartCard(theme, result),
                const SizedBox(height: 20),

                // 5. Feed Consumption Trajectory Graph
                _buildFeedChartCard(theme, result),
                const SizedBox(height: 20),

                // 6. Cumulative FCR Trajectory Graph
                if (result.fcrPoints.isNotEmpty) ...[
                  _buildFcrChartCard(theme, result),
                  const SizedBox(height: 20),
                ],

                // 7. Harvest Performance (for completed batches)
                if (result.harvestData.isNotEmpty) ...[
                  _buildHarvestComparisonCard(theme, result),
                  const SizedBox(height: 20),
                ],

                // 8. Crop Financial Performance
                if (result.financialData.any((f) => f.totalCost > 0 || f.totalRevenue > 0)) ...[
                  _buildFinancialComparisonCard(theme, result),
                  const SizedBox(height: 20),
                ],

                // 9. Transparent Category Performance Summary
                _buildPerformanceSummaryCard(theme, result),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading batch comparison: $err'),
          ),
        ),
      ),
    );
  }

  // ── 1. BATCH SELECTOR RIBBON ─────────────────────────────────
  Widget _buildBatchSelectorRibbon(ThemeData theme, List<BatchMetaItem> batches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected Batches (${batches.length}/3)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (batches.length < 3)
              TextButton.icon(
                onPressed: () => _showBatchPickerModal(context, isAdding: true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add 3rd Batch'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 400;
            return isNarrow
                ? Column(
                    children: batches.map((b) => _buildBatchCard(theme, b, canRemove: batches.length > 2)).toList(),
                  )
                : Row(
                    children: batches.map((b) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildBatchCard(theme, b, canRemove: batches.length > 2),
                        ),
                      );
                    }).toList(),
                  );
          },
        ),
      ],
    );
  }

  Widget _buildBatchCard(ThemeData theme, BatchMetaItem b, {required bool canRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: b.color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: b.color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Batch #${b.batchNumber}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: b.isActive
                      ? AquaColors.statusOptimal.withOpacity(0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  b.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: b.isActive ? AquaColors.statusOptimal : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (canRemove)
                InkWell(
                  onTap: () {
                    final current = ref.read(selectedComparisonBatchIdsProvider);
                    ref.read(selectedComparisonBatchIdsProvider.notifier).state =
                        current.where((id) => id != b.batchId).toList();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${b.pondName} · ${b.siteName}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${b.species.contains(" ") ? b.species.split(" ").first : b.species} · DOC ${b.currentOrHarvestDoc}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _showBatchPickerModal(context, replacingBatchId: b.batchId),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Change Batch',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. COMPARISON MODE SWITCHER ──────────────────────────────
  Widget _buildModeSwitcher(ThemeData theme, ComparisonMode currentMode) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                ref.read(comparisonModeProvider.notifier).state = ComparisonMode.sameDoc;
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: currentMode == ComparisonMode.sameDoc ? theme.colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: currentMode == ComparisonMode.sameDoc
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      'Same DOC Mode (Biological)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: currentMode == ComparisonMode.sameDoc
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Aligns batches by Day of Culture',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                ref.read(comparisonModeProvider.notifier).state = ComparisonMode.sameDate;
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: currentMode == ComparisonMode.sameDate ? theme.colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: currentMode == ComparisonMode.sameDate
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      'Same Date Mode (Calendar)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: currentMode == ComparisonMode.sameDate
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Aligns daily operational feeding',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. QUICK COMPARISON SUMMARY ──────────────────────────────
  Widget _buildQuickComparisonSummary(ThemeData theme, BatchComparisonResult result) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quick KPI Comparison Matrix',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Side-by-side metric comparison. Green highlight indicates superior performance.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),

            // Header row with batch names
            Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Metric',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                ...result.batches.map((b) {
                  return Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: b.color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'B#${b.batchNumber}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            const Divider(height: 16),

            // Metrics Rows
            ...result.metrics.map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              if (m.clarificationNote != null)
                                Text(
                                  m.clarificationNote!,
                                  style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        ...result.batches.map((b) {
                          final str = m.displayStrings[b.batchId] ?? 'N/A';
                          final isWinner = m.bestBatchId == b.batchId;

                          return Expanded(
                            flex: 4,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isWinner ? AquaColors.statusOptimal.withOpacity(0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isWinner
                                    ? Border.all(color: AquaColors.statusOptimal.withOpacity(0.4), width: 1)
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isWinner) ...[
                                    const Icon(Icons.check_circle_rounded, size: 12, color: AquaColors.statusOptimal),
                                    const SizedBox(width: 3),
                                  ],
                                  Flexible(
                                    child: Text(
                                      str,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                                        color: isWinner ? AquaColors.statusOptimal : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const Divider(height: 10, thickness: 0.4),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── 4. GROWTH TRAJECTORY CHART (ABW vs DOC) ─────────────────
  Widget _buildGrowthChartCard(ThemeData theme, BatchComparisonResult result) {
    // Generate series per batch
    final series = <LineChartBarData>[];

    double maxDoc = 30.0;
    double maxAbw = 15.0;

    for (final b in result.batches) {
      final bPoints = result.growthPoints.where((p) => p.batchId == b.batchId).toList();
      bPoints.sort((x, y) => x.doc.compareTo(y.doc));

      final spots = <FlSpot>[];
      for (final p in bPoints) {
        final xVal = p.doc.toDouble();
        final yVal = p.abwGrams;
        spots.add(FlSpot(xVal, yVal));
        if (xVal > maxDoc) maxDoc = xVal;
        if (yVal > maxAbw) maxAbw = yVal;
      }

      if (spots.isNotEmpty) {
        series.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: b.color,
            barWidth: 3.0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: b.color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        );
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Growth Comparison (ABW vs DOC)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Actual sampling points mapped against biological culture age.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            if (series.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No sampling records available to plot.')),
              )
            else
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 1,
                    maxX: maxDoc + 5,
                    minY: 0,
                    maxY: maxAbw + 3,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 5,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: 5,
                          getTitlesWidget: (v, meta) => Text(
                            '${v.toInt()}g',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 15,
                          getTitlesWidget: (v, meta) => Text(
                            'D${v.toInt()}',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: series,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final bIndex = spot.barIndex;
                            final b = result.batches[bIndex % result.batches.length];
                            return LineTooltipItem(
                              '${b.displayName}\nDOC ${spot.x.toInt()}: ${spot.y.toStringAsFixed(2)}g',
                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),
            _buildChartLegend(result.batches),
          ],
        ),
      ),
    );
  }

  // ── 5. FEED CONSUMPTION CHART ────────────────────────────────
  Widget _buildFeedChartCard(ThemeData theme, BatchComparisonResult result) {
    final series = <LineChartBarData>[];
    double maxDoc = 30.0;
    double maxFeed = 20.0;

    for (final b in result.batches) {
      final bPoints = result.feedPoints.where((p) => p.batchId == b.batchId).toList();
      bPoints.sort((x, y) => x.doc.compareTo(y.doc));

      final spots = <FlSpot>[];
      for (final p in bPoints) {
        final xVal = p.doc.toDouble();
        final yVal = p.feedKg;
        spots.add(FlSpot(xVal, yVal));
        if (xVal > maxDoc) maxDoc = xVal;
        if (yVal > maxFeed) maxFeed = yVal;
      }

      if (spots.isNotEmpty) {
        series.add(
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: b.color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Feed Uptake Trajectory (Daily kg)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Daily cumulative feed allocation curve by biological age.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            if (series.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No feeding records available to plot.')),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: 1,
                    maxX: maxDoc + 5,
                    minY: 0,
                    maxY: maxFeed + 5,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: 10,
                          getTitlesWidget: (v, meta) => Text(
                            '${v.toInt()}kg',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 15,
                          getTitlesWidget: (v, meta) => Text(
                            'D${v.toInt()}',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: series,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildChartLegend(result.batches),
          ],
        ),
      ),
    );
  }

  // ── 6. FCR VS DOC CHART ──────────────────────────────────────
  Widget _buildFcrChartCard(ThemeData theme, BatchComparisonResult result) {
    final series = <LineChartBarData>[];

    for (final b in result.batches) {
      final bPoints = result.fcrPoints.where((p) => p.batchId == b.batchId).toList();
      bPoints.sort((x, y) => x.doc.compareTo(y.doc));

      final spots = bPoints.map((p) => FlSpot(p.doc.toDouble(), p.fcr)).toList();
      if (spots.isNotEmpty) {
        series.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: b.color,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
        );
      }
    }

    if (series.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'FCR vs Culture Age (DOC)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Progressive Feed Conversion Ratio. Lower trajectory indicates superior feed conversion efficiency.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0.8,
                  maxY: 2.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 0.2,
                        getTitlesWidget: (v, meta) => Text(
                          v.toStringAsFixed(1),
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 15,
                        getTitlesWidget: (v, meta) => Text(
                          'D${v.toInt()}',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: series,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildChartLegend(result.batches),
          ],
        ),
      ),
    );
  }

  // ── 7. HARVEST COMPARISON CARD ───────────────────────────────
  Widget _buildHarvestComparisonCard(ThemeData theme, BatchComparisonResult result) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, size: 20, color: AquaColors.statusOptimal),
                const SizedBox(width: 8),
                Text(
                  'Harvest Outcome Comparison',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Final verified crop production metrics for completed batches.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ...result.harvestData.map((h) {
              final b = result.getBatch(h.batchId);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (b?.color ?? Colors.teal).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          b?.displayName ?? 'Batch',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AquaColors.statusOptimal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'HARVESTED @ DOC ${h.harvestDoc}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AquaColors.statusOptimal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('Harvest Weight', '${(h.harvestWeightKg / 1000).toStringAsFixed(2)} MT'),
                        _buildMiniStat('Final ABW', '${h.finalAbwGrams.toStringAsFixed(2)} g'),
                        _buildMiniStat('Survival', '${h.survivalPct.toStringAsFixed(1)}%'),
                        _buildMiniStat('Final FCR', h.actualFcr.toStringAsFixed(2)),
                      ],
                    ),
                    if (h.buyerName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Buyer: ${h.buyerName!} · ₹${h.salePricePerKg?.toStringAsFixed(0) ?? "N/A"}/kg',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── 8. FINANCIAL COMPARISON CARD ─────────────────────────────
  Widget _buildFinancialComparisonCard(ThemeData theme, BatchComparisonResult result) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Crop Financial Comparison',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Incurred operating costs vs total commercial revenues.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ...result.financialData.map((f) {
              final b = result.getBatch(f.batchId);
              final isProfitable = f.netProfit >= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (b?.color ?? Colors.teal).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b?.displayName ?? 'Batch', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${f.marginPct.toStringAsFixed(1)}% Margin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isProfitable ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('Total Cost', '₹${(f.totalCost / 100000).toStringAsFixed(2)} L'),
                        _buildMiniStat('Revenue', '₹${(f.totalRevenue / 100000).toStringAsFixed(2)} L'),
                        _buildMiniStat(
                          'Net Profit',
                          '₹${(f.netProfit / 100000).toStringAsFixed(2)} L',
                          valueColor: isProfitable ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── 9. PERFORMANCE SUMMARY CARD ──────────────────────────────
  Widget _buildPerformanceSummaryCard(ThemeData theme, BatchComparisonResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Transparent Performance Insights',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Objective metric-level findings without arbitrary overall composite scores.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
          ),
          const SizedBox(height: 12),
          ...result.performanceSummary.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer),
                        children: [
                          TextSpan(
                            text: '${entry.key}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: entry.value),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildChartLegend(List<BatchMetaItem> batches) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: batches.map((b) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: b.color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(b.displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppSettingsState settings, List<String> selectedIds) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows_rounded, size: 54, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Select at least 2 batches to compare',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose Active or Completed batches across any farm site to perform comparative biological and financial analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _showBatchPickerModal(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Select Batches'),
            ),
          ],
        ),
      ),
    );
  }

  // ── MODAL BATCH PICKER WITH DUPLICATE PREVENTION ────────────
  void _showBatchPickerModal(BuildContext context, {String? replacingBatchId, bool isAdding = false}) async {
    final db = ref.read(appDatabaseProvider);
    final batches = await db.select(db.batches).get();
    final ponds = await db.select(db.ponds).get();
    final pondMap = {for (final p in ponds) p.id: p};

    final currentlySelected = ref.read(selectedComparisonBatchIdsProvider);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isAdding ? 'Select 3rd Batch to Compare' : 'Choose Batch',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Active and Completed batches can be compared together.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = batches[i];
                      final pond = pondMap[b.pondId];
                      final isSelected = currentlySelected.contains(b.id);
                      final isSelf = replacingBatchId == b.id;
                      final isDuplicate = isSelected && !isSelf;

                      return ListTile(
                        enabled: !isDuplicate,
                        title: Text(
                          '${pond?.name ?? "Pond"} — Batch #${b.batchNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDuplicate ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          '${b.species} · ${b.status.toUpperCase()} · Stocked ${(b.shrimpStockedCount / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isDuplicate
                            ? const Chip(
                                label: Text('Already Selected', style: TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                              )
                            : Icon(
                                isSelf ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        onTap: isDuplicate
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                final list = List<String>.from(currentlySelected);
                                if (isAdding) {
                                  if (list.length < 3) list.add(b.id);
                                } else if (replacingBatchId != null) {
                                  final idx = list.indexOf(replacingBatchId);
                                  if (idx != -1) {
                                    list[idx] = b.id;
                                  } else {
                                    list.add(b.id);
                                  }
                                } else {
                                  if (!list.contains(b.id)) list.add(b.id);
                                }
                                ref.read(selectedComparisonBatchIdsProvider.notifier).state = list;
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
