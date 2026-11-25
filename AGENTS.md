# Agent instructions

## Project map

- `lib/chucker_flutter_plus.dart` exports the inspector API and the original console logger API. Keep `Inspector` and `ChuckerFlutterPlus` integrations compatible where practical.
- `lib/src/features/network_inspector/` contains the inspector UI, transaction models, Hive storage, Dio and `package:http` capture adapters, and notification service.
- `lib/src/network_logging/` contains shared console formatting and redaction plus the Dio, Chopper, and `package:http` adapters used by `network_logger.dart` and its client-specific companions. `lib/src/network_logger/` adapts the original logger API to the shared implementation. Check both public APIs when changing logging behavior.
- `lib/src/core/body_capture.dart` and `lib/src/core/observed_http_response.dart` provide bounded body collection and HTTP stream observation. Reuse them when extending capture or logging.
- `example/lib/main.dart` configures the inspector and its navigator key. `example/lib/core/di/dependency_injection.dart` wires the demo clients. `README.md` documents the public setup and supported platforms.

## Implementation constraints

- Check `pubspec.yaml` before using newer SDK or dependency APIs. The current minimums are Flutter 3.47.2 and Dart 3.13.2.
- Keep inspector capture and console logging independently configurable. Preserve existing import paths and opt-out controls. Update the README and example when public setup changes.
- Treat transaction data, console output, exports, and cURL commands as sensitive. Redact credentials before writing or sharing, and preserve body limits, retention, and debug-only defaults. Use synthetic data in tests.
- Preserve stream bytes, errors, and response metadata. Keep diagnostic failures from changing the caller's network result. Test stream changes with fake clients and local streams.
- Keep system notifications opt-in through `Inspector.init`. Verify lifecycle routing and permission handling with mocks, and distinguish mocked coverage from native device verification. Web and Windows use in-app banners.
- Keep changes scoped. Leave machine-specific files and generated runner files out of the diff unless the task requires them.

## Verification

From the repository root, resolve dependencies, format the Dart files you changed, then run analysis and tests.

```sh
flutter pub get
dart format <changed-dart-files>
flutter analyze
flutter test
```

Use `flutter test test/path/to/file_test.dart` for a focused run during development. For example-specific changes, also run `flutter pub get` and `flutter analyze` from `example/`. Check `git diff --check` before handing off, and report any checks you could not run.
