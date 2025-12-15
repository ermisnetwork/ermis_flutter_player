import 'package:flutter/services.dart';

import '../config/ermis_stream_config.dart';

class ErmisViewerController {
  ErmisViewerController({ErmisStreamConfig? config})
    : config = config ?? const ErmisStreamConfig();

  static const MethodChannel _channel = MethodChannel('fmp4_stream_player');

  final ErmisStreamConfig config;
  bool _disposed = false;
  bool _isStreaming = false;

  Future<void> start({required String streamId, required String token}) async {
    if (_disposed) {
      throw StateError(
        'ErmisViewerController has been disposed. Create a new instance.',
      );
    }
    if (_isStreaming) {
      return;
    }

    await _channel.invokeMethod('startStreaming', {
      'streamId': streamId,
      'token': token,
    });
    _isStreaming = true;
  }

  Future<void> stop() async {
    if (_disposed || !_isStreaming) {
      return;
    }

    try {
      await _channel.invokeMethod('stopStreaming');
    } finally {
      _isStreaming = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    try {
      await stop();
    } finally {
      _disposed = true;
    }
  }
}
