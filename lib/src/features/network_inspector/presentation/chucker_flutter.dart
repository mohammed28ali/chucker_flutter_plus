import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../config/dependency_injection/chucker_dependencies.dart';
import '../../../config/theme/inspector_theme.dart';
import '../../../core/body_capture.dart';
import '../../../core/routes/routes.dart';
import '../../../network_logging/log_redactor.dart';
import '../data/models/network_transaction_model.dart';
import '../domain/entities/network_transaction.dart';
import '../infrastructure/dio/chucker_dio_interceptor.dart';
import '../infrastructure/http/chucker_http_client.dart';

import '../infrastructure/notifications/chucker_notification_service.dart';
import 'inspector_settings.dart';
import 'inspector_config.dart';
import 'request_banner.dart';

class ChuckerFlutterPlus {
  ChuckerFlutterPlus._();
  static bool showOnRelease = false;
  static bool showNotification = false;
  static String notificationChannelName = 'Network inspector';
  static Set<String> sensitiveHeaders = {
    ...LogRedactor.defaultSensitiveHeaders,
  };
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final NavigatorObserver navigatorObserver =
      _ChuckerNavigatorObserver();

  static final _dependencies = ChuckerDependencies.create();
  static ChuckerDependencies get dependencies => _dependencies;
  static OverlayEntry? _entry;
  static OverlayState? _inspectorOverlay;
  static ChuckerNotificationService? _notifications;
  static GlobalKey<NavigatorState>? _customNavigatorKey;
  static String? _pendingNotificationRequestId;
  static void Function(String?)? _onUnrecognizedPayload;
  static final settings = InspectorSettingsStore();
  static final _banner = RequestBannerController();
  static final _lifecycle = _InspectorLifecycle();
  static Future<void> _configuration = Future.value();
  static InspectorConfig _config = const InspectorConfig();
  static bool _disposed = false;
  static int _captureSession = 0;

  static bool get isEnabled => !_disposed && (kDebugMode || showOnRelease);
  static int get maximumBodyBytes => _config.maximumBodyBytes;
  static int? get captureSession =>
      isEnabled && settings.value.maximumEntries > 0 ? _captureSession : null;

  static LogRedactor get _redactor => LogRedactor(
    sensitiveHeaders: sensitiveHeaders,
    sensitiveJsonKeys: _config.redactBodyKeys,
    replacement: '██REDACTED██',
  );

  static NavigatorState? get _navigator =>
      _customNavigatorKey?.currentState ?? navigatorKey.currentState;

