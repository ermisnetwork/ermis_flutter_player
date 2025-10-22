import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fmp4_stream_player_method_channel.dart';

abstract class Fmp4StreamPlayerPlatform extends PlatformInterface {
  /// Constructs a Fmp4StreamPlayerPlatform.
  Fmp4StreamPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static Fmp4StreamPlayerPlatform _instance = MethodChannelFmp4StreamPlayer();

  /// The default instance of [Fmp4StreamPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFmp4StreamPlayer].
  static Fmp4StreamPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [Fmp4StreamPlayerPlatform] when
  /// they register themselves.
  static set instance(Fmp4StreamPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
