import 'package:ermis_stream_player/src/api/models/response/ermis_stream_info.dart';

import 'api/ermis_stream_api.dart';
import 'api/models/request/ermis_stream_list_conditions.dart';
import 'api/models/request/ermis_stream_list_query.dart';
import 'api/models/request/ermis_stream_update_request.dart';
import 'api/models/response/ermis_stream_list_response.dart';
import 'broadcaster/ermis_broadcaster_controller.dart';
import 'config/ermis_stream_config.dart';
import 'viewer/ermis_viewer_controller.dart';

class ErmisStreamPlayer {
  final ErmisStreamApi _api;
  final ErmisStreamConfig config;

  ErmisStreamPlayer({this.config = const ErmisStreamConfig()})
    : _api = ErmisStreamApi(config: config);

  ErmisViewerController viewer() {
    return ErmisViewerController(config: config);
  }

  ErmisBroadcasterController broadcaster() {
    return ErmisBroadcasterController(config: config);
  }

  Future<ErmisStreamInfo> createStream({
    required String streamName,
    String? authToken,
    Uri? baseUrl,
  }) {
    return _api.createStream(
      streamName: streamName,
      authToken: authToken,
      baseUrl: baseUrl,
    );
  }

  Future<ErmisStreamListResponse> listStreams({
    String? authToken,
    ErmisStreamListQuery? query,
    ErmisStreamListConditions? conditions,
    Uri? baseUrl,
  }) {
    return _api.listStreams(
      authToken: authToken,
      query: query,
      conditions: conditions,
      baseUrl: baseUrl,
    );
  }

  Future<ErmisStreamInfo> updateStream({
    required String streamId,
    required ErmisStreamUpdateRequest request,
    String? authToken,
    Uri? baseUrl,
  }) {
    return _api.updateStream(
      streamId: streamId,
      request: request,
      authToken: authToken,
      baseUrl: baseUrl,
    );
  }
}
