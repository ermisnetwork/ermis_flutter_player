class ErmisStreamUpdateRequest {
  const ErmisStreamUpdateRequest({
    this.streamName,
    this.streamMethod,
    this.isLive,
    this.streamKey,
  });

  final String? streamName;
  final String? streamMethod;
  final bool? isLive;
  final String? streamKey;

  bool get hasData =>
      streamName != null ||
      streamMethod != null ||
      isLive != null ||
      streamKey != null;

  Map<String, dynamic> toJson() {
    return {
      if (streamName != null) 'stream_name': streamName,
      if (streamMethod != null) 'stream_method': streamMethod,
      if (isLive != null) 'is_live': isLive,
      if (streamKey != null) 'stream_key': streamKey,
    };
  }
}
