import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rtmp_broadcaster/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/ermis_stream_config.dart';

enum ErmisBroadcasterState {
  idle,
  initializing,
  ready,
  broadcasting,
  stopping,
  error,
}

class ErmisBroadcasterController extends ChangeNotifier
    with WidgetsBindingObserver {
  static const ResolutionPreset _resolutionPreset = ResolutionPreset.medium;

  ErmisBroadcasterController({ErmisStreamConfig? config})
    : config = config ?? const ErmisStreamConfig();

  final ErmisStreamConfig config;
  ErmisBroadcasterState _state = ErmisBroadcasterState.idle;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  String? _lastError;
  bool _audioEnabled = true;
  final bool _androidUseOpenGL = true;
  bool _lifecycleAttached = false;

  ErmisBroadcasterState get state => _state;
  CameraController? get cameraController => _cameraController;
  String? get lastError => _lastError;
  bool get isBroadcasting =>
      _cameraController?.value.isStreamingVideoRtmp == true;
  bool get isAudioEnabled => _audioEnabled;
  int get selectedCameraIndex => _selectedCameraIndex;

  Future<void> init({required List<CameraDescription> cameras}) async {
    if (cameras.isEmpty) {
      _setError('No cameras available');
      throw StateError('No cameras available');
    }

    _attachLifecycleObserver();
    _cameras = List<CameraDescription>.unmodifiable(cameras);
    _selectedCameraIndex = 0;
    await _initializeCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> start({
    required String ingestUrl,
    required String streamKey,
  }) async {
    final controller = _cameraController;
    if (controller == null) {
      throw StateError('Call init() before starting a broadcast.');
    }
    if (controller.value.isInitialized != true) {
      throw StateError('Wait for the camera to finish initializing.');
    }
    if (controller.value.isStreamingVideoRtmp == true) {
      return;
    }

    final endpoint = _buildEndpoint(ingestUrl, streamKey);
    if (endpoint == null) {
      throw ArgumentError('Both ingestUrl and streamKey must be provided.');
    }

    try {
      _lastError = null;
      _setState(ErmisBroadcasterState.initializing);
      await controller.startVideoStreaming(endpoint);
      await WakelockPlus.enable();
      _setState(ErmisBroadcasterState.broadcasting);
    } on CameraException catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to start broadcast: ${e.description ?? e.code}');
      rethrow;
    } catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to start broadcast: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    final controller = _cameraController;
    if (controller == null) {
      await WakelockPlus.disable();
      return;
    }
    if (controller.value.isStreamingVideoRtmp != true) {
      await WakelockPlus.disable();
      if (controller.value.isInitialized == true) {
        _setState(ErmisBroadcasterState.ready);
      } else {
        _setState(ErmisBroadcasterState.idle);
      }
      return;
    }

    _setState(ErmisBroadcasterState.stopping);
    try {
      await controller.stopVideoStreaming();
      await WakelockPlus.disable();
      _setState(
        controller.value.isInitialized == true
            ? ErmisBroadcasterState.ready
            : ErmisBroadcasterState.idle,
      );
    } on CameraException catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to stop broadcast: ${e.description ?? e.code}');
      rethrow;
    } catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to stop broadcast: $e');
      rethrow;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) {
      return;
    }

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _changeCamera(nextIndex);
  }

  Future<void> setAudioEnabled(bool enabled) async {
    if (_audioEnabled == enabled) {
      return;
    }

    _audioEnabled = enabled;
    if (_cameraController == null || _cameras.isEmpty) {
      return;
    }

    final wasBroadcasting = isBroadcasting;
    if (wasBroadcasting) {
      await stop();
    }
    await _initializeCameraController(_cameras[_selectedCameraIndex]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;

    if (state == AppLifecycleState.paused) {
      if (controller.value.isStreamingVideoRtmp == true) {
        unawaited(controller.pauseVideoStreaming());
      }
    } else if (state == AppLifecycleState.resumed) {
      if (controller.value.isStreamingVideoRtmp == true) {
        unawaited(controller.resumeVideoStreaming());
      } else if (controller.value.isInitialized == true) {
        unawaited(controller.initialize());
      }
    }
  }

  @override
  Future<void> dispose() async {
    _detachLifecycleObserver();
    try {
      await stop();
    } catch (_) {
      // Ignore stop failures during dispose.
    }

    await _disposeCameraController(notify: false);

    await WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _changeCamera(int newIndex) async {
    if (newIndex < 0 || newIndex >= _cameras.length) {
      return;
    }

    final wasBroadcasting = isBroadcasting;
    if (wasBroadcasting) {
      await stop();
    }

    _selectedCameraIndex = newIndex;
    await _initializeCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _initializeCameraController(
    CameraDescription description,
  ) async {
    await _disposeCameraController();

    final newController = CameraController(
      description,
      _resolutionPreset,
      enableAudio: _audioEnabled,
      androidUseOpenGL: _androidUseOpenGL,
    );

    _cameraController = newController;
    _cameraController!.addListener(_handleCameraValueChanged);
    _setState(ErmisBroadcasterState.initializing);
    try {
      await newController.initialize();
    } on CameraException catch (e) {
      await _disposeCameraController();
      _setError('Camera error: ${e.description ?? e.code}');
      rethrow;
    } catch (e) {
      await _disposeCameraController();
      _setError('Camera error: $e');
      rethrow;
    }

    _lastError = null;
    _setState(ErmisBroadcasterState.ready);
  }

  Future<void> _disposeCameraController({bool notify = true}) async {
    final controller = _cameraController;
    if (controller == null) return;

    controller.removeListener(_handleCameraValueChanged);
    _cameraController = null;
    if (notify) {
      notifyListeners();
    }
    await controller.dispose();
  }

  String? _buildEndpoint(String ingestUrl, String streamKey) {
    final ingest = ingestUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final key = streamKey.trim();
    if (ingest.isEmpty || key.isEmpty) {
      return null;
    }
    return '$ingest/$key';
  }

  void _handleCameraValueChanged() {
    final controller = _cameraController;
    if (controller == null) return;

    if (controller.value.hasError) {
      _setError(controller.value.errorDescription ?? 'Unknown camera error');
    } else {
      notifyListeners();
    }
  }

  void _attachLifecycleObserver() {
    if (_lifecycleAttached) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _lifecycleAttached = true;
  }

  void _detachLifecycleObserver() {
    if (!_lifecycleAttached) return;
    final binding = WidgetsBinding.instance;
    binding.removeObserver(this);
    _lifecycleAttached = false;
  }

  void _setState(ErmisBroadcasterState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _lastError = message;
    _setState(ErmisBroadcasterState.error);
  }
}
