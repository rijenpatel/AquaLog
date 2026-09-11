import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/calculations/health_score_calculator.dart';
import 'package:aqualog/core/calculations/feed_plan_calculator.dart';
import 'package:aqualog/core/services/action_generator_service.dart';

void main() {
  group('Phase C: Pond Health & Risk Scoring', () {
    test('Calculates 6-pillar comprehensive health score and risk level', () {
      final healthy = HealthScoreCalculator.calculateComprehensive(
        doc: 45,
        latestDo: 5.5,
        latestPh: 7.9,
        latestTemp: 29.0,
        latestAmmonia: 0.02,
        latestAdg: 0.32,
        survivalPct: 92.0,
        trayLeftoverPct: 0,
        daysSinceLastSampling: 5,
        todayMortalityCount: 10,
        mortalityPctOfStock: 0.01,
      );

      expect(healthy.totalScore, greaterThanOrEqualTo(80));
      expect(healthy.riskLevel, equals(RiskLevel.green));
      expect(healthy.waterQualityScore, equals(25));
      expect(healthy.growthScore, equals(20));
      expect(healthy.survivalScore, equals(20));
      expect(healthy.feedPerformanceScore, equals(15));
      expect(healthy.samplingRecencyScore, equals(10));
      expect(healthy.mortalityScore, equals(10));

      final distressed = HealthScoreCalculator.calculateComprehensive(
        doc: 60,
        latestDo: 2.8, // Critical DO
        latestAmmonia: 0.45, // High ammonia
        latestAdg: 0.10, // Poor growth
        survivalPct: 68.0, // Low survival
        trayLeftoverPct: 35, // High feed refusal
        daysSinceLastSampling: 18, // Overdue
        todayMortalityCount: 650,
        mortalityPctOfStock: 0.8, // Spike
        doDeclining: true,
        feedIntakeDeclining: true,
      );

      expect(distressed.totalScore, lessThan(50));
      expect(distressed.riskLevel, equals(RiskLevel.red));
      expect(distressed.topConcerns.isNotEmpty, isTrue);
      expect(distressed.recommendations.isNotEmpty, isTrue);
      // Verify correlation was detected
      expect(distressed.correlations.any((c) => c.contains('DO Decline')), isTrue);
    });
  });

  group('Phase C: Daily Farm Action Center Generator', () {
    late AppDatabase db;
    late ActionGeneratorService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = ActionGeneratorService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Generates tasks for missing daily records, overdue sampling, and low stock', () async {
      await db.into(db.farmSites).insert(FarmSitesCompanion.insert(
            id: 'site_1',
            name: 'Delta Farm',
          ));
      await db.into(db.ponds).insert(PondsCompanion.insert(
            id: 'pond_1',
            name: 'Pond 01',
            areaSqMeters: 4000.0,
            waterDepthMeters: 1.5,
            siteId: const drift.Value('site_1'),
          ));
      await db.into(db.batches).insert(BatchesCompanion.insert(
            id: 'batch_1',
            pondId: 'pond_1',
            batchNumber: 1,
            stockingDate: DateTime.now().subtract(const Duration(days: 20)),
            shrimpStockedCount: 100000,
          ));

      // Add a low stock item
      await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
            id: 'item_1',
            name: 'Grower Feed 1.2mm',
            category: 'feed',
            currentStock: const drift.Value(5.0),
            lowStockThreshold: const drift.Value(20.0),
          ));

      // Run action generator
      final count = await service.generateDailyTasks(siteId: 'site_1');
      expect(count, greaterThan(0));

      final tasks = await db.getActionTasks(status: 'pending');
      // Should have: WQ reading due, Sampling due, Low stock reorder
      expect(tasks.any((t) => t.category == 'water_quality'), isTrue);
      expect(tasks.any((t) => t.category == 'sampling'), isTrue);
      expect(tasks.any((t) => t.category == 'inventory'), isTrue);

      // Running again should not create duplicate pending tasks
      final secondCount = await service.generateDailyTasks(siteId: 'site_1');
      expect(secondCount, equals(0));
    });
  });

  group('Phase C: Feed Planning Engine', () {
    test('Calculates base feed and applies tray, weather, and WQ adjustments', () {
      // Biomass 2000 kg, ABW 16g -> feeding rate 3.0% -> Base = 60 kg
      final plan = FeedPlanCalculator.calculateDailyPlan(
        biomassKg: 2000.0,
        abwGrams: 16.0,
        trayLeftoverPct: 30, // -25% (-15 kg)
        isRaining: true, // -15% (-9 kg)
        latestDO: 3.8, // -20% (-12 kg)
      );

      expect(plan.baseFeedKg, equals(60.0));
      expect(plan.trayAdjustmentKg, equals(-15.0));
      expect(plan.weatherAdjustmentKg, equals(-9.0));
      expect(plan.wqAdjustmentKg, equals(-12.0));
      // Base (60) - 15 - 9 - 12 = 24 kg
      expect(plan.recommendedFeedKg, equals(24.0));
      expect(plan.adjustmentReasons.length, equals(3));
    });

    test('Calculates plan vs actual variance accurately', () {
      final variance = FeedPlanCalculator.calculateVariance(
        plannedKg: 50.0,
        actualKg: 55.0,
      );

      expect(variance.varianceKg, equals(5.0));
      expect(variance.variancePct, equals(10.0));
      expect(variance.complianceStatus, equals('Overfed'));

      final adherent = FeedPlanCalculator.calculateVariance(
        plannedKg: 50.0,
        actualKg: 51.5,
      );
      expect(adherent.variancePct, equals(3.0));
      expect(adherent.complianceStatus, equals('Adherent'));
    });
  });
}
