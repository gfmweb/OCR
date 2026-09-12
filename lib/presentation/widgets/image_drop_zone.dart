import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:ru_passport/presentation/theme/tokens.dart';
import 'package:ru_passport/presentation/widgets/glass_panel.dart';

class ImageDropZone extends StatelessWidget {
  const ImageDropZone({
    super.key,
    required this.onPath,
    required this.onPickFile,
    this.title = 'Перетащите изображение паспорта',
    this.subtitle = 'или выберите файл с диска',
  });

  final ValueChanged<String> onPath;
  final VoidCallback onPickFile;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) {
        if (details.files.isEmpty) {
          return;
        }
        final path = details.files.first.path;
        if (path.isNotEmpty) {
          onPath(path);
        }
      },
      child: SizedBox.expand(
        child: GlassPanel(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_outlined, size: 48, color: AppColors.muted),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: onPickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать файл'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
