import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift hide isNull, isNotNull;
import 'package:aqualog/app/app.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNull, isNotNull;
import 'package:aqualog/core/providers/database_provider.dart';
import 'package:aqualog/core/providers/settings_provider.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Onboarding & Persistence Tests', () {
    testWidgets('Fresh install shows Onboarding screen asking ONLY for name', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());

      // Ensure fresh state: zero user profiles
      final initialProfile = await db.getUserProfile();
      expect(initialProfile, isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const AquaLogApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify onboarding screen is presented
      expect(find.text('Welcome to AquaLog'), findsOneWidget);
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Enter user name
      await tester.enterText(find.byType(TextField), 'Rao Aquaculture');
      await tester.pump();

      // Scroll to Continue button if needed and tap
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify profile is saved persistently in SQLite
      final savedProfile = await db.getUserProfile();
      expect(savedProfile, isNotNull);
      expect(savedProfile!.name, equals('Rao Aquaculture'));

      // Verify transition to main app dashboard
      expect(find.text('AquaLog'), findsWidgets);
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Manage'), findsWidgets);

      await db.close();
    });

    test('UserProfile persists across queries and updates', () async {
      final db = AppDatabase(NativeDatabase.memory());

      expect(await db.getUserProfile(), isNull);
      await db.saveUserProfile('Srikanth Varma');

      final profile = await db.getUserProfile();
      expect(profile, isNotNull);
      expect(profile!.name, equals('Srikanth Varma'));

      // Update name
      await db.saveUserProfile('Srikanth Varma & Sons');
      final updated = await db.getUserProfile();
      expect(updated!.name, equals('Srikanth Varma & Sons'));

      await db.close();
    });
  });

  group('Core Farm Hierarchy & Atomic Inventory Tests', () {
    test('Site -> Pond -> Batch relationship and Feed stock consumption', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1. Create Site
      const siteId = 'site_kakinada_01';
      await db.into(db.farmSites).insert(
        FarmSitesCompanion(
          id: const drift.Value(siteId),
          name: const drift.Value('Green Aqua Coastal'),
          villageCity: const drift.Value('Kakinada'),
          district: const drift.Value('East Godavari'),
          state: const drift.Value('Andhra Pradesh'),
          waterSource: const drift.Value('brackish_estuary'),
          latitude: const drift.Value(16.989),
          longitude: const drift.Value(82.247),
        ),
      );

      final sites = await db.select(db.farmSites).get();
      expect(sites.length, equals(1));
      expect(sites.first.name, equals('Green Aqua Coastal'));

      // 2. Create Pond locked to parent Site
      const pondId = 'pond_basin_01';
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: const drift.Value(pondId),
          siteId: const drift.Value(siteId),
          name: const drift.Value('Pond-01'),
          areaSqMeters: const drift.Value(4000.0),
          waterDepthMeters: const drift.Value(1.5),
          aeratorsCount: const drift.Value(6),
          totalAeratorHp: const drift.Value(12.0),
          status: const drift.Value('active'),
        ),
      );

      final ponds = await db.select(db.ponds).get();
      expect(ponds.length, equals(1));
      expect(ponds.first.siteId, equals(siteId));

      // 3. Stock Batch under Pond
      const batchId = 'batch_2026_01';
      await db.into(db.batches).insert(
        BatchesCompanion(
          id: const drift.Value(batchId),
          pondId: const drift.Value(pondId),
          batchNumber: const drift.Value(1),
          species: const drift.Value('Litopenaeus vannamei'),
          stockingDate: drift.Value(DateTime.now().subtract(const Duration(days: 30))),
          shrimpStockedCount: const drift.Value(120000),
          status: const drift.Value('active'),
        ),
      );

      final batches = await db.select(db.batches).get();
      expect(batches.length, equals(1));
      expect(batches.first.pondId, equals(pondId));

      // 4. Create Physical Feed Stock (Rule 28 & 29)
      const feedItemId = 'feed_cp_grower_01';
      await db.createInventoryItemTransaction(
        item: InventoryItemsCompanion(
          id: const drift.Value(feedItemId),
          siteId: const drift.Value(siteId),
          name: const drift.Value('CP Aqua 40% Grower'),
          category: const drift.Value('feed'),
          brand: const drift.Value('CP'),
          pelletSize: const drift.Value('2.0mm'),
          unit: const drift.Value('kg'),
          currentStock: const drift.Value(120.0), // 120 kg
          costPerUnit: const drift.Value(95.0),
        ),
        initialStock: 120.0,
        unitCost: 95.0,
      );

      var feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feedItemId))).getSingle();
      expect(feedItem.currentStock, equals(120.0));

      // 5. Atomic Feed Session Logging (15 kg consumed)
      await db.logFeedSessionTransaction(
        feedRecord: FeedRecordsCompanion(
          id: const drift.Value('feed_rec_01'),
          batchId: const drift.Value(batchId),
          pondId: const drift.Value(pondId),
          date: drift.Value(DateTime.now()),
          timeSlot: const drift.Value('7:00 AM'),
          starterG: const drift.Value(0.0),
          grower1G: const drift.Value(0.0),
          grower2G: const drift.Value(0.0),
          finisher1G: const drift.Value(0.0),
          finisher2G: const drift.Value(0.0),
          otherFeedName: const drift.Value('CP Aqua 40% Grower'),
          otherFeedG: const drift.Value(15000.0),
          totalGrams: const drift.Value(15000.0),
          totalKg: const drift.Value(15.0),
          trayChecked: const drift.Value(true),
          trayLeftoverPct: const drift.Value(0),
        ),
        feedDeductions: [
          {
            'itemId': feedItemId,
            'qtyKg': 15.0,
            'pelletSize': '2.0mm',
          }
        ],
      );

      // Verify stock was decremented from 120 kg to 105 kg
      feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feedItemId))).getSingle();
      expect(feedItem.currentStock, equals(105.0));

      // Verify transaction ledger was created
      final txs = await (db.select(db.inventoryTransactions)..where((t) => t.itemId.equals(feedItemId))).get();
      expect(txs.length, equals(2)); // 1 inward purchase + 1 consumption
      expect(txs.last.type, equals('consumption'));
      expect(txs.last.quantity, equals(-15.0));

      // 6. Insufficient Stock Safety Test (Rule 36)
      // Attempting to consume 200 kg when only 105 kg available
      expect(
        () async => await db.logFeedSessionTransaction(
          feedRecord: FeedRecordsCompanion(
            id: const drift.Value('feed_rec_invalid'),
            batchId: const drift.Value(batchId),
            pondId: const drift.Value(pondId),
            date: drift.Value(DateTime.now()),
            timeSlot: const drift.Value('11:00 AM'),
            starterG: const drift.Value(0.0),
            grower1G: const drift.Value(0.0),
            grower2G: const drift.Value(0.0),
            finisher1G: const drift.Value(0.0),
            finisher2G: const drift.Value(0.0),
            totalGrams: const drift.Value(200000.0),
            totalKg: const drift.Value(200.0),
          ),
          feedDeductions: [
            {
              'itemId': feedItemId,
              'qtyKg': 200.0,
              'pelletSize': '2.0mm',
            }
          ],
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      // Stock must remain unchanged after rollback (Rule 35)
      feedItem = await (db.select(db.inventoryItems)..where((t) => t.id.equals(feedItemId))).getSingle();
      expect(feedItem.currentStock, equals(105.0));

      await db.close();
    });
  });
}
