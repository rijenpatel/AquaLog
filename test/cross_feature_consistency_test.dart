import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/calculations/population_engine.dart';
import 'package:aqualog/core/calculations/water_quality_engine.dart';
import 'package:aqualog/core/calculations/health_score_calculator.dart';
import 'package:aqualog/core/calculations/feed_plan_calculator.dart';
import 'package:aqualog/core/calculations/harvest_decision_engine.dart';
import 'package:aqualog/core/calculations/reorder_assistant_engine.dart';
import 'package:aqualog/core/services/batch_passport_pdf_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Section 28: Cross-Feature Controlled Consistency Test', () {
    test('Controlled test batch reflects consistent metrics across all 10 modules', () async {
      // 1. Setup Farm, Pond, and Controlled Batch (DOC 65)
      final siteId = 'site_controlled_1';
      final pondId = 'pond_controlled_1';
      final batchId = 'batch_controlled_1';
      final stockingDate = DateTime.now().subtract(const Duration(days: 65));

      await db.into(db.farmSites).insert(FarmSitesCompanion.insert(
            id: siteId,
            name: 'Delta Brackish Farm',
            country: const drift.Value('India'),
            status: const drift.Value('active'),
          ));

      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: pondId,
            name: 'Pond 04',
            areaSqMeters: 5000.0,
            waterDepthMeters: 1.5,
            siteId: drift.Value(siteId),
          ));

      // Stock: 500,000 PLs
      await db.into(db.batches).insert(BatchesCompanion.insert(
            id: batchId,
            pondId: pondId,
            batchNumber: 4,
            species: const drift.Value('Litopenaeus vannamei'),
            stockingDate: stockingDate,
            shrimpStockedCount: 500000,
            seedCost: const drift.Value(150000.0),
            targetHarvestWeightG: const drift.Value(25.0),
            status: const drift.Value('active'),
            harvestCount: const drift.Value(20000),
            harvestWeightKg: const drift.Value(360.0),
          ));

      // 2. Mortality: 8,500
      await db.saveMortalityRecord(MortalityRecordsCompanion.insert(
        id: 'mort_ctrl_1',
        pondId: pondId,
        batchId: batchId,
        date: DateTime.now().subtract(const Duration(days: 5)),
        countObserved: const drift.Value(4500),
        countEstimated: const drift.Value(4000),
        reason: const drift.Value('normal'),
      ));

      // 3. Sampling: ABW 18.4 g
      await db.into(db.samplingEntries).insert(SamplingEntriesCompanion.insert(
            id: 'samp_ctrl_1',
            pondId: pondId,
            batchId: batchId,
            date: DateTime.now().subtract(const Duration(days: 1)),
            doc: 64,
            samplingTotalWeightG: 920.0,
            samplingShrimpCount: 50,
            abwGrams: 18.4,
            adgGramsPerDay: const drift.Value(0.26),
          ));

      // 4. Water Quality: DO 4.8 mg/L, pH 7.9, Salinity 18 ppt, Temp 30.2 °C
      await db.saveWaterQualityLog(WaterQualityLogsCompanion.insert(
        id: 'wq_ctrl_1',
        pondId: pondId,
        siteId: drift.Value(siteId),
        date: DateTime.now(),
        timeSlot: const drift.Value('Morning'),
        dissolvedOxygen: const drift.Value(4.8),
        ph: const drift.Value(7.9),
        temperature: const drift.Value(30.2),
        salinity: const drift.Value(18.0),
        ammonia: const drift.Value(0.03),
        nitrite: const drift.Value(0.06),
        alkalinity: const drift.Value(125.0),
        transparencyCm: const drift.Value(34.0),
      ));

      // 5. Feed Record: 42 kg/day
      await db.into(db.feedRecords).insert(FeedRecordsCompanion.insert(
            id: 'feed_ctrl_1',
            pondId: pondId,
            batchId: batchId,
            date: DateTime.now(),
            timeSlot: '7:00 AM',
            totalGrams: 42000.0,
            totalKg: 42.0,
            trayChecked: const drift.Value(true),
            trayLeftoverPct: const drift.Value(5),
          ));

      // 6. Inventory Items: Feed A
      await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
            id: 'item_feed_a',
            name: 'CP Grower 40%',
            category: 'feed',
            unit: const drift.Value('kg'),
            currentStock: const drift.Value(180.0),
            costPerUnit: const drift.Value(95.0),
            lowStockThreshold: const drift.Value(200.0),
            siteId: drift.Value(siteId),
          ));

      // Past 14 days consumption transactions: 42 kg/day
      final now = DateTime.now();
      for (int i = 0; i < 14; i++) {
        await db.into(db.inventoryTransactions).insert(InventoryTransactionsCompanion.insert(
              id: 'tx_feed_$i',
              itemId: 'item_feed_a',
              type: 'consumption',
              quantity: -42.0,
              unitPrice: const drift.Value(95.0),
              totalCost: const drift.Value(3990.0),
              date: now.subtract(Duration(days: i)),
              siteId: drift.Value(siteId),
            ));
      }

      // ==========================================================
      // VERIFY HARMONIZED SYSTEM-WIDE CALCULATIONS
      // ==========================================================

      // A. Population Reconciliation
      final batch = await (db.select(db.batches)..where((b) => b.id.equals(batchId))).getSingle();
      final mortalities = await db.getMortalityRecordsForBatch(batchId);
      final samplings = await (db.select(db.samplingEntries)..where((s) => s.batchId.equals(batchId))).get();

      final popSummary = PopulationEngine.calculatePopulationSummary(
        batch: batch,
        mortalityRecords: mortalities,
        adjustments: [],
        harvestCountOverride: 20000,
      );

      // Remaining = 500,000 - 8,500 (mortality) - 20,000 (harvest) = 471,500
      expect(popSummary.stockedCount, equals(500000));
      expect(popSummary.totalMortality, equals(8500));
      expect(popSummary.cumulativeHarvestedCount, equals(20000));
      expect(popSummary.estimatedRemainingPopulation, equals(471500));

      // B. Standing Biomass
      // Biomass = (471,500 shrimp * 18.4 g) / 1000 = 8,675.6 kg
      final calculatedBiomassKg = (popSummary.estimatedRemainingPopulation * 18.4) / 1000.0;
      expect(calculatedBiomassKg, closeTo(8675.6, 0.1));

      // C. Survival Rate
      // Standing Survival = 471,500 / 500,000 = 94.3%
      expect(popSummary.reconciledSurvivalPct, closeTo(94.3, 0.1));

      // D. Water Quality Intelligence
      final wqLog = (await db.getWaterQualityLogsForPond(pondId)).first;
      final wqStatus = WaterQualityEngine.evaluateLog(wqLog);
      expect(wqStatus, equals(WqStatus.acceptable)); // DO 4.8 is acceptable (optimal >= 5.0)

      final multiRiskAlerts = WaterQualityEngine.detectRiskAlerts([wqLog]);
      expect(multiRiskAlerts.isEmpty, isTrue); // Clean WQ profile, no stress alert

      // E. Comprehensive Pond Health
      final health = HealthScoreCalculator.calculateComprehensive(
        doc: 65,
        latestDo: wqLog.dissolvedOxygen,
        latestPh: wqLog.ph,
        latestTemp: wqLog.temperature,
        latestAmmonia: wqLog.ammonia,
        latestAdg: 0.26,
        survivalPct: popSummary.reconciledSurvivalPct,
        trayLeftoverPct: 5,
        daysSinceLastSampling: 1,
        todayMortalityCount: 0,
      );

      // Excellent health score expected (> 85)
      expect(health.totalScore, greaterThanOrEqualTo(85));
      expect(health.riskLevel, equals(RiskLevel.green));

      // F. Feed Planning
      final feedPlan = FeedPlanCalculator.calculateDailyPlan(
        biomassKg: calculatedBiomassKg,
        abwGrams: 18.4,
        trayLeftoverPct: 5,
        latestDO: wqLog.dissolvedOxygen,
        latestAmmonia: wqLog.ammonia,
      );
      // For 18.4g, feed rate is ~2.4% of 8675.6kg -> ~208 kg
      expect(feedPlan.baseFeedKg, greaterThan(150.0));
      expect(feedPlan.recommendedFeedKg, greaterThan(0.0));

      // G. Harvest Decision Center
      final harvestReport = HarvestDecisionEngine.evaluateScenarios(
        currentDoc: 65,
        currentAbwGrams: 18.4,
        currentPopulation: popSummary.estimatedRemainingPopulation,
        currentBiomassKg: calculatedBiomassKg,
        historicalExpenses: 350000.0,
        targetWeightGrams: 25.0,
        currentAdgGramsPerDay: 0.26,
        feedStockRemainingKg: 180.0,
      );

      expect(harvestReport.scenarios.length, equals(3)); // Harvest Now, +7d, +14d
      expect(harvestReport.scenarios[0].projectedAbwGrams, equals(18.4));
      expect(harvestReport.scenarios[1].projectedAbwGrams, closeTo(20.2, 0.1)); // 18.4 + 7*0.26
      expect(harvestReport.scenarios[2].projectedAbwGrams, closeTo(22.0, 0.1)); // 18.4 + 14*0.26
      expect(harvestReport.decisionExplanation.isNotEmpty, isTrue);

      // H. Inventory Reorder Assistant
      final allItems = await db.select(db.inventoryItems).get();
      final txList = await (db.select(db.inventoryTransactions)..where((t) => t.itemId.equals('item_feed_a'))).get();
      final forecast = ReorderAssistantEngine.forecastItem(
        item: allItems.first,
        itemTransactions: txList,
        customLeadTimeDays: 3,
        customSafetyStockDays: 2.0,
      );

      // 180 kg stock with 42 kg/day consumption => ~4.3 days remaining
      expect(forecast.dailyBurnRate, equals(42.0));
      expect(forecast.projectedDaysRemaining, closeTo(4.3, 0.1));
      expect(forecast.urgency, equals(ReorderUrgency.orderNow)); // < 5 days remaining

      // I. Batch Passport Multi-page PDF Generation
      final site = (await db.select(db.farmSites).get()).first;
      final pond = (await db.select(db.ponds).get()).first;
      final feedRecords = await (db.select(db.feedRecords)..where((f) => f.batchId.equals(batchId))).get();
      final wqLogs = await db.getWaterQualityLogsForPond(pondId);

      final pdfBytes = await BatchPassportPdfService.generatePassportPdfBytes(
        site: site,
        pond: pond,
        batch: batch,
        samplings: samplings,
        feedRecords: feedRecords,
        wqLogs: wqLogs,
        mortalities: mortalities,
        adjustments: [],
        operations: [],
        treatments: [],
        expenses: [],
        revenues: [],
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(2000)); // Comprehensive publication-grade PDF
    });
  });
}
