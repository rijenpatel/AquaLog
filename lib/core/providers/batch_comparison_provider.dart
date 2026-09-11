import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/batch_comparison_models.dart';
import '../services/batch_comparison_service.dart';
import 'database_provider.dart';

/// Provider for selected batch IDs in comparison (2 to 3 batches)
final selectedComparisonBatchIdsProvider = StateProvider<List<String>>((ref) => []);

/// Provider for comparison alignment mode (Same DOC vs Same Date)
final comparisonModeProvider = StateProvider<ComparisonMode>((ref) => ComparisonMode.sameDoc);

/// Reactive batch comparison result provider
final batchComparisonResultProvider = FutureProvider.autoDispose<BatchComparisonResult?>((ref) async {
  final batchIds = ref.watch(selectedComparisonBatchIdsProvider);
  final mode = ref.watch(comparisonModeProvider);

  if (batchIds.length < 2) return null;

  // React to underlying data changes
  ref.watch(allBatchesMasterStreamProvider);
  ref.watch(feedRecordsStreamProvider);
  ref.watch(samplingEntriesStreamProvider);
  ref.watch(expensesStreamProvider);
  ref.watch(revenuesStreamProvider);

  final db = ref.watch(appDatabaseProvider);
  final service = BatchComparisonService(db);

  try {
    return await service.compareBatches(batchIds: batchIds, mode: mode);
  } catch (e) {
    return null;
  }
});
