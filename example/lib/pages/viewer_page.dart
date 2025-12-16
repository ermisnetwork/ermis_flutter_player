import 'dart:async';

import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  final ErmisViewerController _controller = ErmisViewerController();
  final TextEditingController _streamIdController = TextEditingController(
    text: 'f198fc18-d5cb-4699-8225-03a2f9f60a03',
  );
  final TextEditingController _tokenController = TextEditingController(
    text:
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiMHhiYTcxZDJlYzEwZDllZGExZDU1OGIxZWY4NjA3ZGNjN2NhNmM5MzBkIiwiY2xpZW50X2lkIjoiMzNhZTc0NzMtNjMxNS00NDMzLTgyYjAtMmFmYzNhMzk5OWUyIiwiY2hhaW5faWQiOjEsInByb2plY3RfaWQiOiJlYzk2NDk3NS1hZTg0LTRhOGUtOTFhMS0yMjJjYTNhZWVlZjgiLCJhcGlrZXkiOiJzWGhjUHUwSm5lVWJRNlRHMnRYZVBLOE1DMnRCQUhuOSIsImVybWlzIjpmYWxzZSwiZXhwIjoxODY1ODY5MDM3NTk3LCJhZG1pbiI6ZmFsc2UsImdhdGUiOmZhbHNlfQ.7dLKdc2o6VKi5TO32cxJgmPFl4bE2MJmU0garm5Ob8o',
  );

  bool _isStreaming = false;
  bool _isBusy = false;
  String _status = 'Ready';
  int? _viewerCount;
  StreamSubscription<ErmisStreamEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _eventSub = _controller.events.listen((event) {
      if (event.type == 'TotalViewerCount') {
        if (!mounted) return;
        setState(() {
          _viewerCount = event.totalViewers;
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _controller.dispose();
    _streamIdController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _startStream() async {
    if (_isStreaming || _isBusy) return;
    final streamId = _streamIdController.text.trim();
    final token = _tokenController.text.trim();
    if (streamId.isEmpty || token.isEmpty) {
      setState(() => _status = 'Enter stream ID and token');
      return;
    }

    setState(() {
      _isBusy = true;
      _status = 'Connecting...';
    });

    try {
      await _controller.start(streamId: streamId, token: token);
      if (!mounted) return;
      setState(() {
        _isStreaming = true;
        _status = 'Streaming...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Failed to connect';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _stopStream() async {
    if (!_isStreaming || _isBusy) return;
    setState(() {
      _isBusy = true;
      _status = 'Stopping...';
    });

    try {
      await _controller.stop();
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        _status = 'Stopped';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Failed to stop';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: const ErmisStreamPlayerView(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[200],
          width: double.infinity,
          child: Text(
            'Status: $_status${_viewerCount != null ? ' • Viewers: $_viewerCount' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _streamIdController,
                decoration: const InputDecoration(
                  labelText: 'Stream ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          (!_isStreaming && !_isBusy) ? _startStream : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isStreaming && !_isBusy) ? _stopStream : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
