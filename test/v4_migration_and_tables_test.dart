import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase A: Schema v4 and Database Entities', () {
    test('Schema version is 4', () {
      expect(db.schemaVersion, equals(4));
    });

    test('Can insert and query WaterQualityLog', () async {
      // 1. Create site and pond
      await db.into(db.farmSites).insert(FarmSitesCompanion.insert(
            id: 'site_1',
            name: 'Coastal Farm',
          ));
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 01',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
            siteId: const drift.Value('site_1'),
          ));

      // 2. Insert WQ Log
      final wqId = 'wq_1';
      final now = DateTime.now();
      await db.saveWaterQualityLog(WaterQualityLogsCompanion.insert(
        id: wqId,
        pondId: 'pond_1',
        siteId: const drift.Value('site_1'),
        date: now,
        timeSlot: const drift.Value('Morning'),
        temperature: const drift.Value(29.5),
        ph: const drift.Value(7.8),
        dissolvedOxygen: const drift.Value(5.2),
        salinity: const drift.Value(15.0),
        ammonia: const drift.Value(0.02),
        nitrite: const drift.Value(0.04),
        alkalinity: const drift.Value(120.0),
        transparencyCm: const drift.Value(35.0),
      ));

      final logs = await db.getWaterQualityLogsForPond('pond_1');
      expect(logs.length, equals(1));
      expect(logs.first.id, equals(wqId));
      expect(logs.first.ph, equals(7.8));
      expect(logs.first.dissolvedOxygen, equals(5.2));
      expect(logs.first.timeSlot, equals('Morning'));

      final latest = await db.getLatestWaterQualityLog('pond_1');
      expect(latest, isNotNull);
      expect(latest!.id, equals(wqId));
    });

    test('Can insert and query MortalityRecords and calculate cumulative mortality', () async {
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 01',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
          ));
      await db.into(db.batches).insert(BatchesCompanion.insert(
            id: 'batch_1',
            pondId: 'pond_1',
            batchNumber: 1,
            stockingDate: DateTime.now().subtract(const Duration(days: 30)),
            shrimpStockedCount: 100000,
          ));

      // Insert two mortality records
      await db.saveMortalityRecord(MortalityRecordsCompanion.insert(
        id: 'mort_1',
        pondId: 'pond_1',
        batchId: 'batch_1',
        date: DateTime.now().subtract(const Duration(days: 2)),
        countObserved: const drift.Value(45),
        countEstimated: const drift.Value(50),
        reason: const drift.Value('normal'),
      ));

      await db.saveMortalityRecord(MortalityRecordsCompanion.insert(
        id: 'mort_2',
        pondId: 'pond_1',
        batchId: 'batch_1',
        date: DateTime.now().subtract(const Duration(days: 1)),
        countObserved: const drift.Value(60),
        countEstimated: const drift.Value(70),
        reason: const drift.Value('stress'),
      ));

      final mortalities = await db.getMortalityRecordsForBatch('batch_1');
      expect(mortalities.length, equals(2));

      final cumulative = await db.getCumulativeMortalityForBatch('batch_1');
      // 45 + 50 + 60 + 70 = 225
      expect(cumulative, equals(225));
    });

    test('Can insert and query PopulationAdjustment', () async {
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 01',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
          ));
      await db.into(db.batches).insert(BatchesCompanion.insert(
            id: 'batch_1',
            pondId: 'pond_1',
            batchNumber: 1,
            stockingDate: DateTime.now().subtract(const Duration(days: 30)),
            shrimpStockedCount: 100000,
          ));

      await db.savePopulationAdjustment(PopulationAdjustmentsCompanion.insert(
        id: 'adj_1',
        batchId: 'batch_1',
        date: DateTime.now(),
        adjustedCount: 95000,
        previousCount: 98000,
        differenceCount: -3000,
        reason: 'sampling_correction',
        notes: const drift.Value('Reconciliation after cast-net sample'),
      ));

      final adjustments = await db.getPopulationAdjustmentsForBatch('batch_1');
      expect(adjustments.length, equals(1));
      expect(adjustments.first.differenceCount, equals(-3000));
      expect(adjustments.first.reason, equals('sampling_correction'));
    });

    test('Can insert and query PondOperations', () async {
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 01',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
          ));

      await db.savePondOperation(PondOperationsCompanion.insert(
        id: 'op_1',
        pondId: 'pond_1',
        date: DateTime.now(),
        operationType: 'exchange',
        volumeLiters: 500000.0,
        percentageExchanged: const drift.Value(10.0),
        reason: const drift.Value('High ammonia level management'),
        source: const drift.Value('canal'),
        pumpEquipment: const drift.Value('Pump 5HP A'),
      ));

      final ops = await db.getPondOperationsForPond('pond_1');
      expect(ops.length, equals(1));
      expect(ops.first.volumeLiters, equals(500000.0));
      expect(ops.first.percentageExchanged, equals(10.0));
      expect(ops.first.operationType, equals('exchange'));
    });

    test('Can insert, update status, and query FarmActionTasks', () async {
      await db.saveFarmActionTask(FarmActionTasksCompanion.insert(
        id: 'task_1',
        title: 'Check DO in Pond 01',
        category: 'water_quality',
        description: const drift.Value('DO dropped below 4.0 mg/L'),
        priority: const drift.Value('critical'),
      ));

      final pendingTasks = await db.getActionTasks(status: 'pending');
      expect(pendingTasks.length, equals(1));
      expect(pendingTasks.first.priority, equals('critical'));

      // Update to completed
      await db.updateFarmActionTaskStatus('task_1', 'completed', resolutionNotes: 'Aeration increased');

      final completedTasks = await db.getActionTasks(status: 'completed');
      expect(completedTasks.length, equals(1));
      expect(completedTasks.first.completedAt, isNotNull);
      expect(completedTasks.first.resolutionNotes, equals('Aeration increased'));
    });

    test('Can insert and query DailyFeedPlans', () async {
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 01',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
          ));
      await db.into(db.batches).insert(BatchesCompanion.insert(
            id: 'batch_1',
            pondId: 'pond_1',
            batchNumber: 1,
            stockingDate: DateTime.now().subtract(const Duration(days: 30)),
            shrimpStockedCount: 100000,
          ));

      final today = DateTime.now();
      await db.saveDailyFeedPlan(DailyFeedPlansCompanion.insert(
        id: 'fp_1',
        pondId: 'pond_1',
        batchId: 'batch_1',
        date: today,
        baseFeedKg: 50.0,
        trayAdjustmentKg: const drift.Value(-3.0),
        weatherAdjustmentKg: const drift.Value(-2.0),
        wqAdjustmentKg: const drift.Value(0.0),
        recommendedFeedKg: 45.0,
        actualPlannedKg: 45.0,
      ));

      final plan = await db.getDailyFeedPlanForDate('pond_1', today);
      expect(plan, isNotNull);
      expect(plan!.recommendedFeedKg, equals(45.0));
      expect(plan.baseFeedKg, equals(50.0));
      expect(plan.trayAdjustmentKg, equals(-3.0));

      // Modify plan
      await db.updateDailyFeedPlanStatus(
        'fp_1',
        'modified',
        actualPlannedKg: 48.0,
        reason: 'Good appetite observed',
      );

      final updatedPlan = await db.getDailyFeedPlanForDate('pond_1', today);
      expect(updatedPlan!.status, equals('modified'));
      expect(updatedPlan.actualPlannedKg, equals(48.0));
      expect(updatedPlan.recommendedFeedKg, equals(45.0)); // Recommended preserved
      expect(updatedPlan.adjustmentReason, equals('Good appetite observed'));
    });

    test('Delete safety checks prevent deleting pond or batch with linked v4 records', () async {
      await db.into(db.farmSites).insert(FarmSitesCompanion.insert(
            id: 'site_1',
            name: 'Site 1',
          ));
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 1',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
            siteId: const drift.Value('site_1'),
          ));
      await db.into(db.batches).insert(BatchesCompanion.insert(
            id: 'batch_1',
            pondId: 'pond_1',
            batchNumber: 1,
            stockingDate: DateTime.now().subtract(const Duration(days: 10)),
            shrimpStockedCount: 50000,
          ));

      // Link a WQ log to pond_1
      await db.saveWaterQualityLog(WaterQualityLogsCompanion.insert(
        id: 'wq_1',
        pondId: 'pond_1',
        batchId: const drift.Value('batch_1'),
        date: DateTime.now(),
      ));

      // Safety checks should block deletion
      final pondCheck = await db.canDeletePond('pond_1');
      expect(pondCheck.canDelete, isFalse);
      expect(pondCheck.linkedWaterLogs, equals(1));

      final batchCheck = await db.canDeleteBatch('batch_1');
      expect(batchCheck.canDelete, isFalse);
      expect(batchCheck.linkedWaterLogs, equals(1));

      expect(() => db.deletePondSafely('pond_1'), throwsA(isA<DependentRecordsExistException>()));
      expect(() => db.deleteBatchSafely('batch_1'), throwsA(isA<DependentRecordsExistException>()));
    });
  });
}
