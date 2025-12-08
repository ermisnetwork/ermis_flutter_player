Ermis Stream Flutter Player

Flutter plugin để phát trực tiếp video FMP4 qua WebSocket từ Ermis Streaming. Hỗ trợ Android (ExoPlayer) và iOS (AVPlayer).

Features:
- Phát video FMP4 trực tiếp từ WebSocket
- Hỗ trợ start/stop stream dễ dàng
- Callback báo lỗi khi stream không thành công
- Hỗ trợ Android (ExoPlayer) và iOS (AVPlayer)

Installation:

1. Thêm plugin vào pubspec.yaml
```
dependencies:
  ermis_stream_player:
    git:
      url: https://github.com/ermisnetwork/ermis_flutter_player.git
      ref: main
```
2. Chạy:
flutter pub get

Import SDK:
```import 'package:ermis_stream_flutter_player/ermis_stream_flutter_player.dart';```


Start Streaming:

```
bool isStreaming = false;

Future<void> startStream() async {
  final result = await ErmisStreamFlutterPlayer.startStreaming(
    streamId: "your_stream_id",
    token: "your_access_token",
  );

  if (result.success) {
    isStreaming = true;
    print("Streaming started!");
  } else {
    print("Failed to start streaming: ${result.message}");
  }
}

Stop Streaming:

Future<void> stopStream() async {
  await ErmisStreamFlutterPlayer.stopStreaming();
  isStreaming = false;
  print("Streaming stopped");
}
```

Notes:
- SDK sử dụng WebSocket + piped streams để đưa dữ liệu FMP4 vào player.
- Khi startStreaming thất bại, SDK sẽ trả callback với message lỗi.

License:
MIT License © 2025 Ermis Network