  static Future<void> _schedule(Future<void> Function() action) {
    final result = _configuration.then((_) => action());
    _configuration = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static NotificationDelivery notificationDelivery({
    required bool isForeground,
    required InspectorSettings settings,
  }) {
    if (isForeground &&
        settings.inAppBanner &&
        !settings.statusBarWhileForeground) {
      return NotificationDelivery.inApp;
    }
    if (settings.systemNotifications &&
        (!isForeground ||
            !settings.inAppBanner ||
            settings.statusBarWhileForeground)) {
      return NotificationDelivery.statusBar;
    }
    return isForeground && settings.inAppBanner
        ? NotificationDelivery.inApp
        : NotificationDelivery.none;
  }

  static Future<void> initialize({
    int maximumEntries = 100,
    Duration? retention,
    bool? enableOnRelease,
    bool enableNotifications = false,
    String notificationChannelName = 'Network inspector',
    String androidNotificationIcon =
        ChuckerNotificationService.defaultAndroidIcon,
    Set<String> redactHeaders = LogRedactor.defaultSensitiveHeaders,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(String? payload)? onUnrecognizedNotificationPayload,
  }) {
    WidgetsFlutterBinding.ensureInitialized();
    return _schedule(() async {
      _disposed = false;
      _customNavigatorKey = navigatorKey;
      _onUnrecognizedPayload = onUnrecognizedNotificationPayload;
      ChuckerFlutterPlus.notificationChannelName = notificationChannelName;
      final config = InspectorConfig(
        maximumEntries: maximumEntries,
        retention: retention,
        enableOnRelease: enableOnRelease ?? showOnRelease,
        showStatusBarNotification: enableNotifications,
        androidNotificationIcon: androidNotificationIcon,
        redactHeaders: redactHeaders,
      );
      _validate(config);
      settings.value = InspectorSettings(maximumEntries: maximumEntries);
      if (kDebugMode || config.enableOnRelease) {
        try {
          await settings.load(defaultMaximumEntries: maximumEntries);
        } catch (_) {
          settings.value = InspectorSettings(maximumEntries: maximumEntries);
        }
      }
      await _apply(
        config.copyWith(
          maximumEntries: settings.value.maximumEntries.clamp(
            0,
            maximumEntries,
          ),
        ),
        preferences: settings.value.copyWith(
          systemNotifications:
              enableNotifications && settings.value.systemNotifications,
        ),
      );
    });
  }

  static void configure({
    int maximumEntries = 100,
    Duration? retention,
    bool? enableOnRelease,
    Set<String>? redactHeaders,
  }) {
    final config = _config.copyWith(
      maximumEntries: maximumEntries,
      retention: retention,
      clearRetention: retention == null,
      enableOnRelease: enableOnRelease ?? showOnRelease,
      redactHeaders: redactHeaders ?? sensitiveHeaders,
    );
    _validate(config);
    _disposed = false;
    _setCaptureConfig(config, settings.value).ignore();
  }

  static Future<void> setHistoryLimit(int maximumEntries) {
    RangeError.checkNotNegative(maximumEntries, 'maximumEntries');
    return _schedule(() async {
      final next = _config.copyWith(maximumEntries: maximumEntries);
      await _setCaptureConfig(next, settings.value, prune: true);
      await settings.save(settings.value);
    });
  }

  static void _validate(InspectorConfig config) {
    RangeError.checkNotNegative(config.maximumEntries, 'maximumEntries');
    RangeError.checkNotNegative(config.maximumBodyBytes, 'maximumBodyBytes');
    if (config.retention?.isNegative ?? false) {
      throw ArgumentError.value(
        config.retention,
        'retention',
        'Must not be negative.',
      );
    }
    if (config.inAppNotificationDuration.isNegative) {
      throw ArgumentError.value(
        config.inAppNotificationDuration,
        'inAppNotificationDuration',
        'Must not be negative.',
      );
    }
  }

  static Future<void> _setCaptureConfig(
    InspectorConfig config,
    InspectorSettings preferences, {
    bool prune = false,
  }) {
    _config = config;
    showOnRelease = config.enableOnRelease;
    sensitiveHeaders = Set.of(config.redactHeaders);
    settings.value = preferences.copyWith(
      maximumEntries: config.maximumEntries,
    );
    return _dependencies.transactions.configure(
      maximumEntries: config.maximumEntries,
      retention: config.retention,
      maximumBodyBytes: config.maximumBodyBytes,
      prune: prune && isEnabled,
    );
  }

  static Future<void> _apply(
    InspectorConfig config, {
    InspectorSettings? preferences,
  }) async {
    _validate(config);
    final previous = _config;
    try {
      await _setCaptureConfig(
        config,
        preferences ??
            InspectorSettings(
              inAppBanner: config.showInAppNotification,
              systemNotifications: config.showStatusBarNotification,
              statusBarWhileForeground: config.statusBarWhileForeground,
              bannerDuration: config.inAppNotificationDuration,
              bannerPosition: config.inAppNotificationPosition,
              onlyErrors: config.notifyOnlyOnError,
            ),
        prune: true,
      );
    } catch (_) {
      // Local storage can be unavailable in embedded hosts or private browsing.
      // Requests and console logging should still work.
    }
    WidgetsFlutterBinding.ensureInitialized();
    WidgetsBinding.instance.removeObserver(_lifecycle);
    if (isEnabled) WidgetsBinding.instance.addObserver(_lifecycle);
    showNotification = config.showStatusBarNotification;
    if (!isEnabled) hideInspector();
    if (!isEnabled || !settings.value.inAppBanner) _banner.dismiss();
    if (!isEnabled || !showNotification) {
      await _notifications?.dispose();
      _notifications = null;
      _pendingNotificationRequestId = null;
      return;
    }
    if (_notifications?.isInitialized == true &&
        previous.androidNotificationIcon == config.androidNotificationIcon &&
        previous.requestNotificationPermission ==
            config.requestNotificationPermission) {
      return;
    }
    await _notifications?.dispose();
    final service = ChuckerNotificationService(
      onRequestSelected: _openNotificationRequest,
      onUnrecognizedPayload: (payload) => _onUnrecognizedPayload?.call(payload),
    );
    _notifications = service;
    await service.initialize(
      androidIcon: config.androidNotificationIcon,
      requestPermission: config.requestNotificationPermission,
    );
  }

  static Future<void> setNotificationPreferences(
    InspectorSettings preferences,
  ) => _schedule(() async {
    if (!preferences.inAppBanner) _banner.dismiss();
    await settings.save(preferences);
  });

  static Map<String, String> redactHeaders(Map<String, String> headers) =>
      BodyCapture.redact(headers, _redactor);

  static void showChuckerScreen([BuildContext? context]) =>
      showInspector(context);

  static void showInspector([BuildContext? context, String? requestId]) {
    if (!isEnabled ||
        (_entry != null &&
            _inspectorOverlay?.mounted == true &&
            requestId == null)) {
      return;
    }
    final ctx = context ?? _navigator?.context ?? _banner.context;
    final overlay =
        _overlayFor(requestId != null ? null : context) ?? _overlayFor(context);
    if (ctx == null || overlay == null) {
      throw StateError(
        'showInspector requires a context below an Overlay or a mounted '
        'Inspector.navigatorKey on your root Navigator.',
      );
    }
    hideInspector();
    _banner.bind(ctx, overlay: overlay);
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(ctx) ?? Brightness.light;
    _entry = OverlayEntry(
      builder: (_) => _IsolatedInspector(
        brightness: brightness,
        dependencies: _dependencies,
        requestId: requestId,
      ),
    );
    overlay.insert(_entry!);
    _inspectorOverlay = overlay;
  }

  static OverlayState? _overlayFor(BuildContext? context) {
    if (context != null && context.mounted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) return overlay;
    }
    return _navigator?.overlay ?? _banner.overlay;
  }

