import 'dart:convert';

import 'package:chucker_flutter_plus/src/features/network_inspector/infrastructure/body_capture.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures multipart fields and multiple file previews', () async {
    final form = FormData()
      ..fields.addAll([
        const MapEntry('caption', 'Vacation'),
        const MapEntry('album', 'summer'),
      ])
      ..files.addAll([
        MapEntry(
          'photos',
          MultipartFile.fromBytes(
            [1, 2, 3],
            filename: 'first.png',
            contentType: DioMediaType('image', 'png'),
          ),
        ),
        MapEntry(
          'photos',
          MultipartFile.fromBytes(
            [4, 5],
            filename: 'second.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ),
      ]);

    final raw = await BodyCapture.multipartBody(form);

    expect(raw, startsWith(BodyCapture.multipartPreviewPrefix));
    final entries =
        jsonDecode(raw!.substring(BodyCapture.multipartPreviewPrefix.length))
            as List<dynamic>;
    expect(entries.where((entry) => entry['kind'] == 'field'), hasLength(2));
    final files = entries.where((entry) => entry['kind'] == 'file').toList();
    expect(files, hasLength(2));
    expect(files.first['filename'], 'first.png');
    expect(files.first['base64'], base64Encode([1, 2, 3]));
    expect(files.last['filename'], 'second.jpg');
  });

  test('does not retain preview bytes above the configured limit', () async {
    final form = FormData()
      ..files.add(
        MapEntry(
          'video',
          MultipartFile.fromBytes(
            List<int>.filled(BodyCapture.maximumMultipartPreviewBytes + 1, 0),
            filename: 'large.mp4',
            contentType: DioMediaType('video', 'mp4'),
          ),
        ),
      );

    final raw = await BodyCapture.multipartBody(form);
    final entries =
        jsonDecode(raw!.substring(BodyCapture.multipartPreviewPrefix.length))
            as List<dynamic>;

    expect(
      entries.single['size'],
      BodyCapture.maximumMultipartPreviewBytes + 1,
    );
    expect(entries.single.containsKey('base64'), isFalse);
  });
}
