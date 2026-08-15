abstract interface class HgTelemetry {
  void log(String eventName, Map<String, Object?> props);
}

late HgTelemetry hgTelemetry;
