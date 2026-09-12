import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ru_passport/domain/ocr_line.dart';

class OcrOverlay extends StatelessWidget {
  const OcrOverlay({
    super.key,
    required this.imageFile,
    required this.imageSize,
    required this.lines,
    this.fieldRegions = const [],
    this.highlightRegion,
    this.showRawLines = false,
    this.rotationDegrees = 0,
  });

  final File imageFile;
  final Size imageSize;
  final List<OcrLine> lines;
  final List<List<OcrPoint>> fieldRegions;
  final List<OcrPoint>? highlightRegion;
  final bool showRawLines;
  final int rotationDegrees;

  @override
  Widget build(BuildContext context) {
    final turns = ((rotationDegrees ~/ 90) % 4 + 4) % 4;
    final stack = SizedBox(
      width: imageSize.width,
      height: imageSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(imageFile, fit: BoxFit.fill),
          CustomPaint(
            painter: _OcrBoxesPainter(
              imageSize: imageSize,
              lines: lines,
              fieldRegions: fieldRegions,
              highlightRegion: highlightRegion,
              showRawLines: showRawLines,
            ),
          ),
        ],
      ),
    );
    return FittedBox(
      fit: BoxFit.contain,
      child: turns == 0 ? stack : RotatedBox(quarterTurns: turns, child: stack),
    );
  }
}

class _OcrBoxesPainter extends CustomPainter {
  _OcrBoxesPainter({
    required this.imageSize,
    required this.lines,
    required this.fieldRegions,
    required this.highlightRegion,
    required this.showRawLines,
  });

  final Size imageSize;
  final List<OcrLine> lines;
  final List<List<OcrPoint>> fieldRegions;
  final List<OcrPoint>? highlightRegion;
  final bool showRawLines;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) {
      return;
    }
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    if (showRawLines) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x661F6FEB);
      for (final line in lines) {
        _drawRegion(canvas, line.bbox, scaleX, scaleY, paint);
      }
    }
    final fieldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x99228A4C);
    for (final region in fieldRegions) {
      _drawRegion(canvas, region, scaleX, scaleY, fieldPaint);
    }
    final highlight = highlightRegion;
    if (highlight != null && highlight.length >= 4) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFE36209);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0x33E36209);
      final path = _regionPath(highlight, scaleX, scaleY);
      if (path != null) {
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      }
    }
  }

  void _drawRegion(
    Canvas canvas,
    List<OcrPoint> region,
    double scaleX,
    double scaleY,
    Paint paint,
  ) {
    final path = _regionPath(region, scaleX, scaleY);
    if (path != null) {
      canvas.drawPath(path, paint);
    }
  }

  Path? _regionPath(List<OcrPoint> region, double scaleX, double scaleY) {
    if (region.length < 4) {
      return null;
    }
    return Path()
      ..addPolygon([
        for (final point in region) Offset(point.x * scaleX, point.y * scaleY),
      ], true);
  }

  @override
  bool shouldRepaint(covariant _OcrBoxesPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.fieldRegions != fieldRegions ||
        oldDelegate.highlightRegion != highlightRegion ||
        oldDelegate.showRawLines != showRawLines;
  }
}
