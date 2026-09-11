import 'package:flutter/material.dart';

/// Preset template for quickly configuring a shrimp pond
class PondPreset {
  final String title;
  final String description;
  final double areaValue;
  final String areaUnit;
  final double depthMeters;
  final int aeratorUnits;
  final double totalHp;
  final IconData icon;

  const PondPreset({
    required this.title,
    required this.description,
    required this.areaValue,
    required this.areaUnit,
    required this.depthMeters,
    required this.aeratorUnits,
    required this.totalHp,
    required this.icon,
  });

  static const List<PondPreset> standardPresets = [
    PondPreset(
      title: '1.0 Acre Commercial',
      description: 'Standard vannamei intensive basin with 4 paddlewheels',
      areaValue: 1.0,
      areaUnit: 'Acres',
      depthMeters: 1.5,
      aeratorUnits: 4,
      totalHp: 8.0,
      icon: Icons.water_rounded,
    ),
    PondPreset(
      title: '0.5 Acre Intensive',
      description: 'Compact intensive grow-out pond with high circulation',
      areaValue: 0.5,
      areaUnit: 'Acres',
      depthMeters: 1.4,
      aeratorUnits: 2,
      totalHp: 4.0,
      icon: Icons.waves_rounded,
    ),
    PondPreset(
      title: '1.0 Hectare Basin',
      description: 'Large commercial farming basin (10,000 m²)',
      areaValue: 1.0,
      areaUnit: 'Hectares',
      depthMeters: 1.6,
      aeratorUnits: 8,
      totalHp: 16.0,
      icon: Icons.landscape_rounded,
    ),
    PondPreset(
      title: '500 m² Nursery Tank',
      description: 'Early post-larvae nursery & acclimatization tank',
      areaValue: 500.0,
      areaUnit: 'm²',
      depthMeters: 1.2,
      aeratorUnits: 2,
      totalHp: 4.0,
      icon: Icons.bubble_chart_rounded,
    ),
  ];
}

/// A guide card displayed when a farmer is setting up their first pond basin
class FirstPondUserGuideCard extends StatelessWidget {
  final VoidCallback? onStartTutorial;
  final ValueChanged<PondPreset>? onApplyPreset;
  final VoidCallback? onDismiss;
  final bool isDismissible;

