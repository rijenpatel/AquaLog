import '../database/app_database.dart';
import '../calculations/water_quality_engine.dart';
import '../calculations/population_engine.dart';

class ActionGeneratorService {
  final AppDatabase db;

  const ActionGeneratorService(this.db);

  /// Scans active farm entities and synchronizes automated daily operational tasks
  Future<int> generateDailyTasks({String? siteId}) async {
    int generatedCount = 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // 1. Fetch active ponds and active batches
    final pondsQuery = db.select(db.ponds)..where((t) => t.status.equals('active'));
    if (siteId != null) pondsQuery.where((t) => t.siteId.equals(siteId));
    final activePonds = await pondsQuery.get();

    final activeTasks = await db.getActionTasks(status: 'pending');

    bool hasPendingTask(String category, {String? pondId, String? batchId}) {
      return activeTasks.any((t) =>
          t.category == category &&
          (pondId == null || t.pondId == pondId) &&
          (batchId == null || t.batchId == batchId));
    }

    for (final pond in activePonds) {
      final activeBatch = await db.getActiveBatchForPond(pond.id);

      // A. Water Quality Reading Due Check
      final latestWq = await db.getLatestWaterQualityLog(pond.id);
      final hasLoggedWqToday = latestWq != null &&
          latestWq.date.isAfter(todayStart);

      if (!hasLoggedWqToday && !hasPendingTask('water_quality', pondId: pond.id)) {
        await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
          id: 'task_wq_${pond.id}_${todayStart.millisecondsSinceEpoch}',
          siteId: Value(pond.siteId),
          pondId: Value(pond.id),
          batchId: activeBatch != null ? Value(activeBatch.id) : const Value.absent(),
          title: 'Measure Water Quality: ${pond.name}',
          description: const Value('Daily morning/evening DO, pH, and temperature check pending.'),
          category: 'water_quality',
          priority: const Value('normal'),
          dueDate: Value(now.add(const Duration(hours: 4))),
          source: const Value('system'),
        ));
        generatedCount++;
      }

      // B. Water Quality Warning / Critical Alerts
      if (latestWq != null) {
        final wqAlerts = WaterQualityEngine.detectRiskAlerts([latestWq]);
        for (final alert in wqAlerts) {
          final isCritical = alert.severity == WqStatus.critical;
          final taskKey = 'wq_alert_${pond.id}_${alert.title.hashCode}';
          final alreadyExists = activeTasks.any((t) => t.id == taskKey);

          if (!alreadyExists) {
            await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
              id: taskKey,
              siteId: Value(pond.siteId),
              pondId: Value(pond.id),
              batchId: activeBatch != null ? Value(activeBatch.id) : const Value.absent(),
              title: '${pond.name}: ${alert.title}',
              description: Value('${alert.message}\nWhy: ${alert.why}\nRecommended: ${alert.recommendation}'),
              category: 'water_quality',
              priority: Value(isCritical ? 'critical' : 'high'),
              dueDate: Value(now.add(isCritical ? const Duration(hours: 1) : const Duration(hours: 3))),
              source: const Value('system'),
            ));
            generatedCount++;
          }
        }
      }

      // C. Active Batch Checks
      if (activeBatch != null) {
        final samplings = await db.getSamplingsForBatch(activeBatch.id);
        final latestSampling = samplings.isNotEmpty ? samplings.last : null;

        // Sampling Due Check (> 10 days since stocking or last sampling)
        final lastSampleDate = latestSampling?.date ?? activeBatch.stockingDate;
        final daysSinceLastSample = now.difference(lastSampleDate).inDays;

        if (daysSinceLastSample >= 10 && !hasPendingTask('sampling', batchId: activeBatch.id)) {
          final isOverdue = daysSinceLastSample >= 14;
          await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
            id: 'task_smp_${activeBatch.id}_${todayStart.millisecondsSinceEpoch}',
            siteId: Value(pond.siteId),
            pondId: Value(pond.id),
            batchId: Value(activeBatch.id),
            title: '${pond.name}: Cast-Net Sampling ${isOverdue ? "Overdue" : "Due"}',
            description: Value('Last sampled $daysSinceLastSample days ago. Recalibration of ABW, ADG, and FCR required.'),
            category: 'sampling',
            priority: Value(isOverdue ? 'high' : 'normal'),
            dueDate: Value(now.add(const Duration(days: 1))),
            source: const Value('system'),
          ));
          generatedCount++;
        }

        // Mortality Spike Check
        final mortalities = await db.getMortalityRecordsForBatch(activeBatch.id);
        final mortAlerts = PopulationEngine.detectMortalityAlerts(
          mortalityRecords: mortalities,
          currentPopulation: activeBatch.shrimpStockedCount,
          latestDO: latestWq?.dissolvedOxygen,
        );

        for (final mAlert in mortAlerts) {
          final taskKey = 'mort_alert_${activeBatch.id}_${mAlert.title.hashCode}';
          if (!activeTasks.any((t) => t.id == taskKey)) {
            await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
              id: taskKey,
              siteId: Value(pond.siteId),
              pondId: Value(pond.id),
              batchId: Value(activeBatch.id),
              title: '${pond.name}: ${mAlert.title}',
              description: Value('${mAlert.message}\nWhy: ${mAlert.why}\nRecommended: ${mAlert.recommendation}'),
              category: 'mortality',
              priority: Value(mAlert.severity == 'critical' ? 'critical' : 'high'),
              dueDate: Value(now.add(const Duration(hours: 2))),
              source: const Value('system'),
            ));
            generatedCount++;
          }
        }

        // Daily Feed Plan Pending Confirmation Check
        final todayFeedPlan = await db.getDailyFeedPlanForDate(pond.id, now);
        if (todayFeedPlan != null && todayFeedPlan.status == 'pending' && !hasPendingTask('feed', pondId: pond.id)) {
          await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
            id: 'task_fp_${pond.id}_${todayStart.millisecondsSinceEpoch}',
            siteId: Value(pond.siteId),
            pondId: Value(pond.id),
            batchId: Value(activeBatch.id),
            title: '${pond.name}: Confirm Daily Feed Plan (${todayFeedPlan.recommendedFeedKg.toStringAsFixed(1)} kg)',
            description: Value('Suggested ration is ${todayFeedPlan.recommendedFeedKg.toStringAsFixed(1)} kg. Review adjustments for tray & water quality.'),
            category: 'feed',
            priority: const Value('normal'),
            dueDate: Value(now.add(const Duration(hours: 3))),
            source: const Value('system'),
          ));
          generatedCount++;
        }
      }
    }

    // D. Low Inventory Check
    final lowStockItems = await (db.select(db.inventoryItems)
          ..where((t) => t.currentStock.isSmallerOrEqual(t.lowStockThreshold)))
        .get();

    for (final item in lowStockItems) {
      final taskKey = 'inv_low_${item.id}_${todayStart.millisecondsSinceEpoch}';
      if (!activeTasks.any((t) => t.id == taskKey)) {
        await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
          id: taskKey,
          siteId: item.siteId != null ? Value(item.siteId) : const Value.absent(),
          title: 'Reorder Low Stock: ${item.name}',
          description: Value('Current stock (${item.currentStock.toStringAsFixed(1)} ${item.unit}) reached threshold (${item.lowStockThreshold.toStringAsFixed(1)} ${item.unit}).'),
          category: 'inventory',
          priority: const Value('high'),
          dueDate: Value(now.add(const Duration(days: 2))),
          source: const Value('system'),
        ));
        generatedCount++;
      }
    }

    return generatedCount;
  }
}
