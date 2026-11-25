import 'package:dio/dio.dart';

import '../../domain/entities/network_transaction.dart';
import '../body_capture.dart';
import '../../presentation/chucker_flutter.dart';

class ChuckerDioInterceptor extends Interceptor {
  static const _startedAtKey = 'chucker_flutter_plus.started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    await _recordResponse(response);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    await _recordError(err);
    handler.next(err);
  }

  Future<void> _recordResponse(Response<dynamic> response) async {
    final request = response.requestOptions;
    _record(
      NetworkTransaction(
        id: _id(request),
        startedAt: _startedAt(request),
        completedAt: DateTime.now(),
        method: request.method,
        uri: request.uri,
        statusCode: response.statusCode,
        requestHeaders: ChuckerFlutterPlus.redactHeaders(
          _requestHeaders(request.headers),
        ),
        responseHeaders: ChuckerFlutterPlus.redactHeaders(
          _headers(response.headers),
        ),
        rawRequestBody: await BodyCapture.multipartBody(request.data),
        rawResponseBody: BodyCapture.raw(response.data),
        requestBodySize: BodyCapture.size(
          request.data,
          BodyCapture.raw(request.data),
        ),
        responseBodySize: _responseSize(response),
        contentType: response.headers.value('content-type'),
      ),
    );
  }

  Future<void> _recordError(DioException error) async {
    final request = error.requestOptions;
    final response = error.response;
    _record(
      NetworkTransaction(
        id: _id(request),
        startedAt: _startedAt(request),
        completedAt: DateTime.now(),
        method: request.method,
        uri: request.uri,
        statusCode: response?.statusCode,
        requestHeaders: ChuckerFlutterPlus.redactHeaders(
          _requestHeaders(request.headers),
        ),
        responseHeaders: response == null
            ? const {}
            : ChuckerFlutterPlus.redactHeaders(_headers(response.headers)),
        rawRequestBody: await BodyCapture.multipartBody(request.data),
        rawResponseBody: BodyCapture.raw(response?.data),
        requestBodySize: BodyCapture.size(
          request.data,
          BodyCapture.raw(request.data),
        ),
        responseBodySize: response == null ? 0 : _responseSize(response),
        contentType: response?.headers.value('content-type'),
        error: error.message ?? error.type.name,
        stackTrace: error.stackTrace.toString(),
      ),
    );
  }

  Future<void> _record(NetworkTransaction transaction) {
    return ChuckerFlutterPlus.record(transaction);
  }

  DateTime _startedAt(RequestOptions request) =>
      request.extra[_startedAtKey] as DateTime? ?? DateTime.now();

  String _id(RequestOptions request) =>
      '${request.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

  Map<String, String> _headers(Headers headers) =>
      headers.map.map((key, values) => MapEntry(key, values.join(', ')));

  Map<String, String> _requestHeaders(Map<String, dynamic> headers) =>
      headers.map((key, value) => MapEntry(key, value.toString()));

  int _responseSize(Response<dynamic> response) {
    final declared = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    return declared ??
        BodyCapture.size(response.data, BodyCapture.raw(response.data));
  }
}
