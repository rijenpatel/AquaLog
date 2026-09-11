import 'dart:convert';
import '../database/app_database.dart';

class BackupService {
  final AppDatabase db;

  const BackupService(this.db);

  /// Exports full database as a versioned JSON string.
  Future<String> exportToJson() async {
    final sites = await db.select(db.farmSites).get();
    final ponds = await db.select(db.ponds).get();
    final batches = await db.select(db.batches).get();
    final feedRecords = await db.select(db.feedRecords).get();
    final sampling = await db.select(db.samplingEntries).get();
    final inventory = await db.select(db.inventoryItems).get();
    final transactions = await db.select(db.inventoryTransactions).get();
    final expenses = await db.select(db.expenses).get();
    final revenues = await db.select(db.revenues).get();
    final prices = await db.select(db.marketPrices).get();

    final Map<String, dynamic> backup = {
      'schemaVersion': 1,
      'application': 'AquaLog',
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        'sites': sites.map((s) => {
          'id': s.id,
          'name': s.name,
          'address': s.address,
          'latitude': s.latitude,
          'longitude': s.longitude,
          'createdAt': s.createdAt.toIso8601String(),
        }).toList(),
        'ponds': ponds.map((p) => {
          'id': p.id,
          'siteId': p.siteId,
          'name': p.name,
          'areaSqMeters': p.areaSqMeters,
          'waterDepthMeters': p.waterDepthMeters,
          'aeratorsCount': p.aeratorsCount,
          'totalAeratorHp': p.totalAeratorHp,
          'status': p.status,
          'createdAt': p.createdAt.toIso8601String(),
        }).toList(),
        'batches': batches.map((b) => {
          'id': b.id,
          'pondId': b.pondId,
          'batchNumber': b.batchNumber,
          'species': b.species,
          'stockingDate': b.stockingDate.toIso8601String(),
          'shrimpStockedCount': b.shrimpStockedCount,
          'plStage': b.plStage,
          'hatcherySource': b.hatcherySource,
          'seedCost': b.seedCost,
          'targetHarvestWeightG': b.targetHarvestWeightG,
          'status': b.status,
          'harvestDate': b.harvestDate?.toIso8601String(),
          'harvestWeightKg': b.harvestWeightKg,
          'harvestCount': b.harvestCount,
          'salePricePerKg': b.salePricePerKg,
          'actualFcr': b.actualFcr,
          'actualSurvivalPct': b.actualSurvivalPct,
          'createdAt': b.createdAt.toIso8601String(),
        }).toList(),
        'feedRecords': feedRecords.map((f) => {
          'id': f.id,
          'pondId': f.pondId,
          'batchId': f.batchId,
          'date': f.date.toIso8601String(),
          'timeSlot': f.timeSlot,
          'customTime': f.customTime,
          'starterG': f.starterG,
          'grower1G': f.grower1G,
          'grower2G': f.grower2G,
          'finisher1G': f.finisher1G,
          'finisher2G': f.finisher2G,
          'otherFeedName': f.otherFeedName,
          'otherFeedG': f.otherFeedG,
          'totalGrams': f.totalGrams,
          'totalKg': f.totalKg,
          'trayChecked': f.trayChecked,
          'trayLeftoverPct': f.trayLeftoverPct,
          'notes': f.notes,
          'createdAt': f.createdAt.toIso8601String(),
        }).toList(),
        'sampling': sampling.map((s) => {
          'id': s.id,
          'batchId': s.batchId,
          'pondId': s.pondId,
          'date': s.date.toIso8601String(),
          'doc': s.doc,
          'samplingTotalWeightG': s.samplingTotalWeightG,
          'samplingShrimpCount': s.samplingShrimpCount,
          'abwGrams': s.abwGrams,
          'adgGramsPerDay': s.adgGramsPerDay,
          'weightGainGrams': s.weightGainGrams,
          'daysElapsed': s.daysElapsed,
          'notes': s.notes,
          'createdAt': s.createdAt.toIso8601String(),
        }).toList(),
        'inventory': inventory.map((i) => {
          'id': i.id,
          'siteId': i.siteId,
          'category': i.category,
          'name': i.name,
          'brand': i.brand,
          'pelletSize': i.pelletSize,
          'medicineCategory': i.medicineCategory,
          'fuelType': i.fuelType,
          'unit': i.unit,
          'bagWeightKg': i.bagWeightKg,
          'currentStock': i.currentStock,
          'lowStockThreshold': i.lowStockThreshold,
          'costPerUnit': i.costPerUnit,
          'supplier': i.supplier,
          'expiryDate': i.expiryDate?.toIso8601String(),
          'createdAt': i.createdAt.toIso8601String(),
        }).toList(),
        'transactions': transactions.map((t) => {
          'id': t.id,
          'itemId': t.itemId,
          'siteId': t.siteId,
          'type': t.type,
          'quantity': t.quantity,
          'unitPrice': t.unitPrice,
          'totalCost': t.totalCost,
          'date': t.date.toIso8601String(),
          'referenceRecordId': t.referenceRecordId,
          'notes': t.notes,
          'createdAt': t.createdAt.toIso8601String(),
        }).toList(),
        'expenses': expenses.map((e) => {
          'id': e.id,
          'batchId': e.batchId,
          'siteId': e.siteId,
          'pondId': e.pondId,
          'date': e.date.toIso8601String(),
          'category': e.category,
          'amount': e.amount,
          'description': e.description,
          'createdAt': e.createdAt.toIso8601String(),
        }).toList(),
        'revenues': revenues.map((r) => {
          'id': r.id,
          'batchId': r.batchId,
          'date': r.date.toIso8601String(),
          'harvestWeightKg': r.harvestWeightKg,
          'pricePerKg': r.pricePerKg,
          'totalAmount': r.totalAmount,
          'buyerName': r.buyerName,
          'createdAt': r.createdAt.toIso8601String(),
        }).toList(),
        'prices': prices.map((p) => {
          'id': p.id,
          'date': p.date.toIso8601String(),
          'countCategory': p.countCategory,
          'pricePerKg': p.pricePerKg,
          'location': p.location,
          'createdAt': p.createdAt.toIso8601String(),
        }).toList(),
      }
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Validates and restores database atomically from a backup JSON string.
  Future<Map<String, int>> restoreFromJson(String jsonContent) async {
    final dynamic parsed = jsonDecode(jsonContent);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file: root must be a JSON object.');
    }

    final data = parsed['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const FormatException('Invalid backup: missing "data" key.');
    }

    final pondsData = data['ponds'] as List<dynamic>? ?? [];
    final batchesData = data['batches'] as List<dynamic>? ?? [];
    final recordsData = data['feedRecords'] as List<dynamic>? ?? [];
    final inventoryData = data['inventory'] as List<dynamic>? ?? [];

    await db.transaction(() async {
      // Clear existing records in child-to-parent order
      await db.delete(db.inventoryTransactions).go();
      await db.delete(db.treatmentRecords).go();
      await db.delete(db.machineRuns).go();
      await db.delete(db.expenses).go();
      await db.delete(db.revenues).go();
      await db.delete(db.marketPrices).go();
      await db.delete(db.feedRecords).go();
      await db.delete(db.samplingEntries).go();
      await db.delete(db.hapaChecks).go();
      await db.delete(db.growthRecords).go();
      await db.delete(db.biomassSnapshots).go();
      await db.delete(db.inventoryItems).go();
      await db.delete(db.batches).go();
      await db.delete(db.ponds).go();
      await db.delete(db.farmSites).go();

      // Insert Sites
      for (final s in (data['sites'] as List<dynamic>? ?? [])) {
        await db.into(db.farmSites).insert(
          FarmSitesCompanion(
            id: Value(s['id'] as String),
            name: Value(s['name'] as String),
            address: Value(s['address'] as String?),
            latitude: Value((s['latitude'] as num?)?.toDouble()),
            longitude: Value((s['longitude'] as num?)?.toDouble()),
            createdAt: Value(DateTime.parse(s['createdAt'] as String)),
          ),
        );
      }

      // Insert Ponds
      for (final p in pondsData) {
        await db.into(db.ponds).insert(
          PondsCompanion(
            id: Value(p['id'] as String),
            siteId: Value(p['siteId'] as String?),
            name: Value(p['name'] as String),
            areaSqMeters: Value((p['areaSqMeters'] as num).toDouble()),
            waterDepthMeters: Value((p['waterDepthMeters'] as num).toDouble()),
            aeratorsCount: Value((p['aeratorsCount'] as num?)?.toInt() ?? 0),
            totalAeratorHp: Value((p['totalAeratorHp'] as num?)?.toDouble() ?? 0.0),
            status: Value((p['status'] as String?) ?? 'active'),
            createdAt: Value(DateTime.parse(p['createdAt'] as String)),
          ),
        );
      }

      // Insert Batches
      for (final b in batchesData) {
        await db.into(db.batches).insert(
          BatchesCompanion(
            id: Value(b['id'] as String),
            pondId: Value(b['pondId'] as String),
            batchNumber: Value((b['batchNumber'] as num).toInt()),
            species: Value((b['species'] as String?) ?? 'Litopenaeus vannamei'),
            stockingDate: Value(DateTime.parse(b['stockingDate'] as String)),
            shrimpStockedCount: Value((b['shrimpStockedCount'] as num).toInt()),
            plStage: Value((b['plStage'] as String?) ?? 'PL-10'),
            hatcherySource: Value(b['hatcherySource'] as String?),
            seedCost: Value((b['seedCost'] as num?)?.toDouble() ?? 0.0),
            targetHarvestWeightG: Value((b['targetHarvestWeightG'] as num?)?.toDouble() ?? 25.0),
            status: Value((b['status'] as String?) ?? 'active'),
            createdAt: Value(DateTime.parse(b['createdAt'] as String)),
          ),
        );
      }

      // Insert Feed Records
      for (final f in recordsData) {
        await db.into(db.feedRecords).insert(
          FeedRecordsCompanion(
            id: Value(f['id'] as String),
            pondId: Value(f['pondId'] as String),
            batchId: Value(f['batchId'] as String),
            date: Value(DateTime.parse(f['date'] as String)),
            timeSlot: Value(f['timeSlot'] as String),
            customTime: Value(f['customTime'] as String?),
            starterG: Value((f['starterG'] as num?)?.toDouble() ?? 0.0),
            grower1G: Value((f['grower1G'] as num?)?.toDouble() ?? 0.0),
            grower2G: Value((f['grower2G'] as num?)?.toDouble() ?? 0.0),
            finisher1G: Value((f['finisher1G'] as num?)?.toDouble() ?? 0.0),
            finisher2G: Value((f['finisher2G'] as num?)?.toDouble() ?? 0.0),
            otherFeedName: Value(f['otherFeedName'] as String?),
            otherFeedG: Value((f['otherFeedG'] as num?)?.toDouble() ?? 0.0),
            totalGrams: Value((f['totalGrams'] as num).toDouble()),
            totalKg: Value((f['totalKg'] as num).toDouble()),
            trayChecked: Value((f['trayChecked'] as bool?) ?? false),
            trayLeftoverPct: Value((f['trayLeftoverPct'] as num?)?.toInt() ?? 0),
            notes: Value(f['notes'] as String?),
            createdAt: Value(DateTime.parse(f['createdAt'] as String)),
          ),
        );
      }

      // Insert Inventory Items
      for (final i in inventoryData) {
        await db.into(db.inventoryItems).insert(
          InventoryItemsCompanion(
            id: Value(i['id'] as String),
            siteId: Value(i['siteId'] as String?),
            category: Value(i['category'] as String),
            name: Value(i['name'] as String),
            brand: Value(i['brand'] as String?),
            pelletSize: Value(i['pelletSize'] as String?),
            unit: Value((i['unit'] as String?) ?? 'kg'),
            bagWeightKg: Value((i['bagWeightKg'] as num?)?.toDouble() ?? 25.0),
            currentStock: Value((i['currentStock'] as num?)?.toDouble() ?? 0.0),
            lowStockThreshold: Value((i['lowStockThreshold'] as num?)?.toDouble() ?? 10.0),
            costPerUnit: Value((i['costPerUnit'] as num?)?.toDouble() ?? 0.0),
            supplier: Value(i['supplier'] as String?),
            createdAt: Value(DateTime.parse(i['createdAt'] as String)),
          ),
        );
      }
    });

    return {
      'ponds': pondsData.length,
      'batches': batchesData.length,
      'feedRecords': recordsData.length,
      'inventoryItems': inventoryData.length,
    };
  }
}
