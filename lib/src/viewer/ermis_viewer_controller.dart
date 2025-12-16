import 'package:flutter/services.dart';

import '../config/ermis_stream_config.dart';

class ErmisViewerController {
  ErmisViewerController({ErmisStreamConfig? config})
    : config = config ?? const ErmisStreamConfig();

  static const MethodChannel _channel = MethodChannel('fmp4_stream_player');
  static const EventChannel _eventChannel = EventChannel(
    'fmp4_stream_player/events',
  );

  final ErmisStreamConfig config;
  bool _disposed = false;
  bool _isStreaming = false;
  Stream<ErmisStreamEvent>? _events;
  Stream<ErmisStreamEvent> get events =>
      _events ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
        final map = Map<dynamic, dynamic>.from(event as Map);
        return ErmisStreamEvent.fromMap(map);
      });

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

class ErmisStreamEvent {
  final String type;
  final String? streamId;
  final int? totalViewers;

  const ErmisStreamEvent({
    required this.type,
    this.streamId,
    this.totalViewers,
  });

  factory ErmisStreamEvent.fromMap(Map<dynamic, dynamic> map) {
    return ErmisStreamEvent(
      type: map['type']?.toString() ?? 'unknown',
      streamId: map['streamId'] as String? ?? map['stream_id'] as String? ?? '',
      totalViewers:
          (map['totalViewers'] ?? map['total_viewers']) is int
              ? (map['totalViewers'] ?? map['total_viewers']) as int
              : int.tryParse(
                (map['totalViewers'] ?? map['total_viewers'])?.toString() ?? '',
              ),
    );
  }
}
