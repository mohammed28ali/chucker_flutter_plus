import 'dart:async';

import 'package:http/http.dart' as http;

import 'body_capture.dart';

/// Observes a response at consumption time and preserves its stream and
/// the final URL supplied by redirect-aware clients.
http.StreamedResponse observeHttpResponse(
  http.StreamedResponse response, {
  required int bodyLimit,
  bool captureBody = true,
  required void Function(BoundedBodyBytes bytes) onDone,
  required void Function(Object error, BoundedBodyBytes bytes) onError,
}) {
  final bytes = BoundedBodyBytes(bodyLimit);
  var failed = false;
  final stream = response.stream.transform(
    StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        if (!failed && captureBody) bytes.add(chunk);
        sink.add(chunk);
      },
      handleError: (error, stack, sink) {
        if (!failed) {
          failed = true;
          try {
            onError(error, bytes);
          } catch (_) {
            // A diagnostic failure must preserve the caller's original error.
          }
        }
        sink.addError(error, stack);
      },
      handleDone: (sink) {
        try {
          if (!failed) onDone(bytes);
        } catch (_) {
          // A diagnostic failure must still end the caller's stream.
        }
        sink.close();
      },
    ),
  );

  if (response case http.BaseResponseWithUrl(:final url)) {
    return _StreamedResponseWithUrl(response, stream, url);
  }
  return _ObservedStreamedResponse(response, stream);
}

class _ObservedStreamedResponse extends http.StreamedResponse {
  _ObservedStreamedResponse(
    http.StreamedResponse response,
    Stream<List<int>> stream,
  ) : super(
        stream,
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
}

class _StreamedResponseWithUrl extends _ObservedStreamedResponse
    implements http.BaseResponseWithUrl {
  _StreamedResponseWithUrl(super.response, super.stream, this.url);

  @override
  final Uri url;
}
