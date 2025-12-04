
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ermis_stream_player/ermis_stream_player.dart';

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
      streamId: "417c42f6-0cb0-4115-9e48-c15ccbf2b228",
      token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiOGY5OTU5YzYtMDEzYS00ZDIwLTlkYjUtZGNjN2NjNjE1NzA0IiwiY2xpZW50X2lkIjoiYmE3Mzk4YzQtNjdhZi00YzgyLWIyZjMtNDZiOWNhM2Y4MTExIiwiYXBwX25hbWUiOiJFcm1pcy1zdHJlYW1pbmciLCJleHAiOjE3NjQ5NDM3MDE2ODksInJvbGVfbmFtZSI6ImNsaWVudF9hZG1pbiIsInBlcm1pc3Npb25zIjpbMSwyLDMsNCw1LDksMTEsMTIsMTMsMTQsMTUsMTYsMTcsMTgsMTksMjAsMjEsMjIsMjMsMjQsMjUsMjYsMjcsMjgsMjksMzAsMzEsMzIsMzMsMzQsMzUsMzYsMzcsMzgsMzksNDAsNDUsNDcsNDgsNDldfQ.1y8Imb0uaFnDHqnqABZ1sF5d8oDXb_0QQL1_qMtKGRA",
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

// Widget để hiển thị player view
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
