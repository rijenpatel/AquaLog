import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/config/app_config.dart';
import 'package:aqualog/core/services/demo_data_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Master Data Hierarchy & Safe Deletion Checks', () {
    test('Site deletion safety guard prevents deleting site with linked ponds', () async {
      final siteId = 'site_test_1';
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(
          id: drift.Value(siteId),
          name: const drift.Value('Coastal Delta Farm'),
          code: const drift.Value('CDF-01'),
          status: const drift.Value('active'),
        ),
      );

      // Initially site has no ponds -> can delete
      var check = await db.canDeleteSite(siteId);
      expect(check.canDelete, isTrue);
      expect(check.linkedPonds, equals(0));

      // Add a pond under the site
      final pondId = 'pond_test_1';
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(pondId),
          siteId: drift.Value(siteId),
          name: const drift.Value('Basin 1'),
          areaSqMeters: const drift.Value(4000.0),
          waterDepthMeters: const drift.Value(1.5),
        ),
      );

      // Now site cannot be deleted
      check = await db.canDeleteSite(siteId);
      expect(check.canDelete, isFalse);
      expect(check.linkedPonds, equals(1));
    });

    test('Pond deletion safety guard prevents deleting pond with active batches or records', () async {
      final siteId = 'site_test_2';
      final pondId = 'pond_test_2';

      await db.into(db.farmSites).insert(
        FarmSitesCompanion(
          id: drift.Value(siteId),
          name: const drift.Value('Bayview Farm'),
          code: const drift.Value('BVF-01'),
        ),
      );

      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(pondId),
          siteId: drift.Value(siteId),
          name: const drift.Value('Pond 2'),
          areaSqMeters: const drift.Value(5000.0),
          waterDepthMeters: const drift.Value(1.6),
        ),
      );

      // Initially empty pond -> can delete
      var pondCheck = await db.canDeletePond(pondId);
      expect(pondCheck.canDelete, isTrue);

      // Add a batch
      final batchId = 'batch_test_2';
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: drift.Value(batchId),
          pondId: drift.Value(pondId),
          batchNumber: const drift.Value(1),
          species: const drift.Value('Litopenaeus vannamei'),
          stockingDate: drift.Value(DateTime(2026, 8, 1)),
          shrimpStockedCount: const drift.Value(80000),
          status: const drift.Value('active'),
        ),
      );

      // Now pond cannot be deleted
      pondCheck = await db.canDeletePond(pondId);
      expect(pondCheck.canDelete, isFalse);
      expect(pondCheck.linkedBatches, equals(1));
    });

    test('Batch deletion safety guard prevents deleting batch with production logs', () async {
      final batchId = 'batch_test_3';
      final pondId = 'pond_test_3';

      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(pondId),
          name: const drift.Value('Pond 3'),
          areaSqMeters: const drift.Value(4500.0),
          waterDepthMeters: const drift.Value(1.5),
        ),
      );

      await db.into(db.batches).insert(
        BatchesCompanion(
          id: drift.Value(batchId),
          pondId: drift.Value(pondId),
          batchNumber: const drift.Value(1),
          species: const drift.Value('Litopenaeus vannamei'),
          stockingDate: drift.Value(DateTime(2026, 7, 1)),
          shrimpStockedCount: const drift.Value(100000),
          status: const drift.Value('active'),
        ),
      );

      var batchCheck = await db.canDeleteBatch(batchId);
      expect(batchCheck.canDelete, isTrue);

      // Insert feed record
      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const drift.Value('feed_log_1'),
          batchId: drift.Value(batchId),
          pondId: drift.Value(pondId),
          date: drift.Value(DateTime(2026, 7, 15)),
          timeSlot: const drift.Value('7:00 AM'),
          totalGrams: const drift.Value(25000),
          totalKg: const drift.Value(25.0),
        ),
      );

      batchCheck = await db.canDeleteBatch(batchId);
      expect(batchCheck.canDelete, isFalse);
      expect(batchCheck.linkedFeedRecords, equals(1));
    });
  });

  group('One Active Batch per Pond Enforcement', () {
    test('getActiveBatchForPond accurately detects existing active batch', () async {
      final pondId = 'pond_single_active';
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(pondId),
          name: const drift.Value('Basin 4'),
          areaSqMeters: const drift.Value(5000.0),
          waterDepthMeters: const drift.Value(1.5),
        ),
      );

      // No active batch yet
      var active = await db.getActiveBatchForPond(pondId);
      expect(active, isNull);

      // Stock first batch
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value('batch_active_1'),
          pondId: drift.Value(pondId),
          batchNumber: const drift.Value(1),
          species: const drift.Value('Litopenaeus vannamei'),
          stockingDate: drift.Value(DateTime(2026, 6, 1)),
          shrimpStockedCount: const drift.Value(90000),
          status: const drift.Value('active'),
        ),
      );

      // Active batch is found
      active = await db.getActiveBatchForPond(pondId);
      expect(active, isNotNull);
      expect(active!.id, equals('batch_active_1'));
      expect(active.batchNumber, equals(1));

      // Harvest/complete batch
      await (db.update(db.batches)..where((t) => t.id.equals('batch_active_1'))).write(
        const BatchesCompanion(status: drift.Value('completed')),
      );

      // Pond is now free for next batch
      active = await db.getActiveBatchForPond(pondId);
      expect(active, isNull);
    });
  });

  group('Date-based Batch Auto-Resolution', () {
    test('getBatchForPondOnDate returns correct batch covering the date', () async {
      final pondId = 'pond_dates_test';
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(pondId),
          name: const drift.Value('Basin Dates'),
          areaSqMeters: const drift.Value(5000.0),
          waterDepthMeters: const drift.Value(1.5),
        ),
      );

      // Batch 1: May 1 to July 31 (harvested)
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value('batch_cycle_1'),
          pondId: drift.Value(pondId),
          batchNumber: const drift.Value(1),
          species: const drift.Value('Litopenaeus vannamei'),
          stockingDate: drift.Value(DateTime(2026, 5, 1)),
          harvestDate: drift.Value(DateTime(2026, 7, 31)),
          shrimpStockedCount: const drift.Value(100000),
          status: const drift.Value('completed'),
        ),
      );

      // Batch 2: August 15 onwards (active)
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value('batch_cycle_2'),
          pondId: drift.Value(pondId),
          batchNumber: const drift.Value(2),
          species: const drift.Value('Litopenaeus vannamei'),
          stockingDate: drift.Value(DateTime(2026, 8, 15)),
          shrimpStockedCount: const drift.Value(110000),
          status: const drift.Value('active'),
        ),
      );

      // Querying date in June 2026 resolves Batch 1
      final juneBatch = await db.getBatchForPondOnDate(pondId, DateTime(2026, 6, 10));
      expect(juneBatch, isNotNull);
      expect(juneBatch!.id, equals('batch_cycle_1'));

      // Querying date in September 2026 resolves Batch 2
      final septBatch = await db.getBatchForPondOnDate(pondId, DateTime(2026, 9, 5));
      expect(septBatch, isNotNull);
      expect(septBatch!.id, equals('batch_cycle_2'));
    });
  });

  group('Multi-Feed Logging & Atomic Stock Update', () {
    test('Logs multiple feeds in one session and deducts respective inventory stock', () async {
      // Setup inventory feeds
      final feed1Id = 'inv_feed_cp1';
      final feed2Id = 'inv_feed_cp2';

      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: drift.Value(feed1Id),
          siteId: const drift.Value('site_1'),
          category: const drift.Value('feed'),
          name: const drift.Value('CP Grower 1'),
          currentStock: const drift.Value(200.0),
          unit: const drift.Value('kg'),
          costPerUnit: const drift.Value(90.0),
        ),
      );

      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: drift.Value(feed2Id),
          siteId: const drift.Value('site_1'),
          category: const drift.Value('feed'),
          name: const drift.Value('CP Grower 2'),
          currentStock: const drift.Value(150.0),
          unit: const drift.Value('kg'),
          costPerUnit: const drift.Value(95.0),
        ),
      );

      final recordId = 'feed_multi_1';
      final feedCompanion = FeedRecordsCompanion(
        id: drift.Value(recordId),
        batchId: const drift.Value('batch_1'),
        pondId: const drift.Value('pond_1'),
        date: drift.Value(DateTime(2026, 9, 8)),
        timeSlot: const drift.Value('7:00 AM'),
        totalGrams: const drift.Value(35000),
        totalKg: const drift.Value(35.0), // 20kg of feed1 + 15kg of feed2
      );

      await db.logFeedSessionTransaction(
        feedRecord: feedCompanion,
        feedDeductions: [
          {'itemId': feed1Id, 'qtyKg': 20.0, 'pelletSize': '1.8mm'},
          {'itemId': feed2Id, 'qtyKg': 15.0, 'pelletSize': '2.0mm'},
        ],
      );

      // Verify inventory deducted
      final item1 = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feed1Id))).getSingle();
      final item2 = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feed2Id))).getSingle();

      expect(item1.currentStock, equals(180.0)); // 200 - 20
      expect(item2.currentStock, equals(135.0)); // 150 - 15

      // Edit feed session: change quantities to 10kg feed1 + 25kg feed2
      final updatedCompanion = FeedRecordsCompanion(
        id: drift.Value(recordId),
        batchId: const drift.Value('batch_1'),
        pondId: const drift.Value('pond_1'),
        date: drift.Value(DateTime(2026, 9, 8)),
        timeSlot: const drift.Value('7:00 AM'),
        totalKg: const drift.Value(35.0),
      );

      await db.updateFeedSessionTransaction(
        feedRecord: updatedCompanion,
        feedDeductions: [
          {'itemId': feed1Id, 'qtyKg': 10.0, 'pelletSize': '1.8mm'},
          {'itemId': feed2Id, 'qtyKg': 25.0, 'pelletSize': '2.0mm'},
        ],
      );

      // Verify stock was reversed and re-deducted properly:
      // Item 1: 180 + 20 (reversal) - 10 (new) = 190
      // Item 2: 135 + 15 (reversal) - 25 (new) = 125
      final updatedItem1 = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feed1Id))).getSingle();
      final updatedItem2 = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feed2Id))).getSingle();

      expect(updatedItem1.currentStock, equals(190.0));
      expect(updatedItem2.currentStock, equals(125.0));
    });
  });

  group('Application Configuration & Tribute Metadata', () {
    test('AppConfig values match expected release parameters', () {
      expect(AppConfig.appName, equals('AquaLog'));
      expect(AppConfig.appVersion, equals('1.0.0.9'));
      expect(AppConfig.buildNumber, equals(9));
      expect(AppConfig.creationDate, equals('07-09-2026'));
    });
  });

  group('Upgraded Demo Data System Verification', () {
    test('DemoDataService loads 3 active batches with different DOC, 2 completed batches, and 1 archive pond', () async {
      await DemoDataService(db).loadDemoData();

      // Verify Ponds
      final allPonds = await db.select(db.ponds).get();
      expect(allPonds.length, equals(6));

      final activePonds = allPonds.where((p) => p.status == 'active').toList();
      final archivedPonds = allPonds.where((p) => p.status == 'archived').toList();

      expect(activePonds.length, equals(5));
      expect(archivedPonds.length, equals(1));
      expect(archivedPonds.first.name, contains('Pond 6'));
      expect(archivedPonds.first.id, equals('pond_6_archived'));

      // Verify Batches
      final allBatches = await db.select(db.batches).get();
      expect(allBatches.length, equals(5));

      final activeBatches = allBatches.where((b) => b.status == 'active').toList();
      final completedBatches = allBatches.where((b) => b.status == 'completed').toList();

      expect(activeBatches.length, equals(3));
      expect(completedBatches.length, equals(2));

      // Verify different DOC for active batches
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final docs = activeBatches.map((b) => today.difference(b.stockingDate).inDays + 1).toSet();
      expect(docs.length, equals(3), reason: 'All 3 active batches must have different DOC');

      // Verify Completed batches have full harvest details and revenues
      for (final cb in completedBatches) {
        expect(cb.harvestDate, isNotNull);
        expect(cb.harvestWeightKg, isNotNull);
        expect(cb.harvestWeightKg!, greaterThan(2000.0));
        expect(cb.actualFcr, isNotNull);
        expect(cb.actualSurvivalPct, isNotNull);
      }

      final allRevenues = await db.select(db.revenues).get();
      expect(allRevenues.length, equals(2));
      final totalRev = allRevenues.fold(0.0, (sum, r) => sum + r.totalAmount);
      expect(totalRev, greaterThan(2000000.0)); // Over 20 Lakhs in commercial harvest revenue

      // Verify Feed Records are richly populated
      final allFeeds = await db.select(db.feedRecords).get();
      expect(allFeeds.length, greaterThan(100)); // Over 100 multi-feed records

      // Verify Samplings
      final allSamplings = await db.select(db.samplingEntries).get();
      expect(allSamplings.length, greaterThanOrEqualTo(15)); // Comprehensive sampling curves
    });
  });
}
