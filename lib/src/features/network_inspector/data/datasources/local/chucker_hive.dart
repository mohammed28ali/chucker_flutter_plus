import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ChuckerHive {
  static bool _initialized = false;
  static Future<void>? _initializing;
  static String? storagePath;
  static bool get initialized => _initialized;
  static void markInitialized() => _initialized = true;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await (_initializing ??= _initialize());
    } finally {
      _initializing = null;
    }
  }

  static Future<void> _initialize() async {
    if (!kIsWeb) {
      final directory = await getApplicationDocumentsDirectory();
      storagePath = '${directory.path}/chucker_flutter_plus_hive';
    }
    markInitialized();
  }
}
