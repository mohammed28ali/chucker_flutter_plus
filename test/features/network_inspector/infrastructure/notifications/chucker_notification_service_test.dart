import 'dart:io';

import 'package:chucker_flutter_plus/chucker_flutter_plus.dart';
import 'package:chucker_flutter_plus/src/features/network_inspector/infrastructure/notifications/chucker_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;
  late List<MethodCall> recordedCalls;

  NetworkTransaction sampleTransaction() {
    final now = DateTime.utc(2026, 1, 1);
    return NetworkTransaction(
      id: 'tx-1',
      startedAt: now,
      completedAt: now.add(const Duration(milliseconds: 25)),
      method: 'GET',
      uri: Uri.parse('https://example.com/items'),
      statusCode: 200,
      requestHeaders: const {},
      responseHeaders: const {},
    );
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chucker_notif_test');
  });

  setUp(() {
    recordedCalls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDir.path;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void mockNotificationsChannel({
    Set<String> validIcons = const {'@mipmap/ic_launcher'},
    Map<String, Object?>? launchDetails,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          recordedCalls.add(call);
          switch (call.method) {
            case 'initialize':
              final args = Map<Object?, Object?>.from(
                call.arguments as Map<Object?, Object?>,
              );
              final defaultIcon = args['defaultIcon'] as String?;
              if (defaultIcon == null || !validIcons.contains(defaultIcon)) {
                throw PlatformException(
                  code: 'invalid_icon',
                  message:
                      'The resource $defaultIcon could not be found. '
                      'Please make sure it has been added as a drawable '
                      'resource to your Android head project.',
                );
              }
              return true;
            case 'getNotificationAppLaunchDetails':
              return launchDetails ??
                  <String, Object?>{'notificationLaunchedApp': false};
            case 'requestNotificationsPermission':
              return true;
            case 'show':
              return null;
          }
          return null;
        });
  }

  test('uses @mipmap/ic_launcher by default on Android', () async {
    mockNotificationsChannel();
    final service = ChuckerNotificationService();

    final initialized = await service.initialize();

    expect(initialized, isTrue);
    expect(service.isInitialized, isTrue);
    final initCall = recordedCalls.firstWhere((c) => c.method == 'initialize');
    final args = Map<Object?, Object?>.from(
      initCall.arguments as Map<Object?, Object?>,
    );
    expect(args['defaultIcon'], '@mipmap/ic_launcher');

    await service.show(sampleTransaction());
    expect(recordedCalls.any((c) => c.method == 'show'), isTrue);
  });

  test('supports configuring a custom Android notification icon', () async {
    mockNotificationsChannel(validIcons: {'ic_stat_chucker'});

    await Inspector.init(
      config: const InspectorConfig(
        showStatusBarNotification: true,
        androidNotificationIcon: 'ic_stat_chucker',
      ),
    );

    final initCall = recordedCalls.firstWhere((c) => c.method == 'initialize');
    final args = Map<Object?, Object?>.from(
      initCall.arguments as Map<Object?, Object?>,
    );
    expect(args['defaultIcon'], 'ic_stat_chucker');
  });

  test('rejects empty Android notification icon configuration', () async {
    mockNotificationsChannel();
    final service = ChuckerNotificationService();

    await expectLater(
      () => service.initialize(androidIcon: '   '),
      throwsArgumentError,
    );
  });

  test('handles missing Android icon gracefully without throwing', () async {
    mockNotificationsChannel(validIcons: const {});
    final service = ChuckerNotificationService();

    final initialized = await service.initialize();

    expect(initialized, isFalse);
    expect(service.isInitialized, isFalse);

    await service.show(sampleTransaction());
    expect(recordedCalls.any((c) => c.method == 'show'), isFalse);
  });

  test(
    'ChuckerFlutterPlus.initialize does not throw when Android icon is missing',
    () async {
      mockNotificationsChannel(validIcons: const {});

      await expectLater(
        ChuckerFlutterPlus.initialize(
          enableNotifications: true,
          androidNotificationIcon: 'missing_icon',
        ),
        completes,
      );
    },
  );

  test('routes launch notification payload when initialized', () async {
    mockNotificationsChannel(
      launchDetails: <String, Object?>{
        'notificationLaunchedApp': true,
        'notificationResponse': <String, Object?>{
          'notificationResponseType': 0,
          'payload': 'chucker:req-42',
        },
      },
    );
    String? selectedId;
    final service = ChuckerNotificationService(
      onRequestSelected: (id) => selectedId = id,
    );

    final initialized = await service.initialize();

    expect(initialized, isTrue);
    expect(selectedId, 'req-42');
  });
}
