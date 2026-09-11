import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/calculations/feed_calculator.dart';
import '../../core/widgets/aqua_tray_badge.dart';
import '../feed/feed_logging_page.dart';
import '../comparison/batch_comparison_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Daily tab state
  DateTime _dailySelectedDate = DateTime.now();

  // Weekly tab state
  late DateTime _weeklyStartDate;

  // Monthly tab state
  late int _monthlyYear;
  late int _monthlyMonth;

  // Analytics tab state
  String _analyticsMode = 'By Feed'; // 'By Feed', 'By Pond', 'By Phase', 'By DOC'

  // History tab state
  String _historyQuery = '';
  String? _historySelectedPondId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final now = DateTime.now();
    _dailySelectedDate = DateTime(now.year, now.month, now.day);
    _weeklyStartDate = _dailySelectedDate.subtract(const Duration(days: 6));
    _monthlyYear = now.year;
    _monthlyMonth = now.month;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exportHistoryCsv(List<FeedRecord> records, Map<String, String> pondNames) {
    final rows = <List<dynamic>>[];
    rows.add([
      'Date',
      'Time Slot',
      'Pond',
      'Batch ID',
      'Feed Name',
      'Brand',
      'Pellet Size',
      'Quantity (kg)',
      'Total Session Kg',
      'Tray Leftover %',
      'Notes',
    ]);

    for (final r in records) {
      final items = FeedCalculator.getRecordItems(r);
      final pondLabel = pondNames[r.pondId] ?? r.pondId;
      final sessionTotal = FeedCalculator.getRecordTotalKg(r);

      if (items.isNotEmpty) {
        for (final item in items) {
          rows.add([
            DateFormat('yyyy-MM-dd').format(r.date),
            r.timeSlot,
            pondLabel,
            r.batchId,
            item.feedName,
            item.brand ?? '',
            item.size ?? '',
            item.quantityKg.toStringAsFixed(2),
            sessionTotal.toStringAsFixed(2),
            r.trayChecked ? '${r.trayLeftoverPct}%' : 'N/A',
            r.notes ?? '',
          ]);
        }
      } else {
        rows.add([
          DateFormat('yyyy-MM-dd').format(r.date),
          r.timeSlot,
          pondLabel,
          r.batchId,
          r.otherFeedName ?? 'Standard Feed',
          '',
          '',
          sessionTotal.toStringAsFixed(2),
          sessionTotal.toStringAsFixed(2),
          r.trayChecked ? '${r.trayLeftoverPct}%' : 'N/A',
          r.notes ?? '',
        ]);
      }
    }

    final csvString = const ListToCsvConverter().convert(rows);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Exported ${rows.length - 1} feed entries (${csvString.length} bytes) to CSV!'),
        backgroundColor: const Color(0xFF006876),
      ),
    );
  }

  Future<void> _confirmDeleteFeed(FeedRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feed Session?'),
        content: Text(
          'This will permanently delete this feed log (${record.timeSlot} · ${FeedCalculator.getRecordTotalKg(record).toStringAsFixed(1)} kg) and restore the deducted stock to Feed Inventory.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete & Restore Stock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(appDatabaseProvider);
      await db.deleteFeedRecordWithRollback(record.id);
      ref.invalidate(feedRecordsStreamProvider);
      ref.invalidate(allInventoryItemsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Feed session deleted & inventory stock restored.'),
            backgroundColor: Color(0xFF006876),
          ),
        );
      }
    }
  }

  void _editFeed(FeedRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedLoggingPage(
          editRecord: record,
          onFeedLogged: () => ref.invalidate(feedRecordsStreamProvider),
        ),
      ),
    );
  }

  void _showFeedDetailModal(
    FeedRecord r,
    ThemeData theme,
    Map<String, String> pondNames,
    List<Batch> batches,
  ) {
    final items = FeedCalculator.getRecordItems(r);
    final totalKg = FeedCalculator.getRecordTotalKg(r);
    final pondLabel = pondNames[r.pondId] ?? r.pondId;
    final batch = batches.where((b) => b.id == r.batchId).firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006876).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.timeSlot,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF006876)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, dd MMM yyyy').format(r.date),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pond: $pondLabel${batch != null ? " · Batch #${batch.batchNumber} (${batch.species})" : ""}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Total Session Feed KPI Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF006876).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF006876).withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL SESSION CONSUMPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF006876))),
                        const SizedBox(height: 4),
                        Text(
                          '${totalKg.toStringAsFixed(2)} kg',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${items.length} Product${items.length > 1 ? "s" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Feed Products Breakdown List
              Text(
                'Itemized Feeds Fed',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...items.map((it) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.feedName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            '${it.brand ?? "Brand"} · ${it.size ?? "Pellet"}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Text(
                        '${it.quantityKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF006876)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Tray Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: r.trayChecked ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: r.trayChecked ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(r.trayChecked ? Icons.fact_check_rounded : Icons.info_outline_rounded,
                        color: r.trayChecked ? Colors.green : Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.trayChecked
                            ? 'Check Tray Inspected: ${r.trayLeftoverPct}% feed remaining'
                            : 'Check tray inspection was not recorded for this session',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              if (r.notes != null && r.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(r.notes!, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
              ],

              const SizedBox(height: 20),
              // Action Buttons: Edit and Delete
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      label: const Text('Delete Log', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmDeleteFeed(r);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Session'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF006876)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _editFeed(r);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final recordsAsync = ref.watch(feedRecordsStreamProvider);
    final pondsAsync = ref.watch(allPondsStreamProvider);
    final batchesAsync = ref.watch(activeBatchesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.tr('reports_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Batch Comparison',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BatchComparisonPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Analytics'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: recordsAsync.when(
        data: (records) {
          final ponds = pondsAsync.valueOrNull ?? [];
          final batches = batchesAsync.valueOrNull ?? [];
          final pondNames = {for (final p in ponds) p.id: p.name};

          return TabBarView(
            controller: _tabController,
            children: [
              // 1. Daily Tab
              _buildDailyTab(records, theme, pondNames, batches),

              // 2. Weekly Tab
              _buildWeeklyTab(records, theme, pondNames),

              // 3. Monthly Tab
              _buildMonthlyTab(records, theme, pondNames),

              // 4. Analytics Tab (By Feed Type, By Pond, By Phase, By DOC)
              _buildAnalyticsTab(records, theme, pondNames, batches),

              // 5. History Tab
              _buildHistoryTab(records, theme, pondNames, batches),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load records: $e')),
      ),
    );
  }

  // ── DAILY REPORT ───────────────────────────────────────────────

  Widget _buildDailyTab(List<FeedRecord> records, ThemeData theme, Map<String, String> pondNames, List<Batch> batches) {
    final dailyData = FeedCalculator.getDailyFeedTotals(records, _dailySelectedDate);
    final totalKg = (dailyData['totalKg'] as num).toDouble();
    final sessionCount = dailyData['sessionCount'] as int;
    final pondsFedCount = dailyData['pondsFedCount'] as int;
    final dayRecords = dailyData['records'] as List<FeedRecord>;
    final byPond = dailyData['byPond'] as Map<String, double>;
    final byPondSessions = dailyData['byPondSessions'] as Map<String, int>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date Navigator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _dailySelectedDate = _dailySelectedDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dailySelectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 180)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dailySelectedDate = picked);
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF006876)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMM yyyy').format(_dailySelectedDate),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _dailySelectedDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                    ? () {
                        setState(() {
                          _dailySelectedDate = _dailySelectedDate.add(const Duration(days: 1));
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // KPI Summary Strip
        Row(
          children: [
            Expanded(
              child: _buildKpiBox(theme, 'Total Feed', '${totalKg.toStringAsFixed(1)} kg', Icons.scale_rounded, const Color(0xFF006876)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiBox(theme, 'Sessions', '$sessionCount', Icons.alarm_rounded, Colors.teal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiBox(theme, 'Ponds Fed', '$pondsFedCount', Icons.water_rounded, Colors.indigo),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // By Pond Breakdown
        if (byPond.isNotEmpty) ...[
          Text('Daily Consumption by Pond', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            ),
            child: Column(
              children: byPond.entries.map((entry) {
                final pondId = entry.key;
                final pondKg = entry.value;
                final pondPct = totalKg > 0 ? (pondKg / totalKg) : 0.0;
                final pondName = pondNames[pondId] ?? pondId;
                final sessions = byPondSessions[pondId] ?? 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$pondName ($sessions session${sessions > 1 ? "s" : ""})', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${pondKg.toStringAsFixed(1)} kg (${(pondPct * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pondPct,
                          minHeight: 6,
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006876)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Feed Sessions List
        Text('Feeding Sessions (${dayRecords.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        if (dayRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No feed recorded for ${DateFormat('dd MMM yyyy').format(_dailySelectedDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...dayRecords.map((r) => _buildSessionCard(r, theme, pondNames, batches)),
      ],
    );
  }

  Widget _buildSessionCard(
    FeedRecord r,
    ThemeData theme,
    Map<String, String> pondNames,
    List<Batch> batches,
  ) {
    final items = FeedCalculator.getRecordItems(r);
    final totalKg = FeedCalculator.getRecordTotalKg(r);
    final pondLabel = pondNames[r.pondId] ?? r.pondId;

    return InkWell(
      onTap: () => _showFeedDetailModal(r, theme, pondNames, batches),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006876).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.timeSlot,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF006876)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(pondLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${totalKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF006876)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      onSelected: (val) {
                        if (val == 'edit') _editFeed(r);
                        if (val == 'delete') _confirmDeleteFeed(r);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),

            // Dynamic Feed Items Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((it) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        it.size != null && it.size!.isNotEmpty ? '${it.feedName} (${it.size})' : it.feedName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${it.quantityKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            if (r.trayChecked) ...[
              const SizedBox(height: 8),
              AquaTrayBadge(leftoverPct: r.trayLeftoverPct, compact: true),
            ],

            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.notes!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  // ── WEEKLY REPORT ──────────────────────────────────────────────

  Widget _buildWeeklyTab(List<FeedRecord> records, ThemeData theme, Map<String, String> pondNames) {
    final weeklyData = FeedCalculator.getWeeklyFeedTotals(records, _weeklyStartDate);
    final totalKg = (weeklyData['totalKg'] as num).toDouble();
    final avgPerDay = (weeklyData['avgPerDay'] as num).toDouble();
    final sessionCount = weeklyData['sessionCount'] as int;
    final dailyTotals = weeklyData['dailyTotals'] as Map<DateTime, double>;
    final dailyRecords = weeklyData['dailyRecords'] as Map<DateTime, List<FeedRecord>>;
    final weekRecords = weeklyData['records'] as List<FeedRecord>;

    final weekEndDate = _weeklyStartDate.add(const Duration(days: 6));
    final byFeed = FeedCalculator.getFeedDistributionByType(weekRecords);
    final byPond = FeedCalculator.getFeedDistributionByPond(weekRecords, pondNames);

    // Compute max for chart scaling
    double maxDayKg = dailyTotals.values.fold(0.0, (m, v) => v > m ? v : m);
    if (maxDayKg <= 0) maxDayKg = 30.0;
    final chartMaxY = (maxDayKg * 1.25).clamp(10.0, 500.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Week Navigator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _weeklyStartDate = _weeklyStartDate.subtract(const Duration(days: 7));
                  });
                },
              ),
              Text(
                '${DateFormat('dd MMM').format(_weeklyStartDate)} – ${DateFormat('dd MMM yyyy').format(weekEndDate)}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _weeklyStartDate = _weeklyStartDate.add(const Duration(days: 7));
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Weekly KPIs
        Row(
          children: [
            Expanded(child: _buildKpiBox(theme, '7-Day Total', '${totalKg.toStringAsFixed(1)} kg', Icons.scale_rounded, const Color(0xFF006876))),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiBox(theme, 'Daily Average', '${avgPerDay.toStringAsFixed(1)} kg', Icons.auto_graph_rounded, Colors.teal)),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiBox(theme, 'Sessions', '$sessionCount', Icons.alarm_rounded, Colors.indigo)),
          ],
        ),
        const SizedBox(height: 16),

        // Daily Feed Bar Chart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Feed Trajectory', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text('Tap bar to drill down', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                      return;
                    }
                    if (event is FlTapUpEvent) {
                      final dayIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                      final clickedDay = _weeklyStartDate.add(Duration(days: dayIndex));
                      final dayRecs = dailyRecords[clickedDay] ?? [];
                      _showDayDrilldownSheet(clickedDay, dayRecs, pondNames);
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) => Text('${val.toInt()}k', style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < 7) {
                          final day = _weeklyStartDate.add(Duration(days: idx));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('E\nd').format(day), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barGroups: List.generate(7, (i) {
                  final day = _weeklyStartDate.add(Duration(days: i));
                  final dayKg = dailyTotals[day] ?? 0.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dayKg,
                        color: const Color(0xFF006876),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // By Feed Type Breakdown (Dynamic Inventory Products)
        if (byFeed.isNotEmpty) ...[
          Text('Feed Consumed by Product', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildBreakdownCard(theme, byFeed, totalKg),
          const SizedBox(height: 16),
        ],

        // By Pond Breakdown
        if (byPond.isNotEmpty) ...[
          Text('Feed Consumed by Basin', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildBreakdownCard(theme, byPond, totalKg),
        ],
      ],
    );
  }

  void _showDayDrilldownSheet(DateTime day, List<FeedRecord> dayRecords, Map<String, String> pondNames) {
    final dayTotalKg = dayRecords.fold<double>(0.0, (s, r) => s + FeedCalculator.getRecordTotalKg(r));
    final byType = FeedCalculator.getFeedDistributionByType(dayRecords);
    final uniquePonds = dayRecords.map((r) => r.pondId).toSet().length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(day),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${dayRecords.length} sessions · $uniquePonds ponds fed',
                      style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Text(
                  '${dayTotalKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF006876)),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Feed Product Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (byType.isEmpty)
              const Text('No feed recorded on this date.')
            else
              ...byType.entries.map((e) {
                final pct = dayTotalKg > 0 ? (e.value / dayTotalKg) * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${e.value.toStringAsFixed(1)} kg (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MONTHLY REPORT ─────────────────────────────────────────────

  Widget _buildMonthlyTab(List<FeedRecord> records, ThemeData theme, Map<String, String> pondNames) {
    final monthlyData = FeedCalculator.getMonthlyFeedTotals(records, _monthlyYear, _monthlyMonth);
    final totalKg = (monthlyData['totalKg'] as num).toDouble();
    final avgPerDay = (monthlyData['avgPerDay'] as num).toDouble();
    final activePonds = monthlyData['activePonds'] as int;
    final prevTotalKg = (monthlyData['prevTotalKg'] as num).toDouble();
    final changePct = (monthlyData['changePct'] as num).toDouble();
    final weeklyPeriods = monthlyData['weeklyPeriods'] as Map<String, double>;
    final monthRecords = monthlyData['records'] as List<FeedRecord>;

    final byPond = FeedCalculator.getFeedDistributionByPond(monthRecords, pondNames);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Month Navigator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    if (_monthlyMonth == 1) {
                      _monthlyMonth = 12;
                      _monthlyYear -= 1;
                    } else {
                      _monthlyMonth -= 1;
                    }
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(DateTime(_monthlyYear, _monthlyMonth)),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    if (_monthlyMonth == 12) {
                      _monthlyMonth = 1;
                      _monthlyYear += 1;
                    } else {
                      _monthlyMonth += 1;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Monthly KPIs
        Row(
          children: [
            Expanded(child: _buildKpiBox(theme, 'Monthly Total', '${totalKg.toStringAsFixed(1)} kg', Icons.scale_rounded, const Color(0xFF006876))),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiBox(theme, 'Daily Avg', '${avgPerDay.toStringAsFixed(1)} kg', Icons.auto_graph_rounded, Colors.teal)),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiBox(theme, 'Active Ponds', '$activePonds', Icons.water_rounded, Colors.indigo)),
          ],
        ),
        const SizedBox(height: 14),

        // Month-over-Month Comparison Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('vs Previous Month (${prevTotalKg.toStringAsFixed(1)} kg)', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    changePct >= 0
                        ? '+${changePct.toStringAsFixed(1)}% Feed Consumption'
                        : '${changePct.toStringAsFixed(1)}% Feed Consumption',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: changePct >= 0 ? Colors.orange[800] : Colors.blue[800],
                    ),
                  ),
                ],
              ),
              Icon(
                changePct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: changePct >= 0 ? Colors.orange : Colors.blue,
                size: 28,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Weekly Periods Bar Chart
        Text('Weekly Feed Totals', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) => Text('${val.toInt()}k', style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        final keys = weeklyPeriods.keys.toList();
                        if (idx >= 0 && idx < keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(keys[idx], style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barGroups: weeklyPeriods.entries.toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final kg = entry.value.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: kg,
                        color: const Color(0xFF006876),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // By Pond Breakdown
        if (byPond.isNotEmpty) ...[
          Text('Monthly Consumption by Basin', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildBreakdownCard(theme, byPond, totalKg),
        ],
      ],
    );
  }

  // ── ANALYTICS TAB (By Feed, By Pond, By Phase, By DOC) ──────────

  Widget _buildAnalyticsTab(
    List<FeedRecord> records,
    ThemeData theme,
    Map<String, String> pondNames,
    List<Batch> batches,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mode Selector Chips
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'By Feed', label: Text('Product')),
            ButtonSegment(value: 'By Pond', label: Text('Basin')),
            ButtonSegment(value: 'By Phase', label: Text('Phase')),
            ButtonSegment(value: 'By DOC', label: Text('DOC Chart')),
          ],
          selected: {_analyticsMode},
          onSelectionChanged: (set) => setState(() => _analyticsMode = set.first),
        ),
        const SizedBox(height: 16),

        if (_analyticsMode == 'By Feed') ...[
          _buildFeedTypeDonut(records, theme),
        ] else if (_analyticsMode == 'By Pond') ...[
          _buildPondDonut(records, theme, pondNames),
        ] else if (_analyticsMode == 'By Phase') ...[
          _buildPhaseAnalytics(records, theme, batches),
        ] else ...[
          _buildFeedByDocChart(records, theme, batches, pondNames),
        ],
      ],
    );
  }

  Widget _buildFeedTypeDonut(List<FeedRecord> records, ThemeData theme) {
    final distribution = FeedCalculator.getFeedDistributionByType(records);
    final totalKg = distribution.values.fold(0.0, (s, v) => s + v);

    if (totalKg <= 0) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No feeding records available for analysis.')));
    }

    final colors = [
      const Color(0xFF006876),
      Colors.teal,
      Colors.indigo,
      Colors.amber[800]!,
      Colors.deepOrange,
      Colors.purple,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feed Product Distribution', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: distribution.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final pct = (item.value / totalKg) * 100;
                      return PieChartSectionData(
                        color: colors[idx % colors.length],
                        value: item.value,
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: 36,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 24),
              ...distribution.entries.toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final pct = (item.value / totalKg) * 100;
                final c = colors[idx % colors.length];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${item.value.toStringAsFixed(1)} kg (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPondDonut(List<FeedRecord> records, ThemeData theme, Map<String, String> pondNames) {
    final distribution = FeedCalculator.getFeedDistributionByPond(records, pondNames);
    final totalKg = distribution.values.fold(0.0, (s, v) => s + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cultivation Basin Allocation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildBreakdownCard(theme, distribution, totalKg),
      ],
    );
  }

  Widget _buildPhaseAnalytics(List<FeedRecord> records, ThemeData theme, List<Batch> batches) {
    DateTime? stockingDate;
    if (batches.isNotEmpty) {
      stockingDate = batches.first.stockingDate;
    }

    final distribution = FeedCalculator.getFeedDistributionByPhase(records, stockingDate);
    final totalKg = distribution.values.fold(0.0, (s, v) => s + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feed Consumed by Crop Phase', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Starter (DOC 1–10) · Grower (DOC 11–20) · Finisher (DOC 21+)', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 12),
        _buildBreakdownCard(theme, distribution, totalKg),
      ],
    );
  }

  Widget _buildFeedByDocChart(
    List<FeedRecord> records,
    ThemeData theme,
    List<Batch> batches,
    Map<String, String> pondNames,
  ) {
    DateTime stockingDate = DateTime.now().subtract(const Duration(days: 30));
    if (batches.isNotEmpty) {
      stockingDate = batches.first.stockingDate;
    }

    final docMap = FeedCalculator.getFeedByDoc(records, stockingDate);
    final sortedDocs = docMap.keys.toList()..sort();

    if (sortedDocs.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No DOC feed logs available.')));
    }

    final maxKg = docMap.values.fold(0.0, (m, v) => v > m ? v : m);
    final maxY = (maxKg * 1.25).clamp(10.0, 500.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Feed Consumed by DOC', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text('Tap bar to drill down', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent && response?.spot != null) {
                      final idx = response!.spot!.touchedBarGroupIndex;
                      if (idx >= 0 && idx < sortedDocs.length) {
                        final clickedDoc = sortedDocs[idx];
                        final targetDate = stockingDate.add(Duration(days: clickedDoc - 1));
                        final dayRecs = FeedCalculator.getFeedRecordsByDate(records, targetDate);
                        _showDocDrilldownSheet(clickedDoc, targetDate, dayRecs, pondNames);
                      }
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) => Text('${val.toInt()}k', style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < sortedDocs.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('D${sortedDocs[idx]}', style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barGroups: sortedDocs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final doc = entry.value;
                  final kg = docMap[doc] ?? 0.0;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: kg,
                        color: const Color(0xFF006876),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDocDrilldownSheet(int doc, DateTime date, List<FeedRecord> records, Map<String, String> pondNames) {
    final totalKg = records.fold<double>(0.0, (s, r) => s + FeedCalculator.getRecordTotalKg(r));
    final byType = FeedCalculator.getFeedDistributionByType(records);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DOC $doc Feed Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(DateFormat('EEEE, dd MMM yyyy').format(date), style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ],
                ),
                Text('${totalKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF006876))),
              ],
            ),
            const Divider(height: 24),
            const Text('Feed Type Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (byType.isEmpty)
              const Text('No feed breakdown records available.')
            else
              ...byType.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${e.value.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  // ── HISTORY TAB ────────────────────────────────────────────────

  Widget _buildHistoryTab(List<FeedRecord> records, ThemeData theme, Map<String, String> pondNames, List<Batch> batches) {
    final filtered = records.where((r) {
      if (_historySelectedPondId != null && r.pondId != _historySelectedPondId) return false;
      if (_historyQuery.isEmpty) return true;

      final q = _historyQuery.toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      final pondName = (pondNames[r.pondId] ?? '').toLowerCase();
      final notes = (r.notes ?? '').toLowerCase();
      final timeSlot = r.timeSlot.toLowerCase();

      // Check feed item names
      final items = FeedCalculator.getRecordItems(r);
      final feedNames = items.map((i) => '${i.feedName} ${i.brand ?? ""} ${i.size ?? ""}').join(' ').toLowerCase();

      return dateStr.contains(q) || timeSlot.contains(q) || pondName.contains(q) || notes.contains(q) || feedNames.contains(q);
    }).toList();

    return Column(
      children: [
        // Search & Pond Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by feed, pond, date...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _historyQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _exportHistoryCsv(filtered, pondNames),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('CSV'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006876),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Pond Filter Chips
        if (pondNames.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All Ponds'),
                    selected: _historySelectedPondId == null,
                    onSelected: (_) => setState(() => _historySelectedPondId = null),
                  ),
                ),
                ...pondNames.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(e.value),
                      selected: _historySelectedPondId == e.key,
                      onSelected: (val) => setState(() => _historySelectedPondId = val ? e.key : null),
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Filtered Records List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No historical feed records match your filter.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final r = filtered[idx];
                    return _buildSessionCard(r, theme, pondNames, batches);
                  },
                ),
        ),
      ],
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────

  Widget _buildKpiBox(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(ThemeData theme, Map<String, double> items, double totalKg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        children: items.entries.map((entry) {
          final label = entry.key;
          final kg = entry.value;
          final pct = totalKg > 0 ? (kg / totalKg) : 0.0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${kg.toStringAsFixed(1)} kg (${(pct * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006876)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
