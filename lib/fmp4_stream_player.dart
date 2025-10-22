
import 'package:flutter/services.dart';

import 'fmp4_stream_player_platform_interface.dart';

class Fmp4StreamPlayer {
  Future<String?> getPlatformVersion() {
    return Fmp4StreamPlayerPlatform.instance.getPlatformVersion();
  }

  static const _channel = MethodChannel("fmp4_stream_player");

  static Future<void> startStreaming(String url) async {
    await _channel.invokeMethod("startStreaming", {"url": url});
  }

  static Future<void> stop() async {
    await _channel.invokeMethod("stop");
  }
}
