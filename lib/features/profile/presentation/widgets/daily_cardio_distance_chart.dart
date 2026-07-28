import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../../../workout/domain/entities/workout_session.dart';

class DailyCardioDistanceChart extends StatelessWidget {
  const DailyCardioDistanceChart({
    super.key,
    required this.sessions,
    required this.visibleMonth,
  });

  final List<WorkoutSession> sessions;
  final DateTime visibleMonth;

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final hasRecords = points.any(
      (point) => point.runningKm > 0 || point.walkingKm > 0,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${visibleMonth.year}년 ${visibleMonth.month}월 유산소',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 12),
          if (hasRecords) ...[
            const _CardioLegend(),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _DailyCardioDistanceChartPainter(points: points),
                child: const SizedBox.expand(),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('아직 런닝/걷기 기록이 없습니다.', style: AppTextStyles.body),
            ),
        ],
      ),
    );
  }

  List<_CardioDistancePoint> _buildPoints() {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final nextMonth = DateTime(visibleMonth.year, visibleMonth.month + 1);
    final daysInMonth = nextMonth.difference(firstDay).inDays;
    final pointsByDate = <String, _CardioDistancePoint>{};

    for (var i = 0; i < daysInMonth; i++) {
      final date = firstDay.add(Duration(days: i));
      pointsByDate[_dateKey(date)] = _CardioDistancePoint(date: date);
    }

    for (final session in sessions) {
      final point = pointsByDate[session.dateKey];
      if (point == null) continue;

      switch (session.exerciseType) {
        case ExerciseType.running:
          point.runningKm += session.distanceMeters / 1000;
          break;
        case ExerciseType.walking:
          point.walkingKm += session.distanceMeters / 1000;
          break;
        case ExerciseType.pushUp:
        case ExerciseType.pullUp:
          break;
      }
    }

    return pointsByDate.values.toList();
  }
}

class _CardioLegend extends StatelessWidget {
  const _CardioLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendItem(label: 'RUNNING', color: AppColors.brandPrimary),
        SizedBox(width: 14),
        _LegendItem(label: 'WALKING', color: AppColors.textPrimary),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 8, height: 8),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.body.copyWith(fontSize: 12)),
      ],
    );
  }
}

class _DailyCardioDistanceChartPainter extends CustomPainter {
  const _DailyCardioDistanceChartPainter({required this.points});

  final List<_CardioDistancePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPadding = 42.0;
    const rightPadding = 8.0;
    const topPadding = 10.0;
    const bottomPadding = 30.0;
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );
    final maxKm = points.fold<double>(
      0,
      (maxValue, point) =>
          math.max(maxValue, math.max(point.runningKm, point.walkingKm)),
    );
    final yMax = _roundedMax(maxKm);

    _drawGrid(canvas, chartRect, yMax);
    _drawXAxisLabels(canvas, chartRect);
    _drawLine(
      canvas,
      chartRect,
      yMax,
      points.map((point) => point.runningKm).toList(),
      AppColors.brandPrimary,
    );
    _drawLine(
      canvas,
      chartRect,
      yMax,
      points.map((point) => point.walkingKm).toList(),
      AppColors.textPrimary,
    );
  }

  double _roundedMax(double maxKm) {
    if (maxKm <= 0) return 1;
    if (maxKm <= 1) return 1;
    return maxKm.ceilToDouble();
  }

  void _drawGrid(Canvas canvas, Rect chartRect, double yMax) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final labelStyle = AppTextStyles.body.copyWith(fontSize: 10);

    for (var i = 0; i <= 2; i++) {
      final value = yMax / 2 * (2 - i);
      final y = chartRect.top + chartRect.height / 2 * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}km',
        Offset(chartRect.left - 8, y),
        labelStyle,
        TextAlign.right,
        anchorRight: true,
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, Rect chartRect) {
    final labelStyle = AppTextStyles.body.copyWith(fontSize: 10);
    for (var i = 0; i < points.length; i++) {
      final date = points[i].date;
      if (!_shouldDrawXAxisLabel(date, i)) continue;

      _drawText(
        canvas,
        '${date.day}',
        Offset(_xForIndex(chartRect, i), chartRect.bottom + 12),
        labelStyle,
        TextAlign.center,
      );
    }
  }

  bool _shouldDrawXAxisLabel(DateTime date, int index) {
    final lastDay = points.last.date.day;
    if (lastDay == 31 && date.day == 30) return false;
    return index == 0 || date.day % 5 == 0 || index == points.length - 1;
  }

  void _drawLine(
    Canvas canvas,
    Rect chartRect,
    double yMax,
    List<double> values,
    Color color,
  ) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(
        _xForIndex(chartRect, 0),
        _yForValue(chartRect, values.first, yMax),
      );

    for (var i = 1; i < values.length; i++) {
      path.lineTo(
        _xForIndex(chartRect, i),
        _yForValue(chartRect, values[i], yMax),
      );
    }

    canvas.drawPath(path, paint);
  }

  double _xForIndex(Rect chartRect, int index) {
    if (points.length == 1) return chartRect.left;
    return chartRect.left + chartRect.width * index / (points.length - 1);
  }

  double _yForValue(Rect chartRect, double value, double yMax) {
    return chartRect.bottom - chartRect.height * (value / yMax);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
    TextAlign textAlign, {
    bool anchorRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = anchorRight
        ? offset.dx - painter.width
        : offset.dx - painter.width / 2;
    painter.paint(canvas, Offset(dx, offset.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DailyCardioDistanceChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _CardioDistancePoint {
  _CardioDistancePoint({required this.date});

  final DateTime date;
  double runningKm = 0;
  double walkingKm = 0;
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
