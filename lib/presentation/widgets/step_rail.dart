import 'package:flutter/material.dart';
import 'package:ru_passport/domain/pipeline_step.dart';
import 'package:ru_passport/presentation/theme/tokens.dart';

class StepRail extends StatelessWidget {
  const StepRail({
    super.key,
    required this.current,
    required this.canSelect,
    required this.isComplete,
    required this.onSelect,
  });

  final PipelineStep current;
  final bool Function(PipelineStep step) canSelect;
  final bool Function(PipelineStep step) isComplete;
  final ValueChanged<PipelineStep> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < PipelineStep.values.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 18),
                color: AppColors.glassStroke,
              ),
            ),
          _StepDot(
            step: PipelineStep.values[i],
            current: current,
            enabled: canSelect(PipelineStep.values[i]),
            complete: isComplete(PipelineStep.values[i]),
            onSelect: onSelect,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.current,
    required this.enabled,
    required this.complete,
    required this.onSelect,
  });

  final PipelineStep step;
  final PipelineStep current;
  final bool enabled;
  final bool complete;
  final ValueChanged<PipelineStep> onSelect;

  @override
  Widget build(BuildContext context) {
    final isCurrent = step == current;
    final color = step.isPlaceholder
        ? AppColors.muted
        : isCurrent
        ? AppColors.accent
        : complete
        ? AppColors.success
        : enabled
        ? AppColors.text
        : AppColors.muted;
    return InkWell(
      key: Key('pipeline-step-${step.name}'),
      onTap: enabled ? () => onSelect(step) : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isCurrent ? AppColors.accent : color.withValues(alpha: 0.16),
              foregroundColor: isCurrent ? Colors.white : color,
              child: step.isPlaceholder
                  ? const Icon(Icons.lock_outline, size: 14)
                  : Text(
                      '${step.index + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 92,
              child: Text(
                step.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (step.isPlaceholder)
              const Text(
                'скоро',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
