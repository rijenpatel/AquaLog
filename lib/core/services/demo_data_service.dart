import 'dart:convert';
import '../database/app_database.dart';

class DemoDataService {
  final AppDatabase db;

  const DemoDataService(this.db);

  /// Populates a comprehensive, realistic commercial aquaculture farm dataset:
  /// - 2 Farm Sites: Coastal Delta Farms (Bhimavaram) & Swarna Estuary Farm (Nellore)
  /// - 6 Ponds total:
  ///   * Pond 1 (North Grow-out) - Active
  ///   * Pond 2 (East Grow-out) - Active
  ///   * Pond 3 (West Nursery) - Active
  ///   * Pond 4 (South Grow-out) - Active (Ready for next cycle after harvest)
  ///   * Pond 5 (Central Basin) - Active (Resting after harvest)
  ///   * Pond 6 (Eco-Fallow Basin) - ARCHIVED (1 Archive Pond)
  /// - 3 Active Batches with different DOC:
  ///   * Batch 1: Pond 1, DOC 73 (Grow-out late, ABW ~20.4g, Count ~49)
  ///   * Batch 2: Pond 2, DOC 46 (Grow-out mid, ABW ~12.2g, Count ~82)
  ///   * Batch 3: Pond 3, DOC 19 (Nursery early, ABW ~3.8g, Count ~263)
  /// - 2 Completed Batches with full harvest & revenue records:
  ///   * Batch 4: Pond 4, Completed at DOC 100, 2,780 kg harvest, ₹11,81,500 revenue, FCR 1.32
  ///   * Batch 5: Pond 5, Completed at DOC 105, 2,450 kg harvest, ₹10,16,750 revenue, FCR 1.30
  /// - 14 Days of rich multi-feed sessions per active pond with real inventory SKU mixes
  /// - Full sampling growth curves across all batches
  /// - Hapa survival checks, comprehensive inventory SKUs, expenses, revenues, and mandi prices
  Future<void> loadDemoData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await db.transaction(() async {
      // ─────────────────────────────────────────────────────────────
      // 1. FARM SITES (2 Sites)
      // ─────────────────────────────────────────────────────────────
      await db.into(db.farmSites).insertOnConflictUpdate(
        FarmSitesCompanion(
          id: const Value('site_bhimavaram'),
          name: const Value('Coastal Delta Farms — Bhimavaram Creek Farm'),
          code: const Value('CDF-01'),
          villageCity: const Value('Bhimavaram'),
          district: const Value('West Godavari'),
          state: const Value('Andhra Pradesh'),
          description: const Value('Commercial coastal aquaculture facility spanning 8.5 hectares.'),
          latitude: const Value(16.5449),
          longitude: const Value(81.5212),
          status: const Value('active'),
          createdAt: Value(today.subtract(const Duration(days: 180))),
        ),
      );

      await db.into(db.farmSites).insertOnConflictUpdate(
        FarmSitesCompanion(
          id: const Value('site_nellore'),
          name: const Value('Swarna Estuary Farm — Nellore'),
          code: const Value('SEF-02'),
          villageCity: const Value('Mypadu'),
          district: const Value('Nellore'),
          state: const Value('Andhra Pradesh'),
          description: const Value('Estuary farm spanning 6.2 hectares with high-salinity intake.'),
          latitude: const Value(14.4426),
          longitude: const Value(79.9865),
          status: const Value('active'),
          createdAt: Value(today.subtract(const Duration(days: 200))),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 2. PONDS (6 Ponds: 5 Active + 1 Archive)
      // ─────────────────────────────────────────────────────────────
      // Pond 1 (North Grow-out) - Hosts Active Batch 1 (DOC 73)
      await db.into(db.ponds).insertOnConflictUpdate(
        PondsCompanion(
          id: const Value('pond_1'),
          siteId: const Value('site_bhimavaram'),
          name: const Value('Pond 1 (North Grow-out)'),
          areaSqMeters: const Value(4000.0),
          waterDepthMeters: const Value(1.5),
          aeratorsCount: const Value(8),
          totalAeratorHp: const Value(16.0),
          status: const Value('active'),
          description: const Value('HDPE lined grow-out pond with central drain system.'),
          createdAt: Value(today.subtract(const Duration(days: 180))),
        ),
      );

      // Pond 2 (East Grow-out) - Hosts Active Batch 2 (DOC 46)
      await db.into(db.ponds).insertOnConflictUpdate(
        PondsCompanion(
          id: const Value('pond_2'),
          siteId: const Value('site_bhimavaram'),
          name: const Value('Pond 2 (East Grow-out)'),
          areaSqMeters: const Value(4500.0),
          waterDepthMeters: const Value(1.6),
          aeratorsCount: const Value(8),
          totalAeratorHp: const Value(16.0),
          status: const Value('active'),
          description: const Value('Deep clay-bottom grow-out pond with dual paddlewheels.'),
          createdAt: Value(today.subtract(const Duration(days: 180))),
        ),
      );

      // Pond 3 (West Nursery) - Hosts Active Batch 3 (DOC 19)
      await db.into(db.ponds).insertOnConflictUpdate(
        PondsCompanion(
          id: const Value('pond_3'),
          siteId: const Value('site_bhimavaram'),
          name: const Value('Pond 3 (West Nursery)'),
          areaSqMeters: const Value(2500.0),
          waterDepthMeters: const Value(1.2),
          aeratorsCount: const Value(6),
          totalAeratorHp: const Value(12.0),
          status: const Value('active'),
          description: const Value('Covered nursery basin with micro-bubble diffusion tubing.'),
          createdAt: Value(today.subtract(const Duration(days: 180))),
        ),
      );

      // Pond 4 (South Grow-out) - Hosts Completed Batch 4 (Harvested)
      await db.into(db.ponds).insertOnConflictUpdate(
        PondsCompanion(
          id: const Value('pond_4'),
          siteId: const Value('site_bhimavaram'),
          name: const Value('Pond 4 (South Grow-out)'),
          areaSqMeters: const Value(5000.0),
          waterDepthMeters: const Value(1.5),
          aeratorsCount: const Value(10),
          totalAeratorHp: const Value(20.0),
          status: const Value('active'),
          description: const Value('High-capacity earthen grow-out pond with spiral paddlewheels.'),
          createdAt: Value(today.subtract(const Duration(days: 180))),
        ),
      );

      // Pond 5 (Central Basin) - Hosts Completed Batch 5 (Harvested)
      await db.into(db.ponds).insertOnConflictUpdate(
        PondsCompanion(
          id: const Value('pond_5'),
          siteId: const Value('site_nellore'),
          name: const Value('Pond 5 (Central Basin)'),
          areaSqMeters: const Value(4200.0),
          waterDepthMeters: const Value(1.5),
          aeratorsCount: const Value(8),
          totalAeratorHp: const Value(16.0),
          status: const Value('active'),
          description: const Value('Nellore coastal salinity basin with auto-feeders.'),
          createdAt: Value(today.subtract(const Duration(days: 200))),
        ),
      );

      // Pond 6 (Eco-Fallow Basin) - 1 ARCHIVE POND
      await db.into(db.ponds).insertOnConflictUpdate(
        PondsCompanion(
          id: const Value('pond_6_archived'),
          siteId: const Value('site_bhimavaram'),
          name: const Value('Pond 6 (Eco-Fallow Basin)'),
          areaSqMeters: const Value(3500.0),
          waterDepthMeters: const Value(1.4),
          aeratorsCount: const Value(6),
          totalAeratorHp: const Value(12.0),
          status: const Value('archived'), // Explicitly ARCHIVED pond
          description: const Value(
            'Archived fallow basin: soil solarization, agricultural liming, and perimeter biosecurity refurbishment.',
          ),
          createdAt: Value(today.subtract(const Duration(days: 180))),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 3. BATCHES (3 Active with different DOC + 2 Completed)
      // ─────────────────────────────────────────────────────────────
      // Active Batch 1: Pond 1, DOC 73 (Stocked 72 days ago)
      final stockingBatch1 = today.subtract(const Duration(days: 72));
      await db.into(db.batches).insertOnConflictUpdate(
        BatchesCompanion(
          id: const Value('batch_pond_1'),
          pondId: const Value('pond_1'),
          batchNumber: const Value(4),
          species: const Value('Litopenaeus vannamei'),
          stockingDate: Value(stockingBatch1),
          shrimpStockedCount: const Value(120000),
          plStage: const Value('PL-10'),
          hatcherySource: const Value('Apex High-Health Hatchery, Kakinada'),
          seedCost: const Value(48000.0),
          targetHarvestWeightG: const Value(26.0),
          status: const Value('active'),
          targetDoc: const Value(90),
          notes: const Value('Late grow-out phase. Transitioning to Finisher 2.0mm feed.'),
          createdAt: Value(stockingBatch1),
        ),
      );

      // Active Batch 2: Pond 2, DOC 46 (Stocked 45 days ago)
      final stockingBatch2 = today.subtract(const Duration(days: 45));
      await db.into(db.batches).insertOnConflictUpdate(
        BatchesCompanion(
          id: const Value('batch_pond_2'),
          pondId: const Value('pond_2'),
          batchNumber: const Value(2),
          species: const Value('Litopenaeus vannamei'),
          stockingDate: Value(stockingBatch2),
          shrimpStockedCount: const Value(110000),
          plStage: const Value('PL-11'),
          hatcherySource: const Value('Bhimavaram BioHatch'),
          seedCost: const Value(44000.0),
          targetHarvestWeightG: const Value(25.0),
          status: const Value('active'),
          targetDoc: const Value(85),
          notes: const Value('Mid grow-out phase. Strong check tray clearance and high vigor.'),
          createdAt: Value(stockingBatch2),
        ),
      );

      // Active Batch 3: Pond 3, DOC 19 (Stocked 18 days ago)
      final stockingBatch3 = today.subtract(const Duration(days: 18));
      await db.into(db.batches).insertOnConflictUpdate(
        BatchesCompanion(
          id: const Value('batch_pond_3'),
          pondId: const Value('pond_3'),
          batchNumber: const Value(1),
          species: const Value('Litopenaeus vannamei'),
          stockingDate: Value(stockingBatch3),
          shrimpStockedCount: const Value(150000),
          plStage: const Value('PL-9'),
          hatcherySource: const Value('Golden Bay Aqua Hatcheries'),
          seedCost: const Value(57000.0),
          targetHarvestWeightG: const Value(28.0),
          status: const Value('active'),
          targetDoc: const Value(95),
          notes: const Value('Nursery phase. High density acclimatization with gut probiotic supplementation.'),
          createdAt: Value(stockingBatch3),
        ),
      );

      // Completed Batch 4: Pond 4 (Stocked 118 days ago, Harvested 18 days ago)
      final stockingBatch4 = today.subtract(const Duration(days: 118));
      final harvestBatch4 = today.subtract(const Duration(days: 18));
      await db.into(db.batches).insertOnConflictUpdate(
        BatchesCompanion(
          id: const Value('batch_pond_4_completed'),
          pondId: const Value('pond_4'),
          batchNumber: const Value(3),
          species: const Value('Litopenaeus vannamei'),
          stockingDate: Value(stockingBatch4),
          shrimpStockedCount: const Value(130000),
          plStage: const Value('PL-10'),
          hatcherySource: const Value('Apex High-Health Hatchery, Kakinada'),
          seedCost: const Value(52000.0),
          targetHarvestWeightG: const Value(25.0),
          status: const Value('completed'), // Completed batch 1
          harvestDate: Value(harvestBatch4),
          harvestWeightKg: const Value(2780.0),
          harvestCount: const Value(110000),
          harvestType: const Value('full'),
          buyerName: const Value('Royal Marine Exports Ltd, Visakhapatnam'),
          salePricePerKg: const Value(425.0),
          actualFcr: const Value(1.32),
          actualSurvivalPct: const Value(84.6),
          targetDoc: const Value(100),
          notes: const Value('Excellent full harvest outcome: 2.78 MT produced with 1.32 FCR.'),
          createdAt: Value(stockingBatch4),
        ),
      );

      // Completed Batch 5: Pond 5 (Stocked 155 days ago, Harvested 50 days ago)
      final stockingBatch5 = today.subtract(const Duration(days: 155));
      final harvestBatch5 = today.subtract(const Duration(days: 50));
      await db.into(db.batches).insertOnConflictUpdate(
        BatchesCompanion(
          id: const Value('batch_pond_5_completed'),
          pondId: const Value('pond_5'),
          batchNumber: const Value(1),
          species: const Value('Litopenaeus vannamei'),
          stockingDate: Value(stockingBatch5),
          shrimpStockedCount: const Value(115000),
          plStage: const Value('PL-10'),
          hatcherySource: const Value('Nellore Blue Waters Hatchery'),
          seedCost: const Value(46000.0),
          targetHarvestWeightG: const Value(24.0),
          status: const Value('completed'), // Completed batch 2
          harvestDate: Value(harvestBatch5),
          harvestWeightKg: const Value(2450.0),
          harvestCount: const Value(98000),
          harvestType: const Value('full'),
          buyerName: const Value('Devi Sea Foods Ltd, Singarayakonda'),
          salePricePerKg: const Value(415.0),
          actualFcr: const Value(1.30),
          actualSurvivalPct: const Value(85.2),
          targetDoc: const Value(105),
          notes: const Value('High survival commercial crop: 2.45 MT sold directly to export plant.'),
          createdAt: Value(stockingBatch5),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 4. HARVEST REVENUES (For the 2 Completed Batches)
      // ─────────────────────────────────────────────────────────────
      await db.into(db.revenues).insertOnConflictUpdate(
        RevenuesCompanion(
          id: const Value('rev_batch_4'),
          batchId: const Value('batch_pond_4_completed'),
          date: Value(harvestBatch4),
          harvestWeightKg: const Value(2780.0),
          pricePerKg: const Value(425.0),
          totalAmount: const Value(1181500.0), // 2,780 kg * 425
          buyerName: const Value('Royal Marine Exports Ltd, Visakhapatnam'),
          harvestType: const Value('full'),
          notes: const Value('Full pond clear harvest. Final payment received via RTGS.'),
        ),
      );

      await db.into(db.revenues).insertOnConflictUpdate(
        RevenuesCompanion(
          id: const Value('rev_batch_5'),
          batchId: const Value('batch_pond_5_completed'),
          date: Value(harvestBatch5),
          harvestWeightKg: const Value(2450.0),
          pricePerKg: const Value(415.0),
          totalAmount: const Value(1016750.0), // 2,450 kg * 415
          buyerName: const Value('Devi Sea Foods Ltd, Singarayakonda'),
          harvestType: const Value('full'),
          notes: const Value('Nellore farm harvest. Grade A raw headless vannamei standard.'),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 5. HAPA SURVIVAL CHECKS
      // ─────────────────────────────────────────────────────────────
      await db.into(db.hapaChecks).insertOnConflictUpdate(
        HapaChecksCompanion(
          id: const Value('hapa_p1_24h'),
          batchId: const Value('batch_pond_1'),
          pondId: const Value('pond_1'),
          date: Value(stockingBatch1.add(const Duration(hours: 24))),
          hoursElapsed: const Value(24),
          hapaStocked: const Value(100),
          hapaAlive: const Value(97),
          survivalPercentage: const Value(97.0),
          estimatedPopulation: const Value(116400),
          notes: const Value('Exceptional vigor post-stocking acclimatization.'),
        ),
      );

      await db.into(db.hapaChecks).insertOnConflictUpdate(
        HapaChecksCompanion(
          id: const Value('hapa_p2_24h'),
          batchId: const Value('batch_pond_2'),
          pondId: const Value('pond_2'),
          date: Value(stockingBatch2.add(const Duration(hours: 24))),
          hoursElapsed: const Value(24),
          hapaStocked: const Value(100),
          hapaAlive: const Value(94),
          survivalPercentage: const Value(94.0),
          estimatedPopulation: const Value(103400),
          notes: const Value('Normal post-transport recovery in clay-bottom environment.'),
        ),
      );

      await db.into(db.hapaChecks).insertOnConflictUpdate(
        HapaChecksCompanion(
          id: const Value('hapa_p3_24h'),
          batchId: const Value('batch_pond_3'),
          pondId: const Value('pond_3'),
          date: Value(stockingBatch3.add(const Duration(hours: 24))),
          hoursElapsed: const Value(24),
          hapaStocked: const Value(100),
          hapaAlive: const Value(98),
          survivalPercentage: const Value(98.0),
          estimatedPopulation: const Value(147000),
          notes: const Value('High survival in aerated covered nursery tank.'),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 6. SAMPLING GROWTH RECORDS (Across All 5 Batches)
      // ─────────────────────────────────────────────────────────────
      // Batch 1 (Active, DOC 73): Weekly cast-net growth progression
      final b1Samples = [
        {'doc': 22, 'abw': 4.6, 'count': 217, 'adg': 0.21, 'gain': 1.47, 'days': 7},
        {'doc': 29, 'abw': 6.8, 'count': 147, 'adg': 0.31, 'gain': 2.20, 'days': 7},
        {'doc': 36, 'abw': 9.2, 'count': 108, 'adg': 0.34, 'gain': 2.40, 'days': 7},
        {'doc': 43, 'abw': 11.8, 'count': 85, 'adg': 0.37, 'gain': 2.60, 'days': 7},
        {'doc': 50, 'abw': 14.3, 'count': 70, 'adg': 0.36, 'gain': 2.50, 'days': 7},
        {'doc': 57, 'abw': 16.6, 'count': 60, 'adg': 0.33, 'gain': 2.30, 'days': 7},
        {'doc': 64, 'abw': 18.7, 'count': 53, 'adg': 0.30, 'gain': 2.10, 'days': 7},
        {'doc': 71, 'abw': 20.4, 'count': 49, 'adg': 0.24, 'gain': 1.70, 'days': 7},
      ];

      for (final s in b1Samples) {
        final sampleDate = stockingBatch1.add(Duration(days: (s['doc'] as int) - 1));
        await db.into(db.samplingEntries).insertOnConflictUpdate(
          SamplingEntriesCompanion(
            id: Value('sample_b1_doc_${s['doc']}'),
            batchId: const Value('batch_pond_1'),
            pondId: const Value('pond_1'),
            date: Value(sampleDate),
            doc: Value(s['doc'] as int),
            samplingTotalWeightG: Value((s['abw'] as double) * 25),
            samplingShrimpCount: const Value(25),
            abwGrams: Value(s['abw'] as double),
            adgGramsPerDay: Value(s['adg'] as double),
            weightGainGrams: Value(s['gain'] as double),
            daysElapsed: Value(s['days'] as int),
            notes: Value('Uniform carapace, clean hepatopancreas. DOC ${s['doc']}.'),
          ),
        );
      }

      // Batch 2 (Active, DOC 46): Samplings
      final b2Samples = [
        {'doc': 18, 'abw': 3.4, 'count': 294, 'adg': 0.19, 'gain': 1.33, 'days': 7},
        {'doc': 25, 'abw': 5.2, 'count': 192, 'adg': 0.26, 'gain': 1.80, 'days': 7},
        {'doc': 32, 'abw': 7.4, 'count': 135, 'adg': 0.31, 'gain': 2.20, 'days': 7},
        {'doc': 39, 'abw': 9.9, 'count': 101, 'adg': 0.36, 'gain': 2.50, 'days': 7},
        {'doc': 45, 'abw': 12.2, 'count': 82, 'adg': 0.38, 'gain': 2.30, 'days': 6},
      ];

      for (final s in b2Samples) {
        final sampleDate = stockingBatch2.add(Duration(days: (s['doc'] as int) - 1));
        await db.into(db.samplingEntries).insertOnConflictUpdate(
          SamplingEntriesCompanion(
            id: Value('sample_b2_doc_${s['doc']}'),
            batchId: const Value('batch_pond_2'),
            pondId: const Value('pond_2'),
            date: Value(sampleDate),
            doc: Value(s['doc'] as int),
            samplingTotalWeightG: Value((s['abw'] as double) * 25),
            samplingShrimpCount: const Value(25),
            abwGrams: Value(s['abw'] as double),
            adgGramsPerDay: Value(s['adg'] as double),
            weightGainGrams: Value(s['gain'] as double),
            daysElapsed: Value(s['days'] as int),
            notes: Value('Active molting and uniform growth. DOC ${s['doc']}.'),
          ),
        );
      }

      // Batch 3 (Active, DOC 19): Nursery samplings
      final b3Samples = [
        {'doc': 10, 'abw': 1.8, 'count': 555, 'adg': 0.18, 'gain': 1.80, 'days': 10},
        {'doc': 17, 'abw': 3.8, 'count': 263, 'adg': 0.29, 'gain': 2.00, 'days': 7},
      ];

      for (final s in b3Samples) {
        final sampleDate = stockingBatch3.add(Duration(days: (s['doc'] as int) - 1));
        await db.into(db.samplingEntries).insertOnConflictUpdate(
          SamplingEntriesCompanion(
            id: Value('sample_b3_doc_${s['doc']}'),
            batchId: const Value('batch_pond_3'),
            pondId: const Value('pond_3'),
            date: Value(sampleDate),
            doc: Value(s['doc'] as int),
            samplingTotalWeightG: Value((s['abw'] as double) * 30),
            samplingShrimpCount: const Value(30),
            abwGrams: Value(s['abw'] as double),
            adgGramsPerDay: Value(s['adg'] as double),
            weightGainGrams: Value(s['gain'] as double),
            daysElapsed: Value(s['days'] as int),
            notes: Value('Nursery growth tracking. High vitality.'),
          ),
        );
      }

      // ─────────────────────────────────────────────────────────────
      // 7. INVENTORY ITEMS (Full Commercial Portfolio)
      // ─────────────────────────────────────────────────────────────
      // Feeds
      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_starter_05'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Starter 0.5mm (Crumbles)'),
          brand: const Value('Avanti Classic'),
          pelletSize: const Value('0.5mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(350.0),
          lowStockThreshold: const Value(100.0),
          costPerUnit: const Value(98.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_starter_08'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Starter 0.8mm (Crumbles)'),
          brand: const Value('CP Nova'),
          pelletSize: const Value('0.8mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(500.0),
          lowStockThreshold: const Value(120.0),
          costPerUnit: const Value(95.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_grower_12'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Grower 1.2mm'),
          brand: const Value('CP Classic'),
          pelletSize: const Value('1.2mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(1200.0),
          lowStockThreshold: const Value(250.0),
          costPerUnit: const Value(88.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_grower_16'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Grower 1.6mm'),
          brand: const Value('Avanti Pro'),
          pelletSize: const Value('1.6mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(2100.0),
          lowStockThreshold: const Value(500.0),
          costPerUnit: const Value(86.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_grower_18'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Grower 1.8mm'),
          brand: const Value('Waterbase HighPro'),
          pelletSize: const Value('1.8mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(1850.0),
          lowStockThreshold: const Value(400.0),
          costPerUnit: const Value(86.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_finisher_20'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Finisher 2.0mm'),
          brand: const Value('CP Mega'),
          pelletSize: const Value('2.0mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(2400.0),
          lowStockThreshold: const Value(500.0),
          costPerUnit: const Value(84.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_feed_finisher_24'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('feed'),
          name: const Value('Finisher 2.4mm'),
          brand: const Value('Avanti Premium'),
          pelletSize: const Value('2.4mm'),
          unit: const Value('kg'),
          bagWeightKg: const Value(25.0),
          currentStock: const Value(1500.0),
          lowStockThreshold: const Value(350.0),
          costPerUnit: const Value(83.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      // Medicines & Water Conditioners
      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_med_biogut'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('medicine'),
          name: const Value('BioGut Probiotic'),
          brand: const Value('AquaVet Labs'),
          medicineCategory: const Value('Probiotics'),
          unit: const Value('kg'),
          currentStock: const Value(22.0),
          lowStockThreshold: const Value(5.0),
          costPerUnit: const Value(1200.0),
          supplier: const Value('Delta Vet Pharma'),
          expiryDate: Value(today.add(const Duration(days: 90))),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_med_bkc'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('medicine'),
          name: const Value('EcoShield BKC 80% Sanitizer'),
          brand: const Value('Delta Chemicals'),
          medicineCategory: const Value('Disinfectants'),
          unit: const Value('L'),
          currentStock: const Value(50.0),
          lowStockThreshold: const Value(10.0),
          costPerUnit: const Value(380.0),
          supplier: const Value('Delta Vet Pharma'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_med_minerals'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('medicine'),
          name: const Value('SuperMin Aqua Minerals'),
          brand: const Value('Marine Minerals Ltd'),
          medicineCategory: const Value('Minerals'),
          unit: const Value('kg'),
          currentStock: const Value(850.0),
          lowStockThreshold: const Value(200.0),
          costPerUnit: const Value(48.0),
          supplier: const Value('Coastal Feed Agency'),
        ),
      );

      // Fuel & Water Treatment Lime
      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_fuel_diesel'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('fuel'),
          name: const Value('High Speed Diesel (HSD)'),
          brand: const Value('HPCL'),
          fuelType: const Value('Diesel'),
          unit: const Value('L'),
          currentStock: const Value(750.0),
          lowStockThreshold: const Value(150.0),
          costPerUnit: const Value(94.5),
          supplier: const Value('HPCL Outlet, NH-16'),
        ),
      );

      await db.into(db.inventoryItems).insertOnConflictUpdate(
        InventoryItemsCompanion(
          id: const Value('inv_chem_lime'),
          siteId: const Value('site_bhimavaram'),
          category: const Value('medicine'),
          name: const Value('Agriculture Quick Lime (CaCO3)'),
          brand: const Value('Deccan Minerals'),
          medicineCategory: const Value('Water Treatment'),
          unit: const Value('kg'),
          currentStock: const Value(1800.0),
          lowStockThreshold: const Value(300.0),
          costPerUnit: const Value(14.0),
          supplier: const Value('Deccan Minerals'),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 8. MULTI-FEED SESSIONS FOR PAST 14 DAYS (Active Ponds 1, 2, 3)
      // ─────────────────────────────────────────────────────────────
      final timeSlots = ['6:30 AM', '11:00 AM', '3:30 PM', '7:30 PM'];

      for (int d = 13; d >= 0; d--) {
        final date = today.subtract(Duration(days: d));

        // ── POND 1 (Late Grow-out, DOC 60..73) ──
        // Feeds: Grower 1.8mm + Finisher 2.0mm
        for (int s = 0; s < (d == 0 ? 3 : 4); s++) {
          final slot = timeSlots[s];
          final g18Qty = (11.0 + (s * 0.5) - (d * 0.2)).clamp(9.0, 14.0);
          final f20Qty = (7.5 + (s * 0.5) - (d * 0.15)).clamp(6.0, 10.0);
          final totalKg = (g18Qty + f20Qty).roundToDouble();

          final feedItems = [
            {
              'inventoryFeedId': 'inv_feed_grower_18',
              'feedName': 'Grower 1.8mm',
              'brand': 'Waterbase HighPro',
              'size': '1.8mm',
              'quantity': g18Qty,
              'unit': 'kg',
            },
            {
              'inventoryFeedId': 'inv_feed_finisher_20',
              'feedName': 'Finisher 2.0mm',
              'brand': 'CP Mega',
              'size': '2.0mm',
              'quantity': f20Qty,
              'unit': 'kg',
            },
          ];

          await db.into(db.feedRecords).insertOnConflictUpdate(
            FeedRecordsCompanion(
              id: Value('rec_p1_d${d}_s$s'),
              pondId: const Value('pond_1'),
              batchId: const Value('batch_pond_1'),
              date: Value(date),
              timeSlot: Value(slot),
              totalGrams: Value(totalKg * 1000),
              totalKg: Value(totalKg),
              trayChecked: const Value(true),
              trayLeftoverPct: Value(s == 1 ? 4 : (s == 2 ? 6 : 0)),
              feedItemsJson: Value(jsonEncode(feedItems)),
              notes: Value(
                s == 0
                    ? 'Morning ration eagerly consumed along perimeter.'
                    : (s == 1 ? 'Check tray clean within 1.8 hrs.' : 'Steady feed uptake.'),
              ),
            ),
          );
        }

        // ── POND 2 (Mid Grow-out, DOC 33..46) ──
        // Feeds: Grower 1.2mm + Grower 1.6mm
        for (int s = 0; s < (d == 0 ? 2 : 4); s++) {
          final slot = timeSlots[s];
          final g12Qty = (7.0 + (s * 0.4) - (d * 0.15)).clamp(5.0, 9.0);
          final g16Qty = (6.0 + (s * 0.3) - (d * 0.1)).clamp(4.0, 8.0);
          final totalKg = (g12Qty + g16Qty).roundToDouble();

          final feedItems = [
            {
              'inventoryFeedId': 'inv_feed_grower_12',
              'feedName': 'Grower 1.2mm',
              'brand': 'CP Classic',
              'size': '1.2mm',
              'quantity': g12Qty,
              'unit': 'kg',
            },
            {
              'inventoryFeedId': 'inv_feed_grower_16',
              'feedName': 'Grower 1.6mm',
              'brand': 'Avanti Pro',
              'size': '1.6mm',
              'quantity': g16Qty,
              'unit': 'kg',
            },
          ];

          await db.into(db.feedRecords).insertOnConflictUpdate(
            FeedRecordsCompanion(
              id: Value('rec_p2_d${d}_s$s'),
              pondId: const Value('pond_2'),
              batchId: const Value('batch_pond_2'),
              date: Value(date),
              timeSlot: Value(slot),
              totalGrams: Value(totalKg * 1000),
              totalKg: Value(totalKg),
              trayChecked: const Value(true),
              trayLeftoverPct: Value(s == 2 ? 8 : 0),
              feedItemsJson: Value(jsonEncode(feedItems)),
              notes: Value(s == 2 ? 'Minor 8% leftover due to afternoon heat.' : 'Full feed uptake.'),
            ),
          );
        }

        // ── POND 3 (Nursery, DOC 6..19) ──
        // Feeds: Starter 0.5mm + Starter 0.8mm
        for (int s = 0; s < (d == 0 ? 2 : 3); s++) {
          final slot = timeSlots[s];
          final s05Qty = (2.5 + (s * 0.2)).clamp(2.0, 4.0);
          final s08Qty = (3.5 + (s * 0.3)).clamp(3.0, 5.0);
          final totalKg = (s05Qty + s08Qty).roundToDouble();

          final feedItems = [
            {
              'inventoryFeedId': 'inv_feed_starter_05',
              'feedName': 'Starter 0.5mm (Crumbles)',
              'brand': 'Avanti Classic',
              'size': '0.5mm',
              'quantity': s05Qty,
              'unit': 'kg',
            },
            {
              'inventoryFeedId': 'inv_feed_starter_08',
              'feedName': 'Starter 0.8mm (Crumbles)',
              'brand': 'CP Nova',
              'size': '0.8mm',
              'quantity': s08Qty,
              'unit': 'kg',
            },
          ];

          await db.into(db.feedRecords).insertOnConflictUpdate(
            FeedRecordsCompanion(
              id: Value('rec_p3_d${d}_s$s'),
              pondId: const Value('pond_3'),
              batchId: const Value('batch_pond_3'),
              date: Value(date),
              timeSlot: Value(slot),
              totalGrams: Value(totalKg * 1000),
              totalKg: Value(totalKg),
              trayChecked: const Value(true),
              trayLeftoverPct: const Value(0),
              feedItemsJson: Value(jsonEncode(feedItems)),
              notes: const Value('Nursery high density feeding. Clean tray.'),
            ),
          );
        }
      }

      // ─────────────────────────────────────────────────────────────
      // 9. OPERATING EXPENSES (Seed, Feed, Power, Labor, Fuel)
      // ─────────────────────────────────────────────────────────────
      // Seed Expenses for all batches
      final seedExpenses = [
        {'id': 'exp_seed_b1', 'bid': 'batch_pond_1', 'pid': 'pond_1', 'date': stockingBatch1, 'amt': 48000.0, 'desc': 'PL-10 seed: 120,000 pcs @ Rs 0.40'},
        {'id': 'exp_seed_b2', 'bid': 'batch_pond_2', 'pid': 'pond_2', 'date': stockingBatch2, 'amt': 44000.0, 'desc': 'PL-11 seed: 110,000 pcs @ Rs 0.40'},
        {'id': 'exp_seed_b3', 'bid': 'batch_pond_3', 'pid': 'pond_3', 'date': stockingBatch3, 'amt': 57000.0, 'desc': 'PL-9 seed: 150,000 pcs @ Rs 0.38'},
        {'id': 'exp_seed_b4', 'bid': 'batch_pond_4_completed', 'pid': 'pond_4', 'date': stockingBatch4, 'amt': 52000.0, 'desc': 'PL-10 seed: 130,000 pcs @ Rs 0.40'},
        {'id': 'exp_seed_b5', 'bid': 'batch_pond_5_completed', 'pid': 'pond_5', 'date': stockingBatch5, 'amt': 46000.0, 'desc': 'PL-10 seed: 115,000 pcs @ Rs 0.40'},
      ];

      for (final se in seedExpenses) {
        await db.into(db.expenses).insertOnConflictUpdate(
          ExpensesCompanion(
            id: Value(se['id'] as String),
            batchId: Value(se['bid'] as String),
            siteId: const Value('site_bhimavaram'),
            pondId: Value(se['pid'] as String),
            date: Value(se['date'] as DateTime),
            category: const Value('seed'),
            amount: Value(se['amt'] as double),
            description: Value(se['desc'] as String),
          ),
        );
      }

      // Operational Power & Fuel Expenses
      await db.into(db.expenses).insertOnConflictUpdate(
        ExpensesCompanion(
          id: const Value('exp_power_last_month'),
          siteId: const Value('site_bhimavaram'),
          date: Value(today.subtract(const Duration(days: 20))),
          category: const Value('power'),
          amount: const Value(42500.0),
          description: const Value('APCPDCL commercial farm power tariff bill'),
        ),
      );

      await db.into(db.expenses).insertOnConflictUpdate(
        ExpensesCompanion(
          id: const Value('exp_diesel_refill'),
          siteId: const Value('site_bhimavaram'),
          date: Value(today.subtract(const Duration(days: 8))),
          category: const Value('fuel'),
          amount: const Value(28350.0),
          description: const Value('High Speed Diesel 300L refill for backup generator'),
        ),
      );

      await db.into(db.expenses).insertOnConflictUpdate(
        ExpensesCompanion(
          id: const Value('exp_labor_fortnight'),
          siteId: const Value('site_bhimavaram'),
          date: Value(today.subtract(const Duration(days: 5))),
          category: const Value('labor'),
          amount: const Value(24000.0),
          description: const Value('Farm technician and feed feeder wages (2 technicians)'),
        ),
      );

      // ─────────────────────────────────────────────────────────────
      // 10. LOCAL MANDI MARKET PRICES
      // ─────────────────────────────────────────────────────────────
      final prices = [
        {'id': 'price_30c', 'count': '30 count', 'price': 520.0},
        {'id': 'price_40c', 'count': '40 count', 'price': 440.0},
        {'id': 'price_50c', 'count': '50 count', 'price': 380.0},
        {'id': 'price_60c', 'count': '60 count', 'price': 345.0},
        {'id': 'price_80c', 'count': '80 count', 'price': 290.0},
        {'id': 'price_100c', 'count': '100 count', 'price': 250.0},
      ];

      for (final p in prices) {
        await db.into(db.marketPrices).insertOnConflictUpdate(
          MarketPricesCompanion(
            id: Value(p['id'] as String),
            date: Value(today),
            countCategory: Value(p['count'] as String),
            pricePerKg: Value(p['price'] as double),
            location: const Value('Bhimavaram Mandi'),
            notes: const Value('Farm gate price cash settlement.'),
          ),
        );
      }

      // ─────────────────────────────────────────────────────────────
      // 11. GENERATOR MACHINE RUNS
      // ─────────────────────────────────────────────────────────────
      await db.into(db.machineRuns).insertOnConflictUpdate(
        MachineRunsCompanion(
          id: const Value('run_gen_1'),
          siteId: const Value('site_bhimavaram'),
          machineName: const Value('Kirloskar 45 kVA Diesel Generator'),
          fuelItemId: const Value('inv_fuel_diesel'),
          fuelType: const Value('Diesel'),
          date: Value(today.subtract(const Duration(days: 3))),
          runtimeHours: const Value(4.5),
          startHourMeter: const Value(1245.0),
          endHourMeter: const Value(1249.5),
          fuelConsumedLiters: const Value(29.2),
          reason: const Value('Grid power failure during evening storm. Kept all 8 aerators running.'),
        ),
      );
    });
  }
}
