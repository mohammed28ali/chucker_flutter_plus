import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class ChuckerHive {
  static bool _initialized = false;
  static bool get initialized => _initialized;
  static void markInitialized() => _initialized = true;
  static Future<void> initialize() async {
    if (_initialized) return;
    final directory = await getApplicationDocumentsDirectory();
    Hive.init('${directory.path}/chucker_flutter_plus_hive');
    _initialized = true;
  }
}
