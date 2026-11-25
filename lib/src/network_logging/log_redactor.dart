import 'dart:convert';

/// Redacts common secrets from headers, URLs and structured bodies.
class LogRedactor {
  const LogRedactor({
    this.sensitiveHeaders = defaultSensitiveHeaders,
    this.sensitiveJsonKeys = defaultSensitiveKeys,
    this.replacement = '[REDACTED]',
  });

  static const defaultSensitiveHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'api-key',
    'x-auth-token',
    'x-access-token',
  };
  static const defaultSensitiveKeys = {
    'password',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'secret',
    'client_secret',
    'authorization',
    'api_key',
    'x-api-key',
    'session_id',
    'session_token',
    'signature',
    'sig',
    'x-amz-signature',
    'x-amz-credential',
    'x-amz-security-token',
  };

  final Set<String> sensitiveHeaders;
  final Set<String> sensitiveJsonKeys;
  final String replacement;

  bool isSensitiveKey(String key) =>
      _contains(sensitiveJsonKeys, key) ||
      _nestedKeys
          .allMatches(key)
          .any((match) => _contains(sensitiveJsonKeys, match.group(1)!));

  static final _nestedKeys = RegExp(r'\[([^\[\]]+)\]');

  // The original logger API exposes these names.
  Map<String, Object?> headers(Map<String, Object?> input) =>
      redactHeaders(input);
  Object? body(Object? input) => redactBody(input);

  Map<String, Object?> redactHeaders(Map<String, Object?> headers) => {
    for (final entry in headers.entries)
      entry.key: _contains(sensitiveHeaders, entry.key)
          ? replacement
          : _redactHeaderValue(entry.key, entry.value),
  };

  Object? _redactHeaderValue(String key, Object? value) {
    if (const {
      'location',
      'contentlocation',
      'referer',
      'referrer',
    }.contains(_normalize(key))) {
      if (value is Iterable) {
        return value.map((item) => _redactHeaderValue(key, item)).toList();
      }
      if (value is String) {
        final uri = Uri.tryParse(value);
        return uri == null ? replacement : redactUri(uri).toString();
      }
    }
    return redactValue(value);
  }

  Uri redactUri(Uri uri) {
    final query = uri.queryParametersAll;
    final redactQuery = query.keys.any(isSensitiveKey);
    if (uri.userInfo.isEmpty && !uri.hasFragment && !redactQuery) return uri;
    return uri.replace(
      userInfo: '',
      fragment: uri.hasFragment ? replacement : null,
      queryParameters: redactQuery
          ? query.map(
              (key, values) => MapEntry(
                key,
                isSensitiveKey(key)
                    ? List.filled(values.length, replacement)
                    : values,
              ),
            )
          : null,
    );
  }

  /// Parses JSON and URL-encoded forms before redacting nested fields.
  Object? redactBody(Object? value, {String? contentType}) {
    if (value is String) {
      final mediaType = contentType?.split(';').first.trim().toLowerCase();
      if (mediaType == 'application/x-www-form-urlencoded') {
        try {
          return Uri(
            queryParameters: Uri(query: value).queryParametersAll.map(
              (key, values) => MapEntry(
                key,
                isSensitiveKey(key)
                    ? List.filled(values.length, replacement)
                    : values,
              ),
            ),
          ).query;
        } on FormatException {
          return '<invalid form body omitted>';
        }
      }
      final trimmed = value.trimLeft();
      if (mediaType == 'application/json' ||
          (mediaType?.endsWith('+json') ?? false) ||
          trimmed.startsWith('{') ||
          trimmed.startsWith('[')) {
        try {
          return redactValue(jsonDecode(value));
        } on FormatException {
          return '<invalid JSON body omitted>';
        }
      }
    }
    return redactValue(value);
  }

  Object? redactValue(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): isSensitiveKey(entry.key.toString())
              ? replacement
              : redactValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(redactValue).toList(growable: false);
    }
    return value;
  }

  bool _contains(Set<String> values, String candidate) {
    final normalized = _normalize(candidate);
    return values.any((value) => _normalize(value) == normalized);
  }

  static final _separators = RegExp('[^a-z0-9]');
  String _normalize(String value) =>
      value.toLowerCase().replaceAll(_separators, '');
}
