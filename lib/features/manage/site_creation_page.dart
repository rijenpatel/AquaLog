import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:geolocator/geolocator.dart';
import '../../core/database/app_database.dart';
import '../../core/models/weather_models.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/weather_service.dart';
import '../../app/theme/color_schemes.dart';

class SiteCreationPage extends ConsumerStatefulWidget {
  const SiteCreationPage({super.key});

  @override
  ConsumerState<SiteCreationPage> createState() => _SiteCreationPageState();
}

class _SiteCreationPageState extends ConsumerState<SiteCreationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController(text: 'SITE-101');
  final _streetCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _locationSearchCtrl = TextEditingController();

  String _country = 'India';
  String _waterSource = 'brackish_estuary';
  bool _isSaving = false;
  bool _isSearchingLocation = false;
  List<LocationSearchResult> _locationSuggestions = [];
  Timer? _searchDebounce;
  String? _resolvedWeatherLocationName;

  @override
  void initState() {
    super.initState();
    // Fresh setup with no fake hardcoded data
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _streetCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _locationSearchCtrl.dispose();
    super.dispose();
  }

  void _regenerateCode() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(3).join();
      final rand = (DateTime.now().millisecondsSinceEpoch % 900) + 100;
      setState(() {
        _codeCtrl.text = '$initials-$rand';
      });
    } else {
      setState(() {
        _codeCtrl.text = 'SITE-101';
      });
    }
  }

  void _onLocationSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearchingLocation = true);
      final weatherService = ref.read(weatherServiceProvider);
      final results = await weatherService.searchLocations(query);
      if (mounted) {
        setState(() {
          _locationSuggestions = results;
          _isSearchingLocation = false;
        });
      }
    });
  }

  void _selectLocationSuggestion(LocationSearchResult loc) {
    setState(() {
      _resolvedWeatherLocationName = loc.displayName;
      _latCtrl.text = loc.latitude.toStringAsFixed(6);
      _lonCtrl.text = loc.longitude.toStringAsFixed(6);
      if (loc.name.isNotEmpty) _villageCtrl.text = loc.name;
      if (loc.admin1 != null && loc.admin1!.isNotEmpty) _stateCtrl.text = loc.admin1!;
      if (loc.country != null && loc.country!.isNotEmpty) _country = loc.country!;
      _locationSuggestions = [];
      _locationSearchCtrl.text = loc.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Location selected: ${loc.displayName}'),
        backgroundColor: AquaColors.statusOptimal,
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isSearchingLocation = true);

    try {
      // 1. Check location service availability
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location unavailable: Device GPS is disabled. Turn on device location or search manually.'),
              action: SnackBarAction(
                label: 'Turn On',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
              backgroundColor: AquaColors.statusAlert,
            ),
          );
        }
        return;
      }

      // 2. Check & request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied. Enter farm coordinates or search manually.'),
                backgroundColor: AquaColors.statusAlert,
              ),
            );
          }
          return;
        }
      }

      // 3. Handle permanently denied
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permissions permanently denied. Turn on in App Settings or search manually.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
              backgroundColor: AquaColors.statusAlert,
            ),
          );
        }
        return;
      }

      // 4. Get real coordinates from Android GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final latStr = position.latitude.toStringAsFixed(6);
      final lonStr = position.longitude.toStringAsFixed(6);

      if (mounted) {
        setState(() {
          _latCtrl.text = latStr;
          _lonCtrl.text = lonStr;
          _resolvedWeatherLocationName = '${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° E (Device GPS)';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Real device coordinates acquired: $latStr, $lonStr'),
            backgroundColor: AquaColors.statusOptimal,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location request timed out. Please verify GPS signal or search manually.'),
            backgroundColor: AquaColors.statusAlert,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location unavailable: ${e.toString().replaceAll("Exception: ", "")}. Turn on GPS or search manually.'),
            backgroundColor: AquaColors.statusAlert,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latCtrl.text.trim());
    final lon = double.tryParse(_lonCtrl.text.trim());

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter valid Latitude and Longitude for weather forecasts.'),
          backgroundColor: AquaColors.statusAlert,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(appDatabaseProvider);
    final weatherService = ref.read(weatherServiceProvider);

    try {
      final siteId = 'site_${DateTime.now().millisecondsSinceEpoch}';

      await db.into(db.farmSites).insert(
        FarmSitesCompanion(
          id: drift.Value(siteId),
          name: drift.Value(_nameCtrl.text.trim()),
          code: drift.Value(_codeCtrl.text.trim()),
          waterSource: drift.Value(_waterSource),
          address: drift.Value(_streetCtrl.text.trim()),
          villageCity: drift.Value(_villageCtrl.text.trim()),
          district: drift.Value(_districtCtrl.text.trim()),
          state: drift.Value(_stateCtrl.text.trim()),
          country: drift.Value(_country),
          postalCode: drift.Value(_postalCtrl.text.trim()),
          latitude: drift.Value(lat),
          longitude: drift.Value(lon),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      // Invalidate old cache and prefetch live weather for the new coordinates
      await weatherService.invalidateCache(siteId);
      weatherService.getWeatherForSite(siteId: siteId, latitude: lat, longitude: lon);

      // Set active site in settings
      await ref.read(appSettingsProvider.notifier).setSelectedSiteId(siteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Farm Site registered with live weather binding!'),
            backgroundColor: AquaColors.statusOptimal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating site: $e'),
            backgroundColor: AquaColors.statusAlert,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              'Create Farm Site',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'नया फार्म साइट • Root Estate Entity',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hierarchy Callout Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.radar_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Authoritative Estate & Weather Root',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'Tier 1 Master',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A Site is the master boundary for child ponds and batches. Weather is site-scoped using real coordinates to provide agrometeorological guidance.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 1: Site Identification
              _buildSectionCard(
                theme: theme,
                title: 'Site Identification',
                icon: Icons.domain_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Farm Site Name *',
                        hintText: 'e.g. Green Aqua Farm Estuary',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Site name is required' : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Site Code / Facility ID',
                              hintText: 'e.g. GAF-8822',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _regenerateCode,
                          tooltip: 'Regenerate Code',
                          icon: const Icon(Icons.autorenew_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Ecological Water Source *',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    _buildWaterSourceRadio(
                      title: 'Coastal Estuary / Brackish',
                      subtitle: 'Salinity 12–28 ppt • Tidal creek intake',
                      icon: Icons.water_rounded,
                      value: 'brackish_estuary',
                    ),
                    const SizedBox(height: 8),
                    _buildWaterSourceRadio(
                      title: 'Inland Freshwater',
                      subtitle: 'Salinity < 2 ppt • Borewell or canal fed',
                      icon: Icons.waves_rounded,
                      value: 'freshwater',
                    ),
                    const SizedBox(height: 8),
                    _buildWaterSourceRadio(
                      title: 'Full Marine / Deep-sea Intake',
                      subtitle: 'Salinity 30–35 ppt • Offshore pumping system',
                      icon: Icons.scuba_diving_rounded,
                      value: 'marine',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 2: Location Search & Weather Coordinates
              _buildSectionCard(
                theme: theme,
                title: 'Weather Location & Agrometeorology',
                icon: Icons.cloud_sync_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search city, village, or postal code to link Open-Meteo weather forecasts:',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _locationSearchCtrl,
                      onChanged: _onLocationSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search city, village or PIN code...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _isSearchingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    if (_locationSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _locationSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final loc = _locationSuggestions[idx];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined, size: 20, color: AquaColors.primary),
                              title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(loc.displayName),
                              trailing: Text('${loc.latitude.toStringAsFixed(2)}, ${loc.longitude.toStringAsFixed(2)}'),
                              onTap: () => _selectLocationSuggestion(loc),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('Use Device Location Coordinates'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (_resolvedWeatherLocationName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AquaColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AquaColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AquaColors.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Weather Location',
                                    style: theme.textTheme.labelSmall?.copyWith(color: AquaColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _resolvedWeatherLocationName!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Lat: ${_latCtrl.text} · Lon: ${_lonCtrl.text}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Latitude *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lonCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Longitude *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 3: Physical Address
              _buildSectionCard(
                theme: theme,
                title: 'Physical Farm Address (Survey / Landmark)',
                icon: Icons.pin_drop_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _streetCtrl,
                      decoration: InputDecoration(
                        labelText: 'Street Address / Survey Landmark',
                        hintText: 'e.g. Survey No. 42/3, Estuary Road',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _villageCtrl,
                            decoration: InputDecoration(
                              labelText: 'Village / City *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _districtCtrl,
                            decoration: InputDecoration(
                              labelText: 'District *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stateCtrl,
                            decoration: InputDecoration(
                              labelText: 'State *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _postalCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'PIN Code *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSite,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSaving ? 'Registering Site...' : 'Create Farm Site',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildWaterSourceRadio({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isSelected = _waterSource == value;

    return InkWell(
      onTap: () => setState(() => _waterSource = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _waterSource,
              onChanged: (v) {
                if (v != null) setState(() => _waterSource = v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
