import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/network_transaction.dart';

class ChuckerNotificationService {
  /// Default Android notification icon using the standard Flutter launcher
  /// mipmap resource (`android/app/src/main/res/mipmap-*/ic_launcher.png`).
  static const defaultAndroidIcon = '@mipmap/ic_launcher';

  ChuckerNotificationService({
    this.onRequestSelected,
    this.onUnrecognizedPayload,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'chucker_network';
  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String requestId)? onRequestSelected;
  final void Function(String? payload)? onUnrecognizedPayload;
  bool _initialized = false;
  bool get isInitialized => _initialized;
  int _count = 0;
  int _ok = 0;
  int _failed = 0;

  /// Initializes platform notification plugins.
  ///
  /// On Android, [androidIcon] must reference a drawable resource name (for
  /// example `'ic_stat_notify'` in `android/app/src/main/res/drawable/`) or a
  /// mipmap resource prefixed with `@mipmap/` (such as [defaultAndroidIcon]).
  ///
  /// Returns `true` if initialization succeeded, or `false` if the Android
  /// icon resource could not be resolved or platform initialization failed.
  Future<bool> initialize({
    String channelName = 'Network inspector',
    String androidIcon = defaultAndroidIcon,
  }) async {
    if (androidIcon.trim().isEmpty) {
      throw ArgumentError.value(
        androidIcon,
        'androidIcon',
        'Must not be empty.',
      );
    }
    _initialized = false;
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings(androidIcon),
          iOS: const DarwinInitializationSettings(),
          macOS: const DarwinInitializationSettings(),
          linux: const LinuxInitializationSettings(
            defaultActionName: 'Open inspector',
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _route(response.payload),
      );
    } on PlatformException catch (error) {
      if (error.code == 'invalid_icon') {
        debugPrint(
          'ChuckerFlutterPlus: Android notification icon "$androidIcon" was '
          'not found. Status bar notifications are disabled. Add the resource '
          'under android/app/src/main/res/drawable/ (or res/mipmap-*/ with '
          '@mipmap/<name>) or pass androidNotificationIcon during '
          'initialization. (${error.message})',
        );
      } else {
        debugPrint(
          'ChuckerFlutterPlus: Failed to initialize notifications '
          '(${error.code}): ${error.message}',
        );
      }
      return false;
    }

    _initialized = true;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      _route(details?.notificationResponse?.payload);
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return true;
  }

  Future<void> show(
    NetworkTransaction transaction, {
    String channelName = 'Network inspector',
  }) async {
    if (!_initialized) return;
    _count++;
    transaction.succeeded ? _ok++ : _failed++;
    final text = '$_count requests: $_ok OK, $_failed failed';
    await _plugin.show(
      id: 7101,
      title: 'Network activity',
      body: text,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          channelName,
          channelDescription: 'Captured network requests',
          groupKey: _channelId,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
        linux: const LinuxNotificationDetails(),
      ),
      payload: 'chucker:${transaction.id}',
    );
  }

  void _route(String? payload) {
    if (payload?.startsWith('chucker:') ?? false) {
      onRequestSelected?.call(payload!.substring('chucker:'.length));
    } else {
      onUnrecognizedPayload?.call(payload);
    }
  }
}
