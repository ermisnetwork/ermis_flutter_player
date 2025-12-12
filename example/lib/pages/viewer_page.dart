import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

import '../widgets/fmp4_stream_player_view.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  static const _streamId = 'f198fc18-d5cb-4699-8225-03a2f9f60a03';
  static const _token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiMHhiYTcxZDJlYzEwZDllZGExZDU1OGIxZWY4NjA3ZGNjN2NhNmM5MzBkIiwiY2xpZW50X2lkIjoiMzNhZTc0NzMtNjMxNS00NDMzLTgyYjAtMmFmYzNhMzk5OWUyIiwiY2hhaW5faWQiOjEsInByb2plY3RfaWQiOiJlYzk2NDk3NS1hZTg0LTRhOGUtOTFhMS0yMjJjYTNhZWVlZjgiLCJhcGlrZXkiOiJzWGhjUHUwSm5lVWJRNlRHMnRYZVBLOE1DMnRCQUhuOSIsImVybWlzIjpmYWxzZSwiZXhwIjoxODY1NTI3NTE5MTUyLCJhZG1pbiI6ZmFsc2UsImdhdGUiOmZhbHNlfQ.Uj2h-a3uB0TH9DmPD6C8kaip5xkIkxkcH4mtkdUBLw4';

  bool _isStreaming = false;
  String _status = 'Ready';

  Future<void> _startStream() async {
    setState(() => _status = 'Connecting...');

    final success = await ErmisStreamPlayerSDK.joinStream(
      streamId: _streamId,
      token: _token,
    );

    setState(() {
      _isStreaming = success;
      _status = success ? 'Streaming...' : 'Failed to connect';
    });
  }

  Future<void> _stopStream() async {
    final success = await ErmisStreamPlayerSDK.leaveStream();
    setState(() {
      _isStreaming = false;
      _status = success ? 'Stopped' : 'Failed to stop';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.white,
            child: const Fmp4StreamPlayerView(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[200],
          width: double.infinity,
          child: Text(
            'Status: $_status',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
    );
  }
}
