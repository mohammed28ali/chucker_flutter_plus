import '../network_logging/network_log_models.dart' as shared;
import '../network_logging/network_logger.dart' as shared;
import 'log_redactor.dart';
import 'network_log_models.dart';

typedef NetworkLogPrinter = void Function(String message);

/// Compatibility adapter for the original logger signatures.
class NetworkLogger {
  NetworkLogger({
    this.config = const NetworkLogConfig(),
    this.printer = print,
    LogRedactor? redactor,
  }) : redactor =
           redactor ??
           LogRedactor(
             sensitiveHeaders: config.sensitiveHeaders,
             sensitiveJsonKeys: config.sensitiveJsonKeys,
           );

  final NetworkLogConfig config;
  final NetworkLogPrinter printer;
  final LogRedactor redactor;

  late final shared.NetworkLogger _delegate = shared.NetworkLogger(
    config: shared.NetworkLogConfig(
      enabled: config.enabled,
      forceLogging: config.forceLogging,
      enableOnRelease: config.enableOnRelease,
      logRequests: config.logRequests,
      logResponses: config.logResponses,
      logErrors: config.logErrors,
      logTiming: config.logTiming,
      logErrorMessage: config.logErrorMessage,
      logRequestHeaders: config.logRequestHeaders,
      logRequestBody: config.logRequestBody,
      logResponseHeaders: config.logResponseHeaders,
      logResponseBody: config.logResponseBody,
      logErrorBody: config.logErrorBody,
      logCurlCommand: config.logCurlCommand,
      maxBodyLength: config.maxBodyLength,
      slowRequestThreshold: config.slowRequestThreshold,
      requestColor: config.requestColor,
      responseColor: config.responseColor,
      errorColor: config.errorColor,
      resetColor: config.resetColor,
    ),
    printer: printer,
    redactor: _LegacyRedactor(redactor),
  );

  bool get isEnabled => _delegate.isEnabled;

  void logRequest(NetworkRequestLog request) =>
      _delegate.logRequest(_request(request, DateTime.now()));

  void logResponse(
    NetworkRequestLog request,
    NetworkResponseLog response,
    Duration duration,
  ) {
    final now = DateTime.now();
    _delegate.logResponse(
      shared.NetworkResponseLog(
        request: _request(request, now.subtract(duration)),
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        completedAt: now,
      ),
    );
  }

  void logError(
    NetworkRequestLog request,
    NetworkErrorLog error,
    Duration duration,
  ) {
    final now = DateTime.now();
    _delegate.logError(
      shared.NetworkErrorLog(
        request: _request(request, now.subtract(duration)),
        error: error.message,
        type: error.type ?? 'Request failed',
        body: error.body,
        completedAt: now,
      ),
    );
  }

  String curlCommand(NetworkRequestLog request) =>
      _delegate.curlCommand(_request(request, DateTime.now()));

  shared.NetworkRequestLog _request(
    NetworkRequestLog request,
    DateTime start,
  ) => shared.NetworkRequestLog(
    method: request.method,
    url: request.url,
    headers: request.headers,
    body: request.body,
    startedAt: start,
    loggingDisabled: !request.enabled,
    multipartParts: [
      for (final part in request.multipartParts)
        shared.NetworkMultipartPart(
          name: part.name,
          value: part.value,
          fileName: part.filename,
          length: part.length,
        ),
    ],
  );
}

class _LegacyRedactor extends LogRedactor {
  _LegacyRedactor(this.delegate)
    : super(
        sensitiveHeaders: delegate.sensitiveHeaders,
        sensitiveJsonKeys: delegate.sensitiveJsonKeys,
        replacement: delegate.replacement,
      );

  final LogRedactor delegate;

  @override
  Map<String, Object?> redactHeaders(Map<String, Object?> headers) =>
      delegate.headers(headers);

  @override
  Object? redactBody(Object? value, {String? contentType}) =>
      contentType?.toLowerCase().startsWith(
            'application/x-www-form-urlencoded',
          ) ==
          true
      ? delegate.redactBody(value, contentType: contentType)
      : delegate.body(value);

  @override
  Uri redactUri(Uri uri) => delegate.redactUri(uri);
}
