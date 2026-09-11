import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// Represents a single feed product consumed in a feed session.
@immutable
class FeedItem {
  final String? inventoryFeedId;
  final String feedName;
  final String? brand;
  final String? size;
  final double quantity;
  final String unit; // 'kg', 'g', 'bags', 'lbs'
  final double? bagWeightKg; // Configured bag weight in kg if unit is bags
  final bool isLegacy;

  const FeedItem({
    this.inventoryFeedId,
    required this.feedName,
    this.brand,
    this.size,
    required this.quantity,
    this.unit = 'kg',
    this.bagWeightKg,
    this.isLegacy = false,
  });

  /// Quantity converted to canonical kilograms (kg)
  double get quantityKg => FeedCalculator.normalizeFeedQuantityToKg(quantity, unit, bagWeightKg: bagWeightKg);

  Map<String, dynamic> toJson() => {
    if (inventoryFeedId != null) 'inventoryFeedId': inventoryFeedId,
    'feedName': feedName,
    if (brand != null) 'brand': brand,
    if (size != null) 'size': size,
    'quantity': quantity,
    'unit': unit,
    if (bagWeightKg != null) 'bagWeightKg': bagWeightKg,
    'isLegacy': isLegacy,
  };

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      inventoryFeedId: json['inventoryFeedId'] as String?,
      feedName: (json['feedName'] as String?) ?? 'Unknown Feed',
      brand: json['brand'] as String?,
      size: json['size'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: (json['unit'] as String?) ?? 'kg',
      bagWeightKg: (json['bagWeightKg'] as num?)?.toDouble(),
      isLegacy: (json['isLegacy'] as bool?) ?? false,
    );
  }

  FeedItem copyWith({
    String? inventoryFeedId,
    String? feedName,
    String? brand,
    String? size,
    double? quantity,
    String? unit,
    double? bagWeightKg,
    bool? isLegacy,
  }) {
    return FeedItem(
      inventoryFeedId: inventoryFeedId ?? this.inventoryFeedId,
      feedName: feedName ?? this.feedName,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      bagWeightKg: bagWeightKg ?? this.bagWeightKg,
      isLegacy: isLegacy ?? this.isLegacy,
    );
  }

  @override
  String toString() => '$feedName ${size ?? ""} (${quantity.toStringAsFixed(1)} $unit)';
}

/// Stock availability check result
class StockValidationResult {
  final bool isValid;
  final List<String> errors;

  const StockValidationResult({required this.isValid, this.errors = const []});
}

/// Authoritative Feed Engine & Calculations
class FeedCalculator {
  const FeedCalculator();

  /// Canonical conversion of feed quantity to kilograms (kg).
  /// Uses [bagWeightKg] when unit is 'bags' (falling back to 25.0 kg if unspecified or <= 0).
  static double normalizeFeedQuantityToKg(double quantity, String unit, {double? bagWeightKg}) {
    final cleanUnit = unit.trim().toLowerCase();
    if (cleanUnit == 'g' || cleanUnit == 'grams' || cleanUnit == 'gram') {
      return quantity / 1000.0;
    } else if (cleanUnit == 'lbs' || cleanUnit == 'lb') {
      return quantity * 0.45359237;
    } else if (cleanUnit == 'bags' || cleanUnit == 'bag') {
      // Use configured bag weight, fallback to 25.0 kg for legacy compatibility
      final bagWeight = (bagWeightKg != null && bagWeightKg > 0) ? bagWeightKg : 25.0;
      return quantity * bagWeight;
    }
    // Default is kg
    return quantity;
  }

  /// Extracts dynamic [FeedItem] list from a [FeedRecord].
  /// Provides seamless backward compatibility with legacy fixed columns (starterG, grower1G, etc.).
  static List<FeedItem> getRecordItems(FeedRecord record) {
    if (record.feedItemsJson != null && record.feedItemsJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(record.feedItemsJson!);
        if (decoded is List) {
          return decoded
              .map((item) => FeedItem.fromJson(Map<String, dynamic>.from(item as Map)))
              .where((item) => item.quantity > 0)
              .toList();
        }
      } catch (e) {
        debugPrint('FeedCalculator: Error parsing feedItemsJson: $e');
      }
    }

