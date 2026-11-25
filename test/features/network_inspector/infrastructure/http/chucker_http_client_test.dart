import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chucker_flutter_plus/chucker_flutter_plus.dart';
import 'package:chucker_flutter_plus/src/features/network_inspector/data/datasources/local/chucker_hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late _StreamingClient inner;
  late ChuckerHttpClient client;
  final url = Uri.parse(
    'https://user:pass@example.test/posts?accessToken=key&ok=1',
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('chucker_http');
    Hive.init(directory.path);
    ChuckerHive.markInitialized();
  });

  setUp(() async {
    await Inspector.init(config: const InspectorConfig(maximumBodyBytes: 128));
    await Inspector.clearLogs();
    inner = _StreamingClient();
    client = Inspector.attachHttp(inner);
  });

  tearDown(() async {
    await inner.closeStream();
    client.close();
    await Inspector.dispose();
  });

  tearDownAll(() => directory.delete(recursive: true));

  test(
    'forwards the stream and redacts completed transactions before export',
    () async {
      final response = await client
          .send(
            http.Request('POST', url)
              ..headers['authorization'] = 'Bearer hidden'
              ..headers['content-type'] = 'application/x-www-form-urlencoded'
              ..body = 'passWord=private&count=2',
          )
          .timeout(const Duration(seconds: 3));
      expect(
        (response as http.BaseResponseWithUrl).url,
        Uri.parse('https://example.test/redirected'),
      );
      expect(jsonDecode(await Inspector.exportLogs()), isEmpty);

      final body = response.stream.bytesToString();
      inner.controller
        ..add(utf8.encode('{"token":"'))
        ..add(utf8.encode('sensitive","ok":true}'));
      await inner.closeStream();
      expect(await body, '{"token":"sensitive","ok":true}');

      final history = jsonDecode(await Inspector.exportLogs()) as List;
      final record = history.single as Map;
      expect(record['statusCode'], 200);
      expect(record['url'], contains('ok=1'));
      expect(record['url'], isNot(contains('user:pass')));
      expect(record['url'], isNot(contains('=key')));
      expect(record['requestHeaders']['authorization'], contains('REDACTED'));
      expect(record['requestBody'], isNot(contains('private')));
      expect(record['responseBody'], isNot(contains('sensitive')));
      expect(record['responseBodySize'], utf8.encode(await body).length);
    },
  );

  test(
    'oversized JSON bodies are omitted without losing response bytes',
    () async {
      await Inspector.updateConfig(const InspectorConfig(maximumBodyBytes: 12));
      final response = await client.send(http.Request('GET', url));
      final body = response.stream.bytesToString();
      const payload = '{"password":"do not store this"}';
      inner.controller.add(utf8.encode(payload));
      await inner.closeStream();

      expect(await body, payload);
      final history = jsonDecode(await Inspector.exportLogs()) as List;
      final record = history.single as Map;
      expect(record['responseBody'], isNull);
      expect(record['responseBodyTruncated'], isTrue);
      expect(record['responseBodySize'], payload.length);
    },
  );

  test(
    'records stream failure with status and forwards the original error',
    () async {
      final response = await client.send(http.Request('GET', url));
      final failure = StateError('private error details');
      final assertion = expectLater(
        response.stream.toBytes(),
        throwsA(same(failure)),
      );
      inner.controller.addError(failure);
      await inner.closeStream();
      await assertion;

      final history = jsonDecode(await Inspector.exportLogs()) as List;
      final record = history.single as Map;
      expect(record['statusCode'], 200);
      expect(record['error'], 'Response stream failed (StateError)');
    },
  );

  test('a request can opt out independently of the HTTP client', () async {
    final response = await client.send(
      http.Request('GET', url)
        ..headers[ChuckerHttpClient.disableCaptureHeader] = 'true',
    );
    final drain = response.stream.drain<void>();
    await inner.closeStream();
    await drain;
    expect(
      inner.headers,
      isNot(contains(ChuckerHttpClient.disableCaptureHeader)),
    );
    expect(jsonDecode(await Inspector.exportLogs()), isEmpty);
  });
}

class _StreamingClient extends http.BaseClient {
  final controller = StreamController<List<int>>();
  Map<String, String>? headers;

  Future<void> closeStream() =>
      controller.isClosed ? Future.value() : controller.close();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    headers = Map.of(request.headers);
    return _RedirectedResponse(controller.stream);
  }
}

class _RedirectedResponse extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _RedirectedResponse(Stream<List<int>> stream)
    : super(stream, 200, headers: {'content-type': 'application/json'});

  @override
  final Uri url = Uri.parse('https://example.test/redirected');
}
