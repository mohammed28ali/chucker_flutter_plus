import 'package:chucker_flutter_plus/src/config/theme/inspector_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import '../../../config/dependency_injection/chucker_dependencies.dart';
import '../../../core/routes/routes.dart';
import '../domain/entities/network_transaction.dart';
import '../infrastructure/body_capture.dart';
import '../infrastructure/notifications/chucker_notification_service.dart';
import 'inspector_settings.dart';
import 'inspector_config.dart';
import 'request_banner.dart';
import '../../../speed_test/chucker_speed_test.dart';

class ChuckerFlutterPlus {
  ChuckerFlutterPlus._();
  static bool showOnRelease = false;
  static bool showNotification = false;
  static String notificationChannelName = 'Network inspector';

  /// Theme override for the inspector overlay. [ThemeMode.system] follows the
  /// host app brightness without inheriting its colors or typography.
  static ThemeMode themeMode = ThemeMode.light;
  static Set<String> sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
  };
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final NavigatorObserver navigatorObserver =
      _ChuckerNavigatorObserver();

  static ChuckerDependencies _dependencies = ChuckerDependencies.create();
  static ChuckerDependencies get dependencies => _dependencies;
  static OverlayEntry? _entry;
  static ChuckerNotificationService? _notifications;
  static String? _pendingNotificationRequestId;
  static final settings = InspectorSettingsStore();
  static final _banner = RequestBannerController();
  static bool get isEnabled => kDebugMode || showOnRelease;

  static NotificationDelivery notificationDelivery({
    required bool isForeground,
    required InspectorSettings settings,
  }) {
    if (isForeground && settings.inAppBanner) return NotificationDelivery.inApp;
    if (settings.systemNotifications &&
        (!isForeground ||
            !settings.inAppBanner ||
            settings.statusBarWhileForeground)) {
      return NotificationDelivery.statusBar;
    }
    return NotificationDelivery.none;
  }

  static Future<void> initialize({
    int maximumEntries = 100,
    Duration? retention,
    bool? enableOnRelease,
    bool enableNotifications = false,
    bool showInAppNotification = true,
    bool? showStatusBarNotification,
    bool statusBarWhileForeground = false,
    Duration inAppNotificationDuration = const Duration(seconds: 3),
    BannerPosition inAppNotificationPosition = BannerPosition.top,
    bool notifyOnlyOnError = false,
    String notificationChannelName = 'Network inspector',
    String androidNotificationIcon =
        ChuckerNotificationService.defaultAndroidIcon,
    Set<String> redactHeaders = const {'authorization', 'cookie', 'set-cookie'},
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(String? payload)? onUnrecognizedNotificationPayload,
  }) async {
    configure(
      maximumEntries: maximumEntries,
      retention: retention,
      enableOnRelease: enableOnRelease,
      redactHeaders: redactHeaders,
    );
    await settings.load();
    configure(
      maximumEntries: settings.value.maximumEntries,
      retention: retention,
      enableOnRelease: enableOnRelease,
      redactHeaders: redactHeaders,
    );
    final effectiveNavKey = navigatorKey ?? ChuckerFlutterPlus.navigatorKey;
    if (effectiveNavKey.currentContext case final context?
        when context.mounted) {
      _banner.bind(context);
    }
    final showSystemNotifications =
        showStatusBarNotification ?? enableNotifications;
    showNotification = showSystemNotifications;
    ChuckerFlutterPlus.notificationChannelName = notificationChannelName;
    if (showSystemNotifications) {
      _notifications = ChuckerNotificationService(
        onRequestSelected: (id) {
          _openNotificationRequest(id, effectiveNavKey);
        },
        onUnrecognizedPayload: onUnrecognizedNotificationPayload,
      );
      await _notifications!.initialize(
        channelName: notificationChannelName,
        androidIcon: androidNotificationIcon,
      );
    }
    await settings.save(
      InspectorSettings(
        inAppBanner: showInAppNotification,
        systemNotifications: showSystemNotifications,
        statusBarWhileForeground: statusBarWhileForeground,
        bannerDuration: inAppNotificationDuration,
        bannerPosition: inAppNotificationPosition,
        onlyErrors: notifyOnlyOnError,
        maximumEntries: maximumEntries,
      ),
    );
  }

  static void configure({
    int maximumEntries = 100,
    Duration? retention,
    bool? enableOnRelease,
    Set<String>? redactHeaders,
  }) {
    if (maximumEntries < 0) {
      throw ArgumentError.value(
        maximumEntries,
        'maximumEntries',
        'Must not be negative.',
      );
    }
    showOnRelease = enableOnRelease ?? showOnRelease;
    sensitiveHeaders = (redactHeaders ?? sensitiveHeaders)
        .map((e) => e.toLowerCase())
        .toSet();
    _dependencies = ChuckerDependencies.create(
      maximumEntries: maximumEntries,
      retention: retention,
    );
  }

  static Map<String, String> redactHeaders(Map<String, String> headers) =>
      BodyCapture.redact(headers, sensitiveHeaders);

  static void showChuckerScreen([BuildContext? context]) =>
      showInspector(context);

  static void showInspector([BuildContext? context, String? requestId]) {
    final ctx = context ?? navigatorKey.currentContext ?? _banner.context;
    if (ctx == null) {
      if (!isEnabled || _entry != null) return;
      throw StateError(
        'showInspector requires a BuildContext below an Overlay, or set '
        'navigatorKey: ChuckerFlutterPlus.navigatorKey or '
        'navigatorObservers: [ChuckerFlutterPlus.navigatorObserver] in MaterialApp.',
      );
    }
    if (!isEnabled || _entry != null) return;
    final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
    if (overlay == null) {
      throw StateError('showInspector requires a context below an Overlay.');
    }
    _banner.bind(ctx);
    _entry = OverlayEntry(
      builder: (_) =>
          _IsolatedInspector(dependencies: _dependencies, requestId: requestId),
    );
    overlay.insert(_entry!);
  }

  static void _openNotificationRequest(
    String requestId,
    GlobalKey<NavigatorState>? preferredKey,
  ) {
    final context =
        preferredKey?.currentContext ??
        navigatorKey.currentContext ??
        _banner.context;
    if (context != null && context.mounted) {
      showInspector(context, requestId);
    } else {
      // The notification can launch the process before runApp has attached a
      // Navigator. Retry after the first frame; the observer also drains this
      // value when the app uses the package's navigator observer.
      _pendingNotificationRequestId = requestId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingNotificationRequestId;
        final readyContext =
            preferredKey?.currentContext ??
            navigatorKey.currentContext ??
            _banner.context;
        if (pending != null && readyContext != null && readyContext.mounted) {
          _pendingNotificationRequestId = null;
          showInspector(readyContext, pending);
        }
      });
    }
  }

  static void hideInspector() {
    _entry?.remove();
    _entry = null;
  }

  /// Opens a standalone internet speed test for download, upload, and latency.
  ///
  /// Endpoints default to Cloudflare's public speed test service. Pass custom
  /// URLs when using an organization's own test server.
  static Future<void> showSpeedTest(
    BuildContext context, {
    String downloadUrl = 'https://speed.cloudflare.com/__down?bytes=25000000',
    String uploadUrl = 'https://speed.cloudflare.com/__up',
    String latencyUrl = 'https://speed.cloudflare.com/__down?bytes=0',
  }) => ChuckerSpeedTest.show(
    context,
    downloadUrl: downloadUrl,
    uploadUrl: uploadUrl,
    latencyUrl: latencyUrl,
  );

  static Widget button({Key? key}) => Builder(
    builder: (context) => IconButton(
      key: key,
      tooltip: 'Network inspector',
      icon: const Icon(Icons.network_check),
      onPressed: isEnabled ? () => showInspector(context) : null,
    ),
  );

  static Future<void> record(NetworkTransaction transaction) async {
    if (!isEnabled) return;
    await _dependencies.recordTransaction(transaction);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    // Before the first frame Flutter may report `inactive` (or null). Requests
    // during startup are still in-app activity and should use the banner.
    final foreground =
        lifecycleState != AppLifecycleState.paused &&
        lifecycleState != AppLifecycleState.detached;
    final canShow = !settings.value.onlyErrors || !transaction.succeeded;
    final currentSettings = settings.value;
    final showInAppBanner = foreground && currentSettings.inAppBanner;
    final showStatusBarNotification =
        currentSettings.systemNotifications &&
        (!foreground || currentSettings.statusBarWhileForeground);
    if (showInAppBanner && canShow) {
      if (_banner.context == null || !_banner.context!.mounted) {
        if (navigatorKey.currentContext case final ctx? when ctx.mounted) {
          _banner.bind(ctx);
        }
      }
      _banner.show(transaction, settings.value, () {
        _banner.dismiss();
        final context = _banner.context ?? navigatorKey.currentContext;
        if (context != null) showInspector(context, transaction.id);
      });
    }
    if (showStatusBarNotification && showNotification && canShow) {
      await _notifications?.show(
        transaction,
        channelName: notificationChannelName,
      );
    }
  }

  static Future<void> clearLogs() => _dependencies.transactions.clear();
  static Future<String> exportLogs() async => jsonEncode(
    (await _dependencies.transactions.getAll())
        .map(
          (t) => {
            'id': t.id,
            'method': t.method,
            'url': t.uri.toString(),
            'statusCode': t.statusCode,
            'timestamp': t.startedAt.toIso8601String(),
            'durationMs': t.duration.inMilliseconds,
            'requestHeaders': t.requestHeaders,
            'responseHeaders': t.responseHeaders,
            'requestBody': t.rawRequestBody,
            'responseBody': t.rawResponseBody,
            'error': t.error,
          },
        )
        .toList(),
  );
  static Future<void> dispose() async {
    hideInspector();
    await _dependencies.transactions.dispose();
  }
}

