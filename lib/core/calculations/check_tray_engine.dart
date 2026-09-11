import 'package:flutter/foundation.dart';

enum CheckTrayStatus {
  clean('Clean (0%)', 'Trays clean! Vigorous appetite.', '+5% to +10%', 7.5),
  normal('Normal (1–10%)', 'Optimal satiation equilibrium.', 'Maintain (0%)', 0.0),
  moderate('Moderate (11–25%)', 'Mild overfeeding / sluggish digestion.', '-10% to -15%', -12.5),
  surplus('Surplus (>25%)', 'Severe overfeed alert! Risk of DO drop & black soil.', '-30% to -50%', -40.0);

  final String label;
  final String description;
  final String recommendation;
  final double defaultAdjustmentPct;

  const CheckTrayStatus(
    this.label,
    this.description,
    this.recommendation,
    this.defaultAdjustmentPct,
  );
}

@immutable
class CheckTrayRecommendation {
  final CheckTrayStatus status;
  final int leftoverPercentage;
  final double adjustmentPercentage;
  final String guidanceMessage;
  final String actionSummary;

  const CheckTrayRecommendation({
    required this.status,
    required this.leftoverPercentage,
    required this.adjustmentPercentage,
    required this.guidanceMessage,
    required this.actionSummary,
  });

  @override
  String toString() => 'CheckTrayRecommendation(${status.label} -> $actionSummary)';
}

class CheckTrayEngine {
  const CheckTrayEngine();

  /// Evaluates Check-Tray Leftover % and calculates feeding adjustments:
  /// - 0% (Clean Tray): +5% to +10% increase
  /// - 1% to 10% (Normal Tray): Maintain current (0%)
  /// - 11% to 25% (Moderate): -10% to -15% cut
  /// - >25% (Heavy / Surplus): -30% to -50% emergency cut
  static CheckTrayRecommendation evaluate(int leftoverPct) {
    if (leftoverPct <= 0) {
      return const CheckTrayRecommendation(
        status: CheckTrayStatus.clean,
        leftoverPercentage: 0,
        adjustmentPercentage: 7.5,
        guidanceMessage: 'Trays completely empty! Shrimp feeding aggressively. Increase upcoming ration by 5% to 10% to maximize growth potential.',
        actionSummary: 'Increase next feed by +5% to +10%',
      );
    } else if (leftoverPct <= 10) {
      return CheckTrayRecommendation(
        status: CheckTrayStatus.normal,
        leftoverPercentage: leftoverPct,
        adjustmentPercentage: 0.0,
        guidanceMessage: 'Optimal feeding equilibrium. Tray leftover is within the ideal 1% to 10% satiation buffer. Maintain current feeding quantities.',
        actionSummary: 'Maintain current feeding quantity',
      );
    } else if (leftoverPct <= 25) {
      return CheckTrayRecommendation(
        status: CheckTrayStatus.moderate,
        leftoverPercentage: leftoverPct,
        adjustmentPercentage: -12.5,
        guidanceMessage: 'Mild overfeeding or sluggish appetite detected. Reduce upcoming ration by 10% to 15% to prevent uneaten feed settling into bottom sludge.',
        actionSummary: 'Reduce next feed by 10% to 15%',
      );
    } else {
      return CheckTrayRecommendation(
        status: CheckTrayStatus.surplus,
        leftoverPercentage: leftoverPct,
        adjustmentPercentage: -40.0,
        guidanceMessage: 'CRITICAL OVERFEED ALERT! Severe excess feed remaining on trays. Immediately cut upcoming feed by 30% to 50%. Test Dissolved Oxygen, pH, and Nitrite immediately!',
        actionSummary: 'Emergency cut by 30% to 50%',
      );
    }
  }

  /// Calculates adjusted feed quantity in grams for the next session.
  static double calculateAdjustedQuantity({
    required double baseQuantityGrams,
    required CheckTrayRecommendation recommendation,
  }) {
    final adjusted = baseQuantityGrams * (1.0 + (recommendation.adjustmentPercentage / 100.0));
    return double.parse(adjusted.toStringAsFixed(1));
  }
}
