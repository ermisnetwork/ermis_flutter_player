import 'package:ermis_stream_player/src/api/models/response/ermis_stream_info.dart';

import 'api/ermis_stream_api.dart';
import 'api/models/request/ermis_stream_list_conditions.dart';
import 'api/models/request/ermis_stream_list_query.dart';
import 'api/models/request/ermis_stream_update_request.dart';
import 'api/models/response/ermis_stream_list_response.dart';
import 'broadcaster/ermis_broadcaster_controller.dart';
import 'broadcaster/ermis_broadcaster_controller_factory.dart';
import 'config/ermis_stream_config.dart';
import 'viewer/ermis_viewer_controller.dart';

class ErmisStreamPlayer {
  final ErmisStreamApi _api;
  final ErmisStreamConfig config;
  late final ErmisBroadcasterControllerFactory broadcasterFactory;

  ErmisStreamPlayer({this.config = const ErmisStreamConfig()})
    : _api = ErmisStreamApi(config: config) {
    broadcasterFactory = ErmisBroadcasterControllerFactory(
      config: config,
      api: _api,
    );
  }

  ErmisViewerController viewer() {
    return ErmisViewerController(config: config);
  }

  ErmisBroadcasterController broadcaster() {
    return broadcasterFactory.create();
  }

  Future<ErmisStreamInfo> createStream({required String streamName}) {
    return _api.createStream(streamName: streamName);
  }

  Future<ErmisStreamListResponse> listStreams({
    ErmisStreamListQuery? query,
    ErmisStreamListConditions? conditions,
  }) {
    return _api.listStreams(query: query, conditions: conditions);
  }

  Future<ErmisStreamInfo> updateStream({
    required String streamId,
    required ErmisStreamUpdateRequest request,
  }) {
    return _api.updateStream(streamId: streamId, request: request);
  }
}
