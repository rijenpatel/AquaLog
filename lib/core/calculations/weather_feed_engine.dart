import 'package:flutter/foundation.dart';

enum WeatherRiskStatus {
  normal('Optimal Window', 'Normal Feeding'),
  highTemp('Heat Stress', 'High Temperature Alert'),
  lowTemp('Low Metabolism', 'Low Temperature Sluggishness'),
  rainRisk('Rain Shock Risk', 'Heavy Rain Expected'),
  humidityRisk('DO Collapse Danger', 'High Humidity & Warm Water');

  final String label;
  final String title;

  const WeatherRiskStatus(this.label, this.title);
}

@immutable
class WeatherFeedRecommendation {
  final WeatherRiskStatus status;
  final String title;
  final String message;
  final List<String> actions;
  final double feedAdjustmentFactor;

  const WeatherFeedRecommendation({
    required this.status,
    required this.title,
    required this.message,
    required this.actions,
    required this.feedAdjustmentFactor,
  });

  @override
  String toString() => 'WeatherFeedRecommendation($title: factor $feedAdjustmentFactor)';
}

class WeatherFeedEngine {
  const WeatherFeedEngine();

  /// Evaluates weather parameters (temperature °C, relative humidity %, rain probability %)
  /// to provide biological feeding adjustments based on poikilothermic metabolic rules.
  static WeatherFeedRecommendation evaluate({
    required double temperature,
    double? humidity,
    double? rainProbability,
  }) {
    // 1. High Temperature Stress (T >= 34°C)
    if (temperature >= 34.0) {
      return WeatherFeedRecommendation(
        status: WeatherRiskStatus.highTemp,
        title: 'High Temperature Stress',
        message: 'Temperature is ${temperature.toStringAsFixed(1)}°C — above comfortable feeding range. Respiration increases while feeding efficiency drops.',
        actions: const [
          'Shift main rations to cooler hours (early morning 6 AM / evening 7 PM)',
          'Reduce afternoon ration by 20% to 30%',
          'Maximize mechanical surface aeration to avoid thermal stratification',
        ],
        feedAdjustmentFactor: 0.75, // 25% cut
      );
    }

    // 2. Low Temperature Sluggishness (T <= 26°C)
    if (temperature <= 26.0) {
      return WeatherFeedRecommendation(
        status: WeatherRiskStatus.lowTemp,
        title: 'Low Metabolism',
        message: 'Temperature is ${temperature.toStringAsFixed(1)}°C — shrimp enzymatic digestion slows significantly below 26°C.',
        actions: const [
          'Reduce feeding quantity by 20%',
          'Delay morning session until sunlight warms pond surface water',
          'Inspect check-trays 2.5 hours post-feed instead of 2.0 hours',
        ],
        feedAdjustmentFactor: 0.80, // 20% cut
      );
    }

    // 3. Rain Shock Risk (Rain >= 70%)
    if (rainProbability != null && rainProbability >= 70.0) {
      return WeatherFeedRecommendation(
        status: WeatherRiskStatus.rainRisk,
        title: 'Rain Expected',
        message: 'High precipitation probability (${rainProbability.toStringAsFixed(0)}%). Heavy rain causes sudden drops in surface salinity, pH, and water temperature.',
        actions: const [
          'Reduce feed quantity by 25% to 30%',
          'Do NOT broadcast feed during heavy active downpours',
          'Check pond alkalinity and apply agricultural lime/dolomite post-rain',
        ],
        feedAdjustmentFactor: 0.70, // 30% cut
      );
    }

    // 4. High Humidity + High Temperature (DO Collapse Danger)
    if (humidity != null && humidity >= 80.0 && temperature >= 30.0) {
      return WeatherFeedRecommendation(
        status: WeatherRiskStatus.humidityRisk,
        title: 'High Humidity & Warm Water',
        message: 'Warm water with high humidity severely throttles atmospheric oxygen dissolution, creating acute pre-dawn DO collapse risks.',
        actions: const [
          'Increase aerator runtime immediately',
          'Monitor Dissolved Oxygen levels closely before and after feeding',
          'Avoid heavy evening feeding sessions',
        ],
        feedAdjustmentFactor: 0.85, // 15% cut
      );
    }

    // 5. Optimal Commercial Feeding Window
    return WeatherFeedRecommendation(
      status: WeatherRiskStatus.normal,
      title: 'Normal Feeding Window',
      message: 'Temperature is ${temperature.toStringAsFixed(1)}°C — ideal biological metabolism range. Continue scheduled feeding.',
      actions: const [
        'Continue standard feeding schedule',
        'Verify check-trays 2 hours post-feed',
      ],
      feedAdjustmentFactor: 1.0, // 100% standard ration
    );
  }
}