/// Concise public facade for configuration-object based setup.
class Inspector {
  Inspector._();
  static Future<void> init({
    required InspectorConfig config,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(String? payload)? onUnrecognizedNotificationPayload,
  }) async {
    await ChuckerFlutterPlus.initialize(
      maximumEntries: config.maximumEntries,
      enableOnRelease: config.enableOnRelease,
      enableNotifications: config.showStatusBarNotification,
      androidNotificationIcon: config.androidNotificationIcon,
      navigatorKey: navigatorKey,
      onUnrecognizedNotificationPayload: onUnrecognizedNotificationPayload,
    );
    await updateConfig(config);
  }

  static Future<void> updateConfig(InspectorConfig config) async {
    if (config.showStatusBarNotification &&
        ChuckerFlutterPlus._notifications == null) {
      await ChuckerFlutterPlus.initialize(
        maximumEntries: config.maximumEntries,
        enableNotifications: true,
        androidNotificationIcon: config.androidNotificationIcon,
      );
    }
    await ChuckerFlutterPlus.settings.save(
      InspectorSettings(
        inAppBanner: config.showInAppNotification,
        systemNotifications: config.showStatusBarNotification,
        statusBarWhileForeground: config.statusBarWhileForeground,
        bannerDuration: config.inAppNotificationDuration,
        bannerPosition: config.inAppNotificationPosition,
        onlyErrors: config.notifyOnlyOnError,
        maximumEntries: config.maximumEntries,
      ),
    );
    ChuckerFlutterPlus.showNotification = config.showStatusBarNotification;
    ChuckerFlutterPlus.configure(
      maximumEntries: config.maximumEntries,
      enableOnRelease: config.enableOnRelease,
    );
  }

