import 'package:http/http.dart' as http;

import '../../../core/body_capture.dart';
import '../../../core/observed_http_response.dart';
import '../../network_log_models.dart';
import '../../network_logger.dart';

/// An `http.Client` wrapper that tees response bytes while preserving streaming.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient({required this.inner, required this.logger});
  final http.Client inner;
  final NetworkLogger logger;
  static const disableLoggingHeader = 'x-network-logger-disabled';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final started = DateTime.now();
    final disabled =
        request.headers[disableLoggingHeader]?.toLowerCase() == 'true';
    request.headers.remove(disableLoggingHeader);
    if (disabled || !logger.isEnabled) return inner.send(request);
    final requestLog = NetworkRequestLog(
      method: request.method,
      url: request.url,
      headers: {
        for (final entry in request.headers.entries) entry.key: entry.value,
      },
      body: request is http.Request ? _requestBody(request) : null,
      startedAt: started,
      loggingDisabled: disabled,
      multipartParts: request is http.MultipartRequest
          ? [
              ...request.fields.entries.map(
                (e) => NetworkMultipartPart(name: e.key, value: e.value),
              ),
              ...request.files.map(
                (f) => NetworkMultipartPart(
                  name: f.field,
                  fileName: f.filename,
                  contentType: f.contentType.toString(),
                  length: f.length,
                ),
              ),
            ]
          : const [],
    );
    try {
      logger.logRequest(requestLog);
      final response = await inner.send(request);
      final captureBody =
          logger.config.logResponses && logger.config.logResponseBody;
      return observeHttpResponse(
        response,
        bodyLimit: logger.config.maxBodyLength * 4,
        captureBody: captureBody,
        onError: (error, _) => logger.logError(
          NetworkErrorLog(
            request: requestLog,
            error: error,
            type: error.runtimeType.toString(),
            statusCode: response.statusCode,
            headers: response.headers,
          ),
        ),
        onDone: (bytes) => logger.logResponse(
          NetworkResponseLog(
            request: requestLog,
            statusCode: response.statusCode,
            headers: response.headers,
            body: captureBody ? _responseBody(bytes, response) : null,
          ),
        ),
      );
    } catch (error) {
      logger.logError(
        NetworkErrorLog(
          request: requestLog,
          error: error,
          type: error.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  void close() => inner.close();

  Object? _requestBody(http.Request request) {
    if (!logger.config.logRequestBody) return null;
    final limit = logger.config.maxBodyLength * 4;
    final body = BodyCapture.from(
      request.bodyBytes,
      limit: limit,
      contentType: request.headers['content-type'],
      includeBinary: false,
    );
    return body.omitted ? '<body omitted>' : body.text;
  }

  Object? _responseBody(
    BoundedBodyBytes bytes,
    http.StreamedResponse response,
  ) {
    if (bytes.omitted) return '<body omitted: exceeds log limit>';
    final body = BodyCapture.from(
      bytes.takeBytes(),
      limit: bytes.limit,
      contentType: response.headers['content-type'],
      includeBinary: false,
    );
    return body.omitted ? '<body omitted>' : body.text;
  }
}
