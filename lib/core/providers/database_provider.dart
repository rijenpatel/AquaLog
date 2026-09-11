import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Stream Providers for reactive queries
final allSitesStreamProvider = StreamProvider<List<FarmSite>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.farmSites).watch();
});

final activeSitesStreamProvider = StreamProvider<List<FarmSite>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.farmSites)..where((t) => t.status.equals('active'))).watch();
});

final allPondsStreamProvider = StreamProvider<List<Pond>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.ponds)..where((t) => t.status.equals('active'))).watch();
});

final allPondsMasterStreamProvider = StreamProvider<List<Pond>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.ponds).watch();
});

final activeBatchesStreamProvider = StreamProvider<List<Batch>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.batches)..where((t) => t.status.equals('active'))).watch();
});

final allBatchesMasterStreamProvider = StreamProvider<List<Batch>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.batches)..orderBy([(t) => OrderingTerm.desc(t.stockingDate)])).watch();
});

final allInventoryItemsStreamProvider = StreamProvider<List<InventoryItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.inventoryItems).watch();
});

final feedRecordsStreamProvider = StreamProvider<List<FeedRecord>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.feedRecords)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final samplingEntriesStreamProvider = StreamProvider<List<SamplingEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.samplingEntries)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final allHapaChecksStreamProvider = StreamProvider<List<HapaCheck>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.hapaChecks)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.expenses)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final revenuesStreamProvider = StreamProvider<List<Revenue>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.revenues)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final marketPricesStreamProvider = StreamProvider<List<MarketPrice>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.marketPrices)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.userProfiles).watchSingleOrNull();
});

final siteWeatherStreamProvider = StreamProvider.family<WeatherObservation?, String?>((ref, siteId) {
  if (siteId == null) return Stream.value(null);
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.weatherObservations)
        ..where((t) => t.siteId.equals(siteId))
        ..orderBy([(t) => OrderingTerm.desc(t.date)])
        ..limit(1))
      .watchSingleOrNull();
});

final databaseProvider = appDatabaseProvider;

final allWaterQualityLogsStreamProvider = StreamProvider<List<WaterQualityLog>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.waterQualityLogs)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final pondWaterQualityLogsStreamProvider = StreamProvider.family<List<WaterQualityLog>, String>((ref, pondId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchWaterQualityLogsForPond(pondId);
});

final batchMortalityRecordsStreamProvider = StreamProvider.family<List<MortalityRecord>, String>((ref, batchId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchMortalityRecordsForBatch(batchId);
});

final batchPopulationAdjustmentsStreamProvider = StreamProvider.family<List<PopulationAdjustment>, String>((ref, batchId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPopulationAdjustmentsForBatch(batchId);
});

final pondOperationsStreamProvider = StreamProvider.family<List<PondOperation>, String>((ref, pondId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPondOperations(pondId);
});

final allFarmTasksStreamProvider = StreamProvider<List<FarmActionTask>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchActionTasks();
});

final pendingFarmTasksStreamProvider = StreamProvider<List<FarmActionTask>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchActionTasks(status: 'pending');
});

final batchFeedPlansStreamProvider = StreamProvider.family<List<DailyFeedPlan>, String>((ref, batchId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.dailyFeedPlans)
        ..where((t) => t.batchId.equals(batchId))
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();
});

