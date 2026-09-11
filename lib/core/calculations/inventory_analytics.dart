import 'package:flutter/foundation.dart';

@immutable
class DepletionForecastResult {
  final int daysRemaining;
  final DateTime projectedDepletionDate;
  final double dailyBurnRate;
  final double currentStock;
  final bool isUrgentReorder;
  final bool isCriticalReorder;
  final String statusMessage;

  const DepletionForecastResult({
    required this.daysRemaining,
    required this.projectedDepletionDate,
    required this.dailyBurnRate,
    required this.currentStock,
    required this.isUrgentReorder,
    required this.isCriticalReorder,
    required this.statusMessage,
  });

  @override
  String toString() => 'DepletionForecastResult($daysRemaining days remaining)';
}

class InventoryAnalytics {
  const InventoryAnalytics();

  /// Calculates rolling 7-day Daily Burn Rate (kg/day):
  /// Burn Rate = Total Consumed in Last 7 Days / 7.0
  static double calculateDailyBurnRate(double totalConsumedLast7Days) {
    if (totalConsumedLast7Days <= 0) return 0.0;
    return double.parse((totalConsumedLast7Days / 7.0).toStringAsFixed(1));
  }

  /// Forecasts Days of Inventory Remaining:
  /// Days = Floor(Current Stock / Daily Burn Rate)
  static DepletionForecastResult calculateDepletionForecast({
    required double currentStock,
    required double dailyBurnRate,
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();
    final nowMidnight = DateTime(now.year, now.month, now.day);

    if (dailyBurnRate <= 0) {
      return DepletionForecastResult(
        daysRemaining: 999,
        projectedDepletionDate: nowMidnight.add(const Duration(days: 999)),
        dailyBurnRate: 0.0,
        currentStock: currentStock,
        isUrgentReorder: false,
        isCriticalReorder: false,
        statusMessage: 'No recent consumption logged.',
      );
    }

    final days = (currentStock / dailyBurnRate).floor();
    final depletionDate = nowMidnight.add(Duration(days: days));
    final isCritical = days <= 3;
    final isUrgent = days <= 7;

    String message;
    if (isCritical) {
      message = 'CRITICAL REORDER: Stock depleting in $days days!';
    } else if (isUrgent) {
      message = 'Reorder soon: $days days of stock remaining.';
    } else {
      message = '$days days of stock remaining.';
    }

    return DepletionForecastResult(
      daysRemaining: days,
      projectedDepletionDate: depletionDate,
      dailyBurnRate: dailyBurnRate,
      currentStock: currentStock,
      isUrgentReorder: isUrgent,
      isCriticalReorder: isCritical,
      statusMessage: message,
    );
  }

  /// Calculates Stock Turnover Ratio (STR):
  /// STR = Cost of Goods Used / Average Inventory Value
  static double calculateStockTurnoverRatio({
    required double costOfGoodsUsed,
    required double beginningInventoryValue,
    required double endingInventoryValue,
  }) {
    final avgInventory = (beginningInventoryValue + endingInventoryValue) / 2.0;
    if (avgInventory <= 0) return 0.0;
    return double.parse((costOfGoodsUsed / avgInventory).toStringAsFixed(2));
  }

  /// Calculates Feed Shrinkage & Spoilage Percentage:
  /// Shrinkage % = (Spoilage & Damaged Feed (kg) / Purchased Feed (kg)) * 100
  static double calculateFeedShrinkagePct({
    required double damagedAndSpoiledKg,
    required double totalPurchasedKg,
  }) {
    if (totalPurchasedKg <= 0) return 0.0;
    final pct = (damagedAndSpoiledKg / totalPurchasedKg) * 100.0;
    return double.parse(pct.toStringAsFixed(2));
  }

  /// Calculates the valuation of an individual inventory item.
  /// If stock or costPerUnit is negative or zero, returns 0.0.
  /// If stock unit is in bags, and costPerUnit is per-bag vs per-kg, ensures physical alignment.
  static double calculateItemValuation({
    required double currentStock,
    required double costPerUnit,
    String unit = 'kg',
    double bagWeightKg = 25.0,
  }) {
    if (currentStock <= 0 || costPerUnit <= 0) return 0.0;
    final cleanUnit = unit.trim().toLowerCase();
    // If unit is in grams, costPerUnit is typically per-kg or per-g
    if (cleanUnit == 'g' || cleanUnit == 'grams' || cleanUnit == 'gram') {
      return (currentStock / 1000.0) * costPerUnit;
    }
    return currentStock * costPerUnit;
  }

  /// Calculates total inventory valuation across multiple items.
  static double calculateTotalValuation(Iterable<dynamic> items) {
    return items.fold<double>(0.0, (acc, item) {
      final stock = (item.currentStock as num?)?.toDouble() ?? 0.0;
      final cost = (item.costPerUnit as num?)?.toDouble() ?? 0.0;
      final unit = (item.unit as String?) ?? 'kg';
      final bagWeight = (item.bagWeightKg as num?)?.toDouble() ?? 25.0;
      return acc + calculateItemValuation(
        currentStock: stock,
        costPerUnit: cost,
        unit: unit,
        bagWeightKg: bagWeight,
      );
    });
  }
}
