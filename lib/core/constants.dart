class AppConstants {
  static const String appTitle = 'Распознавание паспорта РФ';
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 8765;
  static const Duration serviceReadyTimeout = Duration(seconds: 180);
  static const Duration recognizeTimeout = Duration(seconds: 180);
  static const Duration healthPollInterval = Duration(milliseconds: 500);
}
