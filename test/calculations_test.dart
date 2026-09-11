import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/calculations/calculations.dart';

void main() {
  group('1. DocCalculator Tests', () {
    test('DOC is 1 on stocking date', () {
      final stocking = DateTime(2026, 9, 1);
      final result = DocCalculator.calculate(stockingDate: stocking, targetDate: stocking);
      expect(result.doc, 1);
      expect(result.isFutureDate, isFalse);
      expect(result.stage, LifecycleStage.nursery);
    });

    test('DOC is 1 with warning if stocking date is in the future', () {
      final now = DateTime(2026, 9, 1);
      final future = DateTime(2026, 9, 10);
      final result = DocCalculator.calculate(stockingDate: future, targetDate: now);
      expect(result.doc, 1);
      expect(result.isFutureDate, isTrue);
      expect(result.warning, isNotNull);
    });

    test('DOC calculates accurately across dates and maps lifecycle stages', () {
      final stocking = DateTime(2026, 6, 1);
      // 68 days later:
      final target = DateTime(2026, 8, 8);
      final result = DocCalculator.calculate(stockingDate: stocking, targetDate: target);
      expect(result.doc, 69);
      expect(result.stage, LifecycleStage.growoutMid);

      expect(DocCalculator.getLifecycleStage(10), LifecycleStage.nursery);
      expect(DocCalculator.getLifecycleStage(35), LifecycleStage.growoutEarly);
      expect(DocCalculator.getLifecycleStage(75), LifecycleStage.growoutMid);
      expect(DocCalculator.getLifecycleStage(105), LifecycleStage.finishing);
      expect(DocCalculator.getLifecycleStage(125), LifecycleStage.harvestReady);
    });
  });

  group('2. AbwCalculator Tests', () {
    test('Calculates live ABW correctly and rounds to 2 decimals', () {
      final res = AbwCalculator.calculate(totalWeightGrams: 475.5, count: 25);
      expect(res.abwGrams, 19.02);
      expect(res.formatted, '19.020');
    });

    test('Throws on invalid count or weight', () {
      expect(() => AbwCalculator.calculate(totalWeightGrams: 100, count: 0), throwsArgumentError);
      expect(() => AbwCalculator.calculate(totalWeightGrams: 0, count: 10), throwsArgumentError);
    });
  });

  group('3. AdgCalculator Tests', () {
    test('Calculates ADG and evaluates performance brackets', () {
      final curDate = DateTime(2026, 9, 8);
      final prevDate = DateTime(2026, 9, 1);
      final res = AdgCalculator.calculate(
        currentAbwGrams: 19.02,
        previousAbwGrams: 16.92,
        currentDate: curDate,
        previousDate: prevDate,
      );
      expect(res.weightGainGrams, 2.10);
      expect(res.daysElapsed, 7);
      expect(res.adgGramsPerDay, 0.30);
      expect(res.evaluation, AdgEvaluation.excellent);
    });

    test('Identifies stalling alert when ADG is below 0.10', () {
      final res = AdgCalculator.calculate(
        currentAbwGrams: 15.2,
        previousAbwGrams: 15.0,
        currentDate: DateTime(2026, 9, 8),
        previousDate: DateTime(2026, 9, 1),
      );
      expect(res.adgGramsPerDay, closeTo(0.028, 0.005));
      expect(res.evaluation, AdgEvaluation.stallingAlert);
    });
  });

  group('4. HapaSurvivalCalculator Tests', () {
    test('Calculates survival % and projected population', () {
      final res = HapaSurvivalCalculator.calculate(
        hapaStocked: 100,
        hapaAlive: 96,
        batchStockedCount: 120000,
      );
      expect(res.survivalPercentage, 96.0);
      expect(res.estimatedPopulation, 115200);
    });

    test('Validates hapa alive cannot exceed stocked', () {
      expect(
        () => HapaSurvivalCalculator.calculate(
          hapaStocked: 100,
          hapaAlive: 105,
          batchStockedCount: 100000,
        ),
        throwsArgumentError,
      );
    });
  });

  group('5. BiomassCalculator Tests', () {
    test('Prioritizes Sampling ABW over visual estimation', () {
      final res = BiomassCalculator.calculate(
        estimatedPopulation: 115200,
        samplingAbwGrams: 19.02,
        visualAbwGrams: 18.0,
      );
      expect(res, isNotNull);
      expect(res!.source, BiomassSource.sampling);
      expect(res.biomassKg, 2191.1);
      expect(res.warning, isNull);
    });

    test('Falls back to visual ABW with warning flag when sampling ABW is absent', () {
      final res = BiomassCalculator.calculate(
        estimatedPopulation: 100000,
        samplingAbwGrams: null,
        visualAbwGrams: 15.0,
      );
      expect(res, isNotNull);
      expect(res!.source, BiomassSource.visual);
      expect(res.biomassKg, 1500.0);
      expect(res.warning, isNotNull);
    });

    test('Returns null if population or all ABWs are missing', () {
      expect(BiomassCalculator.calculate(estimatedPopulation: null, samplingAbwGrams: 15.0, visualAbwGrams: null), isNull);
      expect(BiomassCalculator.calculate(estimatedPopulation: 100000, samplingAbwGrams: null, visualAbwGrams: null), isNull);
    });
  });

  group('6. FcrCalculator Tests', () {
    test('Calculates period FCR accurately', () {
      final res = FcrCalculator.calculatePeriodFcr(
        feedFedKg: 650.0,
        biomass1Kg: 1500.0,
        biomass2Kg: 2000.0,
      );
      expect(res.isUndefined, isFalse);
      expect(res.fcr, 1.30);
    });

    test('Handles non-positive biomass gain edge case as undefined', () {
      final res = FcrCalculator.calculatePeriodFcr(
        feedFedKg: 400.0,
        biomass1Kg: 2000.0,
        biomass2Kg: 1950.0, // mortality / weight drop
      );
      expect(res.isUndefined, isTrue);
      expect(res.fcr, isNull);
      expect(res.formatted, 'N/A');
    });

    test('Calculates cumulative FCR', () {
      final res = FcrCalculator.calculateCumulativeFcr(
        totalFeedKg: 3185.0,
        biomassOrHarvestKg: 2450.0,
      );
      expect(res.fcr, 1.30);
    });
  });

  group('7. CheckTrayEngine Tests', () {
    test('0% leftover recommends feed increase', () {
      final rec = CheckTrayEngine.evaluate(0);
      expect(rec.status, CheckTrayStatus.clean);
      expect(rec.adjustmentPercentage, 7.5);
      final nextQty = CheckTrayEngine.calculateAdjustedQuantity(baseQuantityGrams: 5000, recommendation: rec);
      expect(nextQty, 5375.0);
    });

    test('1-10% leftover maintains feed equilibrium', () {
      final rec = CheckTrayEngine.evaluate(8);
      expect(rec.status, CheckTrayStatus.normal);
      expect(rec.adjustmentPercentage, 0.0);
    });

    test('11-25% leftover recommends moderate cut', () {
      final rec = CheckTrayEngine.evaluate(20);
      expect(rec.status, CheckTrayStatus.moderate);
      expect(rec.adjustmentPercentage, -12.5);
    });

    test('>25% leftover triggers emergency cut alert', () {
      final rec = CheckTrayEngine.evaluate(35);
      expect(rec.status, CheckTrayStatus.surplus);
      expect(rec.adjustmentPercentage, -40.0);
    });
  });

  group('8. WeatherFeedEngine Tests', () {
    test('Evaluates heat stress at >= 34°C', () {
      final rec = WeatherFeedEngine.evaluate(temperature: 35.5);
      expect(rec.status, WeatherRiskStatus.highTemp);
      expect(rec.feedAdjustmentFactor, 0.75);
    });

    test('Evaluates low temp metabolism slowdown at <= 26°C', () {
      final rec = WeatherFeedEngine.evaluate(temperature: 24.0);
      expect(rec.status, WeatherRiskStatus.lowTemp);
      expect(rec.feedAdjustmentFactor, 0.80);
    });

    test('Evaluates rain shock risk when rain >= 70%', () {
      final rec = WeatherFeedEngine.evaluate(temperature: 29.0, rainProbability: 85.0);
      expect(rec.status, WeatherRiskStatus.rainRisk);
      expect(rec.feedAdjustmentFactor, 0.70);
    });

    test('Evaluates humidity DO collapse risk', () {
      final rec = WeatherFeedEngine.evaluate(temperature: 31.0, humidity: 88.0, rainProbability: 20.0);
      expect(rec.status, WeatherRiskStatus.humidityRisk);
      expect(rec.feedAdjustmentFactor, 0.85);
    });

    test('Evaluates normal feeding window', () {
      final rec = WeatherFeedEngine.evaluate(temperature: 29.0, humidity: 65.0, rainProbability: 10.0);
      expect(rec.status, WeatherRiskStatus.normal);
      expect(rec.feedAdjustmentFactor, 1.0);
    });
  });

  group('9. HealthScoreCalculator Tests', () {
    test('Calculates holistic 0-100 score across 4 pillars', () {
      final res = HealthScoreCalculator.calculate(
        sessionsLoggedLast7Days: 27, // 96% -> 35 pts
        loggedToday: true,           // +10
        loggedYesterday: true,       // +6
        loggedTwoDaysAgo: true,      // +4 -> 20 pts
        latestAdg: 0.30,             // >= 0.28 -> 25 pts
        hapaSurvivalPct: 94.0,       // >= 92% -> 20 pts
      );
      expect(res.consistencyScore, 35);
      expect(res.activityScore, 20);
      expect(res.growthScore, 25);
      expect(res.survivalScore, 20);
      expect(res.totalScore, 100);
      expect(res.grade, 'A+');
    });
  });

  group('10. HarvestPredictor Tests', () {
    test('Predicts days to harvest based on ADG', () {
      final now = DateTime(2026, 9, 1);
      final res = HarvestPredictor.calculate(
        currentAbwGrams: 18.0,
        targetWeightGrams: 25.0,
        currentAdgGramsPerDay: 0.25,
        currentDate: now,
      );
      // (25 - 18) / 0.25 = 28 days
      expect(res.daysToHarvest, 28);
      expect(res.predictedHarvestDate, DateTime(2026, 9, 29));
      expect(res.isBaselineAdgUsed, isFalse);
    });

    test('Uses baseline ADG 0.22 g/day when no samplings recorded', () {
      final res = HarvestPredictor.calculate(
        currentAbwGrams: 14.0,
        targetWeightGrams: 25.0,
        currentAdgGramsPerDay: null,
      );
      expect(res.isBaselineAdgUsed, isTrue);
      expect(res.adgUsedGramsPerDay, 0.22);
      expect(res.daysToHarvest, (11.0 / 0.22).ceil());
    });
  });

  group('11. WaterVolumeCalculator Tests', () {
    test('Calculates volume and aerator density', () {
      final res = WaterVolumeCalculator.calculate(
        areaSqMeters: 4000.0,
        waterDepthMeters: 1.5,
        totalAeratorHp: 16.0,
      );
      expect(res.areaHectares, 0.4);
      expect(res.volumeM3, 6000.0);
      expect(res.volumeLiters, 6000000.0);
      // 16 HP / 0.4 ha = 40 HP/ha
      expect(res.aeratorDensityHpPerHa, 40.0);
      expect(res.isAerationAdequate, isTrue);
      expect(res.aerationWarning, isNull);
    });

    test('Warns when aerator density < 20 HP/ha', () {
      final res = WaterVolumeCalculator.calculate(
        areaSqMeters: 10000.0, // 1 ha
        waterDepthMeters: 1.5,
        totalAeratorHp: 15.0, // 15 HP/ha < 20
      );
      expect(res.isAerationAdequate, isFalse);
      expect(res.aerationWarning, isNotNull);
    });
  });

  group('12. DosageCalculator Tests', () {
    test('Calculates chemical requirement from PPM', () {
      final res = DosageCalculator.calculateFromPpm(
        volumeM3: 6000.0,
        dosageRatePpm: 2.0,
      );
      expect(res.requiredProductKg, 12.0);
      expect(res.isPpmBased, isTrue);
    });

    test('Calculates agricultural lime from area rate (kg/ha)', () {
      final res = DosageCalculator.calculateFromAreaRate(
        areaHectares: 0.4,
        rateKgPerHa: 150.0,
      );
      expect(res.requiredProductKg, 60.0);
      expect(res.isPpmBased, isFalse);
    });
  });

  group('13. FuelEfficiencyCalculator Tests', () {
    test('Calculates generator fuel burned', () {
      final res = FuelEfficiencyCalculator.calculateConsumption(
        hoursRun: 8.0,
        burnRateLPerHr: 7.5,
      );
      expect(res.fuelConsumedLiters, 60.0);
    });

    test('Forecasts backup hours and warns when < 24h', () {
      final resNormal = FuelEfficiencyCalculator.calculateBackupHours(
        currentReserveLiters: 650.0,
        burnRateLPerHr: 7.5,
      );
      expect(resNormal.backupHoursRemaining, 86);
      expect(resNormal.isLowFuelWarning, isFalse);

      final resLow = FuelEfficiencyCalculator.calculateBackupHours(
        currentReserveLiters: 100.0,
        burnRateLPerHr: 7.5,
      );
      expect(resLow.backupHoursRemaining, 13);
      expect(resLow.isLowFuelWarning, isTrue);
    });

    test('Allocates energy cost by aerator HP', () {
      final cost = FuelEfficiencyCalculator.allocatePondEnergyCost(
        totalFarmEnergyExpense: 120000.0,
        pondAeratorHp: 20.0,
        totalFarmAeratorHp: 60.0,
      );
      expect(cost, 40000.0);
    });
  });

  group('14. BreakEvenCalculator Tests', () {
    test('Calculates break even price per kg', () {
      final res = BreakEvenCalculator.calculate(
        totalBatchCost: 908000.0,
        biomassOrHarvestWeightKg: 2800.0,
        currentMarketPricePerKg: 420.0,
      );
      expect(res.breakEvenPricePerKg, 324.29);
      expect(res.marginPerKg, 95.71);
      expect(res.isProfitableAtMarketPrice, isTrue);
    });
  });

  group('15. InventoryAnalytics Tests', () {
    test('Calculates daily burn rate and depletion forecast', () {
      final burnRate = InventoryAnalytics.calculateDailyBurnRate(595.0); // 595 / 7
      expect(burnRate, 85.0);

      final forecast = InventoryAnalytics.calculateDepletionForecast(
        currentStock: 2450.0,
        dailyBurnRate: burnRate,
      );
      expect(forecast.daysRemaining, 28);
      expect(forecast.isUrgentReorder, isFalse);
    });

    test('Triggers critical reorder when stock <= 3 days', () {
      final forecast = InventoryAnalytics.calculateDepletionForecast(
        currentStock: 150.0,
        dailyBurnRate: 75.0,
      );
      expect(forecast.daysRemaining, 2);
      expect(forecast.isCriticalReorder, isTrue);
    });

    test('Calculates stock turnover ratio and feed shrinkage %', () {
      final str = InventoryAnalytics.calculateStockTurnoverRatio(
        costOfGoodsUsed: 400000.0,
        beginningInventoryValue: 80000.0,
        endingInventoryValue: 120000.0,
      );
      expect(str, 4.0);

      final shrinkage = InventoryAnalytics.calculateFeedShrinkagePct(
        damagedAndSpoiledKg: 25.0,
        totalPurchasedKg: 2500.0,
      );
      expect(shrinkage, 1.0);
    });
  });
}
