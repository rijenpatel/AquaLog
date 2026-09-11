import 'package:flutter/foundation.dart';

@immutable
class HapaResult {
  final double survivalPercentage;
  final int estimatedPopulation;
  final int hapaStocked;
  final int hapaAlive;
  final int batchStockedCount;
  final String formattedSurvival;

  const HapaResult({
    required this.survivalPercentage,
    required this.estimatedPopulation,
    required this.hapaStocked,
    required this.hapaAlive,
    required this.batchStockedCount,
    required this.formattedSurvival,
  });

  @override
  String toString() => 'HapaResult(survival: $formattedSurvival%, estPop: $estimatedPopulation)';
}

class HapaSurvivalCalculator {
  const HapaSurvivalCalculator();

  /// Calculates Hapa Net Survival % and projects total pond population.
  /// Survival % = (hapaAlive / hapaStocked) * 100
  /// N_estimated = StockedCount * (Survival % / 100)
  static HapaResult calculate({
    required int hapaStocked,
    required int hapaAlive,
    required int batchStockedCount,
  }) {
    if (hapaStocked <= 0) {
      throw ArgumentError('Hapa stocked count must be greater than zero (standard: 100 pcs).');
    }
    if (hapaAlive < 0) {
      throw ArgumentError('Hapa alive count cannot be negative.');
    }
    if (hapaAlive > hapaStocked) {
      throw ArgumentError('Hapa alive count ($hapaAlive) cannot exceed stocked count ($hapaStocked).');
    }
    if (batchStockedCount <= 0) {
      throw ArgumentError('Batch stocked count must be greater than zero.');
    }

    final rawSurvival = (hapaAlive / hapaStocked) * 100.0;
    final roundedSurvival = double.parse(rawSurvival.toStringAsFixed(1));
    final estimatedPop = (batchStockedCount * (roundedSurvival / 100.0)).round();

    return HapaResult(
      survivalPercentage: roundedSurvival,
      estimatedPopulation: estimatedPop,
      hapaStocked: hapaStocked,
      hapaAlive: hapaAlive,
      batchStockedCount: batchStockedCount,
      formattedSurvival: roundedSurvival.toStringAsFixed(1),
    );
  }
}
