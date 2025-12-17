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
    streamBaseUrl: Uri.parse('rtmps://streaming.your-domain.com:1935'),
    timeout: const Duration(seconds: 30),
    logger: (msg) => debugPrint('[Ermis] $msg'),
  ),
);
```

`ErmisStreamConfig` cung cấp chung base URL, timeout, logger và provider token cho mọi controller tạo ra từ `ErmisStreamPlayer`. `apiBaseUrl` được dùng cho các API create/list/update stream; `streamBaseUrl` + `app_name`/`stream_key` giúp broadcaster dựng ingest RTMP; `authTokenProvider` được truyền cho mọi request cần Bearer token. Bạn có thể set trước để controller hoạt động thống nhất trong suốt vòng đời app.

---

## API REST: tạo stream mới

SDK cung cấp tiện ích gọi API quản lý stream (hiện hỗ trợ tạo stream). Bạn cần cấu hình `apiBaseUrl` trỏ tới gateway, ví dụ:

```dart
final ermis = ErmisStreamPlayer(
  config: ErmisStreamConfig(
    apiBaseUrl: Uri.parse('https://daibo.ermis.network:9999'),
    authTokenProvider: () async => jwtToken, // đăng ký 1 lần
  ),
);

final streamInfo = await ermis.createStream(
  streamName: 'tudt01',
);

print('Stream ID: ${streamInfo.streamId}');
print('Watch link: ${streamInfo.link}');
print('Stream key: ${streamInfo.streamKey}');
```

- Nếu API trả JSON `{ "error_code": 401, "message": "Unauthorized" }`, SDK sẽ ném `ErmisStreamApiException`.
- Bạn có thể override `baseUrl` ngay khi gọi `createStream` nếu cần trỏ tới endpoint khác.
- `ErmisStreamInfo` chứa các trường `streamId`, `streamName`, `link`, `isLive`, `createdAt`, v.v… để bạn hiển thị trong UI.
+ Để lấy danh sách stream, gọi:
```dart
final streams = await ermis.listStreams(
  query: const ErmisStreamListQuery(page: 1, perPage: 20),
);
print('Total: ${streams.total}, first stream = ${streams.data.first.streamName}');

// Update stream fields (all optional). Nếu stream đang live, chỉ nên set isLive.
await ermis.updateStream(
  streamId: streams.data.first.streamId,
  request: const ErmisStreamUpdateRequest(
    streamMethod: 'software',
    isLive: true,
  ),
);
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
  // streamInfo lấy từ API create/list stream.
  await broadcaster.start(streamInfo: streamInfo);
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

## Ví dụ (thư mục `example/`)

Project mẫu minh hoạ toàn bộ luồng làm việc của SDK:

1. `example/lib/main.dart` khởi tạo `ErmisStreamPlayer` với `ErmisStreamConfig` (API base + stream base + token) và truyền xuống các màn hình.
2. Tab “Settings” (`TokenPage`) cho phép nhập lại base URL/token; sau khi lưu, player sẽ được dựng lại với config mới.
3. Tab “Streams” (`StreamListPage`) gọi `player.listStreams`, hiển thị danh sách và cho phép tạo stream mới. Chọn một stream sẽ mở màn phát.
4. Màn “Broadcaster” (`BroadcastPage`) nhận `ErmisStreamInfo` và `player.broadcasterFactory`, tạo `ErmisBroadcasterController` thông qua factory rồi start/stop bằng `controller.start(streamInfo: ...)` và `controller.stop()`. Controller sẽ tự gọi API `updateStream` để xin stream key, xây ingest URL từ `streamBaseUrl/app_name/stream_key`, bật wakelock và đồng bộ trạng thái `is_live`.
5. Tab “Viewer” (`ViewerPage`) dùng `ErmisViewerController` + `ErmisStreamPlayerView` để xem stream theo `stream_id` + `token`.

Chạy app mẫu:

```sh
cd example
flutter run
```

Luồng sử dụng đề xuất:

1. Mở tab “Settings”, nhập `API base URL`, `Stream base URL (RTMP)` và Bearer token hợp lệ rồi lưu.
2. Sang tab “Streams”, nhấn “Load streams” hoặc “Create” để tạo stream mới. Chọn stream muốn phát → mở màn Broadcaster.
3. Ở màn Broadcaster, nhấn “Start broadcast” để bắt đầu đẩy video, “Stop” để dừng. Controller sẽ tự gọi API cập nhật trạng thái live nên không cần thao tác bổ sung.
4. Tab “Viewer” nhập `stream_id` + token để test playback (tùy backend yêu cầu thêm `token`).

---

## Ghi chú

- SDK sử dụng WebSocket + piped streams để đưa dữ liệu FMP4 vào player.
- Start/Stop sẽ ném `CameraException` hoặc `PlatformException` khi có lỗi, hãy hiển thị thông báo phù hợp.
- Khi start streaming thất bại, controller sẽ cập nhật `state` và `lastError`.

---

## License

MIT License © 2025 Ermis Network
