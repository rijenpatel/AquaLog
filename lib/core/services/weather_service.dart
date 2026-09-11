import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import '../models/weather_models.dart';
import '../providers/database_provider.dart';

class WeatherData {
  final double temperature;
  final double? feelsLike;
  final double? humidity;
  final double? windSpeed;
  final double? rainProbability;
  final String condition;
  final String conditionIcon;
  final double? uvIndex;
  final DateTime observationTime;
  final bool isFromCache;
  final String feedingGuidance;

  const WeatherData({
    required this.temperature,
    this.feelsLike,
    this.humidity,
    this.windSpeed,
    this.rainProbability,
    required this.condition,
    this.conditionIcon = '⛅',
    this.uvIndex,
    required this.observationTime,
    this.isFromCache = false,
    this.feedingGuidance = 'Maintain scheduled ration matched to check-tray consumption.',
  });
}

class WeatherService {
  final AppDatabase db;
  final http.Client _client;

  WeatherService(this.db, [http.Client? client]) : _client = client ?? http.Client();

  /// Search locations via Open-Meteo Geocoding API
  Future<List<LocationSearchResult>> searchLocations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(trimmed)}&count=6&language=en&format=json',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results
              .map((item) => LocationSearchResult.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Return empty list on network or parse error
    }
    return [];
  }

  /// Invalidate cached weather observations for a site (e.g., when coordinates change)
  Future<void> invalidateCache(String siteId) async {
    await db.clearWeatherCache(siteId);
  }

  /// Get current weather for a site with 30-minute Drift SQLite cache
  Future<WeatherData?> getWeatherForSite({
    required String siteId,
    required double latitude,
    required double longitude,
  }) async {
    final forecast = await getFullForecastForSite(
      siteId: siteId,
      latitude: latitude,
      longitude: longitude,
    );
    return WeatherData(
      temperature: forecast.temperature,
      feelsLike: forecast.feelsLike,
      humidity: forecast.humidity,
      windSpeed: forecast.windSpeed,
      rainProbability: forecast.rainProbability,
      condition: forecast.condition,
      conditionIcon: forecast.conditionIcon,
      observationTime: forecast.observationTime,
      isFromCache: forecast.isFromCache,
      feedingGuidance: forecast.feedingGuidance,
    );
  }

  Future<void> syncSiteWeather(FarmSite site) async {
    if (site.latitude == null || site.longitude == null) return;
    await getWeatherForSite(
      siteId: site.id,
      latitude: site.latitude!,
      longitude: site.longitude!,
    );
  }

  /// Get full forecast (current, hourly, 7-day, feeding guidance) with offline cache fallback
  Future<FullWeatherForecast> getFullForecastForSite({
    required String siteId,
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    final now = DateTime.now();

    // 1. Check local cache
    final cached = await db.getLatestWeatherObservation(siteId);
    if (cached != null) {
      final cacheAge = now.difference(cached.date);
      if (cacheAge.inMinutes < 30) {
        final condition = cached.condition ?? 'Partly Cloudy · Estuary Breeze';
        final weatherCode = _mapConditionToWeatherCode(condition);
        final icon = mapWeatherCodeToIcon(weatherCode);
        final guidance = calculateFeedingGuidance(
          temp: cached.temperature,
          rainProb: cached.rainProbability ?? 10.0,
          weatherCode: weatherCode,
        );

        return FullWeatherForecast(
          siteId: siteId,
          locationName: locationName ?? 'Farm Site',
          latitude: latitude,
          longitude: longitude,
          temperature: cached.temperature,
          feelsLike: cached.feelsLike,
          humidity: cached.humidity,
          windSpeed: cached.windSpeed,
          rainProbability: cached.rainProbability,
          weatherCode: weatherCode,
          condition: condition,
          conditionIcon: icon,
          observationTime: cached.date,
          isFromCache: true,
          hourly: _generateSampleHourlyFromBase(cached.temperature, cached.rainProbability ?? 0, weatherCode),
          daily: _generateSampleDailyFromBase(cached.temperature, cached.rainProbability ?? 0, weatherCode),
          feedingGuidance: guidance,
        );
      }
    }

    // 2. Fetch live data from Open-Meteo Forecast API
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,wind_speed_10m'
        '&hourly=temperature_2m,precipitation_probability,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
        '&timezone=auto',
      );

      final response = await _client.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;

        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
          final feels = (current['apparent_temperature'] as num?)?.toDouble() ?? (temp + 2.0);
          final humidity = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 70.0;
          final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.0;
          final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
          final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 1;

          // Parse hourly (take up to 24 slots)
          final hourlyPoints = <HourlyWeatherPoint>[];
          final hourlyData = data['hourly'] as Map<String, dynamic>?;
          double rainProb = 0.0;

          if (hourlyData != null) {
            final times = (hourlyData['time'] as List<dynamic>?) ?? [];
            final temps = (hourlyData['temperature_2m'] as List<dynamic>?) ?? [];
            final codes = (hourlyData['weather_code'] as List<dynamic>?) ?? [];
            final probs = (hourlyData['precipitation_probability'] as List<dynamic>?) ?? [];

            final limit = times.length < 24 ? times.length : 24;
            for (var i = 0; i < limit; i++) {
              final t = DateTime.tryParse(times[i]?.toString() ?? '') ?? now.add(Duration(hours: i));
              final tp = (temps.length > i ? (temps[i] as num?)?.toDouble() : null) ?? temp;
              final cd = (codes.length > i ? (codes[i] as num?)?.toInt() : null) ?? weatherCode;
              final pr = (probs.length > i ? (probs[i] as num?)?.toDouble() : null) ?? 0.0;
              hourlyPoints.add(HourlyWeatherPoint(
                time: t,
                temperature: tp,
                weatherCode: cd,
                precipitationProbability: pr,
              ));
            }
            if (probs.isNotEmpty) {
              rainProb = (probs.first as num?)?.toDouble() ?? 0.0;
            }
          }

          // Parse daily (up to 7 days)
          final dailyPoints = <DailyWeatherPoint>[];
          final dailyData = data['daily'] as Map<String, dynamic>?;
          if (dailyData != null) {
            final dTimes = (dailyData['time'] as List<dynamic>?) ?? [];
            final dCodes = (dailyData['weather_code'] as List<dynamic>?) ?? [];
            final dMaxs = (dailyData['temperature_2m_max'] as List<dynamic>?) ?? [];
            final dMins = (dailyData['temperature_2m_min'] as List<dynamic>?) ?? [];
            final dProbs = (dailyData['precipitation_probability_max'] as List<dynamic>?) ?? [];

            final limit = dTimes.length < 7 ? dTimes.length : 7;
            for (var i = 0; i < limit; i++) {
              final d = DateTime.tryParse(dTimes[i]?.toString() ?? '') ?? now.add(Duration(days: i));
              final cd = (dCodes.length > i ? (dCodes[i] as num?)?.toInt() : null) ?? weatherCode;
              final mx = (dMaxs.length > i ? (dMaxs[i] as num?)?.toDouble() : null) ?? (temp + 3);
              final mn = (dMins.length > i ? (dMins[i] as num?)?.toDouble() : null) ?? (temp - 4);
              final pr = (dProbs.length > i ? (dProbs[i] as num?)?.toDouble() : null) ?? 0.0;
              dailyPoints.add(DailyWeatherPoint(
                date: d,
                weatherCode: cd,
                maxTemp: mx,
                minTemp: mn,
                precipitationProbability: pr,
              ));
            }
          }

          final condition = mapWeatherCodeToCondition(weatherCode);
          final icon = mapWeatherCodeToIcon(weatherCode);
          final guidance = calculateFeedingGuidance(
            temp: temp,
            rainProb: rainProb,
            weatherCode: weatherCode,
          );

          // Cache observation in Drift SQLite
          final obsId = 'w_${now.millisecondsSinceEpoch}_$siteId';
          await db.cacheWeatherObservation(
            WeatherObservationsCompanion(
              id: drift.Value(obsId),
              siteId: drift.Value(siteId),
              date: drift.Value(now),
              temperature: drift.Value(temp),
              feelsLike: drift.Value(feels),
              humidity: drift.Value(humidity),
              windSpeed: drift.Value(wind),
              rainProbability: drift.Value(rainProb),
              condition: drift.Value(condition),
              uvIndex: const drift.Value(7.0),
            ),
          );

          return FullWeatherForecast(
            siteId: siteId,
            locationName: locationName ?? 'Farm Site',
            latitude: latitude,
            longitude: longitude,
            temperature: temp,
            feelsLike: feels,
            humidity: humidity,
            windSpeed: wind,
            precipitation: precip,
            rainProbability: rainProb,
            weatherCode: weatherCode,
            condition: condition,
            conditionIcon: icon,
            observationTime: now,
            isFromCache: false,
            hourly: hourlyPoints,
            daily: dailyPoints,
            feedingGuidance: guidance,
          );
        }
      }
    } catch (_) {
      // Offline fallback to cache
    }

    // 3. Fallback to existing cache if offline
    if (cached != null) {
      final condition = cached.condition ?? 'Partly Cloudy · Estuary Breeze';
      final weatherCode = _mapConditionToWeatherCode(condition);
      final icon = mapWeatherCodeToIcon(weatherCode);
      final guidance = calculateFeedingGuidance(
        temp: cached.temperature,
        rainProb: cached.rainProbability ?? 10.0,
        weatherCode: weatherCode,
      );

      return FullWeatherForecast(
        siteId: siteId,
        locationName: locationName ?? 'Farm Site',
        latitude: latitude,
        longitude: longitude,
        temperature: cached.temperature,
        feelsLike: cached.feelsLike,
        humidity: cached.humidity,
        windSpeed: cached.windSpeed,
        rainProbability: cached.rainProbability,
        weatherCode: weatherCode,
        condition: condition,
        conditionIcon: icon,
        observationTime: cached.date,
        isFromCache: true,
        hourly: _generateSampleHourlyFromBase(cached.temperature, cached.rainProbability ?? 0, weatherCode),
        daily: _generateSampleDailyFromBase(cached.temperature, cached.rainProbability ?? 0, weatherCode),
        feedingGuidance: guidance,
      );
    }

    // 4. Return unavailable state when completely fresh and offline (no cache, no live network)
    return FullWeatherForecast(
      siteId: siteId,
      locationName: locationName ?? 'Farm Site',
      latitude: latitude,
      longitude: longitude,
      temperature: 0.0,
      weatherCode: 0,
      condition: 'Weather unavailable',
      conditionIcon: '⛅',
      observationTime: now,
      isFromCache: false,
      isAvailable: false,
      hourly: const [],
      daily: const [],
      feedingGuidance: 'Weather data unavailable. Connect to the internet to retrieve real-time agrometeorological forecast.',
    );
  }

  static String mapWeatherCodeToCondition(int code) {
    if (code == 0) return 'Clear Sky · Optimal';
    if (code == 1 || code == 2) return 'Partly Cloudy · Estuary Breeze';
    if (code == 3) return 'Overcast · Low D.O. Risk';
    if (code == 45 || code == 48) return 'Foggy · Visibility Reduced';
    if (code >= 51 && code <= 55) return 'Drizzle · Mild Precipitation';
    if (code >= 61 && code <= 67) return 'Rain · Feed Adjustment Required';
    if (code >= 71 && code <= 77) return 'Snow / Cold Surge';
    if (code >= 80 && code <= 82) return 'Heavy Rain Showers · Critical Risk';
    if (code >= 95) return 'Thunderstorm · High Alert';
    return 'Partly Cloudy · Estuary Breeze';
  }

  static String mapWeatherCodeToIcon(int code) {
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 55) return '🌦️';
    if (code >= 61 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '🌨️';
    if (code >= 80 && code <= 82) return '🌧️';
    if (code >= 95) return '⛈️';
    return '⛅';
  }

  static int _mapConditionToWeatherCode(String condition) {
    if (condition.contains('Clear')) return 0;
    if (condition.contains('Partly')) return 1;
    if (condition.contains('Overcast')) return 3;
    if (condition.contains('Thunderstorm')) return 95;
    if (condition.contains('Heavy Rain')) return 80;
    if (condition.contains('Rain') || condition.contains('Drizzle')) return 61;
    return 1;
  }

  /// AquaLog Domain Feeding Guidance based on weather telemetry
  static String calculateFeedingGuidance({
    required double temp,
    required double rainProb,
    required int weatherCode,
  }) {
    if (weatherCode >= 95 || weatherCode >= 80 || rainProb >= 60.0) {
      return 'Rain / High Storm Probability: Reduce feed ration by 25–40%. Run aerators continuously to prevent pond temperature stratification.';
    }
    if (weatherCode >= 61 || rainProb >= 40.0) {
      return 'Rain expected: Monitor check-trays 90 minutes post-feed. Reduce next broadcast by 15% if uneaten pellets detected.';
    }
    if (temp < 24.0) {
      return 'Cool water condition: Shrimp metabolism slower. Reduce scheduled ration by 15–20% to prevent bottom pollution.';
    }
    if (temp > 33.0) {
      return 'High water temperature: Elevated respiration. Check pond Dissolved Oxygen before afternoon broadcast. Keep paddle-wheels active.';
    }
    return 'Optimal aquaculture weather: Water temperature & conditions favorable. Broadcast 100% standard ration according to tray audit.';
  }

  static List<HourlyWeatherPoint> _generateSampleHourlyFromBase(double baseTemp, double baseProb, int code) {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final hour = now.add(Duration(hours: i + 1));
      final tempVariation = (i % 4 == 0) ? 0.5 : (i % 2 == 0 ? -0.3 : 0.8);
      return HourlyWeatherPoint(
        time: hour,
        temperature: double.parse((baseTemp + tempVariation).toStringAsFixed(1)),
        weatherCode: code,
        precipitationProbability: baseProb,
      );
    });
  }

  static List<DailyWeatherPoint> _generateSampleDailyFromBase(double baseTemp, double baseProb, int code) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.add(Duration(days: i));
      return DailyWeatherPoint(
        date: day,
        weatherCode: code,
        maxTemp: double.parse((baseTemp + 3.0).toStringAsFixed(1)),
        minTemp: double.parse((baseTemp - 4.0).toStringAsFixed(1)),
        precipitationProbability: baseProb,
      );
    });
  }
}

final weatherServiceProvider = Provider<WeatherService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WeatherService(db);
});

final siteWeatherForecastProvider = FutureProvider.family<FullWeatherForecast, ({String siteId, double lat, double lon, String? name})>(
  (ref, params) async {
    final service = ref.watch(weatherServiceProvider);
    return service.getFullForecastForSite(
      siteId: params.siteId,
      latitude: params.lat,
      longitude: params.lon,
      locationName: params.name,
    );
  },
);
