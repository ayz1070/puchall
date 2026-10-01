import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../../../workout/domain/entities/workout_session.dart';

class WorkoutCalendar extends StatefulWidget {
  const WorkoutCalendar({
    super.key,
    required this.sessions,
    this.visibleMonth,
    this.onMonthChanged,
  });

  final List<WorkoutSession> sessions;
  final DateTime? visibleMonth;
  final ValueChanged<DateTime>? onMonthChanged;

  @override
  State<WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _moveMonth(int offset) {
    final currentMonth = widget.visibleMonth ?? _visibleMonth;
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + offset);

    if (widget.onMonthChanged != null) {
      widget.onMonthChanged!(nextMonth);
      return;
    }

    setState(() {
      _visibleMonth = nextMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = widget.visibleMonth ?? _visibleMonth;
    final firstDay = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final daysInMonth = nextMonth.difference(firstDay).inDays;
    final leadingEmptyDays = firstDay.weekday % DateTime.daysPerWeek;
    final cellCount = leadingEmptyDays + daysInMonth;
    final rowCount = (cellCount / DateTime.daysPerWeek).ceil();
    final recordsByDate = _recordsByDate(widget.sessions);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 달',
              ),
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 달',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _WeekdayHeader(),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * DateTime.daysPerWeek,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: DateTime.daysPerWeek,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              mainAxisExtent: 92,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmptyDays + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(month.year, month.month, dayNumber);
              final record =
                  recordsByDate[_dateKey(date)] ?? const _DayRecord();
              return _CalendarDayCell(
                date: date,
                record: record,
                isToday: _isSameDate(date, now),
                onTap: () => _showDayRecordSheet(
                  context: context,
                  date: date,
                  record: record,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, _DayRecord> _recordsByDate(List<WorkoutSession> sessions) {
    final records = <String, _DayRecord>{};

    for (final session in sessions) {
      final key = session.dateKey;
      final previous = records[key] ?? const _DayRecord();
      switch (session.exerciseType) {
        case ExerciseType.pushUp:
          records[key] = previous.copyWith(
            pushUpCount: previous.pushUpCount + session.count,
            pushUpCaloriesKcal:
                previous.pushUpCaloriesKcal + session.caloriesKcal,
          );
          break;
        case ExerciseType.pullUp:
          records[key] = previous.copyWith(
            pullUpCount: previous.pullUpCount + session.count,
            pullUpCaloriesKcal:
                previous.pullUpCaloriesKcal + session.caloriesKcal,
          );
          break;
        case ExerciseType.running:
          records[key] = previous.copyWith(
            runningDistanceMeters:
                previous.runningDistanceMeters + session.distanceMeters,
            runningDurationSeconds:
                previous.runningDurationSeconds + session.durationSeconds,
            runningCaloriesKcal:
                previous.runningCaloriesKcal + session.caloriesKcal,
          );
          break;
        case ExerciseType.walking:
          records[key] = previous.copyWith(
            walkingDistanceMeters:
                previous.walkingDistanceMeters + session.distanceMeters,
            walkingDurationSeconds:
                previous.walkingDurationSeconds + session.durationSeconds,
            walkingCaloriesKcal:
                previous.walkingCaloriesKcal + session.caloriesKcal,
          );
          break;
      }
    }

    return records;
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void _showDayRecordSheet({
    required BuildContext context,
    required DateTime date,
    required _DayRecord record,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _DayRecordBottomSheet(date: date, record: record),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Row(
      children: [
        for (final weekday in weekdays)
          Expanded(
            child: Center(
              child: Text(
                weekday,
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.record,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final _DayRecord record;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isToday ? AppColors.surfaceHigh : AppColors.background,
            border: Border.all(
              color: isToday ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${date.day}', style: AppTextStyles.label),
                const SizedBox(height: 4),
                if (record.hasRecord) ...[
                  if (record.pushUpCount > 0)
                    _RecordLine(
                      label: '푸쉬업',
                      value: '${record.pushUpCount}',
                      color: const Color(0xFFFACC15),
                    ),
                  if (record.pullUpCount > 0)
                    _RecordLine(
                      label: '풀업',
                      value: '${record.pullUpCount}',
                      color: AppColors.danger,
                    ),
                  if (record.runningDistanceMeters > 0)
                    _RecordLine(
                      label: '런닝',
                      value: _formatCalendarDistance(
                        record.runningDistanceMeters,
                      ),
                      color: AppColors.brandPrimary,
                    ),
                  if (record.walkingDistanceMeters > 0)
                    _RecordLine(
                      label: '워킹',
                      value: _formatCalendarDistance(
                        record.walkingDistanceMeters,
                      ),
                      color: AppColors.textPrimary,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayRecordBottomSheet extends StatelessWidget {
  const _DayRecordBottomSheet({required this.date, required this.record});

  final DateTime date;
  final _DayRecord record;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(width: 40, height: 4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${date.year}년 ${date.month}월 ${date.day}일',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 16),
            _DayRecordDetailRow(
              label: '푸쉬업',
              value:
                  '${record.pushUpCount}개 · ${record.pushUpCaloriesKcal.round()} kcal',
              color: const Color(0xFFFACC15),
            ),
            const SizedBox(height: 10),
            _DayRecordDetailRow(
              label: '풀업',
              value:
                  '${record.pullUpCount}개 · ${record.pullUpCaloriesKcal.round()} kcal',
              color: AppColors.danger,
            ),
            const SizedBox(height: 10),
            _DayRecordDetailRow(
              label: '런닝',
              value:
                  '${_formatDistance(record.runningDistanceMeters)} · ${_formatDuration(record.runningDurationSeconds)} · ${record.runningCaloriesKcal.round()} kcal',
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: 10),
            _DayRecordDetailRow(
              label: '걷기',
              value:
                  '${_formatDistance(record.walkingDistanceMeters)} · ${_formatDuration(record.walkingDurationSeconds)} · ${record.walkingCaloriesKcal.round()} kcal',
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRecordDetailRow extends StatelessWidget {
  const _DayRecordDetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 8, height: 8),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppTextStyles.label)),
            Text(value, style: AppTextStyles.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 11,
      child: Text(
        '$label $value',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: AppTextStyles.body.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _DayRecord {
  const _DayRecord({
    this.pushUpCount = 0,
    this.pullUpCount = 0,
    this.pushUpCaloriesKcal = 0,
    this.pullUpCaloriesKcal = 0,
    this.runningDistanceMeters = 0,
    this.runningDurationSeconds = 0,
    this.runningCaloriesKcal = 0,
    this.walkingDistanceMeters = 0,
    this.walkingDurationSeconds = 0,
    this.walkingCaloriesKcal = 0,
  });

  final int pushUpCount;
  final int pullUpCount;
  final double pushUpCaloriesKcal;
  final double pullUpCaloriesKcal;
  final double runningDistanceMeters;
  final int runningDurationSeconds;
  final double runningCaloriesKcal;
  final double walkingDistanceMeters;
  final int walkingDurationSeconds;
  final double walkingCaloriesKcal;

  double get cardioDistanceMeters =>
      runningDistanceMeters + walkingDistanceMeters;
  bool get hasStrength => pushUpCount > 0 || pullUpCount > 0;
  bool get hasCardio => cardioDistanceMeters > 0;
  bool get hasRecord => hasStrength || hasCardio;

  _DayRecord copyWith({
    int? pushUpCount,
    int? pullUpCount,
    double? pushUpCaloriesKcal,
    double? pullUpCaloriesKcal,
    double? runningDistanceMeters,
    int? runningDurationSeconds,
    double? runningCaloriesKcal,
    double? walkingDistanceMeters,
    int? walkingDurationSeconds,
    double? walkingCaloriesKcal,
  }) {
    return _DayRecord(
      pushUpCount: pushUpCount ?? this.pushUpCount,
      pullUpCount: pullUpCount ?? this.pullUpCount,
      pushUpCaloriesKcal: pushUpCaloriesKcal ?? this.pushUpCaloriesKcal,
      pullUpCaloriesKcal: pullUpCaloriesKcal ?? this.pullUpCaloriesKcal,
      runningDistanceMeters:
          runningDistanceMeters ?? this.runningDistanceMeters,
      runningDurationSeconds:
          runningDurationSeconds ?? this.runningDurationSeconds,
      runningCaloriesKcal: runningCaloriesKcal ?? this.runningCaloriesKcal,
      walkingDistanceMeters:
          walkingDistanceMeters ?? this.walkingDistanceMeters,
      walkingDurationSeconds:
          walkingDurationSeconds ?? this.walkingDurationSeconds,
      walkingCaloriesKcal: walkingCaloriesKcal ?? this.walkingCaloriesKcal,
    );
  }
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(2)}km';
}

String _formatCalendarDistance(double meters) {
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  if (duration.inHours <= 0) return '$minutes:$remainingSeconds';
  return '${duration.inHours}:$minutes:$remainingSeconds';
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
