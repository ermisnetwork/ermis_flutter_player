import 'package:dio/dio.dart';

import '../config/ermis_stream_config.dart';

class ErmisApiClient {
  ErmisApiClient({required this.config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.apiBaseUrl?.toString() ?? '',
              connectTimeout: config.timeout,
              receiveTimeout: config.timeout,
              headers: {
                if (config.defaultHeaders != null) ...config.defaultHeaders!,
              },
            ),
          );

  final ErmisStreamConfig config;
  final Dio _dio;

  Future<Response<T>> postJson<T>(
    String path, {
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    Uri? baseUrl,
  }) {
    return _request(
      method: 'POST',
      path: path,
      data: data,
      headers: headers,
      baseUrl: baseUrl,
    );
  }

  Future<Response<T>> putJson<T>(
    String path, {
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    Uri? baseUrl,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      data: data,
      headers: headers,
      baseUrl: baseUrl,
    );
  }

  Future<Response<T>> _request<T>({
    required String method,
    required String path,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
    Uri? baseUrl,
  }) async {
    final mergedHeaders = {
      if (config.defaultHeaders != null) ...config.defaultHeaders!,
      if (headers != null) ...headers,
      'Content-Type': 'application/json',
    };

    final Options options = Options(
      method: method,
      headers: mergedHeaders,
      responseType: ResponseType.json,
    );

    final Uri resolvedUri = _resolveUri(path, baseUrl);
    return _dio.requestUri<T>(resolvedUri, data: data, options: options);
  }

  Uri _resolveUri(String path, Uri? baseUrl) {
    final Uri? configBase = baseUrl ?? config.apiBaseUrl;
    if (configBase == null) {
      throw StateError(
        'API base URL is not configured. '
        'Set ErmisStreamConfig.apiBaseUrl or pass baseUrl per call.',
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }

    if (path.startsWith('/')) {
      return configBase.resolve(path);
    }
    return configBase.resolve('/$path');
  }
}
