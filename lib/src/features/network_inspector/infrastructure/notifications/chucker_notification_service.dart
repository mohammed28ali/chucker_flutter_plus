import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/network_transaction.dart';

class ChuckerNotificationService {
  /// Standard Flutter launcher mipmap resource.
  static const defaultAndroidIcon = '@mipmap/ic_launcher';

  ChuckerNotificationService({
    this.onRequestSelected,
    this.onUnrecognizedPayload,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'chucker_network';
  static const _notificationId = 7101;
  static const _minimumInterval = Duration(seconds: 2);
  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String requestId)? onRequestSelected;
  final void Function(String? payload)? onUnrecognizedPayload;
  final Stopwatch _sinceLast = Stopwatch();
  bool _initialized = false;
  bool _supported = false;
  bool _active = false;
  bool _posted = false;
  bool get isInitialized => _initialized;
  int _count = 0;
  int _failed = 0;
  Future<void>? _posting;

  Future<bool> initialize({
    String channelName = 'Network inspector',
    String androidIcon = defaultAndroidIcon,
    bool requestPermission = true,
  }) async {
    if (androidIcon.trim().isEmpty) {
      throw ArgumentError.value(
        androidIcon,
        'androidIcon',
        'Must not be empty.',
      );
    }
    _supported =
        !kIsWeb &&
        switch (defaultTargetPlatform) {
          TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.macOS ||
          TargetPlatform.linux => true,
          _ => false,
        };
    if (!_supported) return false;
    _initialized = false;
    _active = true;
    try {
      final initialized = await _plugin.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings(androidIcon),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: const LinuxInitializationSettings(
            defaultActionName: 'Open inspector',
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _route(response.payload),
      );
      if (initialized == false) {
        _active = false;
        return false;
      }
    } catch (error) {
      _active = false;
      debugPrint(
        'ChuckerFlutterPlus: Could not initialize notifications: ${error.runtimeType}',
      );
      return false;
    }

    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        _route(details?.notificationResponse?.payload);
      }
    } catch (_) {
      // Some notification backends cannot report launch details.
    }

    try {
      final allowed = await _permissionAvailable(requestPermission);
      return _initialized = allowed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _permissionAvailable(bool request) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return request
            ? await android?.requestNotificationsPermission() ?? true
            : await android?.areNotificationsEnabled() ?? true;
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (request) return await ios?.requestPermissions(alert: true) ?? true;
        final permissions = await ios?.checkPermissions();
        return permissions?.isEnabled ?? true;
      case TargetPlatform.macOS:
        final mac = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        if (request) return await mac?.requestPermissions(alert: true) ?? true;
        final permissions = await mac?.checkPermissions();
        return permissions?.isEnabled ?? true;
      default:
        return true;
    }
  }

  Future<void> show(
    NetworkTransaction transaction, {
    String channelName = 'Network inspector',
    bool foreground = false,
  }) async {
    if (!_initialized) return;
    _count++;
    if (!transaction.succeeded) _failed++;
    if (_posting != null ||
        (_sinceLast.isRunning && _sinceLast.elapsed < _minimumInterval)) {
      return;
    }
    _sinceLast
      ..reset()
      ..start();
    final posting = _show(transaction, channelName, foreground);
    _posting = posting;
    await posting;
    _posting = null;
  }

  Future<void> _show(
    NetworkTransaction transaction,
    String channelName,
    bool foreground,
  ) async {
    try {
      await _plugin.show(
        id: _notificationId,
        title: 'Network activity',
        body:
            '$_count requests · ${_count - _failed} succeeded · $_failed failed',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            channelName,
            channelDescription: 'Captured network requests',
            groupKey: _channelId,
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: foreground,
            presentBanner: foreground,
            presentList: foreground,
            presentSound: false,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: foreground,
            presentBanner: foreground,
            presentList: foreground,
            presentSound: false,
          ),
          linux: const LinuxNotificationDetails(),
        ),
        payload: 'chucker:${transaction.id}',
      );
      _posted = true;
    } catch (_) {
      // Permission and platform availability can change after initialization.
    }
  }

  Future<void> dispose() async {
    _initialized = false;
    _active = false;
    await _posting;
    if (!_supported || !_posted) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {}
  }

  void _route(String? payload) {
    if (!_active) return;
    if (payload != null && payload.startsWith('chucker:')) {
      final id = payload.substring('chucker:'.length);
      if (id.isNotEmpty) onRequestSelected?.call(id);
    } else {
      onUnrecognizedPayload?.call(payload);
    }
  }
}
