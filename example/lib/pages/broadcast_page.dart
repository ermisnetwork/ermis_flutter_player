import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BroadcastPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const BroadcastPage({super.key, required this.cameras});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _enableAudio = true;
  bool _useOpenGL = true;
  String _status = 'Ready to broadcast';
  final TextEditingController _ingestController = TextEditingController(
    text: 'rtmps://streaming.ermis.network:1939/Ermis-streaming',
  );
  final TextEditingController _streamKeyController = TextEditingController(
    text: 'f198fc18-d5cb-4699-8225-03a2f9f60a03:4c6f28fff8160cfb',
  );

  bool get _isControllerInitialized =>
      _controller?.value.isInitialized ?? false;
  bool get _isStreaming => _controller?.value.isStreamingVideoRtmp ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFirstCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ingestController.dispose();
    _streamKeyController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _initFirstCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _status = 'No cameras available');
      return;
    }
    await _setCamera(widget.cameras.first);
  }

  Future<void> _setCamera(CameraDescription description) async {
    final previous = _controller;
    _controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: _enableAudio,
      androidUseOpenGL: _useOpenGL,
    );

    _controller!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await _controller!.initialize();
      setState(() => _status = 'Camera ready');
      await previous?.dispose();
    } on CameraException catch (e) {
      setState(() => _status = 'Camera error: ${e.description ?? e.code}');
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_controller == null) return;
    if (state == AppLifecycleState.paused) {
      if (_isStreaming) {
        await _controller?.pauseVideoStreaming();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isStreaming) {
        await _controller?.resumeVideoStreaming();
      } else if (_isControllerInitialized) {
        await _controller?.initialize();
      }
    }
  }

  Future<void> _startStreaming() async {
    if (!_isControllerInitialized) {
      setState(() => _status = 'Initialize the camera first');
      return;
    }

    final url = _buildEndpoint();
    if (url == null) {
      setState(() => _status = 'Enter ingest and stream key');
      return;
    }

    try {
      await _controller!.startVideoStreaming(url);
      await WakelockPlus.enable();
      setState(() => _status = 'Broadcasting to $url');
    } on CameraException catch (e) {
      setState(() => _status = 'Start failed: ${e.description ?? e.code}');
    }
  }

  String? _buildEndpoint() {
    final ingest = _ingestController.text.trim().replaceAll(RegExp(r'/+$'), '');
    final key = _streamKeyController.text.trim();
    if (ingest.isEmpty || key.isEmpty) return null;
    return '$ingest/$key';
  }

  Future<void> _stopStreaming() async {
    if (!_isStreaming) return;
    try {
      await _controller!.stopVideoStreaming();
      setState(() => _status = 'Broadcast stopped');
    } on CameraException catch (e) {
      setState(() => _status = 'Stop failed: ${e.description ?? e.code}');
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2 || _controller == null) return;
    final currentIndex = widget.cameras.indexOf(_controller!.description);
    final nextIndex = (currentIndex + 1) % widget.cameras.length;
    await _setCamera(widget.cameras[nextIndex]);
  }

  Future<void> _toggleAudio(bool value) async {
    _enableAudio = value;
    if (_controller != null) {
      await _setCamera(_controller!.description);
    }
  }

  Future<void> _toggleOpenGL(bool value) async {
    _useOpenGL = value;
    if (_controller != null) {
      await _setCamera(_controller!.description);
    }
  }

  Widget _preview() {
    if (_controller == null || !_isControllerInitialized) {
      return const Center(
        child: Text(
          'Select a camera to preview',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: CameraPreview(_controller!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: Center(child: _preview()),
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
                      onPressed: _isStreaming ? null : _startStreaming,
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
                      onPressed: _isStreaming ? _stopStreaming : null,
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
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.cameraswitch),
                    label: const Text('Switch camera'),
                  ),
                  Row(
                    children: [
                      const Text('Audio'),
                      Switch(
                        value: _enableAudio,
                        onChanged: (value) => _toggleAudio(value),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('OpenGL'),
                      Switch(
                        value: _useOpenGL,
                        onChanged: (value) => _toggleOpenGL(value),
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
