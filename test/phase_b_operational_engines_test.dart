import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/calculations/water_quality_engine.dart';
import 'package:aqualog/core/calculations/population_engine.dart';
import 'package:aqualog/core/calculations/pond_operations_engine.dart';

void main() {
  group('Phase B: WaterQualityEngine Tests', () {
    test('Evaluates normal and abnormal WQ logs accurately', () {
      final normalLog = WaterQualityLog(
        id: 'wq_1',
        pondId: 'pond_1',
        date: DateTime.now(),
        timeSlot: 'Morning',
        temperature: 29.5,
        ph: 7.9,
        dissolvedOxygen: 5.5,
        salinity: 18.0,
        ammonia: 0.02,
        nitrite: 0.05,
        alkalinity: 130.0,
        transparencyCm: 35.0,
        createdAt: DateTime.now(),
      );

      final statusNormal = WaterQualityEngine.evaluateLog(normalLog);
      expect(statusNormal, equals(WqStatus.optimal));

      final criticalLog = WaterQualityLog(
        id: 'wq_2',
        pondId: 'pond_1',
        date: DateTime.now(),
        timeSlot: 'Morning',
        temperature: 30.0,
        ph: 8.8,
        dissolvedOxygen: 2.7, // Critical (<3.0)
        salinity: 18.0,
        ammonia: 0.6, // Critical (>0.5)
        createdAt: DateTime.now(),
      );

      final statusCritical = WaterQualityEngine.evaluateLog(criticalLog);
      expect(statusCritical, equals(WqStatus.critical));
    });

    test('Computes 7-day and 14-day trends and parameter directions', () {
      final now = DateTime.now();
      final logs = [
        WaterQualityLog(
          id: '1',
          pondId: 'pond_1',
          date: now,
          timeSlot: 'Morning',
          dissolvedOxygen: 4.8,
          ammonia: 0.08,
          createdAt: now,
        ),
        WaterQualityLog(
          id: '2',
          pondId: 'pond_1',
          date: now.subtract(const Duration(days: 1)),
          timeSlot: 'Morning',
          dissolvedOxygen: 5.5,
          ammonia: 0.05,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        WaterQualityLog(
          id: '3',
          pondId: 'pond_1',
          date: now.subtract(const Duration(days: 3)),
          timeSlot: 'Morning',
          dissolvedOxygen: 6.0,
          ammonia: 0.03,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      ];

      final trends = WaterQualityEngine.analyzeTrends(logs);
      expect(trends.containsKey('dissolvedOxygen'), isTrue);

      final doTrend = trends['dissolvedOxygen']!;
      expect(doTrend.latestValue, equals(4.8));
      expect(doTrend.previousValue, equals(5.5));
      expect(doTrend.change, equals(-0.7));
      expect(doTrend.direction, equals('declining'));
      expect(doTrend.min7d, equals(4.8));
      expect(doTrend.max7d, equals(6.0));
    });

    test('Detects multi-parameter risk combinations (Ammonia + High pH, Rapid DO drop)', () {
      final now = DateTime.now();
      final logs = [
        WaterQualityLog(
          id: '1',
          pondId: 'pond_1',
          date: now,
          timeSlot: 'Afternoon',
          dissolvedOxygen: 3.5, // dropped from 5.2
          temperature: 33.0,
          ph: 8.7,
          ammonia: 0.2, // high ammonia + high pH
          createdAt: now,
        ),
        WaterQualityLog(
          id: '2',
          pondId: 'pond_1',
          date: now.subtract(const Duration(hours: 6)),
          timeSlot: 'Morning',
          dissolvedOxygen: 5.2,
          temperature: 29.0,
          ph: 8.0,
          ammonia: 0.1,
          createdAt: now.subtract(const Duration(hours: 6)),
        ),
      ];

      final alerts = WaterQualityEngine.detectRiskAlerts(logs);
      expect(alerts.isNotEmpty, isTrue);

      // Verify ammonia + pH alert
      final ammoniaAlert = alerts.firstWhere((a) => a.title.contains('Ammonia'));
      expect(ammoniaAlert.severity, equals(WqStatus.critical));
      expect(ammoniaAlert.why, contains('pH rises'));

      // Verify rapid DO drop alert
      final doDropAlert = alerts.firstWhere((a) => a.title.contains('Rapid DO'));
      expect(doDropAlert.message, contains('dropped by 1.7'));
    });
  });

  group('Phase B: PopulationEngine Tests', () {
    test('Calculates population balance and reconciliation variance vs sampling', () {
      final batch = Batch(
        id: 'batch_1',
        pondId: 'pond_1',
        batchNumber: 1,
        species: 'Litopenaeus vannamei',
        stockingDate: DateTime.now().subtract(const Duration(days: 45)),
        shrimpStockedCount: 100000,
        plStage: 'PL-10',
        seedCost: 40000.0,
        targetHarvestWeightG: 25.0,
        status: 'active',
        hapaStockedCount: 100,
        targetDoc: 93,
        createdAt: DateTime.now(),
      );

      final mortalities = [
        MortalityRecord(
          id: 'm1',
          batchId: 'batch_1',
          pondId: 'pond_1',
          date: DateTime.now().subtract(const Duration(days: 5)),
          countObserved: 1200,
          countEstimated: 800,
          reason: 'normal',
          createdAt: DateTime.now(),
        ),
      ];

      final adjustments = [
        PopulationAdjustment(
          id: 'adj1',
          batchId: 'batch_1',
          date: DateTime.now().subtract(const Duration(days: 2)),
          adjustedCount: 97000,
          previousCount: 98000,
          differenceCount: -1000,
          reason: 'sampling_correction',
          source: 'manual',
          createdAt: DateTime.now(),
        ),
      ];

      // Estimated remaining = 100,000 - 2,000 (mortality) - 1,000 (adj) = 97,000
      // Sampling estimate: Biomass 1700 kg, ABW 18.0g -> (1700 * 1000) / 18 = 94,444
      final summary = PopulationEngine.calculatePopulationSummary(
        batch: batch,
        mortalityRecords: mortalities,
        adjustments: adjustments,
        latestBiomassKg: 1700.0,
        latestAbwGrams: 18.0,
      );

      expect(summary.stockedCount, equals(100000));
      expect(summary.totalMortality, equals(2000));
      expect(summary.netAdjustments, equals(-1000));
      expect(summary.estimatedRemainingPopulation, equals(97000));
      expect(summary.samplingEstimatedPopulation, equals(94444));
      expect(summary.reconciliationDifference, equals(2556));
      expect(summary.varianceStatus, equals(PopulationVarianceStatus.normal)); // 2.6% variance
      expect(summary.reconciledSurvivalPct, equals(97.0));
    });

    test('Triggers daily mortality spike alert when loss exceeds threshold', () {
      final now = DateTime.now();
      final mortalities = [
        MortalityRecord(
          id: 'm_today',
          batchId: 'batch_1',
          pondId: 'pond_1',
          date: now,
          countObserved: 400,
          countEstimated: 200, // Total 600 out of 80,000 = 0.75%
          reason: 'stress',
          createdAt: now,
        ),
      ];

      final alerts = PopulationEngine.detectMortalityAlerts(
        mortalityRecords: mortalities,
        currentPopulation: 80000,
        latestDO: 3.2,
      );

      expect(alerts.isNotEmpty, isTrue);
      final spikeAlert = alerts.firstWhere((a) => a.title.contains('Critical Mortality Spike'));
      expect(spikeAlert.severity, equals('critical'));
      expect(spikeAlert.message, contains('600 dead shrimp'));
    });
  });

  group('Phase B: PondOperationsEngine Tests', () {
    test('Calculates pond capacity and exchange volume percentages accurately', () {
      final pond = Pond(
        id: 'pond_1',
        name: 'Pond 1',
        areaSqMeters: 4000.0,
        waterDepthMeters: 1.5,
        aeratorsCount: 4,
        totalAeratorHp: 8.0,
        status: 'active',
        createdAt: DateTime.now(),
      );

      // Volume = 4000 * 1.5 * 1000 = 6,000,000 Liters (6,000 m3)
      final metrics = PondOperationsEngine.calculatePondCapacity(pond);
      expect(metrics.totalPondCapacityM3, equals(6000.0));
      expect(metrics.totalPondCapacityLiters, equals(6000000.0));

      // 10% exchange in liters
      final liters10Pct = PondOperationsEngine.calculateLitersFromPercentage(pond, 10.0);
      expect(liters10Pct, equals(600000.0));

      // 1,200,000 Liters in percentage
      final pct = PondOperationsEngine.calculatePercentageFromLiters(pond, 1200000.0);
      expect(pct, equals(20.0));
    });

    test('Analyzes water exchange pre and post WQ impact', () {
      final opDate = DateTime(2026, 9, 8, 14, 0);
      final op = PondOperation(
        id: 'op_1',
        pondId: 'pond_1',
        date: opDate,
        operationType: 'exchange',
        volumeLiters: 600000.0,
        percentageExchanged: 10.0,
        createdAt: opDate,
      );

      final wqLogs = [
        WaterQualityLog(
          id: 'pre',
          pondId: 'pond_1',
          date: opDate.subtract(const Duration(hours: 4)),
          timeSlot: 'Morning',
          ammonia: 0.4,
          dissolvedOxygen: 4.0,
          createdAt: opDate.subtract(const Duration(hours: 4)),
        ),
        WaterQualityLog(
          id: 'post',
          pondId: 'pond_1',
          date: opDate.add(const Duration(hours: 12)),
          timeSlot: 'Morning',
          ammonia: 0.15,
          dissolvedOxygen: 5.2,
          createdAt: opDate.add(const Duration(hours: 12)),
        ),
      ];

      final impact = PondOperationsEngine.analyzeExchangeImpact(
        operation: op,
        wqLogs: wqLogs,
      );

      expect(impact.preAmmonia, equals(0.4));
      expect(impact.postAmmonia, equals(0.15));
      // (0.4 - 0.15) / 0.4 = 62.5% reduction
      expect(impact.ammoniaReductionPct, equals(62.5));
      expect(impact.narrative, contains('Ammonia reduced by 62.5%'));
    });
  });
}
