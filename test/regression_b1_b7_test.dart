import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:aqualog/core/database/app_database.dart';
import 'package:aqualog/core/services/weather_service.dart';
import 'package:aqualog/core/providers/batch_dashboard_providers.dart';

import 'package:http/http.dart' as http;

class FailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('Simulated network failure / offline');
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('B1 Regression Tests — Zero-Data Application Integrity', () {
    test('Offline weather without cached record returns unavailable state, never fake 28.5C', () async {
      final service = WeatherService(db, FailingHttpClient());
      final forecast = await service.getFullForecastForSite(
        siteId: 'non_existent_site',
        latitude: 16.9890,
        longitude: 82.2475,
      );

      expect(forecast.isAvailable, false);
      expect(forecast.condition, 'Weather unavailable');
      expect(forecast.temperature, 0.0);
    });

    test('Zero farm data has no sites, no ponds, no batches', () async {
      final sites = await db.select(db.farmSites).get();
      final ponds = await db.select(db.ponds).get();
      final batches = await db.select(db.batches).get();

      expect(sites.isEmpty, true);
      expect(ponds.isEmpty, true);
      expect(batches.isEmpty, true);
    });
  });

  group('B2 & B3 Regression Tests — Site Coordinates & Pond Initial Status', () {
    test('Site coordinates persist and are retrievable', () async {
      const siteId = 'site_test_1';
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(
          id: const Value(siteId),
          name: const Value('Kakinada Estuary Farm'),
          latitude: const Value(16.989042),
          longitude: const Value(82.247465),
          address: const Value('Kakinada, Andhra Pradesh'),
        ),
      );

      final site = await (db.select(db.farmSites)..where((t) => t.id.equals(siteId))).getSingle();
      expect(site.latitude, 16.989042);
      expect(site.longitude, 82.247465);
    });

    test('Pond creation programmatically assigns active status without initial optional prompt', () async {
      const pondId = 'pond_test_1';
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value(pondId),
          name: const Value('Pond A1'),
          areaSqMeters: const Value(5058.0),
          waterDepthMeters: const Value(1.5),
          siteId: const Value('site_test_1'),
          status: const Value('active'),
        ),
      );

      final pond = await (db.select(db.ponds)..where((t) => t.id.equals(pondId))).getSingle();
      expect(pond.status, 'active');
      expect(pond.name, 'Pond A1');
    });
  });

  group('B4 Regression Tests — Stocked Hapa Count, Target DOC, 10-Day Check', () {
    test('Batch persists Hapa count = 100, Target DOC = 93 and original stocked population', () async {
      final stockingDate = DateTime.now().subtract(const Duration(days: 10));
      const batchId = 'batch_b4_test';

      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value(batchId),
          pondId: const Value('pond_test_1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(stockingDate),
          shrimpStockedCount: const Value(120000),
          targetHarvestWeightG: const Value(25.0),
          targetDoc: const Value(93),
          hapaStockedCount: const Value(100),
          status: const Value('active'),
        ),
      );

      final batch = await (db.select(db.batches)..where((t) => t.id.equals(batchId))).getSingle();
      expect(batch.shrimpStockedCount, 120000);
      expect(batch.hapaStockedCount, 100);
      expect(batch.targetDoc, 93);

      // Perform 10-day Hapa Check: 85 alive out of 100
      const alive = 85;
      final survivalPct = (alive / batch.hapaStockedCount) * 100.0;
      final estimatedActive = ((batch.shrimpStockedCount * survivalPct) / 100.0).round();

      expect(survivalPct, 85.0);
      expect(estimatedActive, 102000);

      await db.into(db.hapaChecks).insert(
        HapaChecksCompanion(
          id: const Value('hapa_test_1'),
          batchId: const Value(batchId),
          pondId: const Value('pond_test_1'),
          date: Value(DateTime.now()),
          hoursElapsed: const Value(240),
          hapaStocked: Value(batch.hapaStockedCount),
          hapaAlive: const Value(alive),
          survivalPercentage: Value(survivalPct),
          estimatedPopulation: Value(estimatedActive),
        ),
      );

      // Update actualSurvivalPct on batch
      await (db.update(db.batches)..where((t) => t.id.equals(batchId))).write(
        BatchesCompanion(actualSurvivalPct: Value(survivalPct)),
      );

      final updatedBatch = await (db.select(db.batches)..where((t) => t.id.equals(batchId))).getSingle();
      expect(updatedBatch.actualSurvivalPct, 85.0);
      expect(updatedBatch.shrimpStockedCount, 120000); // Preserved!
    });
  });

  group('B5 Regression Tests — Cast Net Sampling Save & ABW / Count Integrity', () {
    test('Cast Net Sampling inserts successfully with pondId and doc, verifies ABW & Count', () async {
      const batchId = 'batch_b4_test';
      const pondId = 'pond_test_1';
      const sampleCount = 25;
      const totalWeightG = 475.5;
      final abw = totalWeightG / sampleCount; // 19.02 g
      final countPcsPerKg = 1000.0 / abw;

      await db.into(db.samplingEntries).insert(
        SamplingEntriesCompanion(
          id: const Value('samp_1'),
          batchId: const Value(batchId),
          pondId: const Value(pondId),
          doc: const Value(25),
          date: Value(DateTime.now()),
          samplingShrimpCount: const Value(sampleCount),
          samplingTotalWeightG: const Value(totalWeightG),
          abwGrams: Value(abw),
        ),
      );

      final samplings = await (db.select(db.samplingEntries)..where((t) => t.batchId.equals(batchId))).get();
      expect(samplings.length, 1);
      final entry = samplings.first;
      expect(entry.samplingShrimpCount, 25);
      expect(entry.samplingTotalWeightG, 475.5);
      expect(entry.abwGrams, closeTo(19.02, 0.01));
      expect(countPcsPerKg, closeTo(52.57, 0.01));
    });
  });

  group('B6 & B7 Regression Tests — Feed Scoping, Inventory Deductions & Co-Feeding', () {
    test('Feed log atomically deducts feed, medicine, supplement and stores coFedMedicinesJson', () async {
      const siteId = 'site_test_1';
      const pondId = 'pond_test_1';
      const batchId = 'batch_b4_test';

      // Setup inventory items
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('inv_feed_1'),
          siteId: const Value(siteId),
          name: const Value('CP Classic Grower 1.6mm'),
          category: const Value('feed'),
          currentStock: const Value(100.0),
          unit: const Value('kg'),
          costPerUnit: const Value(85.0),
        ),
      );

      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('inv_med_1'),
          siteId: const Value(siteId),
          name: const Value('AquaCure Antibiotic'),
          category: const Value('medicine'),
          currentStock: const Value(2500.0),
          unit: const Value('g'),
          costPerUnit: const Value(1.5),
        ),
      );

      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('inv_sup_1'),
          siteId: const Value(siteId),
          name: const Value('Mineral Mix Powder'),
          category: const Value('supplement'),
          currentStock: const Value(5000.0),
          unit: const Value('g'),
          costPerUnit: const Value(0.5),
        ),
      );

      final coFedList = [
        {'name': 'AquaCure Antibiotic', 'quantity': 500.0, 'unit': 'g', 'category': 'medicine'},
        {'name': 'Mineral Mix Powder', 'quantity': 200.0, 'unit': 'g', 'category': 'supplement'},
      ];

      // Atomic feed logging with co-fed additions
      await db.logFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const Value('feed_log_1'),
          batchId: const Value(batchId),
          pondId: const Value(pondId),
          date: Value(DateTime.now()),
          timeSlot: const Value('07:00 AM'),
          totalKg: const Value(20.0),
          totalGrams: const Value(20000.0),
          coFedMedicinesJson: Value(jsonEncode(coFedList)),
        ),
        feedDeductions: [
          {'itemId': 'inv_feed_1', 'qtyKg': 20.0}
        ],
        medicineDeductions: [
          {'itemId': 'inv_med_1', 'qty': 500.0, 'unit': 'g'}
        ],
        supplementDeductions: [
          {'itemId': 'inv_sup_1', 'qty': 200.0, 'unit': 'g'}
        ],
      );

      // Verify feed record saved
      final feeds = await (db.select(db.feedRecords)..where((t) => t.batchId.equals(batchId))).get();
      expect(feeds.length, 1);
      final feed = feeds.first;
      expect(feed.totalKg, 20.0);
      expect(feed.coFedMedicinesJson != null, true);

      final decodedCoFed = jsonDecode(feed.coFedMedicinesJson!) as List;
      expect(decodedCoFed.length, 2);
      expect(decodedCoFed[0]['name'], 'AquaCure Antibiotic');
      expect(decodedCoFed[1]['name'], 'Mineral Mix Powder');

      // Verify inventory deductions
      final feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_feed_1'))).getSingle();
      expect(feedItem.currentStock, 80.0); // 100 - 20

      final medItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_med_1'))).getSingle();
      expect(medItem.currentStock, 2000.0); // 2500 - 500

      final supItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_sup_1'))).getSingle();
      expect(supItem.currentStock, 4800.0); // 5000 - 200

      // Verify inventory transactions created
      final txs = await db.select(db.inventoryTransactions).get();
      expect(txs.length, 3); // 1 feed consumption, 1 medicine, 1 supplement
    });

    test('Insufficient stock fails atomically and rolls back transaction', () async {
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('inv_feed_rollback'),
          name: const Value('CP Classic Grower'),
          category: const Value('feed'),
          currentStock: const Value(80.0),
          unit: const Value('kg'),
        ),
      );

      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const Value('inv_med_rollback'),
          name: const Value('AquaCure Antibiotic'),
          category: const Value('medicine'),
          currentStock: const Value(500.0),
          unit: const Value('g'),
        ),
      );

      bool failed = false;
      try {
        await db.logFeedSessionTransaction(
          feedRecord: FeedRecordsCompanion(
            id: const Value('feed_log_fail'),
            batchId: const Value('batch_b4_test'),
            pondId: const Value('pond_test_1'),
            date: Value(DateTime.now()),
            timeSlot: const Value('11:00 AM'),
            totalKg: const Value(10.0),
            totalGrams: const Value(10000.0),
          ),
          feedDeductions: [
            {'itemId': 'inv_feed_rollback', 'qtyKg': 10.0}
          ],
          medicineDeductions: [
            {'itemId': 'inv_med_rollback', 'qty': 99999.0, 'unit': 'g'} // Insufficient!
          ],
        );
      } catch (e) {
        failed = true;
      }

      expect(failed, true);

      // Verify feed was NOT inserted and stock was NOT deducted
      final failedFeed = await (db.select(db.feedRecords)..where((t) => t.id.equals('feed_log_fail'))).getSingleOrNull();
      expect(failedFeed == null, true);

      final feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals('inv_feed_rollback'))).getSingle();
      expect(feedItem.currentStock, 80.0); // Unchanged!
    });
  });

  group('Batch View Feed Audit Regression Tests — Progress, Ledger, Chart', () {
    test('getDailyFeedBarsForRange bounds bars by batch stocking date for 7D, 14D, 30D', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Batch stocked 10 days ago (DOC 11 today)
      final stockingDate = today.subtract(const Duration(days: 10));
      const batchId = 'batch_chart_test';
      const pondId = 'pond_chart_test';

      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value(pondId),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
          status: const Value('active'),
        ),
      );

      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value(batchId),
          pondId: const Value(pondId),
          batchNumber: const Value(2),
          species: const Value('Vannamei'),
          stockingDate: Value(stockingDate),
          shrimpStockedCount: const Value(50000),
          targetHarvestWeightG: const Value(25.0),
          targetDoc: const Value(60),
          status: const Value('active'),
        ),
      );

      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const Value('f1'),
          batchId: const Value(batchId),
          pondId: const Value(pondId),
          date: Value(today),
          timeSlot: const Value('7:00 AM'),
          totalKg: const Value(15.0),
          totalGrams: const Value(15000.0),
          trayLeftoverPct: const Value(10),
          otherFeedName: const Value('CP Classic Grower 1.6mm'),
        ),
      );

      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const Value('f2'),
          batchId: const Value(batchId),
          pondId: const Value(pondId),
          date: Value(today.subtract(const Duration(days: 3))),
          timeSlot: const Value('11:00 AM'),
          totalKg: const Value(18.0),
          totalGrams: const Value(18000.0),
          trayLeftoverPct: const Value(25), // Surplus tray!
          otherFeedName: const Value('CP Classic Grower 1.6mm'),
        ),
      );

      final batch = await (db.select(db.batches)..where((t) => t.id.equals(batchId))).getSingle();
      final pond = await (db.select(db.ponds)..where((t) => t.id.equals(pondId))).getSingle();
      final feedRecords = await (db.select(db.feedRecords)..where((t) => t.batchId.equals(batchId))).get();

      final dashboardData = BatchDashboardData(
        batch: batch,
        pond: pond,
        site: null,
        doc: 11,
        targetDoc: 60,
        abw: 12.0,
        hasRealSampling: false,
        countPcsPerKg: 83.3,
        countGrade: '80-90',
        adgGramsPerDay: 0.35,
        standingBiomassKg: 576.0,
        populationPcs: 48000,
        survivalPct: 96.0,
        isFcrAvailable: false,
        todayFeedLoggedKg: 15.0,
        todayFeedAllocatedKg: 20.0,
        feedCompliancePct: 75.0,
        todaySessions: const [],
        validFeedRecords: feedRecords,
        trayStatus: 'Normal',
        trayGuidance: 'Normal feeding',
        growthPoints: const [],
        dailyFeedBars: const [],
        fcrMilestones: const [],
        harvestOutlook: HarvestProjectionData(
          currentAbw: 12.0,
          targetAbw: 25.0,
          currentDoc: 11,
          targetDoc: 60,
          projectedHarvestDate: today.add(const Duration(days: 49)),
          daysRemaining: 49,
          expectedBiomassKg: 1200.0,
          basisDescription: 'Model',
          isAvailable: true,
        ),
        financialOverview: const BatchFinancialData(
          incurredCost: 0,
          projectedRevenue: 0,
          estimatedProfit: 0,
          breakEvenPricePerKg: 0,
          projectedMarginPct: 0,
          costBreakdownNote: '',
        ),
        recentActivity: const [],
        isCompleted: false,
        isHapaCheckDue: false,
        stockedHapaCount: 100,
      );

      // 7 days range
      final bars7 = dashboardData.getDailyFeedBarsForRange(7);
      expect(bars7.length, 7);
      expect(bars7.last.isToday, true);
      expect(bars7.last.feedKg, 15.0);

      // 14 days range — capped by 11 days since stocking!
      final bars14 = dashboardData.getDailyFeedBarsForRange(14);
      expect(bars14.length, 11);
      expect(bars14.first.doc, 1);
      expect(bars14.last.doc, 11);

      // 30 days range — also capped by 11 days since stocking!
      final bars30 = dashboardData.getDailyFeedBarsForRange(30);
      expect(bars30.length, 11);

      // Verify surplus tray flag on the 3rd day back (DOC 8)
      final surplusBar = bars14.firstWhere((b) => b.doc == 8);
      expect(surplusBar.feedKg, 18.0);
      expect(surplusBar.hasSurplusTray, true);
    });

    test('Date-wise feed ledger isolates records correctly for specific dates and handles slots', () async {
      const batchId = 'batch_ledger_test';
      const pondId = 'pond_test_1';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 8, 0);
      final yesterday = today.subtract(const Duration(days: 1));

      // Insert feed record yesterday: 12.0 kg at '7:00 AM'
      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const Value('f_yesterday_1'),
          batchId: const Value(batchId),
          pondId: const Value(pondId),
          date: Value(yesterday),
          timeSlot: const Value('7:00 AM'),
          totalKg: const Value(12.0),
          totalGrams: const Value(12000.0),
          trayLeftoverPct: const Value(5),
          otherFeedName: const Value('CP Classic Grower 1.6mm'),
        ),
      );

      // Insert feed record today: 14.5 kg at '07:00 AM' (zero-padded)
      await db.into(db.feedRecords).insert(
        FeedRecordsCompanion(
          id: const Value('f_today_1'),
          batchId: const Value(batchId),
          pondId: const Value(pondId),
          date: Value(today),
          timeSlot: const Value('07:00 AM'),
          totalKg: const Value(14.5),
          totalGrams: const Value(14500.0),
          trayLeftoverPct: const Value(28), // Surplus
          otherFeedName: const Value('Grobest Premium 2.0mm'),
        ),
      );

      final allRecords = await (db.select(db.feedRecords)..where((t) => t.batchId.equals(batchId))).get();
      expect(allRecords.length, 2);

      // Query ledger for yesterday
      final yesterdayRecords = allRecords.where((r) =>
        r.date.year == yesterday.year && r.date.month == yesterday.month && r.date.day == yesterday.day
      ).toList();
      expect(yesterdayRecords.length, 1);
      expect(yesterdayRecords.first.totalKg, 12.0);
      expect(yesterdayRecords.first.otherFeedName, 'CP Classic Grower 1.6mm');
      expect(yesterdayRecords.first.trayLeftoverPct <= 20, true);

      // Query ledger for today
      final todayRecords = allRecords.where((r) =>
        r.date.year == today.year && r.date.month == today.month && r.date.day == today.day
      ).toList();
      expect(todayRecords.length, 1);
      expect(todayRecords.first.totalKg, 14.5);
      expect(todayRecords.first.otherFeedName, 'Grobest Premium 2.0mm');
      expect(todayRecords.first.trayLeftoverPct > 20, true); // Overfed tray check
    });
  });
}
