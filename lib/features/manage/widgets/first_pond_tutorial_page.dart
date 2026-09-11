import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../app/theme/color_schemes.dart';

/// Interactive 5-Step Guided Tutorial for creating a new aquaculture pond basin
class FirstPondTutorialPage extends ConsumerStatefulWidget {
  final FarmSite site;
  final VoidCallback? onPondCreated;

  const FirstPondTutorialPage({
    super.key,
    required this.site,
    this.onPondCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required FarmSite site,
    VoidCallback? onPondCreated,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FirstPondTutorialPage(
          site: site,
          onPondCreated: onPondCreated,
        ),
      ),
    );
  }

  @override
  ConsumerState<FirstPondTutorialPage> createState() => _FirstPondTutorialPageState();
}

class _FirstPondTutorialPageState extends ConsumerState<FirstPondTutorialPage> {
  int _currentStep = 0; // 0 to 4 (Steps 1 to 5)
  final _pageController = PageController();

  // Form State
  final _nameController = TextEditingController(text: 'Pond 01');
  final _areaController = TextEditingController(text: '1.0');
  final _depthController = TextEditingController(text: '1.5');
  final _aeratorsCountController = TextEditingController(text: '4');
  final _aeratorHpController = TextEditingController(text: '8.0');

  String _areaUnit = 'Acres'; // 'Acres', 'Hectares', 'm²'
  bool _isSubmitting = false;
  String? _stepError;

  @override
  void initState() {
    super.initState();
    _areaController.addListener(_onRebuild);
    _depthController.addListener(_onRebuild);
    _aeratorHpController.addListener(_onRebuild);
    _aeratorsCountController.addListener(_onRebuild);
  }