  static Future<void> clearLogs() => ChuckerFlutterPlus.clearLogs();
  static Future<String> exportLogs() => ChuckerFlutterPlus.exportLogs();
  static Future<void> dispose() => ChuckerFlutterPlus.dispose();
}

/// A self-contained overlay widget that provides an isolated Material 3 theme
/// so the inspector never inherits or modifies the host app's theme.
class _IsolatedInspector extends StatefulWidget {
  const _IsolatedInspector({required this.dependencies, this.requestId});
  final ChuckerDependencies dependencies;
  final String? requestId;

  @override
  State<_IsolatedInspector> createState() => _IsolatedInspectorState();
}

class _IsolatedInspectorState extends State<_IsolatedInspector> {
  Brightness? _hostBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hostBrightness =
        MediaQuery.maybeOf(context)?.platformBrightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        ChuckerFlutterPlus.themeMode == ThemeMode.dark ||
        (ChuckerFlutterPlus.themeMode == ThemeMode.system &&
            _hostBrightness == Brightness.dark);
    final theme = dark ? InspectorTheme.dark() : InspectorTheme.light();
    return SizedBox.expand(
      child: Theme(
        data: theme,
        child: MediaQuery(
          data:
              MediaQuery.maybeOf(context)?.copyWith(
                platformBrightness: dark ? Brightness.dark : Brightness.light,
              ) ??
              MediaQueryData(
                platformBrightness: dark ? Brightness.dark : Brightness.light,
              ),
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
              child: Navigator(
                onGenerateRoute: (routeSettings) => AppRoutes.onGenerateRoute(
                  routeSettings,
                  dependencies: widget.dependencies,
                  initialRequestId: widget.requestId,
                  onClose: ChuckerFlutterPlus.hideInspector,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChuckerNavigatorObserver extends NavigatorObserver {
  void _bindRoute(Route<dynamic>? route) {
    final navigator = route?.navigator;
    final context =
        (route is ModalRoute<dynamic> ? route.subtreeContext : null) ??
        navigator?.context ??
        ChuckerFlutterPlus.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ChuckerFlutterPlus._banner.bind(context, overlay: navigator?.overlay);
      final requestId = ChuckerFlutterPlus._pendingNotificationRequestId;
      if (requestId != null) {
        ChuckerFlutterPlus._pendingNotificationRequestId = null;
        ChuckerFlutterPlus.showInspector(context, requestId);
      }
    }
  }

  void _updateContext(Route<dynamic>? route) {
    _bindRoute(route);
    // didPush can run before the Navigator has built its Overlay. Bind again
    // after the frame so the first request can show a banner without needing
    // another widget (such as the inspector button) to provide an overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindRoute(route));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateContext(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateContext(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateContext(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _updateContext(previousRoute);
  }
}

/// Alias for backwards compatibility with `chucker_flutter`.
typedef ChuckerFlutter = ChuckerFlutterPlus;
