import '../api/ermis_stream_api.dart';
import '../config/ermis_stream_config.dart';
import 'ermis_broadcaster_controller.dart';

class ErmisBroadcasterControllerFactory {
  const ErmisBroadcasterControllerFactory({
    required this.config,
    required ErmisStreamApi api,
  }) : _api = api;

  final ErmisStreamConfig config;
  final ErmisStreamApi _api;

  ErmisBroadcasterController create() {
    return ErmisBroadcasterController(config: config, api: _api);
  }
}
