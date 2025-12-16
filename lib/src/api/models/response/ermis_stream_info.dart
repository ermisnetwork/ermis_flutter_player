class ErmisStreamInfo {
  const ErmisStreamInfo({
    required this.streamId,
    required this.userId,
    required this.streamName,
    required this.streamMethod,
    required this.link,
    required this.appName,
    required this.createdAt,
    required this.updatedAt,
    required this.isLive,
    required this.isPublished,
  });

  final String streamId;
  final String userId;
  final String streamName;
  final String streamMethod;
  final String link;
  final String appName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isLive;
  final bool isPublished;

  factory ErmisStreamInfo.fromJson(Map<String, dynamic> json) {
    return ErmisStreamInfo(
      streamId: json['stream_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      streamName: json['stream_name']?.toString() ?? '',
      streamMethod: json['stream_method']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      appName: json['app_name']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      isLive: json['is_live'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
