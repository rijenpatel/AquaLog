import 'package:flutter/foundation.dart';

@immutable
class HarvestPredictionResult {
  final int daysToHarvest;
  final DateTime predictedHarvestDate;
  final double currentAbwGrams;
  final double targetWeightGrams;
  final double adgUsedGramsPerDay;
  final bool isBaselineAdgUsed;
  final String formattedDays;

  const HarvestPredictionResult({
    required this.daysToHarvest,
    required this.predictedHarvestDate,
    required this.currentAbwGrams,
    required this.targetWeightGrams,
    required this.adgUsedGramsPerDay,
    required this.isBaselineAdgUsed,
    required this.formattedDays,
  });

  @override
  String toString() => 'HarvestPredictionResult(Days: $daysToHarvest, Date: $predictedHarvestDate)';
}

class HarvestPredictor {
  const HarvestPredictor();

  /// Predicts days to target harvest weight and projected calendar harvest date:
  /// Formula: Days to Harvest = (Target Weight (g) - Current ABW (g)) / Current ADG (g/day)
  /// If ADG is null or <= 0 (e.g. fewer than 2 samplings logged), falls back to
  /// standard biological benchmark baseline: 0.22 g/day for intensive L. vannamei.
  static HarvestPredictionResult calculate({
    required double currentAbwGrams,
    required double targetWeightGrams,
    double? currentAdgGramsPerDay,
    DateTime? currentDate,
  }) {
    if (targetWeightGrams <= 0) {
      throw ArgumentError('Target harvest weight must be greater than zero.');
    }

    final now = currentDate ?? DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);

    if (currentAbwGrams >= targetWeightGrams) {
      return HarvestPredictionResult(
        daysToHarvest: 0,
        predictedHarvestDate: nowMidnight,
        currentAbwGrams: currentAbwGrams,
        targetWeightGrams: targetWeightGrams,
        adgUsedGramsPerDay: currentAdgGramsPerDay ?? 0.22,
        isBaselineAdgUsed: currentAdgGramsPerDay == null || currentAdgGramsPerDay <= 0,
        formattedDays: 'Target Reached (0 days)',
      );
    }

    final double adgToUse;
    final bool isBaseline;
    if (currentAdgGramsPerDay != null && currentAdgGramsPerDay > 0) {
      adgToUse = currentAdgGramsPerDay;
      isBaseline = false;
    } else {
      adgToUse = 0.22; // Standard commercial baseline
      isBaseline = true;
    }

    final weightRemaining = targetWeightGrams - currentAbwGrams;
    final days = (weightRemaining / adgToUse).ceil();
    final harvestDate = nowMidnight.add(Duration(days: days));

    return HarvestPredictionResult(
      daysToHarvest: days,
      predictedHarvestDate: harvestDate,
      currentAbwGrams: currentAbwGrams,
      targetWeightGrams: targetWeightGrams,
      adgUsedGramsPerDay: adgToUse,
      isBaselineAdgUsed: isBaseline,
      formattedDays: '$days days',
    );
  }
}
