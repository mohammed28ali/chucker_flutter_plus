import 'package:http/http.dart' as http;

import '../../domain/entities/network_transaction.dart';
import '../../presentation/chucker_flutter.dart';
import '../../../../core/body_capture.dart';
import '../../../../core/observed_http_response.dart';

/// Captures HTTP traffic while forwarding response chunks to the caller.
class ChuckerHttpClient extends http.BaseClient {
  ChuckerHttpClient(this._client);

  /// Set to `true` on a request to skip capture. Removed before sending.
  static const disableCaptureHeader = 'x-chucker-capture-disabled';

  final http.Client _client;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final disabled =
        request.headers.remove(disableCaptureHeader)?.toLowerCase() == 'true';
    final session = ChuckerFlutterPlus.captureSession;
    if (session == null || disabled) return _client.send(request);

    final startedAt = DateTime.now();
    final limit = ChuckerFlutterPlus.maximumBodyBytes;
    final requestHeaders = Map.of(request.headers);
    final requestType = requestHeaders['content-type'];
    final requestBody = switch (request) {
      http.Request() => BodyCapture.from(
        request.bodyBytes,
        limit: limit,
        contentType: requestType,
      ),
      http.MultipartRequest(:final fields) => BodyCapture.from(
        fields,
        limit: limit,
      ),
      _ => BodyCapture(
        size: request.contentLength ?? 0,
        omitted: request.contentLength != 0,
      ),
    };

    Future<void> record({
      http.StreamedResponse? response,
      BodyCapture responseBody = const BodyCapture(),
      String? error,
    }) => ChuckerFlutterPlus.record(
      NetworkTransaction(
        id: '${request.hashCode}-${startedAt.microsecondsSinceEpoch}',
        startedAt: startedAt,
        completedAt: DateTime.now(),
        method: request.method,
        uri: request.url,
        statusCode: response?.statusCode,
        requestHeaders: requestHeaders,
        responseHeaders: response?.headers ?? const {},
        rawRequestBody: requestBody.text,
        requestBodySize: request.contentLength ?? requestBody.size,
        requestBodyTruncated: requestBody.omitted,
        rawResponseBody: responseBody.text,
        responseBodySize: responseBody.size,
        responseBodyTruncated: responseBody.omitted,
        contentType: response?.headers['content-type'],
        error: error,
      ),
      session: session,
    );

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (error) {
      record(error: error.runtimeType.toString()).ignore();
      rethrow;
    }

    return observeHttpResponse(
      response,
      bodyLimit: limit,
      onError: (error, bytes) {
        record(
          response: response,
          responseBody: BodyCapture(size: bytes.size, omitted: true),
          error: 'Response stream failed (${error.runtimeType})',
        ).ignore();
      },
      onDone: (bytes) {
        final responseBody = bytes.omitted
            ? BodyCapture(size: bytes.size, omitted: true)
            : BodyCapture.from(
                bytes.takeBytes(),
                limit: limit,
                contentType: response.headers['content-type'],
              );
        record(response: response, responseBody: responseBody).ignore();
      },
    );
  }

  @override
  void close() => _client.close();
}