  const FirstPondUserGuideCard({
    super.key,
    this.onStartTutorial,
    this.onApplyPreset,
    this.onDismiss,
    this.isDismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF00363D),
                  const Color(0xFF002026),
                ]
              : [
                  const Color(0xFFE0F7FA),
                  const Color(0xFFE8F5E9),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF007A87).withOpacity(isDark ? 0.4 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007A87).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006876).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF006876),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Step-by-Step Pond Tutorial',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF004D56),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006876),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'GUIDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Interactive 5-step tutorial to create and configure your pond',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : const Color(0xFF004D56).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDismissible && onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onDismiss,
                    tooltip: 'Dismiss Guide',
                  ),
              ],
            ),
          ),

          if (onStartTutorial != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF006876),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onStartTutorial,
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: const Text(
                    'Start Step-by-Step Tutorial',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],

          const Divider(height: 1),

          // 5 Step Tutorial Roadmap
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                _buildGuideStep(
                  theme: theme,
                  stepNumber: '1',
                  icon: Icons.tag_rounded,
                  title: 'Basin Identifier',
                  description: 'Name your pond (e.g., "Pond 01"). Links daily check-trays, feed logs, and lab sampling.',
                ),
                const SizedBox(height: 8),
                _buildGuideStep(
                  theme: theme,
                  stepNumber: '2',
                  icon: Icons.straighten_rounded,
                  title: 'Surface Area & Sizing',
                  description: 'Choose Acres, Hectares, or m². Governs carrying capacity and stocking limits.',
                ),
                const SizedBox(height: 8),
                _buildGuideStep(
                  theme: theme,
                  stepNumber: '3',
                  icon: Icons.layers_rounded,
                  title: 'Water Depth & Volume',
                  description: 'Set 1.2m to 1.6m depth to buffer water temperature. Computes live volume.',
                ),
                const SizedBox(height: 8),
                _buildGuideStep(
                  theme: theme,
                  stepNumber: '4',
                  icon: Icons.air_rounded,
                  title: 'Aeration Power (Paddlewheels)',
                  description: 'Configure aerators and total horsepower. Computes live HP/Acre density.',
                ),
                const SizedBox(height: 8),
                _buildGuideStep(
                  theme: theme,
                  stepNumber: '5',
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Review & Register Basin',
                  description: 'Inspect calculated metrics and register the pond with next-step guidance.',
                ),
              ],
            ),
          ),

          // Presets Section
          if (onApplyPreset != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1-Tap Standard Presets:',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF004D56),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 14),
                        label: const Text('Read Best Practices', style: TextStyle(fontSize: 11)),
                        onPressed: () => FirstPondGuideDialog.show(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PondPreset.standardPresets.map((preset) {
                      return ActionChip(
                        avatar: Icon(preset.icon, size: 14, color: const Color(0xFF006876)),
                        label: Text(
                          preset.title,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF004D56).withOpacity(0.5)
                            : Colors.white,
                        side: BorderSide(
                          color: const Color(0xFF006876).withOpacity(0.3),
                        ),
                        onPressed: () => onApplyPreset!(preset),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required ThemeData theme,
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF006876),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF00363D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: isDark ? Colors.white70 : const Color(0xFF1E3A40),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Detailed Dialog explaining aquaculture basin sizing, aeration ratios, and preparation
class FirstPondGuideDialog extends StatelessWidget {
  const FirstPondGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const FirstPondGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF006876).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF006876), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shrimp Pond Architecture',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Best Practices for L. vannamei & P. monodon',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                theme,
                title: '1. Water Depth & Surface Sizing',
                icon: Icons.straighten_rounded,
                content:
                    '• Recommended operating depth is 1.2 to 1.6 meters. Shallow ponds (<1.0m) heat up quickly in summer and experience sudden temperature drops during monsoons.\n'
                    '• Pond surface area determines stocking biomass capacity. 1 Acre is roughly 4,047 m².\n'
                    '• Water Volume Formula: Volume (m³) = Area (m²) × Average Depth (m). 1 m³ = 1,000 Liters.',
              ),
              const SizedBox(height: 12),
              _buildSection(
                theme,
                title: '2. Aeration Rules of Thumb',
                icon: Icons.air_rounded,
                content:
                    '• Aeration provides essential Dissolved Oxygen (DO > 4.0 mg/L) and circulates sludge into central drains.\n'
                    '• Intensive systems (40–60 PL/m²): Deploy 6 to 10 HP aeration per Acre (typically 4-arm or 2-arm paddlewheel aerators).\n'
                    '• Keep aerators running during feeding digestions and peak dark hours (11 PM – 6 AM).',
              ),
              const SizedBox(height: 12),
              _buildSection(
                theme,
                title: '3. Pre-Stocking Preparation Checklist',
                icon: Icons.fact_check_outlined,
                content:
                    '• Drain and sunlight-dry pond bottom until cracks appear (7–10 days).\n'
                    '• Apply agricultural lime (CaCO₃) or Dolomite to buffer pH and raise total alkalinity (>120 ppm).\n'
                    '• Fill filtered seawater/brackish water and bloom green/brown algae (Secchi disk transparency 30–40 cm).',
              ),
              const SizedBox(height: 12),
              _buildSection(
                theme,
                title: '4. What Happens After Creating Pond?',
                icon: Icons.rocket_launch_outlined,
                content:
                    '• Once your pond is created, you can tap "Stock Batch" to log stocking date, PL count, and species.\n'
                    '• AquaLog will automatically start DOC tracking, tray monitoring schedules, feed rations, and water quality telemetry.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got It, Let\'s Build'),
        ),
      ],
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF006876)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006876),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
