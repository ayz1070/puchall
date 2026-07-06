import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/sensor_snapshot.dart';

class SensorValuePanel extends StatelessWidget {
  const SensorValuePanel({super.key, required this.snapshot});

  final SensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SensorGraph(label: '가속도', vector: snapshot.accelerometer),
          const SizedBox(height: 14),
          _SensorGraph(label: '자이로', vector: snapshot.gyroscope),
          const SizedBox(height: 14),
          _SensorGraph(label: '지자기', vector: snapshot.magnetometer),
        ],
      ),
    );
  }
}

class _SensorGraph extends StatelessWidget {
  const _SensorGraph({required this.label, required this.vector});

  final String label;
  final SensorVector vector;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      vector.x.abs(),
      vector.y.abs(),
      vector.z.abs(),
      vector.magnitude,
      1.0,
    ].reduce((value, element) => value > element ? value : element);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 56, child: Text(label, style: AppTextStyles.label)),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 176,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 42,
                        child: CustomPaint(
                          painter: _SensorGraphPainter(
                            vector: vector,
                            maxValue: maxValue,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'x ${vector.x.toStringAsFixed(1)}  y ${vector.y.toStringAsFixed(1)}  z ${vector.z.toStringAsFixed(1)}  m ${vector.magnitude.toStringAsFixed(1)}',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.body.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SensorGraphPainter extends CustomPainter {
  const _SensorGraphPainter({required this.vector, required this.maxValue});

  final SensorVector vector;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final barPaint = Paint()..style = PaintingStyle.fill;
    final centerY = size.height / 2;
    const barWidth = 6.0;
    final gap = (size.width - barWidth * 4) / 3;
    final values = [
      (value: vector.x, color: AppColors.brandPrimary),
      (value: vector.y, color: AppColors.danger),
      (value: vector.z, color: const Color(0xFF38BDF8)),
      (value: vector.magnitude, color: const Color(0xFF22C55E)),
    ];

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), axisPaint);

    for (var i = 0; i < values.length; i++) {
      final item = values[i];
      final normalized = (item.value / maxValue).clamp(-1.0, 1.0);
      final left = i * (barWidth + gap);
      final top = normalized >= 0 ? centerY - centerY * normalized : centerY;
      final bottom = normalized >= 0 ? centerY : centerY - centerY * normalized;

      barPaint.color = item.color;
      canvas.drawRect(
        Rect.fromLTRB(left, top, left + barWidth, bottom),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SensorGraphPainter oldDelegate) {
    return oldDelegate.vector != vector || oldDelegate.maxValue != maxValue;
  }
}
