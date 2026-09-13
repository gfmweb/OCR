class OcrServiceStatus {
  const OcrServiceStatus({
    required this.stage,
    required this.progress,
    required this.ready,
  });

  final String stage;
  final int progress;
  final bool ready;
}
