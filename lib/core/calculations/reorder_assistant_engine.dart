import '../database/app_database.dart';

enum ReorderUrgency {
  optimal,
  lowStock,
  orderNow,
  outOfStock;

  String get label {
    switch (this) {
      case ReorderUrgency.optimal:
        return 'Optimal';
      case ReorderUrgency.lowStock:
        return 'Low Stock';
      case ReorderUrgency.orderNow:
        return 'ORDER NOW';
      case ReorderUrgency.outOfStock:
        return 'Out of Stock';
    }
  }
}

class ItemReorderForecast {
  final InventoryItem item;
  final double currentStock;
  final double dailyBurnRate;
  final double projectedDaysRemaining;
  final int leadTimeDays;
  final double safetyStockQty;
  final double reorderPointQty;
  final double suggestedOrderQty;
  final double minimumOrderQty;
  final double estimatedReorderCost;
  final ReorderUrgency urgency;
  final bool hasExpiryRisk;
  final int? daysToExpiry;
  final String advice;

  const ItemReorderForecast({
    required this.item,
    required this.currentStock,
    required this.dailyBurnRate,
    required this.projectedDaysRemaining,
    required this.leadTimeDays,
    required this.safetyStockQty,
    required this.reorderPointQty,
    required this.suggestedOrderQty,
    required this.minimumOrderQty,
    required this.estimatedReorderCost,
    required this.urgency,
    required this.hasExpiryRisk,
    this.daysToExpiry,
    required this.advice,
  });
}

class ReorderAssistantEngine {
  /// Computes the average daily burn rate from consumption transactions over the lookback window (default 14 days)
  static double calculateDailyBurnRate(List<InventoryTransaction> transactions, {int lookbackDays = 14}) {
    if (transactions.isEmpty) return 0.0;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: lookbackDays));

    final consumptionTx = transactions.where((tx) =>
        (tx.type == 'consumption' || tx.quantity < 0) &&
        !tx.date.isBefore(windowStart)).toList();

    if (consumptionTx.isEmpty) return 0.0;

    double totalConsumed = 0.0;
    for (final tx in consumptionTx) {
      totalConsumed += tx.quantity.abs();
    }

    return double.parse((totalConsumed / lookbackDays).toStringAsFixed(2));
  }

  /// Evaluates stock forecast and procurement recommendation for a single item
  static ItemReorderForecast forecastItem({
    required InventoryItem item,
    required List<InventoryTransaction> itemTransactions,
    int? customLeadTimeDays,
    double? customSafetyStockDays,
    int targetCoverageDays = 21,
  }) {
    final burnRate = calculateDailyBurnRate(itemTransactions);

    int leadTime = customLeadTimeDays ?? (item.category == 'feed' ? 3 : (item.category == 'fuel' ? 2 : 5));
    double safetyStockDays = customSafetyStockDays ?? 3.0;

    double safetyStock = burnRate > 0
        ? double.parse((burnRate * safetyStockDays).toStringAsFixed(1))
        : item.lowStockThreshold;

    if (safetyStock < item.lowStockThreshold) {
      safetyStock = item.lowStockThreshold;
    }

    final reorderPoint = burnRate > 0
        ? double.parse(((burnRate * leadTime) + safetyStock).toStringAsFixed(1))
        : item.lowStockThreshold;

    final daysRemaining = burnRate > 0
        ? double.parse((item.currentStock / burnRate).toStringAsFixed(1))
        : (item.currentStock > 0 ? 999.0 : 0.0);

    ReorderUrgency urgency;
    if (item.currentStock <= 0) {
      urgency = ReorderUrgency.outOfStock;
    } else if (item.currentStock <= reorderPoint) {
      urgency = ReorderUrgency.orderNow;
    } else if (item.currentStock <= (reorderPoint * 1.35)) {
      urgency = ReorderUrgency.lowStock;
    } else {
      urgency = ReorderUrgency.optimal;
    }

    // Suggested order to cover target cycle (default 21 days)
    double suggestedQty = 0.0;
    double minQty = 0.0;

    if (burnRate > 0) {
      final targetStock = (burnRate * targetCoverageDays) + safetyStock;
      suggestedQty = (targetStock - item.currentStock).clamp(0.0, 999999.0);
      minQty = (reorderPoint - item.currentStock + safetyStock).clamp(0.0, 999999.0);
    } else if (item.currentStock <= item.lowStockThreshold) {
      suggestedQty = item.lowStockThreshold * 2;
      minQty = item.lowStockThreshold;
    }

    // Expiry risk
    bool expiryRisk = false;
    int? daysToExpiry;
    if (item.expiryDate != null) {
      daysToExpiry = item.expiryDate!.difference(DateTime.now()).inDays;
      if (daysToExpiry > 0 && burnRate > 0 && daysToExpiry < daysRemaining) {
        expiryRisk = true;
      }
    }

    String advice;
    if (urgency == ReorderUrgency.outOfStock) {
      advice = 'Stock exhausted! Procure ${suggestedQty.toStringAsFixed(0)} ${item.unit} immediately to avoid operational disruption.';
    } else if (urgency == ReorderUrgency.orderNow) {
      advice = 'Stock below reorder point ($reorderPoint ${item.unit}). Place order now to ensure arrival before safety buffer depletes.';
    } else if (urgency == ReorderUrgency.lowStock) {
      advice = 'Stock approaching reorder threshold. Prepare supplier purchase order for ${suggestedQty.toStringAsFixed(0)} ${item.unit}.';
    } else {
      advice = 'Stock level healthy. Projected coverage of $daysRemaining days.';
    }

    if (expiryRisk && daysToExpiry != null) {
      advice += ' Warning: Current stock projected to outlast expiry date ($daysToExpiry days left). Prioritize consumption (FEFO).';
    }

    final cost = double.parse((suggestedQty * item.costPerUnit).toStringAsFixed(2));

    return ItemReorderForecast(
      item: item,
      currentStock: item.currentStock,
      dailyBurnRate: burnRate,
      projectedDaysRemaining: daysRemaining,
      leadTimeDays: leadTime,
      safetyStockQty: safetyStock,
      reorderPointQty: reorderPoint,
      suggestedOrderQty: double.parse(suggestedQty.toStringAsFixed(1)),
      minimumOrderQty: double.parse(minQty.toStringAsFixed(1)),
      estimatedReorderCost: cost,
      urgency: urgency,
      hasExpiryRisk: expiryRisk,
      daysToExpiry: daysToExpiry,
      advice: advice,
    );
  }

  /// Generates the urgent procurement action list
  static List<ItemReorderForecast> generateProcurementList(
    List<InventoryItem> items,
    Map<String, List<InventoryTransaction>> transactionsByItem,
  ) {
    final list = <ItemReorderForecast>[];

    for (final item in items) {
      final txs = transactionsByItem[item.id] ?? const [];
      final forecast = forecastItem(item: item, itemTransactions: txs);
      if (forecast.urgency == ReorderUrgency.orderNow ||
          forecast.urgency == ReorderUrgency.outOfStock ||
          forecast.urgency == ReorderUrgency.lowStock) {
        list.add(forecast);
      }
    }

    // Sort by most urgent first
    list.sort((a, b) => b.urgency.index.compareTo(a.urgency.index));
    return list;
  }
}
