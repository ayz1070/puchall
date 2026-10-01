import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

/// 지금 들어오는 수직 가속도를 기준치와 함께 보여 준다.
///
/// 반복은 아래(-기준치)로 내려갔다가 위(+기준치)로 올라와야 1회로 인식되므로,
/// 막대를 가운데(0)에서 양쪽으로 뻗게 그려 두 방향을 모두 확인할 수 있게 했다.
class VerticalAccelerationPanel extends StatelessWidget {
  const VerticalAccelerationPanel({
    super.key,
    required this.verticalAcceleration,
    required this.amplitudeThreshold,
    required this.repCount,
  });

  final double verticalAcceleration;
  final double amplitudeThreshold;
  final int repCount;

  @override
  Widget build(BuildContext context) {
    final safeThreshold = amplitudeThreshold <= 0 ? 1.0 : amplitudeThreshold;
    // 기준치가 막대 폭의 절반 위치에 오도록 정규화한다.
    final normalized = (verticalAcceleration / (safeThreshold * 2)).clamp(
      -1.0,
      1.0,
    );
    final reached = verticalAcceleration.abs() >= safeThreshold;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('수직 가속도', style: AppTextStyles.label),
              ),
              Text(
                '${verticalAcceleration.toStringAsFixed(2)} / ±${safeThreshold.toStringAsFixed(2)} m/s²',
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final halfWidth = constraints.maxWidth / 2;
                final barWidth = halfWidth * normalized.abs();

                return Stack(
                  children: [
                    Positioned.fill(
                      top: 4,
                      bottom: 4,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      bottom: 4,
                      left: normalized >= 0 ? halfWidth : halfWidth - barWidth,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: barWidth,
                        color: reached
                            ? const Color(0xFFA3E635)
                            : AppColors.brandPrimary,
                      ),
                    ),
                    // 가운데(0) 기준선
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: halfWidth - 1,
                      child: const SizedBox(
                        width: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // ± 기준치 표시
                    _ThresholdTick(left: halfWidth / 2),
                    _ThresholdTick(left: halfWidth + halfWidth / 2),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('아래', style: AppTextStyles.body.copyWith(fontSize: 11)),
              Text('위', style: AppTextStyles.body.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text('인식된 반복 $repCount회', style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _ThresholdTick extends StatelessWidget {
  const _ThresholdTick({required this.left});

  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: left,
      child: const SizedBox(
        width: 2,
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.border),
        ),
      ),
    );
  }
}
