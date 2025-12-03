Ermis Stream Flutter Player

Flutter plugin để phát trực tiếp video FMP4 qua WebSocket từ Ermis Streaming. Hỗ trợ Android (ExoPlayer) và iOS (AVPlayer).

Features:
- Phát video FMP4 trực tiếp từ WebSocket
- Hỗ trợ start/stop stream dễ dàng
- Callback báo lỗi khi stream không thành công
- Hỗ trợ Android (ExoPlayer) và iOS (AVPlayer)

Installation:

1. Thêm plugin vào pubspec.yaml

dependencies:
  ermis_stream_flutter_player:
    git:
      url: https://github.com/ermisnetwork/ermis_flutter_player.git
      ref: main

2. Chạy:
flutter pub get

Usage:
import 'dart:io';

import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isStreaming = false;
  String _status = 'Ready';
  ProcessResult? _lastResult;

  Future<void> _startStream() async {
    setState(() {
      _status = 'Connecting...';
    });

    final success = await ErmisStreamPlayerSDK.startStreaming(
      streamId: "",
      token:
      "",
    );

    setState(() {
      _isStreaming = success;
      _status = success ? 'Streaming...' : 'Failed to connect';
    });
  }

  Future<void> _stopStream() async {
    final success = await ErmisStreamPlayerSDK.stopStreaming();
    setState(() {
      _isStreaming = false;
      _status = success ? 'Stopped' : 'Failed to stop';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Video view
            Expanded(
              child: Container(
                color: Colors.white,
                child: const Fmp4StreamPlayerView(),
              ),
            ),

            // Status bar
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: $_status',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isStreaming ? null : _startStream,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isStreaming ? _stopStream : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Fmp4StreamPlayerView extends StatelessWidget {
  const Fmp4StreamPlayerView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'fmp4_stream_player_view',
        layoutDirection: TextDirection.ltr,
        creationParams: null,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'fmp4_stream_player_view',
        layoutDirection: TextDirection.ltr,
        creationParams: null,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const Center(child: Text('Platform not supported'));
  }
}



Notes:
- SDK sử dụng WebSocket + piped streams để đưa dữ liệu FMP4 vào player.
- Khi startStreaming thất bại, SDK sẽ trả callback với message lỗi.

License:
MIT License © 2025 Ermis Network
