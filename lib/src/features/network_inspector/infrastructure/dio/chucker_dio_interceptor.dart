import 'package:dio/dio.dart';

import '../../domain/entities/network_transaction.dart';
import '../../presentation/chucker_flutter.dart';
import '../../../../core/body_capture.dart';

class ChuckerDioInterceptor extends Interceptor {
  /// Set to true in `Options.extra` to skip capture for a request.
  static const disableCaptureExtraKey = 'chucker_flutter_plus.capture_disabled';
  static const _requestKey = 'chucker_flutter_plus.capture';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = ChuckerFlutterPlus.captureSession;
    options.extra.remove(_requestKey);
    if (session != null && options.extra[disableCaptureExtraKey] != true) {
      options.extra[_requestKey] = (DateTime.now(), session);
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _capture(response.requestOptions, response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _capture(err.requestOptions, err.response, error: err.type.name);
    handler.next(err);
  }

  void _capture(
    RequestOptions request,
    Response<dynamic>? response, {
    String? error,
  }) {
    final start = request.extra.remove(_requestKey);
    if (start is! (DateTime, int) ||
        start.$2 != ChuckerFlutterPlus.captureSession) {
      return;
    }
    try {
      final limit = ChuckerFlutterPlus.maximumBodyBytes;
      final data = request.data;
      final requestSize = _length(
        request.headers.entries.map(
          (entry) => MapEntry(entry.key, entry.value.toString()),
        ),
      );
      final requestBody = BodyCapture.from(
        data is FormData ? Map.fromEntries(data.fields) : data,
        limit: limit,
        contentType: request.contentType,
        declaredSize: data is FormData ? data.length : requestSize,
      );
      final responseHeaders =
          response?.headers.map.map(
            (key, values) => MapEntry(key, values.join(', ')),
          ) ??
          const <String, String>{};
      final contentType = responseHeaders['content-type'];
      final responseSize = _length(responseHeaders.entries);
      final responseData = response?.data;
      final responseBody = responseData is ResponseBody
          ? BodyCapture(size: responseSize ?? 0, omitted: true)
          : BodyCapture.from(
              responseData,
              limit: limit,
              contentType: contentType,
              declaredSize: responseSize,
            );
      ChuckerFlutterPlus.record(
        NetworkTransaction(
          id: '${request.hashCode}-${start.$1.microsecondsSinceEpoch}',
          startedAt: start.$1,
          completedAt: DateTime.now(),
          method: request.method,
          uri: request.uri,
          statusCode: response?.statusCode,
          requestHeaders: request.headers.map(
            (key, value) => MapEntry(key, '$value'),
          ),
          responseHeaders: responseHeaders,
          rawRequestBody: requestBody.text,
          rawResponseBody: responseBody.text,
          requestBodySize:
              requestSize ??
              (data is FormData ? data.length : requestBody.size),
          responseBodySize: responseSize ?? responseBody.size,
          requestBodyTruncated: requestBody.omitted,
          responseBodyTruncated: responseBody.omitted,
          contentType: contentType,
          error: error,
        ),
        session: start.$2,
      ).ignore();
    } catch (_) {
      // Diagnostics must not interfere with the underlying request.
    }
  }

  int? _length(Iterable<MapEntry<String, String>> headers) {
    for (final header in headers) {
      if (header.key.toLowerCase() == 'content-length') {
        return int.tryParse(header.value);
      }
    }
    return null;
  }
}
