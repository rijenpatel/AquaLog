import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/calculations/sampling_calculator.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/batch_dashboard_providers.dart';
import '../../app/theme/color_schemes.dart';

class SamplingDialog extends ConsumerStatefulWidget {
  final Batch batch;
  final Pond pond;
  final SamplingEntry? existingEntry; // If provided, mode is EDIT

  const SamplingDialog({
    super.key,
    required this.batch,
    required this.pond,
    this.existingEntry,
  });

  static Future<void> show(
    BuildContext context, {
    required Batch batch,
    required Pond pond,
    SamplingEntry? existingEntry,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SamplingDialog(
        batch: batch,
        pond: pond,
        existingEntry: existingEntry,
      ),
    );
  }

  @override
  ConsumerState<SamplingDialog> createState() => _SamplingDialogState();
}

class _SamplingDialogState extends ConsumerState<SamplingDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _weightCtrl;
  late TextEditingController _countCtrl;
  late TextEditingController _notesCtrl;
  bool _isSaving = false;
  SamplingEntry? _previousSampling;
  bool _loadingPrevious = true;

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _selectedDate = entry != null ? entry.date : DateTime.now();
    _weightCtrl = TextEditingController(text: entry != null ? entry.samplingTotalWeightG.toString() : '');
    _countCtrl = TextEditingController(text: entry != null ? entry.samplingShrimpCount.toString() : '100');
    _notesCtrl = TextEditingController(text: entry?.notes ?? '');

    _fetchPreviousSampling();
  }

  Future<void> _fetchPreviousSampling() async {
    final db = ref.read(appDatabaseProvider);
    final samplings = await db.getSamplingsForBatch(widget.batch.id);

    // Find the latest entry prior to the selected/editing entry
    final priorSamplings = samplings.where((s) {
      if (widget.existingEntry != null && s.id == widget.existingEntry!.id) return false;
      return SamplingCalculator.normalizeDate(s.date).isBefore(
        SamplingCalculator.normalizeDate(_selectedDate),
      );
    }).toList();

    setState(() {
      _previousSampling = priorSamplings.isNotEmpty ? priorSamplings.last : null;
      _loadingPrevious = false;
    });
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _countCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _calculatedDoc {
    final stock = SamplingCalculator.normalizeDate(widget.batch.stockingDate);
    final sample = SamplingCalculator.normalizeDate(_selectedDate);
    final diff = sample.difference(stock).inDays;
    return diff >= 0 ? diff + 1 : 1;
  }

  double? get _liveAbw {
    final weight = double.tryParse(_weightCtrl.text.trim());
    final count = int.tryParse(_countCtrl.text.trim());
    return SamplingCalculator.calculateAbw(totalCastWeightGrams: weight, sampleCount: count);
  }

  double? get _liveCountPerKg {
    final abw = _liveAbw;
    if (abw == null || abw <= 0) return null;
    return SamplingCalculator.calculateCountPerKg(abw);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final stocking = widget.batch.stockingDate;
    final initial = _selectedDate.isBefore(stocking)
        ? stocking
        : (_selectedDate.isAfter(today) ? today : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(stocking.year, stocking.month, stocking.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Select Sampling Date',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchPreviousSampling();
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Date validations
    final dateErr = SamplingCalculator.validateSamplingDate(
      stockingDate: widget.batch.stockingDate,
      samplingDate: _selectedDate,
    );
    if (dateErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dateErr), backgroundColor: AquaColors.statusAlert),
      );
      return;
    }

    final totalWeight = double.tryParse(_weightCtrl.text.trim());
    if (totalWeight == null || totalWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total cast weight must be greater than zero.'), backgroundColor: AquaColors.statusAlert),
      );
      return;
    }

    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample count must be a positive whole integer.'), backgroundColor: AquaColors.statusAlert),
      );
      return;
    }

    final abw = SamplingCalculator.calculateAbw(totalCastWeightGrams: totalWeight, sampleCount: count);
    if (abw == null || abw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculated ABW is invalid.'), backgroundColor: AquaColors.statusAlert),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);

    // Check for same-day sample duplicate
    final existingSameDay = (await db.getSamplingsForBatch(widget.batch.id)).where((s) {
      if (widget.existingEntry != null && s.id == widget.existingEntry!.id) return false;
      return SamplingCalculator.normalizeDate(s.date) == SamplingCalculator.normalizeDate(_selectedDate);
    }).toList();

    if (existingSameDay.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sampling Already Recorded'),
          content: Text(
            'A sampling entry (${existingSameDay.first.abwGrams.toStringAsFixed(3)}g) already exists for ${DateFormat("dd MMM yyyy").format(_selectedDate)}. Do you want to record another sample for this date?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      final isEdit = widget.existingEntry != null;
      final entryId = isEdit ? widget.existingEntry!.id : 'samp_${DateTime.now().millisecondsSinceEpoch}';

      final companion = SamplingEntriesCompanion(
        id: drift.Value(entryId),
        batchId: drift.Value(widget.batch.id),
        pondId: drift.Value(widget.pond.id),
        date: drift.Value(_selectedDate),
        doc: drift.Value(_calculatedDoc),
        samplingShrimpCount: drift.Value(count),
        samplingTotalWeightG: drift.Value(totalWeight),
        abwGrams: drift.Value(abw),
        notes: drift.Value(_notesCtrl.text.trim()),
      );

      await db.saveSamplingEntry(companion, widget.batch.id);

      ref.invalidate(samplingEntriesStreamProvider);
      ref.invalidate(batchDashboardDataProvider(widget.batch.id));
      ref.invalidate(activeBatchesStreamProvider);

      if (mounted) {
        final countPerKgDisplay = SamplingCalculator.formatCountPerKg(SamplingCalculator.calculateCountPerKg(abw));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Sampling saved: ${abw.toStringAsFixed(3)}g ABW · $countPerKgDisplay'),
            backgroundColor: AquaColors.statusOptimal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save sampling: $e'), backgroundColor: AquaColors.statusAlert),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existingEntry != null;
    final liveAbw = _liveAbw;
    final liveCountPerKg = _liveCountPerKg;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? 'Edit Sampling' : '10-Day Sampling: ${widget.pond.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            'Batch #${widget.batch.batchNumber} · Stocked ${DateFormat("dd MMM yyyy").format(widget.batch.stockingDate)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live ABW & Count/kg KPI Display Tile
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AquaColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AquaColors.primary.withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calculated ABW:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          liveAbw != null ? '${liveAbw.toStringAsFixed(3)} g' : '—',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AquaColors.primary),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Count / kg:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          SamplingCalculator.formatCountPerKg(liveCountPerKg),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AquaColors.primary),
                        ),
                      ],
                    ),
                    if (!_loadingPrevious) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Previous ABW:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            _previousSampling != null
                                ? '${_previousSampling!.abwGrams.toStringAsFixed(3)} g (${DateFormat("dd MMM").format(_previousSampling!.date)})'
                                : '— (Baseline First Sample)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker and Read-Only DOC
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Sampling Date *',
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                        ),
                        child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'DOC',
                        helperText: 'Read-only',
                      ),
                      child: Text(
                        'DOC $_calculatedDoc',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Sample Count (pieces)
              TextFormField(
                controller: _countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sample Count (Prawns Counted) *',
                  suffixText: 'pieces',
                  helperText: 'Physical count of shrimp sampled',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Sample count is required';
                  final n = int.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Must be a whole number > 0';
                  if (val.contains('.')) return 'Must be an integer';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Total Cast Weight (grams)
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total Cast Weight *',
                  suffixText: 'grams (g)',
                  helperText: 'Combined weight of sampled prawns in grams',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Total weight is required';
                  final w = double.tryParse(val.trim());
                  if (w == null || w <= 0) return 'Must be a positive number > 0';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Notes / Observations
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observations (Optional)',
                  hintText: 'Gut full, soft shell, antenna damage, etc.',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _onSave,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(isEdit ? 'Update Sampling' : 'Save Sampling'),
        ),
      ],
    );
  }
}