    // Backward compatibility: Extract from legacy fields
    final legacyItems = <FeedItem>[];
    if (record.starterG > 0) {
      legacyItems.add(FeedItem(
        feedName: 'Starter Feed',
        size: '1.0 mm',
        quantity: record.starterG / 1000.0,
        unit: 'kg',
        isLegacy: true,
      ));
    }
    if (record.grower1G > 0) {
      legacyItems.add(FeedItem(
        feedName: 'Grower Feed',
        size: '1.5 mm',
        quantity: record.grower1G / 1000.0,
        unit: 'kg',
        isLegacy: true,
      ));
    }
    if (record.grower2G > 0) {
      legacyItems.add(FeedItem(
        feedName: 'Grower Feed',
        size: '2.0 mm',
        quantity: record.grower2G / 1000.0,
        unit: 'kg',
        isLegacy: true,
      ));
    }
    if (record.finisher1G > 0) {
      legacyItems.add(FeedItem(
        feedName: 'Finisher Feed',
        size: '2.5 mm',
        quantity: record.finisher1G / 1000.0,
        unit: 'kg',
        isLegacy: true,
      ));
    }
    if (record.finisher2G > 0) {
      legacyItems.add(FeedItem(
        feedName: 'Finisher Feed',
        size: '3.0 mm',
        quantity: record.finisher2G / 1000.0,
        unit: 'kg',
        isLegacy: true,
      ));
    }
    if (record.otherFeedG > 0) {
      legacyItems.add(FeedItem(
        feedName: record.otherFeedName?.isNotEmpty == true ? record.otherFeedName! : 'Special Feed',
        quantity: record.otherFeedG / 1000.0,
        unit: 'kg',
        isLegacy: true,
      ));
    }

    if (legacyItems.isEmpty && record.totalKg > 0) {
      legacyItems.add(FeedItem(
        feedName: 'Standard Feed',
        quantity: record.totalKg,
        unit: 'kg',
        isLegacy: true,
      ));
    }

