import 'package:http/http.dart' as http;

import '../core/body_capture.dart';
import '../core/observed_http_response.dart';
import 'network_log_models.dart';
import 'network_logger.dart';

/// `package:http` wrapper. Streaming response bytes are forwarded as they
/// arrive; logging happens after the consumer finishes the stream.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient({
    required this.inner,
    required this.logger,
    this.shouldLog,
  });
  final http.Client inner;
  final NetworkLogger logger;
  final bool Function(http.BaseRequest request)? shouldLog;
  static const disableLoggingHeader = 'x-network-logger-disabled';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final disabled =
        request.headers.remove(disableLoggingHeader)?.toLowerCase() == 'true';
    if (disabled || !logger.isEnabled) return inner.send(request);
    if (!_shouldLog(request)) return inner.send(request);
    final started = DateTime.now();
    final parts = <NetworkMultipartPart>[];
    Object? body;
    if (request is http.Request) {
      if (logger.config.logRequestBody) {
        final captured = BodyCapture.from(
          request.bodyBytes,
          limit: logger.config.maxBodyLength * 4,
          contentType: request.headers['content-type'],
          includeBinary: false,
        );
        body = captured.omitted ? '<body omitted>' : captured.text;
      }
    } else if (request is http.MultipartRequest) {
      parts.addAll(
        request.fields.entries.map(
          (e) => NetworkMultipartPart(name: e.key, value: e.value),
        ),
      );
      parts.addAll(
        request.files.map(
          (e) => NetworkMultipartPart(
            name: e.field,
            filename: e.filename,
            length: e.length,
          ),
        ),
      );
    }
    final logRequest = NetworkRequestLog(
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: body,
      multipartParts: parts,
    );
    logger.logRequest(logRequest);
    late http.StreamedResponse response;
    try {
      response = await inner.send(request);
    } catch (error) {
      logger.logError(
        logRequest,
        NetworkErrorLog(
          message: logger.config.logErrorMessage ? error.toString() : '',
          type: error.runtimeType.toString(),
        ),
        DateTime.now().difference(started),
      );
      rethrow;
    }

    final captureBody =
        logger.config.logResponses && logger.config.logResponseBody;
    return observeHttpResponse(
      response,
      bodyLimit: logger.config.maxBodyLength * 4,
      captureBody: captureBody,
      onError: (error, _) => logger.logError(
        logRequest,
        NetworkErrorLog(
          message: logger.config.logErrorMessage ? error.toString() : '',
          type: error.runtimeType.toString(),
        ),
        DateTime.now().difference(started),
      ),
      onDone: (bytes) => logger.logResponse(
        logRequest,
        NetworkResponseLog(
          statusCode: response.statusCode,
          headers: response.headers,
          body: captureBody
              ? _decode(bytes, response.headers['content-type'])
              : null,
        ),
        DateTime.now().difference(started),
      ),
    );
  }

  bool _shouldLog(http.BaseRequest request) {
    try {
      return shouldLog?.call(request) ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  void close() => inner.close();

  Object? _decode(BoundedBodyBytes bytes, String? contentType) {
    if (bytes.omitted) return '<body omitted: exceeds log limit>';
    final body = BodyCapture.from(
      bytes.takeBytes(),
      limit: bytes.limit,
      contentType: contentType,
      includeBinary: false,
    );
    return body.omitted ? '<body omitted>' : body.text;
  }
}
