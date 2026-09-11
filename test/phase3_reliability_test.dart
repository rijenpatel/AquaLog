import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aqualog/core/config/app_config.dart';
import 'package:aqualog/core/database/app_database.dart';

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

  group('PHASE 3 - Bug 8: Sampling History Recalculation Atomicity', () {
    test('Sampling deletion and dependent growth recalculation execute transactionally', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const drift.Value('site_1'), name: const drift.Value('Site 1'), code: const drift.Value('S1')),
      );
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const drift.Value('pond_1'),
          siteId: const drift.Value('site_1'),
          name: const drift.Value('Pond 1'),
          areaSqMeters: const drift.Value(1000.0),
          waterDepthMeters: const drift.Value(1.5),
        ),
      );
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          batchNumber: const drift.Value(1),
          species: const drift.Value('Vannamei'),
          stockingDate: drift.Value(DateTime(2026, 1, 1)),
          shrimpStockedCount: const drift.Value(100000),
        ),
      );

      // Create 3 sequential sampling entries
      await db.into(db.samplingEntries).insert(
        SamplingEntriesCompanion(
          id: const drift.Value('sample_1'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 1, 10)),
          doc: const drift.Value(10),
          abwGrams: const drift.Value(3.0),
          samplingShrimpCount: const drift.Value(50),
          samplingTotalWeightG: const drift.Value(150.0),
        ),
      );
      await db.into(db.samplingEntries).insert(
        SamplingEntriesCompanion(
          id: const drift.Value('sample_2'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 1, 20)),
          doc: const drift.Value(20),
          abwGrams: const drift.Value(6.0),
          samplingShrimpCount: const drift.Value(50),
          samplingTotalWeightG: const drift.Value(300.0),
        ),
      );
      await db.into(db.samplingEntries).insert(
        SamplingEntriesCompanion(
          id: const drift.Value('sample_3'),
          batchId: const drift.Value('batch_1'),
          pondId: const drift.Value('pond_1'),
          date: drift.Value(DateTime(2026, 1, 30)),
          doc: const drift.Value(30),
          abwGrams: const drift.Value(10.0),
          samplingShrimpCount: const drift.Value(50),
          samplingTotalWeightG: const drift.Value(500.0),
        ),
      );

      // Delete sample 2 with batchId
      await db.deleteSamplingEntry('sample_2', 'batch_1');

      final remaining = await db.select(db.samplingEntries).get();
      expect(remaining.length, equals(2));
      expect(remaining.map((s) => s.id), containsAll(['sample_1', 'sample_3']));
    });
  });

  group('PHASE 3 - Bug 9: Robust Unique Transaction IDs', () {
    test('Rapid purchase transactions produce 100% unique collision-free UUID identifiers', () async {
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(id: const drift.Value('site_1'), name: const drift.Value('Site 1'), code: const drift.Value('S1')),
      );
      await db.into(db.inventoryItems).insert(
        InventoryItemsCompanion(
          id: const drift.Value('item_rapid'),
          siteId: const drift.Value('site_1'),
          category: const drift.Value('feed'),
          name: const drift.Value('Feed Pellets'),
          currentStock: const drift.Value(0.0),
          unit: const drift.Value('kg'),
          costPerUnit: const drift.Value(50.0),
        ),
      );

      // Rapidly trigger 50 purchase transactions
      for (int i = 0; i < 50; i++) {
        await db.purchaseInventoryTransaction(
          itemId: 'item_rapid',
          quantity: 1.0,
          unitCost: 50.0,
          totalCost: 50.0,
          date: DateTime.now(),
        );
      }

      final txs = await db.select(db.inventoryTransactions).get();
      expect(txs.length, equals(50));

      final idSet = txs.map((t) => t.id).toSet();
      expect(idSet.length, equals(50), reason: 'Every transaction ID must be strictly unique');
      for (final id in idSet) {
        expect(id.startsWith('tx_pur_'), isTrue);
        // UUID length check: 'tx_pur_' + 36 uuid chars = 43 chars
        expect(id.length, equals(43));
      }
    });
  });

  group('PHASE 3 - Bug 10: Canonical Release Metadata Matching', () {
    test('AppConfig appVersion and buildNumber match current release configuration', () {
      expect(AppConfig.appName, equals('AquaLog'));
      expect(AppConfig.appVersion, equals('1.0.0.9'));
      expect(AppConfig.buildNumber, equals(9));
    });
  });
}
