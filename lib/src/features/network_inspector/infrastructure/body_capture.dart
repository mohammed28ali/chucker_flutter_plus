import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class BodyCapture {
  static const multipartPreviewPrefix = 'CHUCKER_MULTIPART_PREVIEW:';
  static const maximumMultipartPreviewBytes = 256 * 1024;

  static String? raw(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List<int>) return base64Encode(value);
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  static int size(Object? value, String? rawValue) {
    if (value is Uint8List || value is List<int>) {
      return (value as List<int>).length;
    }
    return rawValue == null ? 0 : utf8.encode(rawValue).length;
  }

  static Future<String?> multipartBody(Object? value) async {
    if (value is! FormData) return raw(value);
    final entries = <Map<String, Object?>>[];
    for (final field in value.fields) {
      entries.add({'kind': 'field', 'name': field.key, 'value': field.value});
    }
    for (final entry in value.files) {
      final file = entry.value;
      List<int>? bytes;
      if (file.length <= maximumMultipartPreviewBytes && !file.isFinalized) {
        try {
          final builder = BytesBuilder(copy: false);
          await for (final chunk in file.clone().finalize()) {
            builder.add(chunk);
          }
          bytes = builder.takeBytes();
        } catch (_) {
          bytes = null;
        }
      }
      entries.add({
        'kind': 'file',
        'name': entry.key,
        'filename': file.filename,
        'contentType':
            file.contentType?.toString() ?? 'application/octet-stream',
        'size': file.length,
        if (bytes != null) 'base64': base64Encode(bytes),
      });
    }
    return '$multipartPreviewPrefix${jsonEncode(entries)}';
  }

  static Map<String, String> redact(
    Map<String, String> headers,
    Set<String> sensitive,
  ) => Map.unmodifiable(
    headers.map(
      (key, value) => MapEntry(
        key,
        sensitive.contains(key.toLowerCase()) ? '██REDACTED██' : value,
      ),
    ),
  );
}
