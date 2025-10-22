import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fmp4_stream_player_platform_interface.dart';

/// An implementation of [Fmp4StreamPlayerPlatform] that uses method channels.
class MethodChannelFmp4StreamPlayer extends Fmp4StreamPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fmp4_stream_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
