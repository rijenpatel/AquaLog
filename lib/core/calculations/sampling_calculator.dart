import 'package:flutter/foundation.dart';
import 'doc_calculator.dart';

/// Centralized sampling interval: 10 days
const int kSamplingIntervalDays = 10;

/// Sampling officially starts at DOC 50
const int kSamplingStartDoc = 50;

enum SamplingStatus {
  notActive('Sampling not active', false),
  dueFirstSample('Sampling Due', true),
  dueIntervalReached('Sampling Due', true),
  upToDate('Sampling Up To Date', false);

  final String label;
  final bool isDue;

  const SamplingStatus(this.label, this.isDue);
}

@immutable
class SamplingGrowthResult {
  final double? growthSincePrev;
  final int? daysSincePrev;
  final double? dailyGrowth;
  final String? formattedGrowth;
  final String? formattedDailyGrowth;

  const SamplingGrowthResult({
    this.growthSincePrev,
    this.daysSincePrev,
    this.dailyGrowth,
    this.formattedGrowth,
    this.formattedDailyGrowth,
  });
}

class SamplingCalculator {
  const SamplingCalculator();

  /// Normalizes a DateTime to calendar date (midnight local time)
  static DateTime normalizeDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Calculates elapsed calendar days between two dates.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final d1 = normalizeDate(from);
    final d2 = normalizeDate(to);
    return d2.difference(d1).inDays;
  }

  /// Calculates DOC for sampling: DOC = Date Difference + 1
  /// Sampling date cannot be before stocking date.
  static int calculateSamplingDoc({
    required DateTime stockingDate,
    required DateTime samplingDate,
  }) {
    final stock = normalizeDate(stockingDate);
    final sample = normalizeDate(samplingDate);
    if (sample.isBefore(stock)) {
      throw ArgumentError('Sampling date cannot be before the stocking date.');
    }
    return sample.difference(stock).inDays + 1;
  }

  /// Validates sampling date:
  /// 1. Cannot be before stocking date.
  /// 2. Cannot be in the future.
  static String? validateSamplingDate({
    required DateTime stockingDate,
    required DateTime samplingDate,
    DateTime? today,
  }) {
    final sDate = normalizeDate(samplingDate);
    final stockDate = normalizeDate(stockingDate);
    final tDate = normalizeDate(today ?? DateTime.now());

    if (sDate.isBefore(stockDate)) {
      return 'Sampling date cannot be before the stocking date.';
    }
    if (sDate.isAfter(tDate)) {
      return 'Sampling date cannot be in the future.';
    }
    return null;
  }

  /// Live calculation of ABW in grams rounded to 3 decimal places.
  /// Formula: ABW = Total Cast Weight / Sample Count
  static double? calculateAbw({
    required double? totalCastWeightGrams,
    required int? sampleCount,
  }) {
    if (totalCastWeightGrams == null || totalCastWeightGrams <= 0) return null;
    if (sampleCount == null || sampleCount <= 0) return null;
    final raw = totalCastWeightGrams / sampleCount;
    if (raw.isNaN || raw.isInfinite) return null;
    return double.parse(raw.toStringAsFixed(3));
  }

  /// Derived Count/kg:
  /// Formula: Count/kg = 1000 / ABW (g)
  static double? calculateCountPerKg(double? abwGrams) {
    if (abwGrams == null || abwGrams <= 0) return null;
    final count = 1000.0 / abwGrams;
    if (count.isNaN || count.isInfinite) return null;
    return count;
  }

  /// Derived Whole Count/kg:
  static int? calculateWholeCountPerKg(double? abwGrams) {
    final count = calculateCountPerKg(abwGrams);
    return count?.round();
  }

  /// Formatted display for Count/kg as whole integer (e.g. "118 shrimp/kg")
  static String formatCountPerKg(double? countPerKg) {
    if (countPerKg == null || countPerKg <= 0 || countPerKg.isNaN || countPerKg.isInfinite) {
      return '—';
    }
    return '${countPerKg.round()} shrimp/kg';
  }

  /// Determines the SamplingStatus for a batch:
  /// - State 1: DOC < 50 -> Sampling not active
  /// - State 2: DOC >= 50 && no sampling -> Sampling Due (first sampling required)
  /// - State 3: DOC >= 50 && latest sampling exists && elapsedDays < 10 -> Sampling Up To Date
  /// - State 4: DOC >= 50 && latest sampling exists && elapsedDays >= 10 -> Sampling Due (interval reached)
  static SamplingStatus getSamplingStatus({
    required String batchStatus,
    required DateTime stockingDate,
    required DateTime? latestSamplingDate,
    DateTime? today,
  }) {
    if (batchStatus.toLowerCase() != 'active') {
      return SamplingStatus.notActive;
    }

    final now = today ?? DateTime.now();
    final doc = DocCalculator.calculate(stockingDate: stockingDate, targetDate: now).doc;

    if (doc < kSamplingStartDoc) {
      return SamplingStatus.notActive;
    }

    if (latestSamplingDate == null) {
      return SamplingStatus.dueFirstSample;
    }

    final elapsedDays = calendarDaysBetween(latestSamplingDate, now);
    if (elapsedDays >= kSamplingIntervalDays) {
      return SamplingStatus.dueIntervalReached;
    }

    return SamplingStatus.upToDate;
  }

  /// Centralized check whether a batch needs sampling.
  /// Exactly: elapsedDays >= 10
  static bool batchNeedsSampling({
    required String batchStatus,
    required DateTime stockingDate,
    required DateTime? latestSamplingDate,
    DateTime? today,
  }) {
    final status = getSamplingStatus(
      batchStatus: batchStatus,
      stockingDate: stockingDate,
      latestSamplingDate: latestSamplingDate,
      today: today,
    );
    return status.isDue;
  }

  /// Calculates growth between current and immediately previous sampling:
  /// - Growth = Current ABW - Previous ABW
  /// - Days = Current Date - Previous Date (calendar days)
  /// - Daily Growth = Growth / Days
  /// If previous is null (first sample), returns null for all growth metrics.
  static SamplingGrowthResult calculateGrowth({
    required double currentAbw,
    required DateTime currentDate,
    double? previousAbw,
    DateTime? previousDate,
  }) {
    if (previousAbw == null || previousDate == null) {
      return const SamplingGrowthResult(
        growthSincePrev: null,
        daysSincePrev: null,
        dailyGrowth: null,
        formattedGrowth: '—',
        formattedDailyGrowth: '—',
      );
    }

    final growth = double.parse((currentAbw - previousAbw).toStringAsFixed(3));
    final days = calendarDaysBetween(previousDate, currentDate);

    double? dailyGrowth;
    String formattedDaily = '—';
    if (days > 0) {
      dailyGrowth = double.parse((growth / days).toStringAsFixed(3));
      final sign = dailyGrowth >= 0 ? '+' : '';
      formattedDaily = '$sign${dailyGrowth.toStringAsFixed(3)} g/day';
    }

    final growthSign = growth >= 0 ? '+' : '';
    final formattedGrowth = '$growthSign${growth.toStringAsFixed(3)} g';

    return SamplingGrowthResult(
      growthSincePrev: growth,
      daysSincePrev: days > 0 ? days : null,
      dailyGrowth: dailyGrowth,
      formattedGrowth: formattedGrowth,
      formattedDailyGrowth: formattedDaily,
    );
  }

  /// Calculates Daily Growth = Growth / Days
  static double? calculateDailyGrowth({
    required double? growth,
    required int? days,
  }) {
    if (growth == null || days == null || days <= 0) return null;
    return double.parse((growth / days).toStringAsFixed(3));
  }

  /// Formats Growth for display (e.g. "+2.000 g")
  static String formatGrowth(double? growth) {
    if (growth == null) return '—';
    final sign = growth >= 0 ? '+' : '';
    return '$sign${growth.toStringAsFixed(3)} g';
  }

  /// Formats Daily Growth for display (e.g. "+0.200 g/day")
  static String formatDailyGrowth(double? dailyGrowth) {
    if (dailyGrowth == null) return '—';
    final sign = dailyGrowth >= 0 ? '+' : '';
    return '$sign${dailyGrowth.toStringAsFixed(3)} g/day';
  }

  /// Returns current authoritative shrimp weight for batch:
  /// IF valid sampling exists -> return latest Sampling ABW
  /// ELSE IF visual weight exists -> return latest Visual Weight
  /// ELSE -> return null
  static double? getCurrentWeight({
    required double? latestSamplingAbw,
    required double? latestVisualWeight,
  }) {
    if (latestSamplingAbw != null && latestSamplingAbw > 0) {
      return latestSamplingAbw;
    }
    if (latestVisualWeight != null && latestVisualWeight > 0) {
      return latestVisualWeight;
    }
    return null;
  }

  /// Biomass (kg) = Estimated Population * ABW (g) / 1000
  /// Estimated Population = Stocked Shrimp * Hapa Survival % / 100
  static double? calculateBiomass({
    required int stockedShrimp,
    required double hapaSurvivalPct,
    required double abwGrams,
  }) {
    if (stockedShrimp <= 0 || hapaSurvivalPct <= 0 || abwGrams <= 0) return null;
    final estimatedPop = (stockedShrimp * (hapaSurvivalPct / 100.0)).round();
    final biomassKg = (estimatedPop * abwGrams) / 1000.0;
    return double.parse(biomassKg.toStringAsFixed(1));
  }

  /// Calculates dynamic 10-day sampling schedule and operational notification phase.
  /// Rule: Latest sample date + 10 days = next sampling date.
  /// First 7 days (<7 elapsed): Up To Date.
  /// Days 7-9: "Next sampling coming" with "Due [date]".
  /// Day 10: "Sampling Due Today".
  /// Day >10: "Sampling Overdue".
  /// Month and year boundaries are handled accurately via calendar arithmetic.
  static SamplingSchedule calculateSchedule({
    required String batchStatus,
    required DateTime stockingDate,
    required DateTime? latestSamplingDate,
    DateTime? today,
  }) {
    if (batchStatus.toLowerCase() != 'active') {
      return const SamplingSchedule(
        state: SamplingScheduleState.notActive,
        statusLabel: 'Inactive',
      );
    }

    final now = normalizeDate(today ?? DateTime.now());
    final stock = normalizeDate(stockingDate);
    final doc = DocCalculator.calculate(stockingDate: stock, targetDate: now).doc;

    // Case 1: First-time batch (no sample logged yet)
    if (latestSamplingDate == null) {
      final doc50Date = DateTime(stock.year, stock.month, stock.day + (kSamplingStartDoc - 1));
      final daysUntilDoc50 = calendarDaysBetween(now, doc50Date);

      if (doc < 43) {
        return SamplingSchedule(
          state: SamplingScheduleState.upToDate,
          nextSampleDate: doc50Date,
          daysUntilNextSample: daysUntilDoc50,
          statusLabel: 'Sampling Starts DOC 50',
          detailLabel: 'Due ${_formatMonthDay(doc50Date)}',
          isWarning: false,
        );
      } else if (doc < kSamplingStartDoc) {
        return SamplingSchedule(
          state: SamplingScheduleState.approaching,
          nextSampleDate: doc50Date,
          daysUntilNextSample: daysUntilDoc50,
          statusLabel: 'Next sampling coming',
          detailLabel: 'Due ${_formatMonthDay(doc50Date)}',
          isWarning: false,
        );
      } else if (doc == kSamplingStartDoc) {
        return SamplingSchedule(
          state: SamplingScheduleState.due,
          nextSampleDate: doc50Date,
          daysUntilNextSample: 0,
          statusLabel: 'Sampling Due',
          detailLabel: 'DOC 50 baseline required',
          isWarning: true,
        );
      } else {
        final overdueDays = doc - kSamplingStartDoc;
        return SamplingSchedule(
          state: SamplingScheduleState.overdue,
          nextSampleDate: doc50Date,
          daysUntilNextSample: -overdueDays,
          statusLabel: 'Sampling Overdue',
          detailLabel: '${overdueDays}d overdue',
          isWarning: true,
        );
      }
    }

    // Case 2: Latest sampling exists
    final latestDate = normalizeDate(latestSamplingDate);
    final nextDate = DateTime(latestDate.year, latestDate.month, latestDate.day + kSamplingIntervalDays);
    final daysElapsed = calendarDaysBetween(latestDate, now);
    final daysRemaining = kSamplingIntervalDays - daysElapsed;

    if (daysElapsed < 7) {
      return SamplingSchedule(
        state: SamplingScheduleState.upToDate,
        latestSampleDate: latestDate,
        nextSampleDate: nextDate,
        daysSinceLatestSample: daysElapsed,
        daysUntilNextSample: daysRemaining,
        statusLabel: 'Sampling Up To Date',
        detailLabel: 'Sampled ${_formatMonthDay(latestDate)}',
        isWarning: false,
      );
    } else if (daysElapsed < kSamplingIntervalDays) {
      return SamplingSchedule(
        state: SamplingScheduleState.approaching,
        latestSampleDate: latestDate,
        nextSampleDate: nextDate,
        daysSinceLatestSample: daysElapsed,
        daysUntilNextSample: daysRemaining,
        statusLabel: 'Next sampling coming',
        detailLabel: 'Due ${_formatMonthDay(nextDate)}',
        isWarning: false,
      );
    } else if (daysElapsed == kSamplingIntervalDays) {
      return SamplingSchedule(
        state: SamplingScheduleState.due,
        latestSampleDate: latestDate,
        nextSampleDate: nextDate,
        daysSinceLatestSample: daysElapsed,
        daysUntilNextSample: 0,
        statusLabel: 'Sampling Due Today',
        detailLabel: 'Due ${_formatMonthDay(nextDate)}',
        isWarning: true,
      );
    } else {
      final overdueDays = daysElapsed - kSamplingIntervalDays;
      return SamplingSchedule(
        state: SamplingScheduleState.overdue,
        latestSampleDate: latestDate,
        nextSampleDate: nextDate,
        daysSinceLatestSample: daysElapsed,
        daysUntilNextSample: -overdueDays,
        statusLabel: 'Sampling Overdue',
        detailLabel: '${overdueDays}d overdue',
        isWarning: true,
      );
    }
  }

  static String _formatMonthDay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

enum SamplingScheduleState {
  notActive,
  upToDate,
  approaching,
  due,
  overdue,
}

@immutable
class SamplingSchedule {
  final SamplingScheduleState state;
  final DateTime? latestSampleDate;
  final DateTime? nextSampleDate;
  final int? daysSinceLatestSample;
  final int? daysUntilNextSample;
  final String statusLabel;
  final String? detailLabel;
  final bool isWarning;

  const SamplingSchedule({
    required this.state,
    this.latestSampleDate,
    this.nextSampleDate,
    this.daysSinceLatestSample,
    this.daysUntilNextSample,
    required this.statusLabel,
    this.detailLabel,
    this.isWarning = false,
  });
}

