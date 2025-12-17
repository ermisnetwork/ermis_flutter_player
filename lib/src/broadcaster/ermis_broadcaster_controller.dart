import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rtmp_broadcaster/camera.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/ermis_stream_api.dart';
import '../api/models/request/ermis_stream_update_request.dart';
import '../api/models/response/ermis_stream_info.dart';
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

  ErmisBroadcasterController({ErmisStreamConfig? config, ErmisStreamApi? api})
    : config = config ?? const ErmisStreamConfig(),
      _api = api ?? ErmisStreamApi(config: config ?? const ErmisStreamConfig());

  final ErmisStreamConfig config;
  final ErmisStreamApi _api;
  ErmisBroadcasterState _state = ErmisBroadcasterState.idle;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  String? _lastError;
  bool _audioEnabled = true;
  final bool _androidUseOpenGL = true;
  bool _lifecycleAttached = false;
  ErmisStreamInfo? _activeStream;

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

  Future<void> start({required ErmisStreamInfo streamInfo}) async {
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

    _lastError = null;
    _setState(ErmisBroadcasterState.initializing);

    late ErmisStreamInfo refreshedStream;
    try {
      refreshedStream = await _updateLiveStatus(
        streamId: streamInfo.streamId,
        isLive: true,
      );
    } catch (e) {
      _setError('Unable to start broadcast: $e');
      rethrow;
    }

    final endpoint = _buildEndpoint(refreshedStream);

    try {
      _activeStream = refreshedStream;
      await controller.startVideoStreaming(endpoint);
      await WakelockPlus.enable();
      _setState(ErmisBroadcasterState.broadcasting);
    } on CameraException catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to start broadcast: ${e.description ?? e.code}');
      await _safeUpdateLiveStatus(
        streamId: refreshedStream.streamId,
        isLive: false,
      );
      _activeStream = null;
      rethrow;
    } catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to start broadcast: $e');
      await _safeUpdateLiveStatus(
        streamId: refreshedStream.streamId,
        isLive: false,
      );
      _activeStream = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    final controller = _cameraController;
    final String? activeStreamId = _activeStream?.streamId;
    if (controller == null) {
      await WakelockPlus.disable();
      if (activeStreamId != null) {
        await _safeUpdateLiveStatus(streamId: activeStreamId, isLive: false);
        _activeStream = null;
      }
      return;
    }
    if (controller.value.isStreamingVideoRtmp != true) {
      await WakelockPlus.disable();
      if (activeStreamId != null) {
        await _safeUpdateLiveStatus(streamId: activeStreamId, isLive: false);
        _activeStream = null;
      }
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
      if (activeStreamId != null) {
        await _safeUpdateLiveStatus(streamId: activeStreamId, isLive: false);
        _activeStream = null;
      }
      _setState(
        controller.value.isInitialized == true
            ? ErmisBroadcasterState.ready
            : ErmisBroadcasterState.idle,
      );
    } on CameraException catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to stop broadcast: ${e.description ?? e.code}');
      if (activeStreamId != null) {
        await _safeUpdateLiveStatus(streamId: activeStreamId, isLive: false);
        _activeStream = null;
      }
      rethrow;
    } catch (e) {
      await WakelockPlus.disable();
      _setError('Unable to stop broadcast: $e');
      if (activeStreamId != null) {
        await _safeUpdateLiveStatus(streamId: activeStreamId, isLive: false);
        _activeStream = null;
      }
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

  String _buildEndpoint(ErmisStreamInfo streamInfo) {
    final Uri? base = config.streamBaseUrl;
    if (base == null) {
      throw StateError(
        'Configure ErmisStreamConfig.streamBaseUrl before broadcasting.',
      );
    }
    final sanitizedBase = base.toString().trim().replaceAll(RegExp(r'/+$'), '');
    final appName = streamInfo.appName.trim();
    final streamKey = streamInfo.streamKey.trim();
    if (appName.isEmpty || streamKey.isEmpty) {
      throw ArgumentError(
        'Stream info must contain non-empty appName and streamKey.',
      );
    }
    final normalizedApp = appName.replaceAll(RegExp(r'^/+|/+$'), '');
    final normalizedKey = streamKey.replaceAll(RegExp(r'^/+'), '');
    return '$sanitizedBase/$normalizedApp/$normalizedKey';
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

  Future<ErmisStreamInfo> _updateLiveStatus({
    required String streamId,
    required bool isLive,
  }) {
    return _api.updateStream(
      streamId: streamId,
      request: ErmisStreamUpdateRequest(isLive: isLive),
    );
  }

  Future<void> _safeUpdateLiveStatus({
    required String streamId,
    required bool isLive,
  }) async {
    try {
      await _updateLiveStatus(streamId: streamId, isLive: isLive);
    } catch (e) {
      config.logger?.call(
        '[ErmisBroadcasterController] Failed to update live status: $e',
      );
    }
  }
}
