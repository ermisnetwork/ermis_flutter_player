import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ermis_stream_player/src/api/models/response/ermis_stream_info.dart';

import '../config/ermis_stream_config.dart';
import 'ermis_api_client.dart';
import 'models/exceptions/ermis_stream_api_exception.dart';
import 'models/request/ermis_stream_list_conditions.dart';
import 'models/request/ermis_stream_list_query.dart';
import 'models/response/ermis_stream_list_response.dart';

class ErmisStreamApi {
  ErmisStreamApi({required this.config, ErmisApiClient? client})
    : _client = client ?? ErmisApiClient(config: config);

  final ErmisStreamConfig config;
  final ErmisApiClient _client;

  Future<ErmisStreamInfo> createStream({
    required String streamName,
    required String authToken,
    Uri? baseUrl,
  }) async {
    if (streamName.trim().isEmpty) {
      throw ArgumentError.value(streamName, 'streamName', 'Cannot be empty');
    }

    final headers = <String, String>{
      'Authorization':
          authToken.startsWith('Bearer ') ? authToken : 'Bearer $authToken',
    };
    final payload = <String, dynamic>{'stream_name': streamName};

    try {
      final response = await _client.postJson<Map<String, dynamic>>(
        '/stream-gate/streams',
        data: payload,
        headers: headers,
        baseUrl: baseUrl,
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
    required String authToken,
    ErmisStreamListQuery? query,
    ErmisStreamListConditions? conditions,
    Uri? baseUrl,
  }) async {
    final headers = <String, String>{
      'Authorization':
          authToken.startsWith('Bearer ') ? authToken : 'Bearer $authToken',
    };
    final payload = <String, dynamic>{
      'list_query': query?.toJson() ?? const ErmisStreamListQuery().toJson(),
      'conditions': conditions?.toJson() ?? <String, dynamic>{},
    };

    try {
      final response = await _client.postJson<Map<String, dynamic>>(
        '/stream-gate/streams/list',
        data: payload,
        headers: headers,
        baseUrl: baseUrl,
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

  void _log(String message) {
    config.logger?.call('[ErmisStreamApi] $message');
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
