import 'package:flutter/foundation.dart';

@immutable
class BreakEvenResult {
  final double breakEvenPricePerKg;
  final double totalBatchCost;
  final double biomassOrHarvestWeightKg;
  final double? currentMarketPricePerKg;
  final double? marginPerKg;
  final bool? isProfitableAtMarketPrice;
  final String formattedBreakEven;

  const BreakEvenResult({
    required this.breakEvenPricePerKg,
    required this.totalBatchCost,
    required this.biomassOrHarvestWeightKg,
    this.currentMarketPricePerKg,
    this.marginPerKg,
    this.isProfitableAtMarketPrice,
    required this.formattedBreakEven,
  });

  @override
  String toString() => 'BreakEvenResult(₹$formattedBreakEven/kg)';
}

class BreakEvenCalculator {
  const BreakEvenCalculator();

  /// Calculates Break-Even Shrimp Sale Price benchmark (₹/kg):
  /// Break-Even Price = Total Incurred Batch Costs (₹) / Current Biomass or Harvest Weight (kg)
  static BreakEvenResult calculate({
    required double totalBatchCost,
    required double biomassOrHarvestWeightKg,
    double? currentMarketPricePerKg,
  }) {
    if (biomassOrHarvestWeightKg <= 0) {
      throw ArgumentError('Biomass or harvest weight must be greater than zero.');
    }
    if (totalBatchCost < 0) {
      throw ArgumentError('Total batch costs cannot be negative.');
    }

    final rawBreakEven = totalBatchCost / biomassOrHarvestWeightKg;
    final roundedBreakEven = double.parse(rawBreakEven.toStringAsFixed(2));

    double? margin;
    bool? isProfitable;
    if (currentMarketPricePerKg != null && currentMarketPricePerKg > 0) {
      margin = double.parse((currentMarketPricePerKg - roundedBreakEven).toStringAsFixed(2));
      isProfitable = margin >= 0;
    }

    return BreakEvenResult(
      breakEvenPricePerKg: roundedBreakEven,
      totalBatchCost: totalBatchCost,
      biomassOrHarvestWeightKg: biomassOrHarvestWeightKg,
      currentMarketPricePerKg: currentMarketPricePerKg,
      marginPerKg: margin,
      isProfitableAtMarketPrice: isProfitable,
      formattedBreakEven: roundedBreakEven.toStringAsFixed(2),
    );
  }
}
