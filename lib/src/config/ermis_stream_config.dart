typedef ErmisLogger = void Function(String message);

class ErmisStreamConfig {
  final Uri? apiBaseUrl;
  final Map<String, String>? defaultHeaders;
  final Duration? timeout;
  final ErmisLogger? logger;

  const ErmisStreamConfig({
    this.apiBaseUrl,
    this.defaultHeaders,
    this.timeout,
    this.logger,
  });
}
