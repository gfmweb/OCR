import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ru_passport/domain/pipeline_step.dart';
import 'package:ru_passport/presentation/theme/tokens.dart';
import 'package:ru_passport/presentation/widgets/glass_panel.dart';

class SnapshotStrip extends StatelessWidget {
  const SnapshotStrip({
    super.key,
    required this.firstSpreadPath,
    required this.registrationPath,
    required this.currentStep,
    required this.onSelect,
    required this.canSelect,
  });

  final String? firstSpreadPath;
  final String? registrationPath;
  final PipelineStep currentStep;
  final ValueChanged<PipelineStep> onSelect;
  final bool Function(PipelineStep step) canSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SnapshotCard(
            slotKey: 'snapshot-firstSpread',
            label: 'Разворот',
            path: firstSpreadPath,
            selected: currentStep == PipelineStep.firstSpread,
            onTap: canSelect(PipelineStep.firstSpread)
                ? () => onSelect(PipelineStep.firstSpread)
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _SnapshotCard(
            slotKey: 'snapshot-registration',
            label: 'Регистрация',
            path: registrationPath,
            selected: currentStep == PipelineStep.registration,
            onTap: canSelect(PipelineStep.registration)
                ? () => onSelect(PipelineStep.registration)
                : null,
          ),
        ),
      ],
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.slotKey,
    required this.label,
    required this.path,
    required this.selected,
    required this.onTap,
  });

  final String slotKey;
  final String label;
  final String? path;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: Key(slotKey),
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.glassStroke,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 72,
                  height: 48,
                  child: path == null
                      ? const ColoredBox(
                          color: Color(0x33FFFFFF),
                          child: Icon(Icons.photo_outlined, size: 20, color: AppColors.muted),
                        )
                      : Image.file(
                          File(path!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0x33FFFFFF),
                            child: Icon(Icons.photo_outlined, size: 20, color: AppColors.muted),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.accent : AppColors.text,
                    ),
                  ),
                  Text(
                    path == null ? 'Нет снимка' : 'Снимок добавлен',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
