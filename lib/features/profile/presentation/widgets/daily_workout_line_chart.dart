import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../../../workout/domain/entities/workout_session.dart';

class DailyWorkoutLineChart extends StatelessWidget {
  const DailyWorkoutLineChart({
    super.key,
    required this.sessions,
    this.visibleMonth,
    this.onTap,
  });

  final List<WorkoutSession> sessions;
  final DateTime? visibleMonth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final month = visibleMonth ?? _currentMonth();
    final points = _buildPoints(sessions, month);
    final hasRecords = points.any(
      (point) => point.pushUpCount > 0 || point.pullUpCount > 0,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${month.year}년 ${month.month}월 데일리',
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasRecords) ...[
              const _ChartLegend(),
              const SizedBox(height: 14),
              SizedBox(
                height: 210,
                child: CustomPaint(
                  painter: _DailyWorkoutLineChartPainter(points: points),
                  child: const SizedBox.expand(),
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text('아직 운동 기록이 없습니다.', style: AppTextStyles.body),
              ),
          ],
        ),
      ),
    );
  }

  List<_DailyWorkoutPoint> _buildPoints(
    List<WorkoutSession> sessions,
    DateTime month,
  ) {
    final firstDay = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final daysInMonth = nextMonth.difference(firstDay).inDays;
    final countsByDate = <String, _ExerciseCounts>{};

    for (var i = 0; i < daysInMonth; i++) {
      final date = firstDay.add(Duration(days: i));
      countsByDate[_dateKey(date)] = _ExerciseCounts(date: date);
    }

    for (final session in sessions) {
      final date = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      final key = _dateKey(date);
      final counts = countsByDate[key];
      if (counts == null) continue;

      switch (session.exerciseType) {
        case ExerciseType.pushUp:
          counts.pushUpCount += session.count;
          break;
        case ExerciseType.pullUp:
          counts.pullUpCount += session.count;
          break;
        case ExerciseType.running:
        case ExerciseType.walking:
          break;
      }
    }

    return countsByDate.values
        .map(
          (counts) => _DailyWorkoutPoint(
            date: counts.date,
            pushUpCount: counts.pushUpCount,
            pullUpCount: counts.pullUpCount,
          ),
        )
        .toList();
  }

  DateTime _currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendItem(label: 'PUSH UP', color: Color(0xFFFACC15)),
        SizedBox(width: 14),
        _LegendItem(label: 'PULL UP', color: AppColors.danger),
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

class _DailyWorkoutLineChartPainter extends CustomPainter {
  const _DailyWorkoutLineChartPainter({required this.points});

  final List<_DailyWorkoutPoint> points;

  static const _pushUpColor = Color(0xFFFACC15);
  static const _pullUpColor = AppColors.danger;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPadding = 34.0;
    const rightPadding = 8.0;
    const topPadding = 10.0;
    const bottomPadding = 30.0;
    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );
    final maxCount = points.fold<int>(
      0,
      (maxValue, point) =>
          math.max(maxValue, math.max(point.pushUpCount, point.pullUpCount)),
    );
    final yMax = _roundedMax(maxCount);

    _drawGrid(canvas, chartRect, yMax);
    _drawXAxisLabels(canvas, chartRect);
    _drawLine(
      canvas,
      chartRect,
      yMax,
      points.map((point) => point.pushUpCount).toList(),
      _pushUpColor,
    );
    _drawLine(
      canvas,
      chartRect,
      yMax,
      points.map((point) => point.pullUpCount).toList(),
      _pullUpColor,
    );
  }

  int _roundedMax(int maxCount) {
    if (maxCount <= 0) return 10;
    if (maxCount <= 10) return 10;
    return ((maxCount / 10).ceil()) * 10;
  }

  void _drawGrid(Canvas canvas, Rect chartRect, int yMax) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final labelStyle = AppTextStyles.body.copyWith(fontSize: 10);

    for (var i = 0; i <= 2; i++) {
      final value = (yMax / 2 * (2 - i)).round();
      final y = chartRect.top + chartRect.height / 2 * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        '$value',
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

      final x = _xForIndex(chartRect, i);
      _drawText(
        canvas,
        '${date.day}',
        Offset(x, chartRect.bottom + 12),
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
    int yMax,
    List<int> values,
    Color color,
  ) {
    if (values.isEmpty) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final offsets = [
      for (var i = 0; i < values.length; i++)
        Offset(
          _xForIndex(chartRect, i),
          _yForValue(chartRect, values[i], yMax),
        ),
    ];
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);

    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }

    canvas.drawPath(path, linePaint);
  }

  double _xForIndex(Rect chartRect, int index) {
    if (points.length == 1) return chartRect.left;
    return chartRect.left + chartRect.width * index / (points.length - 1);
  }

  double _yForValue(Rect chartRect, int value, int yMax) {
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
  bool shouldRepaint(covariant _DailyWorkoutLineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _DailyWorkoutPoint {
  const _DailyWorkoutPoint({
    required this.date,
    required this.pushUpCount,
    required this.pullUpCount,
  });

  final DateTime date;
  final int pushUpCount;
  final int pullUpCount;
}

class _ExerciseCounts {
  _ExerciseCounts({required this.date});

  final DateTime date;
  int pushUpCount = 0;
  int pullUpCount = 0;
}
