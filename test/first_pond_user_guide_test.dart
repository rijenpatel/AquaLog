import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:aqualog/features/manage/widgets/first_pond_user_guide.dart';
import 'package:aqualog/features/manage/widgets/first_pond_tutorial_page.dart';
import 'package:aqualog/core/database/app_database.dart' hide isNotNull;
import 'package:aqualog/core/providers/database_provider.dart';

void main() {
  group('First Pond User Guide Feature Tests', () {
    test('Standard presets contain valid aquaculture parameters', () {
      expect(PondPreset.standardPresets.length, equals(4));

      final acrePreset = PondPreset.standardPresets.firstWhere((p) => p.title.contains('1.0 Acre'));
      expect(acrePreset.areaValue, equals(1.0));
      expect(acrePreset.areaUnit, equals('Acres'));
      expect(acrePreset.depthMeters, equals(1.5));
      expect(acrePreset.aeratorUnits, equals(4));
      expect(acrePreset.totalHp, equals(8.0));

      final hectarePreset = PondPreset.standardPresets.firstWhere((p) => p.title.contains('Hectare'));
      expect(hectarePreset.areaValue, equals(1.0));
      expect(hectarePreset.areaUnit, equals('Hectares'));
      expect(hectarePreset.depthMeters, equals(1.6));
      expect(hectarePreset.aeratorUnits, equals(8));
      expect(hectarePreset.totalHp, equals(16.0));
    });

    testWidgets('FirstPondUserGuideCard renders tutorial banner, roadmap steps, and triggers callbacks', (tester) async {
      bool tutorialStarted = false;
      PondPreset? selectedPreset;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstPondUserGuideCard(
                onStartTutorial: () {
                  tutorialStarted = true;
                },
                onApplyPreset: (preset) {
                  selectedPreset = preset;
                },
              ),
            ),
          ),
        ),
      );

      // Verify Header & Step titles
      expect(find.text('Step-by-Step Pond Tutorial'), findsOneWidget);
      expect(find.text('GUIDED'), findsOneWidget);
      expect(find.text('Start Step-by-Step Tutorial'), findsOneWidget);
      expect(find.text('Basin Identifier'), findsOneWidget);
      expect(find.text('Surface Area & Sizing'), findsOneWidget);
      expect(find.text('Water Depth & Volume'), findsOneWidget);
      expect(find.text('Aeration Power (Paddlewheels)'), findsOneWidget);
      expect(find.text('Review & Register Basin'), findsOneWidget);

      // Verify Preset Action Chips are present
      expect(find.text('1.0 Acre Commercial'), findsOneWidget);
      expect(find.text('0.5 Acre Intensive'), findsOneWidget);

      // Tap tutorial button
      await tester.tap(find.text('Start Step-by-Step Tutorial'));
      await tester.pump();
      expect(tutorialStarted, isTrue);

      // Tap the 1.0 Acre preset
      await tester.tap(find.text('1.0 Acre Commercial'));
      await tester.pump();

      expect(selectedPreset, isNotNull);
      expect(selectedPreset!.title, equals('1.0 Acre Commercial'));
      expect(selectedPreset!.areaValue, equals(1.0));
      expect(selectedPreset!.depthMeters, equals(1.5));
    });

    testWidgets('FirstPondTutorialPage step-by-step navigation works across steps', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final site = FarmSite(
        id: 'test_site_1',
        name: 'Delta Brackish Farm',
        address: 'Plot 4, Estuary Road',
        state: 'Andhra Pradesh',
        country: 'India',
        status: 'active',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: FirstPondTutorialPage(site: site),
          ),
        ),
      );

      // Verify Step 1: Basin Identifier
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Name Your Cultivation Basin'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pond 01'), findsOneWidget);

      // Advance to Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify Step 2: Surface Sizing
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('Define Water Surface Area'), findsOneWidget);
      expect(find.text('Standardized Area:'), findsOneWidget);

      // Advance to Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify Step 3: Water Depth & Volume
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Set Operating Water Depth'), findsOneWidget);
      expect(find.text('Calculated Water Volume:'), findsOneWidget);

      // Advance to Step 4
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify Step 4: Aeration Equipment
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('Configure Aeration Equipment'), findsOneWidget);
      expect(find.text('Aeration Density:'), findsOneWidget);

      // Advance to Step 5: Review
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text('Review & Register Basin'), findsOneWidget);
      expect(find.text('Create Pond'), findsOneWidget);

      // Tap Create Pond to save to database
      await tester.tap(find.text('Create Pond'));
      await tester.pumpAndSettle();

      // Verify pond was created in database
      final ponds = await (db.select(db.ponds)..where((tbl) => tbl.siteId.equals(site.id))).get();
      expect(ponds.length, equals(1));
      expect(ponds.first.name, equals('Pond 01'));
      expect(ponds.first.areaSqMeters, closeTo(4046.86, 0.1));

      await db.close();
    });

    testWidgets('FirstPondGuideDialog renders comprehensive guidance sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FirstPondGuideDialog.show(context),
                child: const Text('Open Guide'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Guide'));
      await tester.pumpAndSettle();

      // Verify Dialog contents
      expect(find.text('Shrimp Pond Architecture'), findsOneWidget);
      expect(find.text('1. Water Depth & Surface Sizing'), findsOneWidget);
      expect(find.text('2. Aeration Rules of Thumb'), findsOneWidget);
      expect(find.text('3. Pre-Stocking Preparation Checklist'), findsOneWidget);
      expect(find.text('4. What Happens After Creating Pond?'), findsOneWidget);

      // Close Dialog
      await tester.tap(find.text("Got It, Let's Build"));
      await tester.pumpAndSettle();

      expect(find.text('Shrimp Pond Architecture'), findsNothing);
    });
  });
}
