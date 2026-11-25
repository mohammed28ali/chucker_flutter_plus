import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import '../../../../../core/body_capture.dart';
import '../../models/network_transaction_model.dart';
import 'chucker_hive.dart';

class NetworkTransactionLocalDataSource {
  NetworkTransactionLocalDataSource({
    this.typeId = 30001,
    this.maximumBodyBytes = 1024 * 1024,
    this.encryptionKey,
    this.initializeHive,
  });
  static const boxName = 'chucker_flutter_plus_requests';
  final int typeId;
  int maximumBodyBytes;
  final List<int>? encryptionKey;
  final Future<void> Function()? initializeHive;
  LazyBox<NetworkTransactionModel>? _box;

  Future<LazyBox<NetworkTransactionModel>> get _open async {
    if (!ChuckerHive.initialized) {
      if (initializeHive != null) {
        await initializeHive!();
      } else {
        await ChuckerHive.initialize();
      }
      ChuckerHive.markInitialized();
    }
    if (!Hive.isAdapterRegistered(typeId)) {
      Hive.registerAdapter(_RequestLogAdapter(typeId));
    }
    return _box ??= await Hive.openLazyBox<NetworkTransactionModel>(
      boxName,
      path: ChuckerHive.storagePath,
      encryptionCipher: encryptionKey == null
          ? null
          : HiveAesCipher(Uint8List.fromList(encryptionKey!)),
    );
  }

  Future<List<NetworkTransactionModel>> readAll() async {
    final box = await _open;
    final values = await Future.wait(box.keys.map((key) => box.get(key)));
    return values.whereType<NetworkTransactionModel>().toList();
  }

  Future<void> put(NetworkTransactionModel transaction) async {
    final box = await _open;
    final request = transaction.rawRequestBody;
    final response = transaction.rawResponseBody;
    final requestOmitted = _exceedsLimit(request);
    final responseOmitted = _exceedsLimit(response);
    final value = requestOmitted || responseOmitted
        ? NetworkTransactionModel.fromJson({
            ...transaction.toJson(),
            if (requestOmitted) 'rawRequestBody': null,
            if (responseOmitted) 'rawResponseBody': null,
            if (requestOmitted) 'requestBodyTruncated': true,
            if (responseOmitted) 'responseBodyTruncated': true,
          })
        : transaction;
    await box.put(value.id, value);
  }

  bool _exceedsLimit(String? value) =>
      value != null &&
      (maximumBodyBytes == 0 || BodyCapture.utf8Size(value) > maximumBodyBytes);

  Future<void> deleteAll(Iterable<String> ids) async {
    if (ids.isNotEmpty) await (await _open).deleteAll(ids);
  }

  Future<void> clear() async => (await _open).clear();
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}

class _RequestLogAdapter extends TypeAdapter<NetworkTransactionModel> {
  const _RequestLogAdapter(this.typeId);
  @override
  final int typeId;
  @override
  NetworkTransactionModel read(BinaryReader reader) =>
      NetworkTransactionModel.fromJson(
        (reader.read() as Map).cast<String, Object?>(),
      );
  @override
  void write(BinaryWriter writer, NetworkTransactionModel value) =>
      writer.write(value.toJson());
}
