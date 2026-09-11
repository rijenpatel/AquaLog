import 'package:flutter/foundation.dart';

@immutable
class AbwResult {
  final double abwGrams;
  final double totalWeightGrams;
  final int count;
  final String formatted;
  final double? countPerKg;
  final int? wholeCountPerKg;
  final String formattedCountPerKg;

  const AbwResult({
    required this.abwGrams,
    required this.totalWeightGrams,
    required this.count,
    required this.formatted,
    this.countPerKg,
    this.wholeCountPerKg,
    this.formattedCountPerKg = '—',
  });

  @override
  String toString() => 'AbwResult($formatted g, count: $count, countPerKg: $formattedCountPerKg)';
}

class AbwCalculator {
  const AbwCalculator();

  /// Calculates Live Average Body Weight (ABW) in grams from cast net sampling.
  /// Formula: ABW (g) = Total Weight (g) / Shrimp Count (pieces)
  /// Rounded to 3 decimal places.
  /// Also derives Count/kg = 1000 / ABW.
  static AbwResult calculate({
    required double totalWeightGrams,
    required int count,
  }) {
    if (count <= 0) {
      throw ArgumentError('Shrimp sample count must be greater than zero.');
    }
    if (totalWeightGrams <= 0) {
      throw ArgumentError('Sample total weight must be greater than zero.');
    }

    final rawAbw = totalWeightGrams / count;
    final roundedAbw = double.parse(rawAbw.toStringAsFixed(3));
    final countPerKg = rawAbw > 0 ? 1000.0 / rawAbw : null;
    final wholeCount = countPerKg?.round();

    return AbwResult(
      abwGrams: roundedAbw,
      totalWeightGrams: totalWeightGrams,
      count: count,
      formatted: roundedAbw.toStringAsFixed(3),
      countPerKg: countPerKg,
      wholeCountPerKg: wholeCount,
      formattedCountPerKg: wholeCount != null ? '$wholeCount shrimp/kg' : '—',
    );
  }

  /// Calculates Count/kg from ABW (g).
  /// Formula: Count/kg = 1000 / ABW
  static double? calculateCountPerKg(double abwGrams) {
    if (abwGrams <= 0 || abwGrams.isNaN || abwGrams.isInfinite) return null;
    return 1000.0 / abwGrams;
  }
}
