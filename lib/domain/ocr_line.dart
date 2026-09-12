class OcrPoint {
  const OcrPoint(this.x, this.y);

  final double x;
  final double y;

  factory OcrPoint.fromJson(List<dynamic> raw) {
    return OcrPoint((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
  }
}

class OcrLine {
  const OcrLine({
    required this.text,
    required this.confidence,
    required this.bbox,
  });

  final String text;
  final double confidence;
  final List<OcrPoint> bbox;

  factory OcrLine.fromJson(Map<String, dynamic> json) {
    final rawBox = (json['bbox'] as List<dynamic>? ?? const [])
        .map((item) => OcrPoint.fromJson(item as List<dynamic>))
        .toList();
    return OcrLine(
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      bbox: rawBox,
    );
  }
}
