import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/widgets/aqua_dropdown.dart';

class PopulationAdjustmentDialog extends ConsumerStatefulWidget {
  final String batchId;
  final int currentEstimatedPopulation;
  final VoidCallback? onAdjusted;

  const PopulationAdjustmentDialog({
    super.key,
    required this.batchId,
    required this.currentEstimatedPopulation,
    this.onAdjusted,
  });

  static Future<void> show(
    BuildContext context, {
    required String batchId,
    required int currentEstimatedPopulation,
    VoidCallback? onAdjusted,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PopulationAdjustmentDialog(
        batchId: batchId,
        currentEstimatedPopulation: currentEstimatedPopulation,
        onAdjusted: onAdjusted,
      ),
    );
  }

  @override
  ConsumerState<PopulationAdjustmentDialog> createState() => _PopulationAdjustmentDialogState();
}

class _PopulationAdjustmentDialogState extends ConsumerState<PopulationAdjustmentDialog> {
  final _newCountController = TextEditingController();
  final _reasonController = TextEditingController();
  String _selectedReasonCategory = 'sampling_correction';
  bool _isSaving = false;

  final List<Map<String, String>> _categories = [
    {'value': 'sampling_correction', 'label': 'Cast-Net Sampling Correction'},
    {'value': 'stocking_correction', 'label': 'Stocking Count Correction'},
    {'value': 'counting_correction', 'label': 'Physical Verification / Tally'},
    {'value': 'data_correction', 'label': 'Data Entry Error Fix'},
    {'value': 'other', 'label': 'Other Operational Adjustment'},
  ];

  @override
  void initState() {
    super.initState();
    _newCountController.text = widget.currentEstimatedPopulation.toString();
  }

  @override
  void dispose() {
    _newCountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newCount = int.tryParse(_newCountController.text.trim());
    if (newCount == null || newCount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid non-negative population count.')),
      );
      return;
    }

    final diff = newCount - widget.currentEstimatedPopulation;
    if (diff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjusted count is identical to current population.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      final adjId = 'adj_${const Uuid().v4()}';
      await db.savePopulationAdjustment(PopulationAdjustmentsCompanion.insert(
        id: adjId,
        batchId: widget.batchId,
        date: DateTime.now(),
        adjustedCount: newCount,
        previousCount: widget.currentEstimatedPopulation,
        differenceCount: diff,
        reason: _selectedReasonCategory,
        notes: _reasonController.text.trim().isNotEmpty
            ? Value(_reasonController.text.trim())
            : const Value.absent(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Population adjusted: ${diff > 0 ? "+$diff" : "$diff"} shrimp.')),
        );
        widget.onAdjusted?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adjustment failed: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? entered = int.tryParse(_newCountController.text.trim());
    final int diff = entered != null ? entered - widget.currentEstimatedPopulation : 0;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: Colors.teal),
          SizedBox(width: 8),
          Text('Adjust Population'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Estimated Stock: ${widget.currentEstimatedPopulation.toString()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Total Population Count',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Adjustment Delta: ${diff >= 0 ? "+$diff" : "$diff"} shrimp',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: diff < 0 ? Colors.red : (diff > 0 ? Colors.green : Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            AquaDropdownFormField<String>(
              value: _selectedReasonCategory,
              labelText: 'Adjustment Reason',
              prefixIcon: const Icon(Icons.rule_rounded, size: 20),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReasonCategory = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Audit Remarks / Evidence',
                hintText: 'Basis for correction, sampling dates...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Saving...') : const Text('Confirm Adjustment'),
        ),
      ],
    );
  }
}
