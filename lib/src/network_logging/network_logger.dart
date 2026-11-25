import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'log_redactor.dart';
import 'network_log_models.dart';

typedef NetworkLogPrinter = void Function(String message);

/// Client-independent formatter and printer for network activity.
class NetworkLogger {
  NetworkLogger({
    this.config = const NetworkLogConfig(),
    NetworkLogPrinter? printer,
    LogRedactor? redactor,
  }) : printer = printer ?? _defaultPrinter,
       redactor =
           redactor ??
           LogRedactor(
             sensitiveHeaders: config.sensitiveHeaders,
             sensitiveJsonKeys: config.sensitiveJsonKeys,
           );

  final NetworkLogConfig config;
  final NetworkLogPrinter printer;
  final LogRedactor redactor;
  // ignore: avoid_print
  static void _defaultPrinter(String message) => print(message);
  bool get isEnabled =>
      config.forceLogging ||
      (config.enabled && (kDebugMode || config.enableOnRelease));

  void logRequest(NetworkRequestLog request) => _safe(() {
    if (!isEnabled || request.loggingDisabled || !config.logRequests) return;
    final b = StringBuffer(
      '${config.requestColor}┌─ ${request.method} ${redactor.redactUri(request.url)}\n',
    );
    if (config.logCurlCommand) b.writeln('│ cURL: ${curlCommand(request)}');
    if (config.logRequestHeaders) {
      b.writeln('│ Headers: ${_json(redactor.redactHeaders(request.headers))}');
    }
    if (config.logRequestBody) {
      b.writeln('│ Body: ${_formatBody(request.body, request.headers)}');
      if (request.multipartParts.isNotEmpty) {
        b.writeln('│ Multipart: ${_json(_multipart(request.multipartParts))}');
      }
    }
    b.write('└─${config.resetColor}');
    printer(b.toString());
  });

  void logResponse(NetworkResponseLog response) => _safe(() {
    if (!isEnabled ||
        response.request.loggingDisabled ||
        !config.logResponses) {
      return;
    }
    final status = response.statusCode;
    final duration = response.duration;
    final color = status >= 500
        ? config.errorColor
        : status >= 400
        ? '\x1B[33m'
        : status >= 300
        ? '\x1B[36m'
        : config.responseColor;
    final b = StringBuffer(
      '$color┌─ ${response.request.method} ${redactor.redactUri(response.request.url)} [$status]${_timing(duration)}\n',
    );
    if (duration >= config.slowRequestThreshold) {
      b.writeln(
        '│ SLOW REQUEST (>${config.slowRequestThreshold.inMilliseconds}ms)',
      );
    }
    if (config.logResponseHeaders) {
      b.writeln(
        '│ Headers: ${_json(redactor.redactHeaders(response.headers))}',
      );
    }
    if (config.logResponseBody) {
      b.writeln('│ Body: ${_formatBody(response.body, response.headers)}');
    }
    b.write('└─${config.resetColor}');
    printer(b.toString());
  });

  void logError(NetworkErrorLog error) => _safe(() {
    if (!isEnabled || error.request.loggingDisabled || !config.logErrors) {
      return;
    }
    final duration = error.duration;
    final b = StringBuffer(
      '${config.errorColor}┌─ ${error.request.method} ${redactor.redactUri(error.request.url)} ERROR ${error.statusCode ?? ''}${_timing(duration)}\n',
    );
    final message = config.logErrorMessage ? ': ${error.error}' : '';
    b.writeln('│ ${error.type ?? error.error.runtimeType}$message');
    if (config.logResponseHeaders && error.headers.isNotEmpty) {
      b.writeln('│ Headers: ${_json(redactor.redactHeaders(error.headers))}');
    }
    if (config.logErrorBody) {
      b.writeln('│ Body: ${_formatBody(error.body, error.headers)}');
    }
    if (duration >= config.slowRequestThreshold) {
      b.writeln(
        '│ SLOW REQUEST (>${config.slowRequestThreshold.inMilliseconds}ms)',
      );
    }
    b.write('└─${config.resetColor}');
    printer(b.toString());
  });

  String curlCommand(NetworkRequestLog request) {
    final parts = <String>['curl', '-X', _quote(request.method)];
    if (config.logRequestHeaders) {
      for (final entry in redactor.redactHeaders(request.headers).entries) {
        if (const {
          'content-length',
          'transfer-encoding',
        }.contains(entry.key.toLowerCase())) {
          continue;
        }
        parts.addAll(['-H', _quote('${entry.key}: ${entry.value}')]);
      }
    }
    if (config.logRequestBody &&
        request.body != null &&
        request.multipartParts.isEmpty) {
      final text = _preparedBody(request.body, request.headers, pretty: false);
      if (text.length <= config.maxBodyLength &&
          request.body is! Stream &&
          request.body is! List<int>) {
        parts.addAll(['--data-raw', _quote(text)]);
      }
    }
    if (config.logRequestBody) {
      for (final part in request.multipartParts) {
        final sensitive = redactor.isSensitiveKey(part.name);
        final file = !sensitive && part.fileName != null;
        final value = sensitive
            ? redactor.replacement
            : file
            ? '@${part.fileName}'
            : _preparedBody(part.value, const {}, pretty: false);
        if (value.length <= config.maxBodyLength) {
          parts.addAll([
            file ? '-F' : '--form-string',
            _quote('${part.name}=$value'),
          ]);
        }
      }
    }
    parts.add(_quote(redactor.redactUri(request.url).toString()));
    return parts.join(' ');
  }

  String _formatBody(Object? value, Map<String, Object?> headers) {
    if (value == null) return '<empty>';
    final text = _preparedBody(value, headers);
    if (text.length <= config.maxBodyLength) return text;
    return '${text.substring(0, config.maxBodyLength)}… [truncated ${text.length - config.maxBodyLength} chars]';
  }

  String _preparedBody(
    Object? value,
    Map<String, Object?> headers, {
    bool pretty = true,
  }) {
    if (value is Stream) return '<stream body omitted>';
    if (value is List<int>) return '<${value.length} binary bytes>';
    String? type;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') {
        final header = entry.value;
        type = header is Iterable
            ? header.firstOrNull?.toString()
            : header?.toString();
        break;
      }
    }
    final redacted = redactor.redactBody(value, contentType: type);
    return redacted is String
        ? redacted
        : pretty
        ? _json(redacted)
        : jsonEncode(redacted);
  }

  String _timing(Duration duration) =>
      config.logTiming ? ' ${duration.inMilliseconds}ms' : '';

  String _json(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  List<Map<String, Object?>> _multipart(List<NetworkMultipartPart> parts) => [
    for (final part in parts)
      {
        'name': part.name,
        if (redactor.isSensitiveKey(part.name))
          'value': redactor.replacement
        else ...{
          if (part.value != null) 'value': _formatBody(part.value, const {}),
          if (part.fileName != null) 'fileName': part.fileName,
          if (part.contentType != null) 'contentType': part.contentType,
          if (part.length != null) 'length': part.length,
        },
      },
  ];
  void _safe(void Function() action) {
    try {
      action();
    } catch (_) {
      /* Logging must not affect requests. */
    }
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
}
