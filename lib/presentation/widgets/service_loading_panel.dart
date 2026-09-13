import 'package:flutter/material.dart';
import 'package:ru_passport/core/constants.dart';
import 'package:ru_passport/presentation/theme/tokens.dart';
import 'package:ru_passport/presentation/widgets/glass_panel.dart';

class ServiceLoadingPanel extends StatelessWidget {
  const ServiceLoadingPanel({
    super.key,
    required this.progress,
    required this.stageLabel,
    this.errorText,
    this.onRetry,
  });

  final double? progress;
  final String stageLabel;
  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = errorText != null;
    return SizedBox.expand(
      child: GlassPanel(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppConstants.appIconAsset,
              width: 64,
              height: 64,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppConstants.appTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              failed ? errorText! : stageLabel,
              textAlign: TextAlign.center,
              style: TextStyle(color: failed ? AppColors.danger : AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 280,
              child: LinearProgressIndicator(value: failed ? null : progress),
            ),
            if (failed && onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
