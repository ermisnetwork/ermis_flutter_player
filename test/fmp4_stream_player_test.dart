import 'package:flutter_test/flutter_test.dart';
import 'package:fmp4_stream_player/fmp4_stream_player.dart';
import 'package:fmp4_stream_player/fmp4_stream_player_platform_interface.dart';
import 'package:fmp4_stream_player/fmp4_stream_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFmp4StreamPlayerPlatform
    with MockPlatformInterfaceMixin
    implements Fmp4StreamPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final Fmp4StreamPlayerPlatform initialPlatform = Fmp4StreamPlayerPlatform.instance;

  test('$MethodChannelFmp4StreamPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFmp4StreamPlayer>());
  });

  test('getPlatformVersion', () async {
    Fmp4StreamPlayer fmp4StreamPlayerPlugin = Fmp4StreamPlayer();
    MockFmp4StreamPlayerPlatform fakePlatform = MockFmp4StreamPlayerPlatform();
    Fmp4StreamPlayerPlatform.instance = fakePlatform;

    expect(await fmp4StreamPlayerPlugin.getPlatformVersion(), '42');
  });
}
