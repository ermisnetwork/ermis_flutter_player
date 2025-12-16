# Ermis Stream Flutter Player

Flutter plugin giúp xây dựng ứng dụng livestream với hệ sinh thái Ermis Streaming. SDK cung cấp đầy đủ controller + widget để:

- Xem stream (FMP4/WebSocket) với player native (Android dùng ExoPlayer, iOS dùng AVPlayer).
- Phát stream RTMP trực tiếp bằng camera thiết bị (dựa trên `rtmp_broadcaster`).
- Quản lý vòng đời, đổi camera, bật/tắt âm thanh và nhận trạng thái từ controller.

---

## Tính năng chính

- **Viewer**
  - `ErmisViewerController` điều khiển start/stop stream qua `MethodChannel`.
  - `ErmisStreamPlayerView` hiển thị PlatformView native được plugin đăng ký.
- **Broadcaster**
  - `ErmisBroadcasterController` bao bọc camera + RTMP streaming, tự quản lý wakelock/lifecycle.
  - `ErmisBroadcasterPreview` dựng preview camera + placeholder trạng thái.
- **Entrypoint**
  - `ErmisStreamPlayer` giúp bạn khởi tạo controller thông qua một cấu hình chung (`ErmisStreamConfig`).
- Chạy được trên Android 5.0+ và iOS 13+ (khuyến nghị), có sẵn project ví dụ trong thư mục `example/`.

---

## Cài đặt

Thêm vào `pubspec.yaml` của app:

```yaml
dependencies:
  ermis_stream_player:
    git:
      url: https://github.com/ermisnetwork/ermis_flutter_player.git
      ref: main
```

Sau đó chạy:

```sh
flutter pub get
```

Import SDK:

```dart
import 'package:ermis_stream_player/ermis_stream_player.dart';
```

---

## Cấu hình chung (tuỳ chọn)

```dart
final ermis = ErmisStreamPlayer(
  config: ErmisStreamConfig(
    apiBaseUrl: Uri.parse('https://api.your-domain.com'),
    timeout: const Duration(seconds: 30),
    logger: (msg) => debugPrint('[Ermis] $msg'),
  ),
);
```

`ErmisStreamConfig` chỉ lưu thông tin để dùng trong tương lai; hiện tại controller chưa gọi network từ config nhưng bạn có thể truyền trước để đảm bảo tương thích khi SDK mở rộng.

---

## API REST: tạo stream mới

SDK cung cấp tiện ích gọi API quản lý stream (hiện hỗ trợ tạo stream). Bạn cần cấu hình `apiBaseUrl` trỏ tới gateway, ví dụ:

```dart
final ermis = ErmisStreamPlayer(
  config: ErmisStreamConfig(
    apiBaseUrl: Uri.parse('https://daibo.ermis.network:9999'),
  ),
);

final streamInfo = await ermis.createStream(
  streamName: 'tudt01',
  authToken: jwtToken,
);

print('Stream ID: ${streamInfo.streamId}');
print('Watch link: ${streamInfo.link}');
```

- Nếu API trả JSON `{ "error_code": 401, "message": "Unauthorized" }`, SDK sẽ ném `ErmisStreamApiException`.
- Bạn có thể override `baseUrl` ngay khi gọi `createStream` nếu cần trỏ tới endpoint khác.
- `ErmisStreamInfo` chứa các trường `streamId`, `streamName`, `link`, `isLive`, `createdAt`, v.v… để bạn hiển thị trong UI.
+ Để lấy danh sách stream, gọi:
```dart
final streams = await ermis.listStreams(
  authToken: jwtToken,
  query: const ErmisStreamListQuery(page: 1, perPage: 20),
);
print('Total: ${streams.total}, first stream = ${streams.data.first.streamName}');
```

---

## Viewer: xem stream FMP4

```dart
final viewer = ErmisViewerController();

Future<void> start() async {
  await viewer.start(
    streamId: 'your_stream_id',
    token: 'secure_token',
  );
}

Future<void> stop() => viewer.stop();

@override
void dispose() {
  unawaited(viewer.dispose());
  super.dispose();
}
```

Trong widget tree, render player:

```dart
const ErmisStreamPlayerView();
```

> Lưu ý: controller tự quản lý `MethodChannel`. Không in log token ra console để tránh lộ thông tin nhạy cảm.

### Lấy số người đang xem (viewer count)

Từ phiên bản hiện tại, native plugin phát ra các sự kiện qua `EventChannel`. Bạn có thể lắng nghe stream bằng thuộc tính `controller.events`:

```dart
late final StreamSubscription<ErmisStreamEvent> _sub;

@override
void initState() {
  super.initState();
  _sub = viewer.events.listen((event) {
    if (event.type == 'TotalViewerCount') {
      setState(() {
        currentViewers = event.totalViewers ?? 0;
      });
    }
  });
}

@override
void dispose() {
  _sub.cancel();
  unawaited(viewer.dispose());
  super.dispose();
}
```

---

## Broadcaster: phát stream RTMP

```dart
final broadcaster = ErmisBroadcasterController();
late final List<CameraDescription> cameras;

@override
void initState() {
  super.initState();
  _init();
}

Future<void> _init() async {
  cameras = await availableCameras();
  await broadcaster.init(cameras: cameras);
}

Future<void> startBroadcast() async {
  await broadcaster.start(
    ingestUrl: 'rtmps://streaming.ermis.network:1939/Ermis-streaming',
    streamKey: 'stream-key',
  );
}

Future<void> stopBroadcast() => broadcaster.stop();

Future<void> toggleAudio(bool enabled) => broadcaster.setAudioEnabled(enabled);

@override
void dispose() {
  unawaited(broadcaster.dispose());
  super.dispose();
}
```

Preview trong UI:

```dart
ErmisBroadcasterPreview(controller: broadcaster);
```

Controller sẽ:

- Tự động enable wakelock khi đang phát, tắt khi dừng/huỷ.
- Xử lý `WidgetsBindingObserver` để pause/resume khi app vào background.
- Cho phép chuyển camera (`switchCamera`) và đọc lỗi cuối (`lastError`).

---

## API phụ trợ

- **ErmisStreamPlayerSDK.joinStream / leaveStream**: API cũ dạng static, vẫn giữ để tương thích (nếu chưa muốn dùng controller).
- **availableCameras / CameraDescription / CameraException**: được export lại từ plugin để ví dụ có thể lấy danh sách camera mà không import trực tiếp `rtmp_broadcaster`.

---

## Ví dụ

Chạy app mẫu:

```sh
cd example
flutter run
```

Tab “Viewer” sử dụng `ErmisViewerController` + `ErmisStreamPlayerView`.

Tab “Broadcaster” dùng `ErmisBroadcasterController` + `ErmisBroadcasterPreview`, kèm input ingest + stream key.

---

## Ghi chú

- SDK sử dụng WebSocket + piped streams để đưa dữ liệu FMP4 vào player.
- Start/Stop sẽ ném `CameraException` hoặc `PlatformException` khi có lỗi, hãy hiển thị thông báo phù hợp.
- Khi start streaming thất bại, controller sẽ cập nhật `state` và `lastError`.

---

## License

MIT License © 2025 Ermis Network
