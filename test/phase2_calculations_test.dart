import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:aqualog/core/calculations/feed_calculator.dart';
import 'package:aqualog/core/calculations/inventory_analytics.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PHASE 2 - Bug 5: Feed Bag Weight Normalization', () {
    test('Standard 25kg bag normalization', () {
      expect(FeedCalculator.normalizeFeedQuantityToKg(2.0, 'bags', bagWeightKg: 25.0), equals(50.0));
      expect(FeedCalculator.normalizeFeedQuantityToKg(1.0, 'bags', bagWeightKg: 25.0), equals(25.0));
      // Fallback default
      expect(FeedCalculator.normalizeFeedQuantityToKg(2.0, 'bags'), equals(50.0));
    });

    test('Configurable 30kg bag normalization', () {
      expect(FeedCalculator.normalizeFeedQuantityToKg(2.0, 'bags', bagWeightKg: 30.0), equals(60.0));
      expect(FeedCalculator.normalizeFeedQuantityToKg(1.5, 'bags', bagWeightKg: 30.0), equals(45.0));
    });

    test('Configurable 40kg bag normalization', () {
      expect(FeedCalculator.normalizeFeedQuantityToKg(2.0, 'bags', bagWeightKg: 40.0), equals(80.0));
    });

    test('FeedItem computes quantityKg accurately with custom bag weight', () {
      const item30 = FeedItem(
        feedName: 'Grower 30kg',
        quantity: 3.0,
        unit: 'bags',
        bagWeightKg: 30.0,
      );
      expect(item30.quantityKg, equals(90.0));

      const itemKg = FeedItem(
        feedName: 'Standard Kg Feed',
        quantity: 45.0,
        unit: 'kg',
      );
      expect(itemKg.quantityKg, equals(45.0));
    });
  });

  group('PHASE 2 - Bug 6: Inventory Valuation', () {
    test('calculateItemValuation handles kg, grams, and physical units consistently', () {
      // 50 kg at 90/kg = 4500
      expect(InventoryAnalytics.calculateItemValuation(currentStock: 50.0, costPerUnit: 90.0, unit: 'kg'), equals(4500.0));

      // 5000 grams at 90/kg = 450
      expect(InventoryAnalytics.calculateItemValuation(currentStock: 5000.0, costPerUnit: 90.0, unit: 'g'), equals(450.0));

      // Fuel: 20 L at 95/L = 1900
      expect(InventoryAnalytics.calculateItemValuation(currentStock: 20.0, costPerUnit: 95.0, unit: 'L'), equals(1900.0));

      // Medicine: 10 bottles at 400/bottle = 4000
      expect(InventoryAnalytics.calculateItemValuation(currentStock: 10.0, costPerUnit: 400.0, unit: 'bottle'), equals(4000.0));

      // Non-positive returns 0.0
      expect(InventoryAnalytics.calculateItemValuation(currentStock: -5.0, costPerUnit: 90.0), equals(0.0));
      expect(InventoryAnalytics.calculateItemValuation(currentStock: 50.0, costPerUnit: 0.0), equals(0.0));
    });
  });

  group('PHASE 2 - Bug 7: Overlapping Batch Periods Prevention', () {
    test('Detects period overlap within same pond and allows non-overlapping intervals', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const Value('site_1'), name: const Value('Site 1'), code: const Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('pond_1'),
          siteId: const Value('site_1'),
          name: const Value('Pond 1'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const Value('pond_2'),
          siteId: const Value('site_1'),
          name: const Value('Pond 2'),
          areaSqMeters: const Value(1000.0),
          waterDepthMeters: const Value(1.5),
        ),
      );

      // Batch A: Jan 1 -> Jun 30, completed
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const Value('batch_a'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(1),
          species: const Value('Vannamei'),
          stockingDate: Value(DateTime(2026, 1, 1)),
          harvestDate: Value(DateTime(2026, 6, 30)),
          status: const Value('completed'),
          shrimpStockedCount: const Value(50000),
        ),
      );

      // 1. Partial/Nested overlap with Batch A (June 15 -> Dec 31) in pond_1
      final overlapConflict = await db.checkBatchOverlap(
        pondId: 'pond_1',
        stockingDate: DateTime(2026, 6, 15),
        harvestDate: DateTime(2026, 12, 31),
      );
      expect(overlapConflict, isNotNull);
      expect(overlapConflict!.id, equals('batch_a'));

      // 2. Non-overlapping batch after June 30 (July 1 -> Dec 31) in pond_1
      final noConflict = await db.checkBatchOverlap(
        pondId: 'pond_1',
        stockingDate: DateTime(2026, 7, 1),
        harvestDate: DateTime(2026, 12, 31),
      );
      expect(noConflict, isNull);

      // 3. Same overlapping dates but in a DIFFERENT pond (pond_2) -> Allowed
      final diffPondNoConflict = await db.checkBatchOverlap(
        pondId: 'pond_2',
        stockingDate: DateTime(2026, 6, 15),
        harvestDate: DateTime(2026, 12, 31),
      );
      expect(diffPondNoConflict, isNull);

      // 4. Self-edit check: Batch A does not conflict with itself when excluded
      final selfEditNoConflict = await db.checkBatchOverlap(
        pondId: 'pond_1',
        stockingDate: DateTime(2026, 1, 1),
        harvestDate: DateTime(2026, 6, 30),
        excludeBatchId: 'batch_a',
      );
      expect(selfEditNoConflict, isNull);
    });
  });
}
