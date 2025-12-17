import 'dart:async';

typedef ErmisLogger = void Function(String message);
typedef ErmisAuthTokenProvider = FutureOr<String> Function();

class ErmisStreamConfig {
  final Uri? apiBaseUrl;
  final Uri? streamBaseUrl;
  final Map<String, String>? defaultHeaders;
  final Duration? timeout;
  final ErmisLogger? logger;
  final ErmisAuthTokenProvider? authTokenProvider;
  final Map<String, dynamic>? partnerInfo;

  const ErmisStreamConfig({
    this.apiBaseUrl,
    this.streamBaseUrl,
    this.defaultHeaders,
    this.timeout,
    this.logger,
    this.authTokenProvider,
    this.partnerInfo,
  });
}
