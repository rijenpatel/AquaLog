class LocationSearchResult {
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? admin1;
  final String? timezone;

  const LocationSearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
    this.timezone,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String?,
      admin1: json['admin1'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  String get displayName {
    final parts = <String>[name];
    if (admin1 != null && admin1!.isNotEmpty && admin1 != name) {
      parts.add(admin1!);
    }
    if (country != null && country!.isNotEmpty) {
      parts.add(country!);
    }
    return parts.join(', ');
  }
}

class HourlyWeatherPoint {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final double precipitationProbability;

  const HourlyWeatherPoint({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
  });
}

class DailyWeatherPoint {
  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final double precipitationProbability;

  const DailyWeatherPoint({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationProbability,
  });
}

class FullWeatherForecast {
  final String siteId;
  final String locationName;
  final double latitude;
  final double longitude;
  final double temperature;
  final double? feelsLike;
  final double? humidity;
  final double? windSpeed;
  final double? precipitation;
  final double? rainProbability;
  final int weatherCode;
  final String condition;
  final String conditionIcon;
  final DateTime observationTime;
  final bool isFromCache;
  final bool isAvailable;
  final List<HourlyWeatherPoint> hourly;
  final List<DailyWeatherPoint> daily;
  final String feedingGuidance;

  const FullWeatherForecast({
    required this.siteId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    this.feelsLike,
    this.humidity,
    this.windSpeed,
    this.precipitation,
    this.rainProbability,
    required this.weatherCode,
    required this.condition,
    required this.conditionIcon,
    required this.observationTime,
    this.isFromCache = false,
    this.isAvailable = true,
    this.hourly = const [],
    this.daily = const [],
    required this.feedingGuidance,
  });
}
