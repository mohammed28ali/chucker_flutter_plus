import '../../../network_logging/log_redactor.dart';
import '../domain/entities/network_transaction.dart';
import '../infrastructure/notifications/chucker_notification_service.dart';
import 'inspector_settings.dart';

/// Notification and capture options for `Inspector.init`.
class InspectorConfig {
  const InspectorConfig({
    this.enableOnRelease = false,
    this.showInAppNotification = true,
    this.showStatusBarNotification = false,
    this.statusBarWhileForeground = false,
    this.inAppNotificationDuration = const Duration(seconds: 3),
    this.inAppNotificationPosition = BannerPosition.top,
    this.notifyOnlyOnError = false,
    this.maximumEntries = 100,
    this.retention = const Duration(days: 7),
    this.maximumBodyBytes = 64 * 1024,
    this.redactHeaders = LogRedactor.defaultSensitiveHeaders,
    this.redactBodyKeys = LogRedactor.defaultSensitiveKeys,
    this.notificationFilter,
    this.requestNotificationPermission = true,
    this.androidNotificationIcon =
        ChuckerNotificationService.defaultAndroidIcon,
  });
  final bool enableOnRelease;
  final bool showInAppNotification;
  final bool showStatusBarNotification;
  final bool statusBarWhileForeground;
  final Duration inAppNotificationDuration;
  final BannerPosition inAppNotificationPosition;
  final bool notifyOnlyOnError;
  final int maximumEntries;

  /// Keep entries this long. Null disables age-based pruning.
  final Duration? retention;

  /// Maximum bytes per captured body. Zero captures metadata only.
  final int maximumBodyBytes;
  final Set<String> redactHeaders;
  final Set<String> redactBodyKeys;

  /// Additional filter evaluated on the redacted transaction after saving it.
  final bool Function(NetworkTransaction)? notificationFilter;

  /// Whether initialization may prompt for OS notification permissions.
  final bool requestNotificationPermission;

  /// Android status bar notification icon resource name.
  ///
  /// Defaults to `@mipmap/ic_launcher`, which resolves the standard Flutter
  /// launcher icon under `android/app/src/main/res/mipmap-*/ic_launcher.png`.
  /// To use a custom drawable, add it under `android/app/src/main/res/drawable/`
  /// and pass its resource name without extension (e.g. `'ic_notification'`),
  /// or prefix a mipmap resource with `@mipmap/` (e.g. `'@mipmap/app_icon'`).
  final String androidNotificationIcon;

  InspectorConfig copyWith({
    bool? enableOnRelease,
    bool? showInAppNotification,
    bool? showStatusBarNotification,
    bool? statusBarWhileForeground,
    Duration? inAppNotificationDuration,
    BannerPosition? inAppNotificationPosition,
    bool? notifyOnlyOnError,
    int? maximumEntries,
    Duration? retention,
    bool clearRetention = false,
    int? maximumBodyBytes,
    Set<String>? redactHeaders,
    Set<String>? redactBodyKeys,
    bool Function(NetworkTransaction)? notificationFilter,
    bool clearNotificationFilter = false,
    bool? requestNotificationPermission,
    String? androidNotificationIcon,
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
    retention: clearRetention ? null : retention ?? this.retention,
    maximumBodyBytes: maximumBodyBytes ?? this.maximumBodyBytes,
    redactHeaders: redactHeaders ?? this.redactHeaders,
    redactBodyKeys: redactBodyKeys ?? this.redactBodyKeys,
    notificationFilter: clearNotificationFilter
        ? null
        : notificationFilter ?? this.notificationFilter,
    requestNotificationPermission:
        requestNotificationPermission ?? this.requestNotificationPermission,
    androidNotificationIcon:
        androidNotificationIcon ?? this.androidNotificationIcon,
  );
}

enum NotificationDelivery { none, inApp, statusBar }
