import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/calculations/harvest_decision_engine.dart';
import 'package:aqualog/core/calculations/reorder_assistant_engine.dart';

void main() {
  group('Phase D: Harvest Decision Engine', () {
    test('Calculates and compares Now, +7d, and +14d harvest scenarios', () {
      final report = HarvestDecisionEngine.evaluateScenarios(
        currentDoc: 75,
        currentAbwGrams: 20.0,
        currentPopulation: 100000,
        currentBiomassKg: 2000.0,
        historicalExpenses: 450000.0,
        targetWeightGrams: 25.0,
        currentAdgGramsPerDay: 0.30,
        feedCostPerKg: 90.0,
      );

      expect(report.scenarios.length, equals(3));
      final nowScenario = report.scenarios[0];
      final plus7Scenario = report.scenarios[1];
      final plus14Scenario = report.scenarios[2];

      expect(nowScenario.daysFromNow, equals(0));
      expect(nowScenario.projectedAbwGrams, equals(20.0));
      expect(nowScenario.projectedMarketPricePerKg, equals(350.0));

      expect(plus7Scenario.daysFromNow, equals(7));
      expect(plus7Scenario.projectedAbwGrams, greaterThan(20.0));
      expect(plus7Scenario.additionalFeedKg, greaterThan(0));

      expect(plus14Scenario.daysFromNow, equals(14));
      expect(plus14Scenario.projectedAbwGrams, greaterThan(plus7Scenario.projectedAbwGrams));

      // There must be one recommended scenario
      expect(report.scenarios.where((s) => s.isRecommended).length, equals(1));
      expect(report.decisionExplanation.isNotEmpty, isTrue);
    });

    test('Assigns correct market price slabs based on count and ABW', () {
      expect(HarvestDecisionEngine.getMarketPriceForAbw(34.0), equals(460.0)); // 30 count
      expect(HarvestDecisionEngine.getMarketPriceForAbw(25.0), equals(390.0)); // 40 count
      expect(HarvestDecisionEngine.getMarketPriceForAbw(20.0), equals(350.0)); // 50 count
      expect(HarvestDecisionEngine.getMarketPriceForAbw(14.0), equals(250.0));
      expect(HarvestDecisionEngine.getMarketPriceForAbw(10.0), equals(200.0));
    });
  });

  group('Phase D: Inventory Reorder Assistant Engine', () {
    test('Calculates burn rate, reorder point, and triggers ORDER NOW when stock is low', () {
      final now = DateTime.now();
      final item = InventoryItem(
        id: 'feed_1',
        category: 'feed',
        name: 'Starter Feed 0.8mm',
        unit: 'kg',
        bagWeightKg: 25.0,
        currentStock: 120.0, // Low
        lowStockThreshold: 50.0,
        costPerUnit: 92.0,
        createdAt: now.subtract(const Duration(days: 30)),
      );

      // Past 14 days consumption: 14 sessions of 40kg = 560kg / 14 = 40 kg/day
      final txs = List<InventoryTransaction>.generate(
        14,
        (i) => InventoryTransaction(
          id: 'tx_$i',
          itemId: 'feed_1',
          type: 'consumption',
          quantity: -40.0,
          unitPrice: 92.0,
          totalCost: 3680.0,
          date: now.subtract(Duration(days: i)),
          createdAt: now.subtract(Duration(days: i)),
        ),
      );

      final burnRate = ReorderAssistantEngine.calculateDailyBurnRate(txs);
      expect(burnRate, equals(40.0));

      final forecast = ReorderAssistantEngine.forecastItem(
        item: item,
        itemTransactions: txs,
        customLeadTimeDays: 3,
        customSafetyStockDays: 3.0,
      );

      // Daily usage = 40 kg/day
      // Days remaining = 120 / 40 = 3.0 days
      // Lead time = 3 days (120kg), Safety stock = 3 days (120kg)
      // Reorder point = (40 * 3) + 120 = 240 kg
      // Since stock (120) <= reorderPoint (240) -> ORDER NOW!
      expect(forecast.dailyBurnRate, equals(40.0));
      expect(forecast.projectedDaysRemaining, equals(3.0));
      expect(forecast.reorderPointQty, equals(240.0));
      expect(forecast.urgency, equals(ReorderUrgency.orderNow));
      expect(forecast.suggestedOrderQty, greaterThan(0));
    });

    test('Detects expiry risk when item projected to outlast expiry date', () {
      final now = DateTime.now();
      final item = InventoryItem(
        id: 'med_1',
        category: 'medicine',
        name: 'Probiotic Water Guard',
        unit: 'L',
        bagWeightKg: 1.0,
        currentStock: 100.0,
        lowStockThreshold: 10.0,
        costPerUnit: 450.0,
        expiryDate: now.add(const Duration(days: 20)), // Expires in 20 days
        createdAt: now.subtract(const Duration(days: 60)),
      );

      // Usage is only 1 L/day -> 100 days to consume, but expires in 20 days
      final txs = <InventoryTransaction>[
        InventoryTransaction(
          id: 'tx_med',
          itemId: 'med_1',
          type: 'consumption',
          quantity: -14.0, // 14L over 14 days = 1L/day
          unitPrice: 450.0,
          totalCost: 6300.0,
          date: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 5)),
        ),
      ];

      final forecast = ReorderAssistantEngine.forecastItem(
        item: item,
        itemTransactions: txs,
      );

      expect(forecast.dailyBurnRate, equals(1.0));
      expect(forecast.projectedDaysRemaining, equals(100.0));
      expect(forecast.hasExpiryRisk, isTrue);
      expect(forecast.advice, contains('outlast expiry date'));
    });

    test('Generates prioritized urgent procurement list', () {
      final now = DateTime.now();
      final itemCrit = InventoryItem(
        id: 'crit_item',
        category: 'feed',
        name: 'Finisher 2.0mm',
        unit: 'kg',
        bagWeightKg: 25.0,
        currentStock: 0.0, // Out of stock
        lowStockThreshold: 100.0,
        costPerUnit: 90.0,
        createdAt: now,
      );

      final itemNormal = InventoryItem(
        id: 'norm_item',
        category: 'fuel',
        name: 'Diesel',
        unit: 'L',
        bagWeightKg: 1.0,
        currentStock: 500.0, // Optimal
        lowStockThreshold: 50.0,
        costPerUnit: 94.0,
        createdAt: now,
      );

      final list = ReorderAssistantEngine.generateProcurementList(
        [itemCrit, itemNormal],
        {},
      );

      expect(list.length, equals(1));
      expect(list.first.item.id, equals('crit_item'));
      expect(list.first.urgency, equals(ReorderUrgency.outOfStock));
    });
  });
}
