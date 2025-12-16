class ErmisStreamListConditions {
  const ErmisStreamListConditions({
    this.streamName,
    this.isLive,
    this.isPublished,
  });

  final String? streamName;
  final bool? isLive;
  final bool? isPublished;

  Map<String, dynamic> toJson() {
    return {
      if (streamName != null) 'stream_name': streamName,
      if (isLive != null) 'is_live': isLive,
      if (isPublished != null) 'is_published': isPublished,
    };
  }
}