  void _onRebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _areaController.removeListener(_onRebuild);
    _depthController.removeListener(_onRebuild);
    _aeratorHpController.removeListener(_onRebuild);
    _aeratorsCountController.removeListener(_onRebuild);
    _nameController.dispose();
    _areaController.dispose();
    _depthController.dispose();
    _aeratorsCountController.dispose();
    _aeratorHpController.dispose();
    super.dispose();
  }

  double _getAreaInSqMeters() {
    final sanitized = _areaController.text.trim().replaceAll(',', '.');
    final val = double.tryParse(sanitized) ?? 0.0;
    switch (_areaUnit) {
      case 'Acres':
        return val * 4046.86;
      case 'Hectares':
        return val * 10000.0;
      case 'm²':
      default:
        return val;
    }
  }

  double _getDepthInMeters() {
    final sanitized = _depthController.text.trim().replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 1.5;
  }

  double _getVolumeInCubicMeters() {
    return _getAreaInSqMeters() * _getDepthInMeters();
  }

  double _getAeratorHp() {
    final sanitized = _aeratorHpController.text.trim().replaceAll(',', '.');
    final val = double.tryParse(sanitized) ?? 0.0;
    return val < 0.0 ? 0.0 : val;
  }

  int _getAeratorsCount() {
    final val = int.tryParse(_aeratorsCountController.text.trim()) ?? 0;
    return val < 0 ? 0 : val;
  }

  double _getAerationHpPerAcre() {
    final areaAcres = _getAreaInSqMeters() / 4046.86;
    if (areaAcres <= 0) return 0.0;
    return _getAeratorHp() / areaAcres;
  }

  Future<bool> _validateCurrentStep() async {
    setState(() => _stepError = null);

    if (_currentStep == 0) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(() => _stepError = 'Please enter a name or identifier for your pond.');
        return false;
      }
      final db = ref.read(appDatabaseProvider);
      final existingPonds = await (db.select(db.ponds)..where((tbl) => tbl.siteId.equals(widget.site.id))).get();
      if (existingPonds.any((p) => p.name.trim().toLowerCase() == name.toLowerCase())) {
        setState(() => _stepError = 'A pond named "$name" already exists under ${widget.site.name}. Please choose another name.');
        return false;
      }
    } else if (_currentStep == 1) {
      final area = _getAreaInSqMeters();
      if (area <= 0) {
        setState(() => _stepError = 'Please enter a surface area greater than 0.');
        return false;
      }
    } else if (_currentStep == 2) {
      final depth = _getDepthInMeters();
      if (depth <= 0) {
        setState(() => _stepError = 'Please enter a water depth greater than 0.');
        return false;
      }
      if (depth < 0.8) {
        setState(() => _stepError = 'Warning: Depths under 0.8m heat up rapidly and promote wild benthic algae.');
      }
    } else if (_currentStep == 3) {
      if (_getAeratorsCount() < 0 || _getAeratorHp() < 0) {
        setState(() => _stepError = 'Aerator units and horsepower cannot be negative.');
        return false;
      }
    }

    return true;
  }

  Future<void> _onNextStep() async {
    final isValid = await _validateCurrentStep();
    if (!isValid) return;

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
        _stepError = null;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _savePond();
    }
  }

  void _onPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _stepError = null;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _savePond() async {
    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final areaSqMeters = _getAreaInSqMeters();
      final depth = _getDepthInMeters();
      final aeratorsCount = _getAeratorsCount();
      final aeratorHp = _getAeratorHp();
      final newPondId = 'pond_${DateTime.now().millisecondsSinceEpoch}';

      final db = ref.read(appDatabaseProvider);
      await db.into(db.ponds).insert(
        PondsCompanion(
          id: drift.Value(newPondId),
          siteId: drift.Value(widget.site.id),
          name: drift.Value(name),
          areaSqMeters: drift.Value(areaSqMeters),
          waterDepthMeters: drift.Value(depth),
          aeratorsCount: drift.Value(aeratorsCount),
          totalAeratorHp: drift.Value(aeratorHp),
          status: const drift.Value('active'),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pond "$name" created successfully!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF006876),
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onPondCreated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _stepError = 'Failed to create pond: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step-by-Step Pond Tutorial',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Site: ${widget.site.name}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Exit Tutorial'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Indicator
            _buildProgressBar(theme),

            // Step Content PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Name(theme, isDark),
                  _buildStep2Area(theme, isDark),
                  _buildStep3Depth(theme, isDark),
                  _buildStep4Aeration(theme, isDark),
                  _buildStep5Review(theme, isDark),
                ],
              ),
            ),

            // Error notice if any
            if (_stepError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AquaColors.statusAlert.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AquaColors.statusAlert.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: AquaColors.statusAlert, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _stepError!,
                        style: TextStyle(color: AquaColors.statusAlert, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Navigation Bar
            _buildBottomNav(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    final progress = (_currentStep + 1) / 5.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 5',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF006876),
                ),
              ),
              Text(
                _getStepTitle(_currentStep),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: const Color(0xFF006876),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Basin Identifier';
      case 1:
        return 'Surface Sizing';
      case 2:
        return 'Depth & Volume';
      case 3:
        return 'Aeration Sizing';
      case 4:
        return 'Review & Confirm';
      default:
        return '';
    }
  }

  Widget _buildBottomNav(ThemeData theme) {
    final isLastStep = _currentStep == 4;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSubmitting ? null : _onPreviousStep,
            icon: Icon(_currentStep == 0 ? Icons.close_rounded : Icons.arrow_back_rounded, size: 16),
            label: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF006876),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSubmitting ? null : _onNextStep,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 18),
            label: Text(
              _isSubmitting
                  ? 'Saving Pond...'
                  : (isLastStep ? 'Create Pond' : 'Next Step'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialHeader({
    required ThemeData theme,
    required bool isDark,
    required String stepBadge,
    required String title,
    required String tipTitle,
    required String tipDescription,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF006876).withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                stepBadge.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF006876),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),

        // Tutorial Guidance Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF00282E) : const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF007A87).withOpacity(isDark ? 0.4 : 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF006876),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tipTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF004D56),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tipDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : const Color(0xFF00363D),
                        height: 1.35,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // STEP 1: Basin Identifier
  Widget _buildStep1Name(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            theme: theme,
            isDark: isDark,
            stepBadge: 'Step 1 of 5',
            title: 'Name Your Cultivation Basin',
            tipTitle: 'Why Pond Tagging Matters',
            tipDescription:
                'Every pond in AquaLog is tracked individually. Its name connects all daily check-tray logs, water quality tests, feeding charts, and eventual harvest lots.',
            icon: Icons.tag_rounded,
          ),
          Text(
            'Enter Basin Identifier:',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g. Pond 01, Basin Alpha, Nursery 1',
              prefixIcon: const Icon(Icons.water_rounded, color: Color(0xFF006876)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Quick Suggestions:',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['Pond 01', 'Pond 02', 'Basin Alpha', 'Nursery 1'].map((suggestion) {
              return ActionChip(
                label: Text(suggestion, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _nameController.text = suggestion;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // STEP 2: Surface Sizing
  Widget _buildStep2Area(ThemeData theme, bool isDark) {
    final areaSqM = _getAreaInSqMeters();
    final areaAcres = areaSqM / 4046.86;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            theme: theme,
            isDark: isDark,
            stepBadge: 'Step 2 of 5',
            title: 'Define Water Surface Area',
            tipTitle: 'How Area Governs Capacity',
            tipDescription:
                'Surface area determines your maximum stocking density and bio-capacity. In shrimp farming, standard commercial stocking ranges from 30 to 60 postlarvae per m².',
            icon: Icons.straighten_rounded,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _areaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Water Surface Area *',
                    hintText: 'e.g. 1.0',
                    prefixIcon: const Icon(Icons.crop_landscape_rounded, color: Color(0xFF006876)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _areaUnit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Acres', child: Text('Acres')),
                    DropdownMenuItem(value: 'Hectares', child: Text('Hectares')),
                    DropdownMenuItem(value: 'm²', child: Text('m²')),
                  ],
                  onChanged: (v) => setState(() => _areaUnit = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Conversion Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Standardized Area:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  '${areaSqM.toInt()} m²  ·  ${areaAcres.toStringAsFixed(2)} Acres',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Quick Common Sizes:',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('0.5 Acre (~2,023 m²)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _areaController.text = '0.5';
                  _areaUnit = 'Acres';
                }),
              ),
              ActionChip(
                label: const Text('1.0 Acre (~4,047 m²)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _areaController.text = '1.0';
                  _areaUnit = 'Acres';
                }),
              ),
              ActionChip(
                label: const Text('1.0 Hectare (10,000 m²)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _areaController.text = '1.0';
                  _areaUnit = 'Hectares';
                }),
              ),
              ActionChip(
                label: const Text('500 m² Nursery Tank', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _areaController.text = '500';
                  _areaUnit = 'm²';
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 3: Depth & Volume
  Widget _buildStep3Depth(ThemeData theme, bool isDark) {
    final volume = _getVolumeInCubicMeters();
    final volumeMl = volume / 1000000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            theme: theme,
            isDark: isDark,
            stepBadge: 'Step 3 of 5',
            title: 'Set Operating Water Depth',
            tipTitle: 'Why 1.2m to 1.6m is Recommended',
            tipDescription:
                'Shallow water (<1.0m) experiences extreme heat in afternoons and rapid chilling during rain. Depths of 1.2m–1.6m buffer water temperature and maintain healthy algal blooms.',
            icon: Icons.layers_rounded,
          ),
          TextFormField(
            controller: _depthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Water Depth (meters) *',
              hintText: 'e.g. 1.5',
              suffixText: 'meters',
              prefixIcon: const Icon(Icons.height_rounded, color: Color(0xFF006876)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Live Water Volume Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF006876).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF006876).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calculated Water Volume:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '${volume.toStringAsFixed(0)} m³ (${(volume * 1000).toInt()} L)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006876)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Equivalent to ${volumeMl.toStringAsFixed(3)} Megaliters (ML). AquaLog uses this volume to dose lime, probiotics, and water treatments accurately.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Recommended Depth Presets:',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('1.2 m (Nursery)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _depthController.text = '1.2'),
              ),
              ActionChip(
                label: const Text('1.4 m (Compact)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _depthController.text = '1.4'),
              ),
              ActionChip(
                label: const Text('1.5 m (Standard Optimal)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => setState(() => _depthController.text = '1.5'),
              ),
              ActionChip(
                label: const Text('1.6 m (Deep Commercial)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _depthController.text = '1.6'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 4: Aeration Sizing
  Widget _buildStep4Aeration(ThemeData theme, bool isDark) {
    final hpPerAcre = _getAerationHpPerAcre();
    final aeratorCount = _getAeratorsCount();
    final totalHp = _getAeratorHp();

    String ratingLabel;
    Color ratingColor;
    if (hpPerAcre < 6) {
      ratingLabel = 'Low Aeration (<6 HP/Ac)';
      ratingColor = Colors.orange;
    } else if (hpPerAcre <= 18) {
      ratingLabel = 'Optimal Commercial (6-18 HP/Ac)';
      ratingColor = const Color(0xFF006876);
    } else {
      ratingLabel = 'Super-Intensive (>18 HP/Ac)';
      ratingColor = Colors.purple;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            theme: theme,
            isDark: isDark,
            stepBadge: 'Step 4 of 5',
            title: 'Configure Aeration Equipment',
            tipTitle: 'Dissolved Oxygen & Sludge Control',
            tipDescription:
                'Paddlewheel aerators keep DO above 4.0 ppm and swirl waste into central drains. Rule of thumb: 1 HP per 300–400 kg standing biomass (approx. 8–16 HP per acre in intensive culture).',
            icon: Icons.air_rounded,
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _aeratorsCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Aerator Units *',
                    hintText: 'e.g. 4',
                    suffixText: 'units',
                    prefixIcon: const Icon(Icons.rotate_right_rounded, color: Color(0xFF006876)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _aeratorHpController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Total Aerator HP *',
                    hintText: 'e.g. 8.0',
                    suffixText: 'HP',
                    prefixIcon: const Icon(Icons.bolt_rounded, color: Color(0xFF006876)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Aeration Telemetry Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Aeration Density:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ratingColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ratingLabel,
                        style: TextStyle(color: ratingColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${hpPerAcre.toStringAsFixed(1)} HP / Acre ($totalHp HP across $aeratorCount units)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF006876)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adequate aeration provides oxygen reserve during night hours when plankton respire.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Quick Setup Presets:',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('4 Units (8 HP)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _aeratorsCountController.text = '4';
                  _aeratorHpController.text = '8.0';
                }),
              ),
              ActionChip(
                label: const Text('6 Units (12 HP)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _aeratorsCountController.text = '6';
                  _aeratorHpController.text = '12.0';
                }),
              ),
              ActionChip(
                label: const Text('8 Units (16 HP)', style: TextStyle(fontSize: 11)),
                onPressed: () => setState(() {
                  _aeratorsCountController.text = '8';
                  _aeratorHpController.text = '16.0';
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 5: Review & Confirm
  Widget _buildStep5Review(ThemeData theme, bool isDark) {
    final name = _nameController.text.trim();
    final areaSqM = _getAreaInSqMeters();
    final areaAcres = areaSqM / 4046.86;
    final depth = _getDepthInMeters();
    final volume = _getVolumeInCubicMeters();
    final aeratorUnits = _getAeratorsCount();
    final aeratorHp = _getAeratorHp();
    final hpPerAcre = _getAerationHpPerAcre();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            theme: theme,
            isDark: isDark,
            stepBadge: 'Step 5 of 5',
            title: 'Review & Register Basin',
            tipTitle: 'Tutorial Complete! Ready to Save',
            tipDescription:
                'Review your pond parameters below. Once created, you can immediately record water conditioning and stock your first batch of shrimp postlarvae.',
            icon: Icons.check_circle_outline_rounded,
          ),

          // Summary Profile Card
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF006876).withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF006876).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006876).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFF006876)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Unnamed Pond' : name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Site: ${widget.site.name}',
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'READY',
                        style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Metrics Table
                _buildSummaryRow(
                  theme,
                  label: 'Surface Area',
                  value: '${areaSqM.toInt()} m² (${areaAcres.toStringAsFixed(2)} Acres)',
                  icon: Icons.straighten_rounded,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  theme,
                  label: 'Operating Depth',
                  value: '$depth meters',
                  icon: Icons.height_rounded,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  theme,
                  label: 'Water Volume',
                  value: '${volume.toStringAsFixed(0)} m³ (${(volume / 1000).toStringAsFixed(1)} kL)',
                  icon: Icons.water_drop_rounded,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  theme,
                  label: 'Aeration Units',
                  value: '$aeratorUnits units ($aeratorHp HP)',
                  icon: Icons.rotate_right_rounded,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  theme,
                  label: 'Aeration Density',
                  value: '${hpPerAcre.toStringAsFixed(1)} HP / Acre',
                  icon: Icons.bolt_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Next Steps Checklist
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Steps in AquaLog:',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                _buildChecklistLine('1. Water preparation: fill, lime (CaCO₃), and establish phytoplankton bloom.'),
                _buildChecklistLine('2. Tap "Stock Batch" to record postlarvae count, hatchery source, and start DOC counting.'),
                _buildChecklistLine('3. Log daily feeds, check trays, and water quality telemetry.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, {required String label, required String value, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF006876)),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChecklistLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF006876)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11.5, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
