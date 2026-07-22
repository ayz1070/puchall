import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../workout/domain/entities/exercise_type.dart';
import '../../../workout/domain/entities/workout_session.dart';
import '../../../workout/presentation/viewmodels/workout_history_view_model.dart';

class WorkoutRecordsPage extends ConsumerWidget {
  const WorkoutRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('운동 기록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            sessions.when(
              data: (items) => _WorkoutCalendar(sessions: items),
              loading: () =>
                  const Text('운동 기록을 불러오는 중', style: AppTextStyles.body),
              error: (error, stackTrace) =>
                  const Text('운동 기록을 불러오지 못했습니다.', style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCalendar extends StatefulWidget {
  const _WorkoutCalendar({required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  State<_WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<_WorkoutCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _moveMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = _visibleMonth;
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
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 94,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmptyDays + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(month.year, month.month, dayNumber);
              return _CalendarDayCell(
                date: date,
                record: recordsByDate[_dateKey(date)] ?? const _DayRecord(),
                isToday: _isSameDate(date, now),
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
          );
          break;
        case ExerciseType.pullUp:
          records[key] = previous.copyWith(
            pullUpCount: previous.pullUpCount + session.count,
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
  });

  final DateTime date;
  final _DayRecord record;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isToday ? AppColors.surfaceHigh : AppColors.background,
        border: Border.all(
          color: isToday ? AppColors.textPrimary : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${date.day}', style: AppTextStyles.label),
            const Spacer(),
            if (record.hasRecord) ...[
              _RecordLine(
                label: '푸쉬업',
                count: record.pushUpCount,
                color: const Color(0xFFFACC15),
              ),
              const SizedBox(height: 3),
              _RecordLine(
                label: '풀업',
                count: record.pullUpCount,
                color: AppColors.danger,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 13,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '$label $count',
          maxLines: 1,
          style: AppTextStyles.body.copyWith(
            color: count > 0 ? color : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _DayRecord {
  const _DayRecord({this.pushUpCount = 0, this.pullUpCount = 0});

  final int pushUpCount;
  final int pullUpCount;

  bool get hasRecord => pushUpCount > 0 || pullUpCount > 0;

  _DayRecord copyWith({int? pushUpCount, int? pullUpCount}) {
    return _DayRecord(
      pushUpCount: pushUpCount ?? this.pushUpCount,
      pullUpCount: pullUpCount ?? this.pullUpCount,
    );
  }
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