    return legacyItems;
  }

  /// Authoritative function for total feed consumed in kilograms (kg) for a [FeedRecord].
  /// All reports, charts, FCR, and dashboard widgets MUST call this function.
  static double getRecordTotalKg(FeedRecord record) {
    final items = getRecordItems(record);
    if (items.isNotEmpty) {
      return items.fold(0.0, (sum, item) => sum + item.quantityKg);
    }
    return record.totalKg;
  }

  /// Filter records by batch ID
  static List<FeedRecord> getFeedRecordsByBatch(List<FeedRecord> records, String batchId) {
    return records.where((r) => r.batchId == batchId).toList();
  }

  /// Filter records by pond ID
  static List<FeedRecord> getFeedRecordsByPond(List<FeedRecord> records, String pondId) {
    return records.where((r) => r.pondId == pondId).toList();
  }

  /// Filter records by date (ignoring time)
  static List<FeedRecord> getFeedRecordsByDate(List<FeedRecord> records, DateTime date) {
    return records.where((r) =>
      r.date.year == date.year &&
      r.date.month == date.month &&
      r.date.day == date.day
    ).toList();
  }

  /// Filter records between [from] and [to] inclusive
  static List<FeedRecord> getFeedRecordsByDateRange(List<FeedRecord> records, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return records.where((r) => !r.date.isBefore(start) && !r.date.isAfter(end)).toList();
  }

  /// Feed distribution by dynamic feed name/type (returns Map of feed label -> total kg)
  static Map<String, double> getFeedDistributionByType(List<FeedRecord> records) {
    final distribution = <String, double>{};
    for (final record in records) {
      final items = getRecordItems(record);
      for (final item in items) {
        final label = item.size != null && item.size!.trim().isNotEmpty
            ? '${item.feedName} (${item.size})'
            : item.feedName;
        distribution[label] = (distribution[label] ?? 0.0) + item.quantityKg;
      }
    }
    return distribution;
  }

  /// Feed distribution by Pond (returns Map of pondName or pondId -> total kg)
  static Map<String, double> getFeedDistributionByPond(List<FeedRecord> records, [Map<String, String>? pondNames]) {
    final distribution = <String, double>{};
    for (final record in records) {
      final name = pondNames?[record.pondId] ?? 'Pond ${record.pondId}';
      distribution[name] = (distribution[name] ?? 0.0) + getRecordTotalKg(record);
    }
    return distribution;
  }

  /// Feed distribution by Phase (DOC 1-10, DOC 11-20, DOC 21+)
  static Map<String, double> getFeedDistributionByPhase(List<FeedRecord> records, DateTime? batchStockingDate) {
    final distribution = <String, double>{
      'DOC 1–10': 0.0,
      'DOC 11–20': 0.0,
      'DOC 21+': 0.0,
    };

    for (final record in records) {
      int doc = 1;
      if (batchStockingDate != null) {
        doc = record.date.difference(batchStockingDate).inDays + 1;
        if (doc < 1) doc = 1;
      }

      final kg = getRecordTotalKg(record);
      if (doc <= 10) {
        distribution['DOC 1–10'] = (distribution['DOC 1–10'] ?? 0.0) + kg;
      } else if (doc <= 20) {
        distribution['DOC 11–20'] = (distribution['DOC 11–20'] ?? 0.0) + kg;
      } else {
        distribution['DOC 21+'] = (distribution['DOC 21+'] ?? 0.0) + kg;
      }
    }
    return distribution;
  }

  /// Total feed consumed per DOC for a batch (returns Map of DOC -> total kg)
  static Map<int, double> getFeedByDoc(List<FeedRecord> records, DateTime batchStockingDate) {
    final docMap = <int, double>{};
    for (final record in records) {
      final doc = record.date.difference(batchStockingDate).inDays + 1;
      if (doc >= 1) {
        docMap[doc] = (docMap[doc] ?? 0.0) + getRecordTotalKg(record);
      }
    }
    return docMap;
  }

  /// Calculates Daily totals and pond breakdowns for a specific date
  static Map<String, dynamic> getDailyFeedTotals(List<FeedRecord> records, DateTime date) {
    final dayRecords = getFeedRecordsByDate(records, date);
    final totalKg = dayRecords.fold(0.0, (sum, r) => sum + getRecordTotalKg(r));
    final uniquePonds = dayRecords.map((r) => r.pondId).toSet();

    final byPond = <String, double>{};
    final byPondSessions = <String, int>{};
    for (final r in dayRecords) {
      byPond[r.pondId] = (byPond[r.pondId] ?? 0.0) + getRecordTotalKg(r);
      byPondSessions[r.pondId] = (byPondSessions[r.pondId] ?? 0) + 1;
    }

    return {
      'totalKg': totalKg,
      'sessionCount': dayRecords.length,
      'pondsFedCount': uniquePonds.length,
      'records': dayRecords,
      'byPond': byPond,
      'byPondSessions': byPondSessions,
    };
  }

  /// Calculates Weekly totals for the 7 days starting from [startDate]
  static Map<String, dynamic> getWeeklyFeedTotals(List<FeedRecord> records, DateTime startDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final weekRecords = records.where((r) => !r.date.isBefore(start) && !r.date.isAfter(end)).toList();

    final dailyTotals = <DateTime, double>{};
    final dailyRecords = <DateTime, List<FeedRecord>>{};
    for (int i = 0; i < 7; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      final dayRecs = getFeedRecordsByDate(weekRecords, day);
      dailyTotals[day] = dayRecs.fold(0.0, (sum, r) => sum + getRecordTotalKg(r));
      dailyRecords[day] = dayRecs;
    }

    final totalKg = weekRecords.fold(0.0, (sum, r) => sum + getRecordTotalKg(r));
    final avgPerDay = totalKg / 7.0;

    return {
      'totalKg': totalKg,
      'avgPerDay': avgPerDay,
      'sessionCount': weekRecords.length,
      'dailyTotals': dailyTotals,
      'dailyRecords': dailyRecords,
      'records': weekRecords,
    };
  }

  /// Calculates Monthly totals, weekly sub-periods, and month-over-month comparison
  static Map<String, dynamic> getMonthlyFeedTotals(List<FeedRecord> records, int year, int month) {
    final start = DateTime(year, month, 1);
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final end = nextMonth.subtract(const Duration(seconds: 1));

    final monthRecords = records.where((r) => !r.date.isBefore(start) && !r.date.isAfter(end)).toList();
    final totalKg = monthRecords.fold(0.0, (sum, r) => sum + getRecordTotalKg(r));

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final avgPerDay = totalKg / daysInMonth;

    // Previous month comparison
    final prevYear = month == 1 ? year - 1 : year;
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevStart = DateTime(prevYear, prevMonth, 1);
    final prevEnd = DateTime(year, month, 1).subtract(const Duration(seconds: 1));
    final prevRecords = records.where((r) => !r.date.isBefore(prevStart) && !r.date.isAfter(prevEnd)).toList();
    final prevTotalKg = prevRecords.fold(0.0, (sum, r) => sum + getRecordTotalKg(r));

    final changePct = prevTotalKg > 0
        ? ((totalKg - prevTotalKg) / prevTotalKg) * 100.0
        : (totalKg > 0 ? 100.0 : 0.0);

    // Break into 4-5 weekly chunks: Days 1-7, 8-14, 15-21, 22-28, 29+
    final weeklyPeriods = <String, double>{
      'W1 (1–7)': 0.0,
      'W2 (8–14)': 0.0,
      'W3 (15–21)': 0.0,
      'W4 (22–28)': 0.0,
    };
    if (daysInMonth > 28) {
      weeklyPeriods['W5 (29–$daysInMonth)'] = 0.0;
    }

    for (final r in monthRecords) {
      final d = r.date.day;
      final kg = getRecordTotalKg(r);
      if (d <= 7) {
        weeklyPeriods['W1 (1–7)'] = (weeklyPeriods['W1 (1–7)'] ?? 0.0) + kg;
      } else if (d <= 14) {
        weeklyPeriods['W2 (8–14)'] = (weeklyPeriods['W2 (8–14)'] ?? 0.0) + kg;
      } else if (d <= 21) {
        weeklyPeriods['W3 (15–21)'] = (weeklyPeriods['W3 (15–21)'] ?? 0.0) + kg;
      } else if (d <= 28) {
        weeklyPeriods['W4 (22–28)'] = (weeklyPeriods['W4 (22–28)'] ?? 0.0) + kg;
      } else {
        weeklyPeriods['W5 (29–$daysInMonth)'] = (weeklyPeriods['W5 (29–$daysInMonth)'] ?? 0.0) + kg;
      }
    }

    final uniquePonds = monthRecords.map((r) => r.pondId).toSet().length;
    final prevUniquePonds = prevRecords.map((r) => r.pondId).toSet().length;

    return {
      'totalKg': totalKg,
      'avgPerDay': avgPerDay,
      'sessionCount': monthRecords.length,
      'activePonds': uniquePonds,
      'prevTotalKg': prevTotalKg,
      'prevSessionCount': prevRecords.length,
      'prevActivePonds': prevUniquePonds,
      'changePct': changePct,
      'weeklyPeriods': weeklyPeriods,
      'records': monthRecords,
    };
  }

  /// Finds the immediately preceding feed session for the same batch/pond before [currentDate] & [currentTimeSlot].
  static FeedRecord? getPreviousFeedSession({
    required List<FeedRecord> records,
    required String batchId,
    String? pondId,
    required DateTime currentDate,
    String? currentTimeSlot,
  }) {
    final candidateRecords = records.where((r) {
      if (r.batchId != batchId) return false;
      if (pondId != null && r.pondId != pondId) return false;

      final recDate = DateTime(r.date.year, r.date.month, r.date.day);
      final targetDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

      if (recDate.isBefore(targetDate)) return true;
      if (recDate.isAtSameMomentAs(targetDate)) {
        // Compare time slots if provided
        final order = {'7:00 AM': 1, '11:00 AM': 2, '4:00 PM': 3, '7:00 PM': 4, 'Other': 5};
        final recOrder = order[r.timeSlot] ?? 0;
        final curOrder = order[currentTimeSlot] ?? 99;
        return recOrder < curOrder;
      }
      return false;
    }).toList();

    if (candidateRecords.isEmpty) return null;

    candidateRecords.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      final order = {'7:00 AM': 1, '11:00 AM': 2, '4:00 PM': 3, '7:00 PM': 4, 'Other': 5};
      return (order[b.timeSlot] ?? 0).compareTo(order[a.timeSlot] ?? 0);
    });

    return candidateRecords.first;
  }

  /// Calculates quantity difference (in kg) between current item and corresponding item in previous record.
  /// Returns Map with:
  /// - 'previousQtyKg': double
  /// - 'diffKg': double
  /// - 'status': 'increase' | 'decrease' | 'same' | 'new'
  static Map<String, dynamic> getItemQuantityChange({
    required FeedItem currentItem,
    FeedRecord? previousRecord,
  }) {
    if (previousRecord == null) {
      return {
        'previousQtyKg': 0.0,
        'diffKg': currentItem.quantityKg,
        'status': 'new',
      };
    }

    final prevItems = getRecordItems(previousRecord);
    // Try to match by inventoryFeedId first, or by feedName and size
    FeedItem? matched;
    if (currentItem.inventoryFeedId != null) {
      matched = prevItems.firstWhere(
        (it) => it.inventoryFeedId == currentItem.inventoryFeedId,
        orElse: () => const FeedItem(feedName: '', quantity: 0),
      );
    }
    if (matched == null || matched.feedName.isEmpty) {
      matched = prevItems.firstWhere(
        (it) => it.feedName.toLowerCase() == currentItem.feedName.toLowerCase() &&
                (it.size ?? '').toLowerCase() == (currentItem.size ?? '').toLowerCase(),
        orElse: () => const FeedItem(feedName: '', quantity: 0),
      );
    }

    if (matched.feedName.isEmpty) {
      return {
        'previousQtyKg': 0.0,
        'diffKg': currentItem.quantityKg,
        'status': 'new',
      };
    }

    final prevKg = matched.quantityKg;
    final curKg = currentItem.quantityKg;
    final diff = curKg - prevKg;

    String status = 'same';
    if (diff > 0.01) {
      status = 'increase';
    } else if (diff < -0.01) {
      status = 'decrease';
    }

    return {
      'previousQtyKg': prevKg,
      'diffKg': diff,
      'status': status,
    };
  }

  /// Validates stock availability for each feed item against current inventory stock.
  /// Prevents insufficient-stock entries and negative inventory.
  static StockValidationResult validateFeedInventoryAvailability({
    required List<FeedItem> requestedItems,
    required Map<String, double> availableStockByInventoryId,
    Map<String, String>? feedNamesById,
  }) {
    final errors = <String>[];

    // Group requested quantities by inventory ID in case operator selected same feed twice
    final aggregatedRequests = <String, double>{};
    final itemSnapshots = <String, FeedItem>{};

    for (final item in requestedItems) {
      if (item.inventoryFeedId != null && item.inventoryFeedId!.isNotEmpty) {
        final id = item.inventoryFeedId!;
        aggregatedRequests[id] = (aggregatedRequests[id] ?? 0.0) + item.quantityKg;
        itemSnapshots[id] = item;
      }
    }

    for (final entry in aggregatedRequests.entries) {
      final id = entry.key;
      final requestedKg = entry.value;
      final availableStock = availableStockByInventoryId[id] ?? 0.0;
      final name = itemSnapshots[id]?.feedName ?? feedNamesById?[id] ?? 'Feed #$id';

      if (requestedKg > availableStock) {
        errors.add('$name: Available ${availableStock.toStringAsFixed(1)} kg, Requested ${requestedKg.toStringAsFixed(1)} kg');
      }
    }

    return StockValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
