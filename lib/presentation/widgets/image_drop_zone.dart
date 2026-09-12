import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class ImageDropZone extends StatelessWidget {
  const ImageDropZone({
    super.key,
    required this.onPath,
    required this.onPickFile,
  });

  final ValueChanged<String> onPath;
  final VoidCallback onPickFile;

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
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0D7DE)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_outlined, size: 56, color: Color(0xFF57606A)),
            const SizedBox(height: 16),
            const Text(
              'Перетащите изображение паспорта',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('или выберите файл с диска'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Выбрать файл'),
            ),
          ],
        ),
      ),
    );
  }
}