  static void _openNotificationRequest(String requestId) {
    if (!isEnabled || !showNotification || requestId.isEmpty) return;
    _pendingNotificationRequestId = requestId;
    _schedulePendingOpen();
  }

  static void _schedulePendingOpen() {
    if (_pendingNotificationRequestId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = _pendingNotificationRequestId;
      if (id == null || _overlayFor(null) == null || !isEnabled) return;
      _pendingNotificationRequestId = null;
      showInspector(null, id);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static void hideInspector() {
    final entry = _entry;
    _entry = null;
    _inspectorOverlay = null;
    entry?.remove();
    entry?.dispose();
  }

  static Widget button({Key? key}) => Builder(
    builder: (context) => IconButton(
      key: key,
      tooltip: 'Network inspector',
      icon: const Icon(Icons.network_check),
      onPressed: isEnabled ? () => showInspector(context) : null,
    ),
  );

  static Future<void> record(
    NetworkTransaction transaction, {
    int? session,
  }) async {
    _schedulePendingOpen();
    final active = captureSession;
    if (active == null || (session != null && session != active)) return;
    late NetworkTransaction safe;
    try {
      safe = _sanitize(transaction);
      await _dependencies.recordTransaction(safe);
    } catch (_) {
      return;
    }
    if (captureSession != active ||
        WidgetsBinding.instance.lifecycleState == null) {
      return;
    }
    final preferences = settings.value;
    try {
      if ((preferences.onlyErrors && safe.succeeded) ||
          !(_config.notificationFilter?.call(safe) ?? true)) {
        return;
      }
    } catch (_) {
      return;
    }
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final service = _notifications;
    final delivery = notificationDelivery(
      isForeground: foreground,
      settings: preferences.copyWith(
        systemNotifications:
            preferences.systemNotifications &&
            showNotification &&
            service?.isInitialized == true,
      ),
    );
    if (delivery == NotificationDelivery.inApp) {
      final context = _navigator?.context ?? _banner.context;
      final overlay = _overlayFor(null);
      if (context == null || overlay == null || !context.mounted) return;
      _banner.bind(context, overlay: overlay);
      _banner.show(safe, preferences, () {
        _banner.dismiss();
        if (_overlayFor(null) != null) showInspector(null, safe.id);
      });
    } else if (delivery == NotificationDelivery.statusBar) {
      await service?.show(
        safe,
        channelName: notificationChannelName,
        foreground: foreground,
      );
    }
  }

  static NetworkTransaction _sanitize(NetworkTransaction t) {
    final redactor = _redactor;
    String? header(Map<String, String> headers, String name) {
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == name) return entry.value;
      }
      return null;
    }

    BodyCapture body(String? raw, String? type) {
      final bounded = BodyCapture.from(raw, limit: maximumBodyBytes);
      if (bounded.text == null) return bounded;
      return BodyCapture.from(
        redactor.redactBody(bounded.text, contentType: type),
        limit: maximumBodyBytes,
      );
    }

    final request = body(
      t.rawRequestBody,
      header(t.requestHeaders, 'content-type'),
    );
    final response = body(
      t.rawResponseBody,
      t.contentType ?? header(t.responseHeaders, 'content-type'),
    );
    return NetworkTransactionModel.fromJson({
      ...NetworkTransactionModel.fromEntity(t).toJson(),
      'uri': redactor.redactUri(t.uri).toString(),
      'requestHeaders': redactHeaders(t.requestHeaders),
      'responseHeaders': redactHeaders(t.responseHeaders),
      'rawRequestBody': request.text,
      'rawResponseBody': response.text,
      'requestBodyTruncated': t.requestBodyTruncated || request.omitted,
      'responseBodyTruncated': t.responseBodyTruncated || response.omitted,
    });
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
            'requestBodySize': t.requestBodySize,
            'requestBodyTruncated': t.requestBodyTruncated,
            'responseBody': t.rawResponseBody,
            'responseBodySize': t.responseBodySize,
            'responseBodyTruncated': t.responseBodyTruncated,
            'error': t.error,
          },
        )
        .toList(),
  );
  static Future<void> dispose() => _schedule(() async {
    _disposed = true;
    _captureSession++;
    _pendingNotificationRequestId = null;
    _customNavigatorKey = null;
    _onUnrecognizedPayload = null;
    showNotification = false;
    WidgetsFlutterBinding.ensureInitialized().removeObserver(_lifecycle);
    hideInspector();
    _banner.reset();
    await _notifications?.dispose();
    _notifications = null;
    try {
      await _dependencies.transactions.dispose();
    } finally {
      await settings.close();
    }
  });
}

