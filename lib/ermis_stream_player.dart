import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErmisStreamPlayerSDK {
  static const MethodChannel _channel = MethodChannel('fmp4_stream_player');

  static Future<bool> startStreaming({
    required String streamId,
    required String token,
  }) async {
    try {
      final result = await _channel.invokeMethod('startStreaming', {
        'streamId': streamId,
        'token': token,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Failed to start streaming: ${e.message}');
      return false;
    }
  }

  static Future<bool> stopStreaming() async {
    try {
      final result = await _channel.invokeMethod('stopStreaming');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Failed to start streaming: ${e.message}');
      return false;
    }
  }
}