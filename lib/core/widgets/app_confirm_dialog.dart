import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.confirmIcon,
    this.confirmBackgroundColor = AppColors.brandPrimary,
    this.confirmForegroundColor = AppColors.onBrandPrimary,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final IconData? confirmIcon;
  final Color confirmBackgroundColor;
  final Color confirmForegroundColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 132),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    Text(message, style: AppTextStyles.body),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox.expand(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.background,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          side: BorderSide.none,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(cancelLabel),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox.expand(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: confirmBackgroundColor,
                          foregroundColor: confirmForegroundColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          side: BorderSide.none,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: _DialogButtonLabel(
                          label: confirmLabel,
                          icon: confirmIcon,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButtonLabel extends StatelessWidget {
  const _DialogButtonLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }
}