/// Configuration and integration helpers for the network inspector.
class Inspector {
  Inspector._();

  static GlobalKey<NavigatorState> get navigatorKey =>
      ChuckerFlutterPlus.navigatorKey;

  static Future<void> init({
    InspectorConfig config = const InspectorConfig(),
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(String? payload)? onUnrecognizedNotificationPayload,
  }) {
    WidgetsFlutterBinding.ensureInitialized();
    return ChuckerFlutterPlus._schedule(() async {
      ChuckerFlutterPlus._disposed = false;
      ChuckerFlutterPlus._customNavigatorKey = navigatorKey;
      ChuckerFlutterPlus._onUnrecognizedPayload =
          onUnrecognizedNotificationPayload;
      await ChuckerFlutterPlus._apply(config);
    });
  }

  static Future<void> updateConfig(InspectorConfig config) =>
      ChuckerFlutterPlus._schedule(() => ChuckerFlutterPlus._apply(config));

  /// Attaches capture once and returns the same client.
  static Dio attachDio(Dio dio) {
    if (!dio.interceptors.any((item) => item is ChuckerDioInterceptor)) {
      dio.interceptors.add(ChuckerDioInterceptor());
    }
    return dio;
  }

  /// Wraps a client for capture. Closing the wrapper closes the inner client.
  static ChuckerHttpClient attachHttp(http.Client client) =>
      client is ChuckerHttpClient ? client : ChuckerHttpClient(client);

  static void show([BuildContext? context]) =>
      ChuckerFlutterPlus.showInspector(context);
  static Widget button({Key? key}) => ChuckerFlutterPlus.button(key: key);
  static Future<void> clearLogs() => ChuckerFlutterPlus.clearLogs();
  static Future<String> exportLogs() => ChuckerFlutterPlus.exportLogs();
  static Future<void> dispose() => ChuckerFlutterPlus.dispose();
}

class _InspectorLifecycle extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChuckerFlutterPlus._schedulePendingOpen();
    }
  }
}

/// A self-contained overlay widget that provides an isolated Material 3 theme
/// so the inspector never inherits or modifies the host app's theme.
class _IsolatedInspector extends StatefulWidget {
  const _IsolatedInspector({
    required this.brightness,
    required this.dependencies,
    this.requestId,
  });
  final Brightness brightness;
  final ChuckerDependencies dependencies;
  final String? requestId;

  @override
  State<_IsolatedInspector> createState() => _IsolatedInspectorState();
}

class _IsolatedInspectorState extends State<_IsolatedInspector> {
  late Brightness _brightness;

  @override
  void initState() {
    super.initState();
    _brightness = widget.brightness;
  }

  @override
  Widget build(BuildContext context) {
    // Re-read system brightness so a toggle in Settings works immediately
    final theme = _brightness == Brightness.dark
        ? InspectorTheme.dark()
        : InspectorTheme.light();
    return Theme(
      data: theme,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: ScaffoldMessenger(
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
    );
  }
}

class _ChuckerNavigatorObserver extends NavigatorObserver {
  void _updateContext(Route<dynamic>? route) {
    final navigatorState = route?.navigator ?? navigator;
    final overlay = navigatorState?.overlay;
    if (navigatorState != null && overlay != null) {
      ChuckerFlutterPlus._banner.bind(navigatorState.context, overlay: overlay);
      ChuckerFlutterPlus._schedulePendingOpen();
    }
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
