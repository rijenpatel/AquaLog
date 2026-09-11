import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/weather_models.dart';
import '../../core/services/weather_service.dart';
import '../../app/theme/color_schemes.dart';

class WeatherPage extends ConsumerStatefulWidget {
  final String? initialSiteId;
  final String? initialSiteName;
  final double? initialLat;
  final double? initialLon;

  const WeatherPage({
    super.key,
    this.initialSiteId,
    this.initialSiteName,
    this.initialLat,
    this.initialLon,
  });

  @override
  ConsumerState<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends ConsumerState<WeatherPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<LocationSearchResult> _searchResults = [];

  String? _selectedSiteId;
  String? _selectedLocationName;
  double? _selectedLat;
  double? _selectedLon;

  bool _isLoading = false;
  FullWeatherForecast? _forecast;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.initialSiteId ?? 'site_current';
    _selectedLocationName = widget.initialSiteName ?? 'Kakinada, Andhra Pradesh';
    _selectedLat = widget.initialLat ?? 16.989042;
    _selectedLon = widget.initialLon ?? 82.247518;

    _fetchWeather();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final weatherService = ref.read(weatherServiceProvider);
      final results = await weatherService.searchLocations(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _fetchWeather() async {
    if (_selectedLat == null || _selectedLon == null) {
      setState(() {
        _errorMessage = 'No coordinates set for this site location.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weatherService = ref.read(weatherServiceProvider);
      final result = await weatherService.getFullForecastForSite(
        siteId: _selectedSiteId ?? 'adhoc_site',
        latitude: _selectedLat!,
        longitude: _selectedLon!,
        locationName: _selectedLocationName,
      );

      if (mounted) {
        setState(() {
          _forecast = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load weather. Please check your internet connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _selectLocation(LocationSearchResult loc) {
    setState(() {
      _selectedLocationName = loc.displayName;
      _selectedLat = loc.latitude;
      _selectedLon = loc.longitude;
      _searchResults = [];
      _searchCtrl.text = loc.name;
    });
    _fetchWeather();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site Weather & Telemetry',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'मौसम एवं फीड मार्गदर्शन • Open-Meteo API',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Weather',
            onPressed: _isLoading ? null : _fetchWeather,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search city, village, or PIN code...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Search suggestions dropdown
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = _searchResults[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, size: 20, color: AquaColors.primary),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${item.admin1 ?? ''} ${item.country ?? ''} · (${item.latitude.toStringAsFixed(3)}, ${item.longitude.toStringAsFixed(3)})',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () => _selectLocation(item),
                  );
                },
              ),
            ),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          // 3. Main Content Area
          Expanded(
            child: _buildMainContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    if (_isLoading && _forecast == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _forecast == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AquaColors.statusAlert),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _fetchWeather,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final fc = _forecast;
    if (fc == null) {
      return const Center(child: Text('No weather data available'));
    }

    return RefreshIndicator(
      onRefresh: _fetchWeather,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Header & Freshness Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 18, color: AquaColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _selectedLocationName ?? fc.locationName,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Lat: ${fc.latitude.toStringAsFixed(4)} · Lon: ${fc.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: fc.isFromCache
                        ? theme.colorScheme.surfaceContainerHighest
                        : AquaColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fc.isFromCache ? Icons.archive_outlined : Icons.wifi_rounded,
                        size: 14,
                        color: fc.isFromCache ? theme.colorScheme.outline : AquaColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fc.isFromCache ? 'Cached (${DateFormat('HH:mm').format(fc.observationTime)})' : 'Live · Fresh',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fc.isFromCache ? theme.colorScheme.outline : AquaColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Current Weather Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AquaColors.primary,
                    AquaColors.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AquaColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${fc.temperature.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            fc.condition,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        fc.conditionIcon,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricStat('Feels Like', '${(fc.feelsLike ?? fc.temperature).toStringAsFixed(1)}°C', Icons.thermostat_rounded),
                      _buildMetricStat('Humidity', '${(fc.humidity ?? 70).toStringAsFixed(0)}%', Icons.water_drop_rounded),
                      _buildMetricStat('Wind', '${(fc.windSpeed ?? 12).toStringAsFixed(1)} km/h', Icons.air_rounded),
                      _buildMetricStat('Rain Prob', '${(fc.rainProbability ?? 0).toStringAsFixed(0)}%', Icons.umbrella_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Aquaculture Feeding & Aeration Guidance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AquaColors.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: AquaColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AquaLog Feeding Recommendation',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AquaColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fc.feedingGuidance,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hourly Forecast Strip (24 Hours)
            Text(
              'Hourly Forecast',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fc.hourly.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final h = fc.hourly[idx];
                  final icon = WeatherService.mapWeatherCodeToIcon(h.weatherCode);
                  final timeStr = DateFormat('ha').format(h.time);

                  return Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          idx == 0 ? 'Now' : timeStr,
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(icon, style: const TextStyle(fontSize: 22)),
                        Text(
                          '${h.temperature.toStringAsFixed(0)}°',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (h.precipitationProbability > 0)
                          Text(
                            '${h.precipitationProbability.toStringAsFixed(0)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AquaColors.primary,
                              fontSize: 10,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 7-Day Forecast Cards
            Text(
              '7-Day Outlook',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fc.daily.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (ctx, idx) {
                  final d = fc.daily[idx];
                  final icon = WeatherService.mapWeatherCodeToIcon(d.weatherCode);
                  final dayStr = idx == 0
                      ? 'Today'
                      : idx == 1
                          ? 'Tomorrow'
                          : DateFormat('EEEE').format(d.date);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            dayStr,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(icon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        if (d.precipitationProbability > 0)
                          Row(
                            children: [
                              const Icon(Icons.water_drop_outlined, size: 12, color: AquaColors.primary),
                              Text(
                                '${d.precipitationProbability.toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall?.copyWith(color: AquaColors.primary),
                              ),
                            ],
                          )
                        else
                          const SizedBox(width: 32),
                        const Spacer(),
                        Text(
                          '${d.maxTemp.toStringAsFixed(0)}°',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${d.minTemp.toStringAsFixed(0)}°',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}
