# Chucker Flutter Plus

![Chucker Flutter Plus feature banner](https://raw.githubusercontent.com/mohammed28ali/chucker_flutter_plus/main/assets/images/chucker_flutter_plus_banner.png)

Capture and inspect HTTP traffic inside your Flutter app. Chucker Flutter Plus
stores a bounded local request history, shows in-app banners, and can post
optional system notifications. It supports Dio and `package:http` capture, plus
a separate console logger for Dio, Chopper, and `package:http`.


## Install

```sh
flutter pub add chucker_flutter_plus
```

## Capture requests

Initialize the inspector once before `runApp`. Add its navigator observer to
your `MaterialApp` so in-app banners can attach to the app overlay and
notification taps can open the selected request.

```dart
import 'package:chucker_flutter_plus/chucker_flutter_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChuckerFlutterPlus.initialize(
    maximumEntries: 200,
    retention: const Duration(days: 7),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [ChuckerFlutterPlus.navigatorObserver],
    home: const HomePage(),
  );
}

final dio = Dio()..interceptors.add(ChuckerDioInterceptor());
```

For `package:http`, wrap a client:

```dart
import 'package:chucker_flutter_plus/chucker_flutter_plus.dart';
import 'package:http/http.dart' as http;

final client = ChuckerHttpClient(http.Client());
final response = await client.get(Uri.parse('https://example.com/items'));
```

`ChuckerHttpClient` buffers each response before returning it so the inspector
can save the response body, then returns the response bytes to the caller.

### Open the inspector

Add the built-in button to a widget:

```dart
ChuckerFlutterPlus.button()
```

Or open the inspector directly. Pass a request ID to open that request's
details page:

```dart
ChuckerFlutterPlus.showInspector(context);
ChuckerFlutterPlus.showInspector(context, requestId);
```

Use `ChuckerFlutterPlus.hideInspector()` to close it. The inspector also
provides methods to clear history and export it as JSON:

```dart
await ChuckerFlutterPlus.clearLogs();
final json = await ChuckerFlutterPlus.exportLogs();
```

## Notifications

In-app banners appear while the app is in the foreground. Enable system
notifications during initialization if you also want OS notifications when
the app is in the background:

```dart
await ChuckerFlutterPlus.initialize(
  enableNotifications: true,
);
```

For more control, configure both notification types with `Inspector`:

```dart
await Inspector.init(
  config: const InspectorConfig(
    showInAppNotification: true,
    showStatusBarNotification: true,
    statusBarWhileForeground: false,
    inAppNotificationDuration: Duration(seconds: 3),
    inAppNotificationPosition: BannerPosition.top,
    notifyOnlyOnError: false,
    maximumEntries: 200,
  ),
);
```

On Android 13 and later, add the notification permission to the host app's
`android/app/src/main/AndroidManifest.xml`; the package also requests runtime
permission during initialization:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Android notifications use the package's fixed Chucker notification icon. iOS
uses the app icon and requests notification permission during initialization.
Tapping a Chucker system notification opens the inspector at the matching
request.

## Console logging

`NetworkLogger` is independent from inspector capture. Create one instance and
share it across your network clients. Logging is enabled in debug builds by
default; use `forceLogging: true` to enable it in release builds.

```dart
import 'package:flutter/foundation.dart';
import 'package:chucker_flutter_plus/network_logger.dart';

final logger = NetworkLogger(
  config: const NetworkLogConfig(
    logRequestHeaders: true,
    logRequestBody: true,
    logResponseHeaders: true,
    logResponseBody: true,
    logErrorBody: true,
    logCurlCommand: true,
    maxBodyLength: 4000,
    slowRequestThreshold: Duration(seconds: 3),
  ),
  printer: debugPrint,
);
```

Use the matching adapter for each client:

```dart
import 'package:chopper/chopper.dart' as chopper;
import 'package:chucker_flutter_plus/dio_network_logger.dart';
import 'package:chucker_flutter_plus/chopper_network_logger.dart';
import 'package:chucker_flutter_plus/http_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

final dio = Dio()
  ..interceptors.add(DioNetworkLoggerInterceptor(logger: logger));

final chopper = ChopperClient(
  interceptors: [ChopperNetworkLoggerInterceptor(logger: logger)],
);

final loggedHttp = LoggingHttpClient(
  inner: http.Client(),
  logger: logger,
);
```

The console logger redacts common credential headers and sensitive JSON keys
by default. Customize them with `NetworkLogConfig.sensitiveHeaders`,
`NetworkLogConfig.sensitiveJsonKeys`, or a `LogRedactor`:

```dart
final logger = NetworkLogger(
  redactor: const LogRedactor(
    sensitiveHeaders: {'authorization', 'x-session-id'},
    sensitiveJsonKeys: {'password', 'access_token', 'private_note'},
  ),
);
```

Disable logging for an individual request with the adapter's control:

```dart
// Dio
dio.get('/private', options: Options(extra: {
  DioNetworkLoggerInterceptor.disableLoggingExtraKey: true,
}));

// Chopper
final privateChopperRequest = chopper.Request(
  'GET',
  Uri.parse('/private'),
  Uri.parse('https://api.example.com'),
  tag: const NetworkLoggerDisabled(),
);

// package:http: the control header is removed before sending.
final privateHttpRequest = http.Request('GET', uri)
  ..headers[LoggingHttpClient.disableLoggingHeader] = 'true';
```

`LoggingHttpClient` preserves response streaming and logs after the stream is
read. It does not consume a `StreamedRequest` body to inspect it.

## Privacy and retention

Inspector capture is enabled in debug builds by default. Set
`enableOnRelease: true` during initialization, or call
`ChuckerFlutterPlus.configure(enableOnRelease: true)`, to enable capture in
release builds. Set `maximumEntries` and `retention` to bound local history.

Request headers are redacted before storage. The defaults cover `Authorization`,
`Cookie`, and `Set-Cookie`; configure additional headers with `redactHeaders`:

```dart
await ChuckerFlutterPlus.initialize(
  redactHeaders: {'authorization', 'cookie', 'x-api-key'},
);
```

Request and response bodies are stored for inspection. Review the data your app
sends before enabling capture or console logging in production.

## Development

```sh
dart format .
flutter analyze
flutter test
```
