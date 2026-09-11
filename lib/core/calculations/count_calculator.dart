/// Count Calculator
/// Implements domain formula: Count (pcs/kg) = 1000 / ABW (grams)
class CountResult {
  final double countPcsPerKg;
  final String bracket;
  final String formatted;

  const CountResult({
    required this.countPcsPerKg,
    required this.bracket,
    required this.formatted,
  });
}

class CountCalculator {
  /// Strictly derives Count from Average Body Weight (g)
  /// Count = 1000 / ABW
  static CountResult calculateFromAbw(double abwGrams) {
    if (abwGrams <= 0) {
      throw ArgumentError('ABW must be positive to calculate shrimp count');
    }
    final count = 1000.0 / abwGrams;
    String bracket;
    if (count <= 40) {
      bracket = '30-40';
    } else if (count <= 50) {
      bracket = '40-50';
    } else if (count <= 60) {
      bracket = '50-60';
    } else if (count <= 70) {
      bracket = '60-70';
    } else if (count <= 80) {
      bracket = '70-80';
    } else {
      bracket = '80-100';
    }
    return CountResult(
      countPcsPerKg: count,
      bracket: bracket,
      formatted: count.toStringAsFixed(2),
    );
  }
}
