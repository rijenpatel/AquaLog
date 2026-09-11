import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/widgets/aqua_dropdown.dart';

class MortalityLoggingDialog extends ConsumerStatefulWidget {
  final String batchId;
  final String pondId;
  final VoidCallback? onLogged;

  const MortalityLoggingDialog({
    super.key,
    required this.batchId,
    required this.pondId,
    this.onLogged,
  });

  static Future<void> show(BuildContext context, {required String batchId, required String pondId, VoidCallback? onLogged}) {
    return showDialog(
      context: context,
      builder: (_) => MortalityLoggingDialog(batchId: batchId, pondId: pondId, onLogged: onLogged),
    );
  }

  @override
  ConsumerState<MortalityLoggingDialog> createState() => _MortalityLoggingDialogState();
}

class _MortalityLoggingDialogState extends ConsumerState<MortalityLoggingDialog> {
  final _observedController = TextEditingController();
  final _estimatedController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedReason = 'normal';
  bool _isSaving = false;

  final List<Map<String, String>> _reasons = [
    {'value': 'normal', 'label': 'Normal Baseline'},
    {'value': 'stress', 'label': 'Environmental Stress'},
    {'value': 'disease_suspected', 'label': 'Suspected Pathogen / Disease'},
    {'value': 'low_do', 'label': 'Low DO / Hypoxia'},
    {'value': 'weather', 'label': 'Weather Event / Heavy Rain'},
    {'value': 'handling', 'label': 'Handling / Netting Stress'},
    {'value': 'unknown', 'label': 'Unknown / Unspecified'},
    {'value': 'other', 'label': 'Other Reason'},
  ];

  @override
  void dispose() {
    _observedController.dispose();
    _estimatedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final observed = int.tryParse(_observedController.text.trim()) ?? 0;
    final estimated = int.tryParse(_estimatedController.text.trim()) ?? 0;

    if (observed <= 0 && estimated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter observed or estimated count.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      final recId = 'mort_${const Uuid().v4()}';
      await db.saveMortalityRecord(MortalityRecordsCompanion.insert(
        id: recId,
        batchId: widget.batchId,
        pondId: widget.pondId,
        date: DateTime.now(),
        countObserved: Value(observed),
        countEstimated: Value(estimated),
        reason: Value(_selectedReason),
        notes: _notesController.text.trim().isNotEmpty ? Value(_notesController.text.trim()) : const Value.absent(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mortality record logged successfully.')),
        );
        widget.onLogged?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log mortality: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.remove_circle_outline_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Log Daily Mortality'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _observedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Observed Dead Count (Trays / Surface)',
                hintText: 'e.g. 35',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _estimatedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated Additional Dead Count',
                hintText: 'e.g. 50 (if uncollected at bottom)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AquaDropdownFormField<String>(
              value: _selectedReason,
              labelText: 'Primary Suspected Cause',
              prefixIcon: const Icon(Icons.help_outline_rounded, size: 20),
              items: _reasons
                  .map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observations & Notes',
                hintText: 'Signs on gills, shell condition, swim behavior...',
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
          child: _isSaving ? const Text('Saving...') : const Text('Log Mortality'),
        ),
      ],
    );
  }
}
