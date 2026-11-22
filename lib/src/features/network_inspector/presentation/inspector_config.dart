import 'inspector_settings.dart';

/// Notification and capture options for [Inspector.init].
class InspectorConfig {
  const InspectorConfig({
    this.enableOnRelease = false,
    this.showInAppNotification = true,
    this.showStatusBarNotification = true,
    this.statusBarWhileForeground = false,
    this.inAppNotificationDuration = const Duration(seconds: 3),
    this.inAppNotificationPosition = BannerPosition.top,
    this.notifyOnlyOnError = false,
    this.maximumEntries = 100,
  });
  final bool enableOnRelease;
  final bool showInAppNotification;
  final bool showStatusBarNotification;
  final bool statusBarWhileForeground;
  final Duration inAppNotificationDuration;
  final BannerPosition inAppNotificationPosition;
  final bool notifyOnlyOnError;
  final int maximumEntries;

  InspectorConfig copyWith({
    bool? enableOnRelease,
    bool? showInAppNotification,
    bool? showStatusBarNotification,
    bool? statusBarWhileForeground,
    Duration? inAppNotificationDuration,
    BannerPosition? inAppNotificationPosition,
    bool? notifyOnlyOnError,
    int? maximumEntries,
  }) => InspectorConfig(
    enableOnRelease: enableOnRelease ?? this.enableOnRelease,
    showInAppNotification: showInAppNotification ?? this.showInAppNotification,
    showStatusBarNotification:
        showStatusBarNotification ?? this.showStatusBarNotification,
    statusBarWhileForeground:
        statusBarWhileForeground ?? this.statusBarWhileForeground,
    inAppNotificationDuration:
        inAppNotificationDuration ?? this.inAppNotificationDuration,
    inAppNotificationPosition:
        inAppNotificationPosition ?? this.inAppNotificationPosition,
    notifyOnlyOnError: notifyOnlyOnError ?? this.notifyOnlyOnError,
    maximumEntries: maximumEntries ?? this.maximumEntries,
  );
}

enum NotificationDelivery { none, inApp, statusBar }
