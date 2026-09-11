import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/calculations/water_quality_engine.dart';
import '../../core/widgets/aqua_dropdown.dart';
import '../../app/theme/color_schemes.dart';

class WaterQualityEntryPage extends ConsumerStatefulWidget {
  final String initialPondId;
  final VoidCallback? onSaved;

  const WaterQualityEntryPage({
    super.key,
    required this.initialPondId,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {required String pondId, VoidCallback? onSaved}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WaterQualityEntryPage(initialPondId: pondId, onSaved: onSaved),
      ),
    );
  }

  @override
  ConsumerState<WaterQualityEntryPage> createState() => _WaterQualityEntryPageState();
}

class _WaterQualityEntryPageState extends ConsumerState<WaterQualityEntryPage> {
  late String _selectedPondId;
  String _selectedTimeSlot = 'Morning';
  final DateTime _recordDate = DateTime.now();

  final _tempController = TextEditingController();
  final _phController = TextEditingController();
  final _doController = TextEditingController();
  final _salinityController = TextEditingController();
  final _ammoniaController = TextEditingController();
  final _nitriteController = TextEditingController();
  final _alkalinityController = TextEditingController();
  final _transparencyController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPondId = widget.initialPondId;
    _determineInitialTimeSlot();
  }

  void _determineInitialTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      _selectedTimeSlot = 'Morning';
    } else if (hour < 16) {
      _selectedTimeSlot = 'Afternoon';
    } else {
      _selectedTimeSlot = 'Evening';
    }
  }

  @override
  void dispose() {
    _tempController.dispose();
    _phController.dispose();
    _doController.dispose();
    _salinityController.dispose();
    _ammoniaController.dispose();
    _nitriteController.dispose();
    _alkalinityController.dispose();
    _transparencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _getStatusColor(WqStatus status) {
    switch (status) {
      case WqStatus.optimal:
        return AquaColors.statusOptimal;
      case WqStatus.acceptable:
        return Colors.blue;
      case WqStatus.warning:
        return AquaColors.statusWarning;
      case WqStatus.critical:
        return AquaColors.statusCritical;
    }
  }

  Widget _buildField({
    required String label,
    required String paramKey,
    required TextEditingController controller,
    required String unit,
    String? hint,
  }) {
    final threshold = WaterQualityEngine.defaultThresholds[paramKey];
    final val = double.tryParse(controller.text.trim());
    final status = threshold != null && val != null ? threshold.evaluate(val) : null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status != null
              ? _getStatusColor(status).withOpacity(0.6)
              : theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.25 : 0.35),
          width: status != null ? 1.4 : 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (threshold != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Optimal: ${threshold.optimalMin}-${threshold.optimalMax} $unit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: hint ?? '0.0',
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                suffixText: ' $unit',
                suffixStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.35), width: 0.8),
              ),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveEntry({bool nextPond = false}) async {
    final db = ref.read(databaseProvider);
    final activeBatch = await db.getActiveBatchForPond(_selectedPondId);

    final double? temp = double.tryParse(_tempController.text.trim());
    final double? ph = double.tryParse(_phController.text.trim());
    final double? doVal = double.tryParse(_doController.text.trim());
    final double? salinity = double.tryParse(_salinityController.text.trim());
    final double? ammonia = double.tryParse(_ammoniaController.text.trim());
    final double? nitrite = double.tryParse(_nitriteController.text.trim());
    final double? alkalinity = double.tryParse(_alkalinityController.text.trim());
    final double? transparency = double.tryParse(_transparencyController.text.trim());

    if (temp == null && ph == null && doVal == null && salinity == null && ammonia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one water quality parameter.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final logId = 'wq_${const Uuid().v4()}';
      await db.saveWaterQualityLog(WaterQualityLogsCompanion.insert(
        id: logId,
        pondId: _selectedPondId,
        batchId: activeBatch != null ? Value(activeBatch.id) : const Value.absent(),
        date: _recordDate,
        timeSlot: Value(_selectedTimeSlot),
        temperature: temp != null ? Value(temp) : const Value.absent(),
        ph: ph != null ? Value(ph) : const Value.absent(),
        dissolvedOxygen: doVal != null ? Value(doVal) : const Value.absent(),
        salinity: salinity != null ? Value(salinity) : const Value.absent(),
        ammonia: ammonia != null ? Value(ammonia) : const Value.absent(),
        nitrite: nitrite != null ? Value(nitrite) : const Value.absent(),
        alkalinity: alkalinity != null ? Value(alkalinity) : const Value.absent(),
        transparencyCm: transparency != null ? Value(transparency) : const Value.absent(),
        notes: _notesController.text.trim().isNotEmpty
            ? Value(_notesController.text.trim())
            : const Value.absent(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water quality record saved successfully.')),
        );
        widget.onSaved?.call();

        if (nextPond) {
          final allPonds = await db.select(db.ponds).get();
          final currentIndex = allPonds.indexWhere((p) => p.id == _selectedPondId);
          if (currentIndex >= 0 && currentIndex < allPonds.length - 1) {
            setState(() {
              _selectedPondId = allPonds[currentIndex + 1].id;
              _tempController.clear();
              _phController.clear();
              _doController.clear();
              _salinityController.clear();
              _ammoniaController.clear();
              _nitriteController.clear();
              _alkalinityController.clear();
              _transparencyController.clear();
              _notesController.clear();
              _isSaving = false;
            });
            return;
          }
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pondsAsync = ref.watch(allPondsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Water Quality'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {},
          ),
        ],
      ),
      body: pondsAsync.when(
        data: (ponds) {
          if (ponds.isEmpty) {
            return const Center(child: Text('No ponds found. Create a pond first.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pond & Time Slot Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AquaDropdownFormField<String>(
                        value: _selectedPondId,
                        labelText: 'Pond',
                        prefixIcon: const Icon(Icons.water_drop_outlined, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        items: ponds
                            .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPondId = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AquaDropdownFormField<String>(
                        value: _selectedTimeSlot,
                        labelText: 'Time Slot',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        items: ['Morning', 'Afternoon', 'Evening', 'Custom']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTimeSlot = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Core Parameters List
                _buildField(
                  label: 'Dissolved Oxygen (DO)',
                  paramKey: 'dissolvedOxygen',
                  controller: _doController,
                  unit: 'mg/L',
                  hint: '5.2',
                ),
                _buildField(
                  label: 'pH Level',
                  paramKey: 'ph',
                  controller: _phController,
                  unit: '',
                  hint: '7.8',
                ),
                _buildField(
                  label: 'Water Temperature',
                  paramKey: 'temperature',
                  controller: _tempController,
                  unit: '°C',
                  hint: '29.5',
                ),
                _buildField(
                  label: 'Salinity',
                  paramKey: 'salinity',
                  controller: _salinityController,
                  unit: 'ppt',
                  hint: '18.0',
                ),
                _buildField(
                  label: 'Ammonia (NH3-N)',
                  paramKey: 'ammonia',
                  controller: _ammoniaController,
                  unit: 'mg/L',
                  hint: '0.02',
                ),
                _buildField(
                  label: 'Nitrite (NO2-N)',
                  paramKey: 'nitrite',
                  controller: _nitriteController,
                  unit: 'mg/L',
                  hint: '0.05',
                ),
                _buildField(
                  label: 'Alkalinity',
                  paramKey: 'alkalinity',
                  controller: _alkalinityController,
                  unit: 'mg/L',
                  hint: '125.0',
                ),
                _buildField(
                  label: 'Transparency / Secchi',
                  paramKey: 'transparencyCm',
                  controller: _transparencyController,
                  unit: 'cm',
                  hint: '35.0',
                ),

                // Notes Field
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Field Observation Notes',
                    hintText: 'Water color, algae bloom, weather remarks...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Save Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _saveEntry(nextPond: true);
                              },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Save & Next Pond'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _saveEntry(nextPond: false);
                              },
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded),
                        label: const Text('Save'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading ponds: $err')),
      ),
    );
  }
}
