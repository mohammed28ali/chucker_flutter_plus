import '../network_logging/log_redactor.dart';

/// Client-independent description of an outgoing HTTP request.
class NetworkRequestLog {
  const NetworkRequestLog({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.multipartParts = const [],
    this.enabled = true,
  });

  final String method;
  final Uri url;
  final Map<String, Object?> headers;
  final Object? body;
  final List<NetworkMultipartPart> multipartParts;

  /// Set false to suppress logging for this request.
  final bool enabled;
}

/// Multipart metadata that can be safely logged without depending on a client.
class NetworkMultipartPart {
  const NetworkMultipartPart({
    required this.name,
    this.value,
    this.filename,
    this.length,
  });
  final String name;
  final Object? value;
  final String? filename;
  final int? length;
}

/// Client-independent description of an HTTP response.
class NetworkResponseLog {
  const NetworkResponseLog({
    required this.statusCode,
    this.headers = const {},
    this.body,
  });
  final int statusCode;
  final Map<String, Object?> headers;
  final Object? body;
}

/// Client-independent description of a request failure.
class NetworkErrorLog {
  const NetworkErrorLog({required this.message, this.type, this.body});
  final String message;
  final String? type;
  final Object? body;
}

/// Shared behavior for [NetworkLogger].
class NetworkLogConfig {
  const NetworkLogConfig({
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponseHeaders = true,
    this.logResponseBody = true,
    this.logErrorBody = true,
    this.logRequests = true,
    this.logResponses = true,
    this.logErrors = true,
    this.logTiming = true,
    this.logErrorMessage = false,
    this.logCurlCommand = true,
    this.enabled = true,
    this.forceLogging = false,
    this.enableOnRelease = false,
    this.maxBodyLength = 4000,
    this.slowRequestThreshold = const Duration(seconds: 10),
    this.sensitiveHeaders = LogRedactor.defaultSensitiveHeaders,
    this.sensitiveJsonKeys = LogRedactor.defaultSensitiveKeys,
    this.requestColor = '\x1B[36m',
    this.responseColor = '\x1B[32m',
    this.errorColor = '\x1B[31m',
    this.resetColor = '\x1B[0m',
  }) : assert(maxBodyLength >= 0);

  final bool logRequestHeaders,
      logRequestBody,
      logResponseHeaders,
      logResponseBody,
      logErrorBody,
      logCurlCommand,
      enabled,
      forceLogging,
      enableOnRelease;
  final bool logRequests, logResponses, logErrors, logTiming, logErrorMessage;
  final int maxBodyLength;
  final Duration slowRequestThreshold;
  final Set<String> sensitiveHeaders, sensitiveJsonKeys;
  final String requestColor, responseColor, errorColor, resetColor;
}
