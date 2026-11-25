import 'dart:convert';
import 'dart:typed_data';

import '../network_logging/log_redactor.dart';

class BodyCapture {
  const BodyCapture({this.text, this.size = 0, this.omitted = false});

  final String? text;
  final int size;
  final bool omitted;

  factory BodyCapture.from(
    Object? value, {
    required int limit,
    String? contentType,
    int? declaredSize,
    bool includeBinary = true,
  }) {
    if (value == null) return BodyCapture(size: declaredSize ?? 0);
    if (value is List<int>) {
      if (value.isEmpty) return const BodyCapture();
      if (limit == 0 || value.length > limit) {
        return BodyCapture(size: value.length, omitted: true);
      }
      if (!_isText(contentType)) {
        final length = value.length;
        return includeBinary && ((length + 2) ~/ 3) * 4 <= limit
            ? BodyCapture(text: base64Encode(value), size: length)
            : BodyCapture(size: length, omitted: true);
      }
      try {
        final charsets = RegExp(
          r'charset\s*=\s*"?([^;"\s]+)',
          caseSensitive: false,
        );
        final name = charsets.firstMatch(contentType ?? '')?.group(1);
        final encoding = name == null ? utf8 : Encoding.getByName(name) ?? utf8;
        return BodyCapture(text: encoding.decode(value), size: value.length);
      } on FormatException {
        return BodyCapture(size: value.length, omitted: true);
      }
    }
    if (value is Stream || limit == 0 || (declaredSize ?? 0) > limit) {
      return BodyCapture(size: declaredSize ?? 0, omitted: true);
    }
    if (value is String) {
      final size = utf8Size(value);
      return size <= limit
          ? BodyCapture(text: value, size: size)
          : BodyCapture(size: size, omitted: true);
    }
    final output = _BoundedJsonSink(limit);
    try {
      final conversion = JsonUtf8Encoder(
        null,
        null,
        1024,
      ).startChunkedConversion(output);
      conversion.add(value);
      conversion.close();
      return BodyCapture(
        text: utf8.decode(output.buffer.takeBytes()),
        size: output.size,
      );
    } catch (_) {
      return BodyCapture(size: declaredSize ?? 0, omitted: true);
    }
  }

  static bool _isText(String? type) {
    final mime = type?.toLowerCase() ?? '';
    return mime.isEmpty ||
        mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('javascript') ||
        mime.contains('x-www-form-urlencoded');
  }

  static int utf8Size(String value) {
    var bytes = 0;
    for (final rune in value.runes) {
      bytes += rune < 0x80
          ? 1
          : rune < 0x800
          ? 2
          : rune < 0x10000
          ? 3
          : 4;
    }
    return bytes;
  }

  static Map<String, String> redact(
    Map<String, String> headers,
    LogRedactor redactor,
  ) => Map.unmodifiable(
    redactor
        .redactHeaders(headers)
        .map((key, value) => MapEntry(key, '$value')),
  );
}

class _BoundedJsonSink implements Sink<List<int>> {
  _BoundedJsonSink(this.limit);
  final int limit;
  final buffer = BytesBuilder();
  int size = 0;

  @override
  void add(List<int> chunk) {
    size += chunk.length;
    if (size > limit) throw const FormatException('Body exceeds capture limit');
    buffer.add(chunk);
  }

  @override
  void close() {}
}

/// Collects a complete body within the cap. Oversized prefixes are discarded
/// so a partial JSON or form body can never bypass structural redaction.
class BoundedBodyBytes {
  BoundedBodyBytes(this.limit);
  final int limit;
  final _bytes = BytesBuilder();
  int size = 0;
  bool get omitted => size > limit;

  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    size += chunk.length;
    if (omitted) {
      _bytes.clear();
    } else {
      _bytes.add(chunk);
    }
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}
