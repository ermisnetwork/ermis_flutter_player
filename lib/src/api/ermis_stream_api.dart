import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ermis_stream_player/src/api/models/response/ermis_stream_info.dart';

import '../config/ermis_stream_config.dart';
import 'ermis_api_client.dart';
import 'models/exceptions/ermis_stream_api_exception.dart';
import 'models/request/ermis_stream_list_conditions.dart';
import 'models/request/ermis_stream_list_query.dart';
import 'models/request/ermis_stream_update_request.dart';
import 'models/response/ermis_stream_list_response.dart';

class ErmisStreamApi {
  ErmisStreamApi({required this.config, ErmisApiClient? client})
    : _client = client ?? ErmisApiClient(config: config);

  final ErmisStreamConfig config;
  final ErmisApiClient _client;

  Future<ErmisStreamInfo> createStream({
    required String streamName,
  }) async {
    if (streamName.trim().isEmpty) {
      throw ArgumentError.value(streamName, 'streamName', 'Cannot be empty');
    }

    final token = await _resolveAuthToken();
    final headers = <String, String>{'Authorization': token};
    final payload = <String, dynamic>{
      'stream_name': streamName,
      'stream_method': 'software',
    };

    try {
      final response = await _client.postJson<Map<String, dynamic>>(
        '/stream-gate/streams',
        data: payload,
        headers: headers,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ErmisStreamInfo.fromJson(data);
      }
      throw ErmisStreamApiException(
        statusCode: response.statusCode,
        message: 'Unexpected response format',
      );
    } on DioException catch (e) {
      _log('Dio error: ${e.message}');
      throw _mapDioException(e);
    } on TimeoutException catch (_) {
      throw ErmisStreamApiException(message: 'Request timed out');
    }
  }

  Future<ErmisStreamListResponse> listStreams({
    ErmisStreamListQuery? query,
    ErmisStreamListConditions? conditions,
  }) async {
    final token = await _resolveAuthToken();
    final headers = <String, String>{'Authorization': token};
    final payload = <String, dynamic>{
      'list_query': query?.toJson() ?? const ErmisStreamListQuery().toJson(),
      'conditions': conditions?.toJson() ?? <String, dynamic>{},
    };

    try {
      final response = await _client.postJson<Map<String, dynamic>>(
        '/stream-gate/streams/list',
        data: payload,
        headers: headers,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ErmisStreamListResponse.fromJson(data);
      }
      throw ErmisStreamApiException(
        statusCode: response.statusCode,
        message: 'Unexpected response format',
      );
    } on DioException catch (e) {
      _log('Dio error: ${e.message}');
      throw _mapDioException(e);
    }
  }

  Future<ErmisStreamInfo> updateStream({
    required String streamId,
    required ErmisStreamUpdateRequest request,
  }) async {
    if (streamId.trim().isEmpty) {
      throw ArgumentError.value(streamId, 'streamId', 'Cannot be empty');
    }
    if (!request.hasData) {
      throw ArgumentError('Provide at least one field to update.');
    }

    final token = await _resolveAuthToken();
    final headers = <String, String>{'Authorization': token};

    try {
      final response = await _client.putJson<Map<String, dynamic>>(
        '/stream-gate/streams/$streamId',
        data: request.toJson(),
        headers: headers,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ErmisStreamInfo.fromJson(data);
      }
      throw ErmisStreamApiException(
        statusCode: response.statusCode,
        message: 'Unexpected response format',
      );
    } on DioException catch (e) {
      _log('Dio error: ${e.message}');
      throw _mapDioException(e);
    }
  }

  void _log(String message) {
    config.logger?.call('[ErmisStreamApi] $message');
  }

  Future<String> _resolveAuthToken() async {
    final String? providedToken = await config.authTokenProvider?.call();
    if (providedToken == null || providedToken.trim().isEmpty) {
      throw StateError(
        'Authentication token is required. '
        'Provide authToken parameter or configure ErmisStreamConfig.authTokenProvider.',
      );
    }
    return providedToken.startsWith('Bearer ')
        ? providedToken
        : 'Bearer ${providedToken.trim()}';
  }

  ErmisStreamApiException _mapDioException(DioException exception) {
    final response = exception.response;
    if (response == null) {
      return ErmisStreamApiException(
        message: exception.message ?? 'Network error',
      );
    }
    final statusCode = response.statusCode;
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ErmisStreamApiException(
        statusCode: statusCode,
        errorCode: data['error_code'] as int?,
        message:
            data['message']?.toString() ??
            'Request failed (${response.statusCode})',
      );
    }
    return ErmisStreamApiException(
      statusCode: statusCode,
      message: 'Request failed ($statusCode)',
    );
  }
}
