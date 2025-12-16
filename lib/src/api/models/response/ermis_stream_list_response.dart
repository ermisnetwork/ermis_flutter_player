import 'package:ermis_stream_player/src/api/models/response/ermis_stream_info.dart';

class ErmisStreamListResponse {
  const ErmisStreamListResponse({
    required this.data,
    required this.page,
    required this.perPage,
    required this.total,
    this.extra,
  });

  final List<ErmisStreamInfo> data;
  final int page;
  final int perPage;
  final int total;
  final ErmisStreamListExtra? extra;

  factory ErmisStreamListResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['data'] as List<dynamic>? ?? const [];
    return ErmisStreamListResponse(
      data:
          list
              .map(
                (item) =>
                    ErmisStreamInfo.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      page: json['page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? list.length,
      total: json['total'] as int? ?? list.length,
      extra:
          json['extra'] is Map<String, dynamic>
              ? ErmisStreamListExtra.fromJson(
                json['extra'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}

class ErmisStreamListExtra {
  const ErmisStreamListExtra({
    required this.totalActive,
    required this.totalStreams,
  });

  final int totalActive;
  final int totalStreams;

  factory ErmisStreamListExtra.fromJson(Map<String, dynamic> json) {
    return ErmisStreamListExtra(
      totalActive: json['total_active'] as int? ?? 0,
      totalStreams: json['total_streams'] as int? ?? 0,
    );
  }
}
