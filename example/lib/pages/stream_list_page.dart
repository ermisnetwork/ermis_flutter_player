import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

class StreamListPage extends StatefulWidget {
  const StreamListPage({
    super.key,
    required this.player,
    required this.onCreateStream,
    required this.onStreamSelected,
  });

  final ErmisStreamPlayer? player;
  final VoidCallback onCreateStream;
  final ValueChanged<ErmisStreamInfo> onStreamSelected;

  @override
  State<StreamListPage> createState() => _StreamListPageState();
}

class _StreamListPageState extends State<StreamListPage> {
  Future<ErmisStreamListResponse>? _future;

  @override
  void didUpdateWidget(StreamListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player && widget.player == null) {
      setState(() => _future = null);
    }
  }

  void _load() {
    final player = widget.player;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure token first')),
      );
      return;
    }
    setState(() {
      _future = player.listStreams(
        query: const ErmisStreamListQuery(page: 1, perPage: 20),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null) {
      return _buildPlaceholder('Configure API token in the Auth tab first.');
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Load streams'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.onCreateStream,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _future == null
                  ? _buildPlaceholder('Tap "Load streams" to fetch data.')
                  : FutureBuilder<ErmisStreamListResponse>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _buildPlaceholder(
                          'Error: ${snapshot.error}',
                          isError: true,
                        );
                      }
                      final response = snapshot.data;
                      if (response == null || response.data.isEmpty) {
                        return _buildPlaceholder('No streams found.');
                      }
                      return ListView.separated(
                        itemCount: response.data.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final stream = response.data[index];
                          return ListTile(
                            title: Text(stream.streamName),
                            subtitle: Text(
                              'ID: ${stream.streamId}\n'
                              'Method: ${stream.streamMethod}\n'
                              'Live: ${stream.isLive}',
                            ),
                            isThreeLine: true,
                            trailing: Icon(
                              stream.isLive
                                  ? Icons.wifi_tethering
                                  : Icons.pause_circle,
                              color: stream.isLive ? Colors.green : Colors.grey,
                            ),
                            onTap: () => widget.onStreamSelected(stream),
                          );
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String message, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: isError ? Colors.red : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
