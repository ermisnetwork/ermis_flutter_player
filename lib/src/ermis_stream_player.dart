import 'broadcaster/ermis_broadcaster_controller.dart';
import 'config/ermis_stream_config.dart';
import 'viewer/ermis_viewer_controller.dart';

class ErmisStreamPlayer {
  final ErmisStreamConfig config;

  ErmisStreamPlayer({this.config = const ErmisStreamConfig()});

  ErmisViewerController viewer() {
    return ErmisViewerController(config: config);
  }

  ErmisBroadcasterController broadcaster() {
    return ErmisBroadcasterController(config: config);
  }
}
