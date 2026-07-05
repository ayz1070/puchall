import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/sensor_snapshot.dart';

class SensorValuePanel extends StatelessWidget {
  const SensorValuePanel({super.key, required this.snapshot});

  final SensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('센서 수치', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          _SensorRow(label: '가속도', vector: snapshot.accelerometer),
          _SensorRow(label: '자이로', vector: snapshot.gyroscope),
          _SensorRow(label: '지자기', vector: snapshot.magnetometer),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({required this.label, required this.vector});

  final String label;
  final SensorVector vector;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            'x ${vector.x.toStringAsFixed(2)}   y ${vector.y.toStringAsFixed(2)}   z ${vector.z.toStringAsFixed(2)}   |m| ${vector.magnitude.toStringAsFixed(2)}',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
