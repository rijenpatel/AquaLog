import 'package:flutter_test/flutter_test.dart';
import 'package:aqualog/core/models/weather_models.dart';
import 'package:aqualog/core/services/weather_service.dart';
import 'package:aqualog/core/providers/dashboard_context_provider.dart';
import 'package:aqualog/core/calculations/calculations.dart';

void main() {
  group('1. DashboardContext & Context Switching Tests', () {
    test('Default context is FarmDashboardContext', () {
      final notifier = DashboardContextNotifier();
      expect(notifier.state, isA<FarmDashboardContext>());
    });

    test('Selecting a batch updates context to BatchDashboardContext', () {
      final notifier = DashboardContextNotifier();
      notifier.selectBatch('batch_01');
      expect(notifier.state, isA<BatchDashboardContext>());
      expect((notifier.state as BatchDashboardContext).batchId, 'batch_01');

      notifier.selectBatch('batch_02');
      expect(notifier.state, isA<BatchDashboardContext>());
      expect((notifier.state as BatchDashboardContext).batchId, 'batch_02');
    });

    test('Selecting farm resets context immediately to FarmDashboardContext', () {
      final notifier = DashboardContextNotifier();
      notifier.selectBatch('batch_03');
      expect(notifier.state, isA<BatchDashboardContext>());

      notifier.selectFarm();
      expect(notifier.state, isA<FarmDashboardContext>());
    });
  });

  group('2. Count Calculator & Strict Biological Scaling', () {
    test('Count = 1000 / Latest ABW', () {
      final res1 = CountCalculator.calculateFromAbw(18.77);
      expect(res1.countPcsPerKg, closeTo(53.28, 0.02));
      expect(res1.bracket, '50-60');

      final res2 = CountCalculator.calculateFromAbw(20.00);
      expect(res2.countPcsPerKg, 50.0);
      expect(res2.bracket, '40-50');

      final res3 = CountCalculator.calculateFromAbw(25.00);
      expect(res3.countPcsPerKg, 40.0);
      expect(res3.bracket, '30-40');
    });
  });

  group('3. Open-Meteo Weather Models & Geocoding Search Tests', () {
    test('Parses Geocoding result JSON correctly', () {
      final json = {
        'name': 'Kakinada',
        'latitude': 16.989042,
        'longitude': 82.247518,
        'country': 'India',
        'admin1': 'Andhra Pradesh',
        'timezone': 'Asia/Kolkata',
      };
      final result = LocationSearchResult.fromJson(json);
      expect(result.name, 'Kakinada');
      expect(result.latitude, 16.989042);
      expect(result.longitude, 82.247518);
      expect(result.country, 'India');
      expect(result.admin1, 'Andhra Pradesh');
      expect(result.displayName, 'Kakinada, Andhra Pradesh, India');
    });

    test('Maps WMO Weather Codes to Human-Readable Conditions & Icons', () {
      expect(WeatherService.mapWeatherCodeToCondition(0), contains('Clear'));
      expect(WeatherService.mapWeatherCodeToIcon(0), '☀️');

      expect(WeatherService.mapWeatherCodeToCondition(1), contains('Partly Cloudy'));
      expect(WeatherService.mapWeatherCodeToIcon(1), '⛅');

      expect(WeatherService.mapWeatherCodeToCondition(3), contains('Overcast'));
      expect(WeatherService.mapWeatherCodeToIcon(3), '☁️');

      expect(WeatherService.mapWeatherCodeToCondition(61), contains('Rain'));
      expect(WeatherService.mapWeatherCodeToIcon(61), '🌧️');

      expect(WeatherService.mapWeatherCodeToCondition(95), contains('Thunderstorm'));
      expect(WeatherService.mapWeatherCodeToIcon(95), '⛈️');
    });

    test('Calculates domain AquaLog feeding guidance based on real weather telemetry', () {
      // Storm / High rain risk
      final stormGuidance = WeatherService.calculateFeedingGuidance(
        temp: 28.0,
        rainProb: 80.0,
        weatherCode: 95,
      );
      expect(stormGuidance, contains('Reduce feed ration'));
      expect(stormGuidance, contains('aerators'));

      // Low temp
      final coldGuidance = WeatherService.calculateFeedingGuidance(
        temp: 22.0,
        rainProb: 10.0,
        weatherCode: 1,
      );
      expect(coldGuidance, contains('Cool water'));
      expect(coldGuidance, contains('Reduce scheduled ration'));

      // High heat
      final hotGuidance = WeatherService.calculateFeedingGuidance(
        temp: 34.5,
        rainProb: 5.0,
        weatherCode: 0,
      );
      expect(hotGuidance, contains('High water temperature'));
      expect(hotGuidance, contains('Dissolved Oxygen'));

      // Optimal conditions
      final optimalGuidance = WeatherService.calculateFeedingGuidance(
        temp: 28.5,
        rainProb: 10.0,
        weatherCode: 1,
      );
      expect(optimalGuidance, contains('Optimal aquaculture weather'));
    });
  });
}
