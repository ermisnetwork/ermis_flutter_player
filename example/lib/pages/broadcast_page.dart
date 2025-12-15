import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final ErmisBroadcasterController _controller = ErmisBroadcasterController();
  final TextEditingController _ingestController = TextEditingController(
    text: 'rtmps://streaming.ermis.network:1939/Ermis-streaming',
  );
  final TextEditingController _streamKeyController = TextEditingController(
    text: 'f198fc18-d5cb-4699-8225-03a2f9f60a03:4c6f28fff8160cfb',
  );

  bool _isLoadingCamera = true;
  bool _isBusy = false;
  bool _audioEnabled = true;
  String _status = 'Loading cameras...';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _loadCameras();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {
      _audioEnabled = _controller.isAudioEnabled;
    });
  }

  Future<void> _loadCameras() async {
    setState(() {
      _isLoadingCamera = true;
      _status = 'Loading cameras...';
    });
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _isLoadingCamera = false;
          _status = 'No cameras available';
        });
        return;
      }
      await _controller.init(cameras: cameras);
      if (!mounted) return;
      setState(() {
        _isLoadingCamera = false;
        _status = 'Camera ready';
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCamera = false;
        _status = 'Camera error: ${e.description ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCamera = false;
        _status = 'Camera error: $e';
      });
    }
  }

  Future<void> _startBroadcast() async {
    final ingest = _ingestController.text.trim();
    final streamKey = _streamKeyController.text.trim();
    if (ingest.isEmpty || streamKey.isEmpty) {
      setState(() => _status = 'Enter ingest and stream key');
      return;
    }
    setState(() {
      _isBusy = true;
      _status = 'Starting broadcast...';
    });

    try {
      await _controller.start(ingestUrl: ingest, streamKey: streamKey);
      if (!mounted) return;
      setState(() => _status = 'Broadcasting...');
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Start failed: ${e.description ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Start failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _stopBroadcast() async {
    setState(() {
      _isBusy = true;
      _status = 'Stopping broadcast...';
    });
    try {
      await _controller.stop();
      if (!mounted) return;
      setState(() => _status = 'Broadcast stopped');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Stop failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _switchCamera() async {
    setState(() => _status = 'Switching camera...');
    try {
      await _controller.switchCamera();
      if (!mounted) return;
      setState(() => _status = 'Camera switched');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Switch camera failed');
    }
  }

  Future<void> _toggleAudio(bool value) async {
    setState(() => _audioEnabled = value);
    try {
      await _controller.setAudioEnabled(value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _audioEnabled = !value;
        _status = 'Audio update failed';
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _ingestController.dispose();
    _streamKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBroadcasting = _controller.isBroadcasting;
    final bool canStart =
        !_isLoadingCamera &&
        !isBroadcasting &&
        !_isBusy &&
        _controller.cameraController != null;
    final bool canStop = isBroadcasting && !_isBusy;

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: Center(
              child: ErmisBroadcasterPreview(controller: _controller),
            ),
          ),
        ),
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: $_status',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_controller.lastError != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${_controller.lastError}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _ingestController,
                decoration: const InputDecoration(
                  labelText: 'RTMP ingest',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _streamKeyController,
                decoration: const InputDecoration(
                  labelText: 'Stream key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canStart ? _startBroadcast : null,
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Start broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canStop ? _stopBroadcast : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed:
                        _controller.cameraController != null
                            ? _switchCamera
                            : null,
                    icon: const Icon(Icons.cameraswitch),
                    label: const Text('Switch camera'),
                  ),
                  Row(
                    children: [
                      const Text('Audio'),
                      Switch(
                        value: _audioEnabled,
                        onChanged:
                            _controller.cameraController == null
                                ? null
                                : (value) => _toggleAudio(value),
                      ),
                    ],
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
