import 'dart:convert';
import '../database/app_database.dart';

class LegacyImportResult {
  final int pondsImported;
  final int batchesImported;
  final int recordsImported;
  final int inventoryImported;
  final int errorsCount;
  final List<String> warnings;

  const LegacyImportResult({
    required this.pondsImported,
    required this.batchesImported,
    required this.recordsImported,
    required this.inventoryImported,
    required this.errorsCount,
    required this.warnings,
  });

  @override
  String toString() => 'LegacyImportResult(ponds: $pondsImported, batches: $batchesImported, records: $recordsImported)';
}

class LegacyImportService {
  final AppDatabase db;

  const LegacyImportService(this.db);

  /// Detects if an arbitrary JSON string is an old AquaLog web application export:
  /// Old exports have either top-level keys like `al_ponds`, `al_records` or
  /// an object with `data.ponds` or array collections.
  static bool isLegacyFormat(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('al_ponds') ||
            decoded.containsKey('al_records') ||
            decoded.containsKey('al_batches')) {
          return true;
        }
        if (decoded['data'] is Map<String, dynamic>) {
          final data = decoded['data'] as Map<String, dynamic>;
          if (data.containsKey('ponds') && decoded['schemaVersion'] == null) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Migrates legacy web application data into Drift SQLite tables.
  Future<LegacyImportResult> importLegacyJson(String jsonString) async {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON root: Expected object.');
    }

    // Extract arrays from either raw localStorage keys or structured wrapper
    final List<dynamic> rawPonds = decoded['al_ponds'] ?? (decoded['data']?['ponds']) ?? [];
    final List<dynamic> rawBatches = decoded['al_batches'] ?? (decoded['data']?['batches']) ?? [];
    final List<dynamic> rawRecords = decoded['al_records'] ?? (decoded['data']?['records']) ?? [];
    final List<dynamic> rawInventory = decoded['al_inventory'] ?? (decoded['data']?['inventory']) ?? [];

    int pondsCount = 0;
    int batchesCount = 0;
    int recordsCount = 0;
    int inventoryCount = 0;
    int errors = 0;
    final warnings = <String>[];

    await db.transaction(() async {
      // 1. Migrate Ponds
      for (final p in rawPonds) {
        try {
          final pondId = p['id']?.toString() ?? 'pond_${DateTime.now().millisecondsSinceEpoch}_$pondsCount';
          final name = p['name']?.toString() ?? 'Pond ${pondsCount + 1}';
          final area = (p['area'] ?? p['areaSqMeters'] ?? 4000.0) as num;
          final depth = (p['depth'] ?? p['waterDepthMeters'] ?? 1.5) as num;
          final aerators = (p['aerators'] ?? p['aeratorsCount'] ?? 0) as num;
          final hp = (p['hp'] ?? p['totalAeratorHp'] ?? 0.0) as num;

          await db.into(db.ponds).insertOnConflictUpdate(
            PondsCompanion(
              id: Value(pondId),
              name: Value(name),
              areaSqMeters: Value(area.toDouble()),
              waterDepthMeters: Value(depth.toDouble()),
              aeratorsCount: Value(aerators.toInt()),
              totalAeratorHp: Value(hp.toDouble()),
              status: Value(p['status']?.toString() ?? 'active'),
            ),
          );
          pondsCount++;
        } catch (e) {
          errors++;
          warnings.add('Failed to import legacy pond: $e');
        }
      }

      // 2. Migrate Batches
      for (final b in rawBatches) {
        try {
          final batchId = b['id']?.toString() ?? 'batch_${DateTime.now().millisecondsSinceEpoch}_$batchesCount';
          final pondId = b['pondId']?.toString() ?? (rawPonds.isNotEmpty ? rawPonds.first['id'].toString() : 'pond_1');
          final batchNum = (b['batchNum'] ?? b['batchNumber'] ?? (batchesCount + 1)) as num;
          final species = b['species']?.toString() ?? 'Litopenaeus vannamei';
          final stockingDateStr = b['stockingDate']?.toString() ?? DateTime.now().toIso8601String();
          final count = (b['count'] ?? b['shrimpStockedCount'] ?? 100000) as num;

          DateTime stockingDate;
          try {
            stockingDate = DateTime.parse(stockingDateStr);
          } catch (_) {
            stockingDate = DateTime.now();
          }

          await db.into(db.batches).insertOnConflictUpdate(
            BatchesCompanion(
              id: Value(batchId),
              pondId: Value(pondId),
              batchNumber: Value(batchNum.toInt()),
              species: Value(species),
              stockingDate: Value(stockingDate),
              shrimpStockedCount: Value(count.toInt()),
              plStage: Value(b['plStage']?.toString() ?? 'PL-10'),
              hatcherySource: Value(b['hatchery']?.toString() ?? b['hatcherySource']?.toString()),
              seedCost: Value((b['seedCost'] as num?)?.toDouble() ?? 0.0),
              targetHarvestWeightG: Value((b['targetWeight'] as num?)?.toDouble() ?? 25.0),
              status: Value(b['status']?.toString() ?? 'active'),
            ),
          );
          batchesCount++;
        } catch (e) {
          errors++;
          warnings.add('Failed to import legacy batch: $e');
        }
      }

      // 3. Migrate Records
      for (final r in rawRecords) {
        try {
          final recId = r['id']?.toString() ?? 'rec_${DateTime.now().millisecondsSinceEpoch}_$recordsCount';
          final pondId = r['pondId']?.toString() ?? (rawPonds.isNotEmpty ? rawPonds.first['id'].toString() : 'pond_1');
          final batchId = r['batchId']?.toString() ?? (rawBatches.isNotEmpty ? rawBatches.first['id'].toString() : 'batch_1');
          final dateStr = r['date']?.toString() ?? DateTime.now().toIso8601String();
          final timeSlot = r['time']?.toString() ?? r['timeSlot']?.toString() ?? '7:00 AM';

          DateTime date;
          try {
            date = DateTime.parse(dateStr);
          } catch (_) {
            date = DateTime.now();
          }

          final totalGrams = (r['totalGrams'] ?? r['total'] ?? 0.0) as num;
          final totalKg = totalGrams / 1000.0;

          await db.into(db.feedRecords).insertOnConflictUpdate(
            FeedRecordsCompanion(
              id: Value(recId),
              pondId: Value(pondId),
              batchId: Value(batchId),
              date: Value(date),
              timeSlot: Value(timeSlot),
              starterG: Value((r['feed1'] as num?)?.toDouble() ?? 0.0),
              grower1G: Value((r['feed2'] as num?)?.toDouble() ?? 0.0),
              grower2G: Value((r['feed3'] as num?)?.toDouble() ?? 0.0),
              finisher1G: Value((r['feed4'] as num?)?.toDouble() ?? 0.0),
              finisher2G: Value((r['feed5'] as num?)?.toDouble() ?? 0.0),
              totalGrams: Value(totalGrams.toDouble()),
              totalKg: Value(totalKg),
              trayChecked: Value(r['trayLeftover'] != null),
              trayLeftoverPct: Value((r['trayLeftover'] as num?)?.toInt() ?? 0),
              notes: Value(r['notes']?.toString()),
            ),
          );
          recordsCount++;
        } catch (e) {
          errors++;
          warnings.add('Failed to import legacy feed record: $e');
        }
      }

      // 4. Migrate Inventory
      for (final i in rawInventory) {
        try {
          final itemId = i['id']?.toString() ?? 'inv_${DateTime.now().millisecondsSinceEpoch}_$inventoryCount';
          final name = i['name']?.toString() ?? 'Feed Item';
          final category = i['category']?.toString() ?? 'feed';
          final stock = (i['currentStock'] ?? i['stock'] ?? 0.0) as num;

          await db.into(db.inventoryItems).insertOnConflictUpdate(
            InventoryItemsCompanion(
              id: Value(itemId),
              name: Value(name),
              category: Value(category),
              currentStock: Value(stock.toDouble()),
              costPerUnit: Value((i['costPerUnit'] as num?)?.toDouble() ?? 0.0),
              unit: Value(i['unit']?.toString() ?? 'kg'),
            ),
          );
          inventoryCount++;
        } catch (e) {
          errors++;
          warnings.add('Failed to import legacy inventory item: $e');
        }
      }
    });

    return LegacyImportResult(
      pondsImported: pondsCount,
      batchesImported: batchesCount,
      recordsImported: recordsCount,
      inventoryImported: inventoryCount,
      errorsCount: errors,
      warnings: warnings,
    );
  }
}
