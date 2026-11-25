import 'package:flutter/foundation.dart';

import '../../domain/entities/network_transaction.dart';
import '../../domain/repositories/network_transaction_repository.dart';
import '../datasources/local/network_transaction_local_data_source.dart';
import '../models/network_transaction_model.dart';

class NetworkTransactionRepositoryImpl implements NetworkTransactionRepository {
  NetworkTransactionRepositoryImpl(
    this._localDataSource, {
    this.maximumEntries = 100,
    this.retention,
  });

  final NetworkTransactionLocalDataSource _localDataSource;
  int maximumEntries;
  Duration? retention;
  final changes = ValueNotifier<int>(0);

  // Queue reads and mutations so configuration changes, deletion and saves
  // cannot race. An individual storage error does not poison the queue.
  Future<void> _pending = Future.value();
  Map<String, DateTime>? _timestamps;

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> configure({
    required int maximumEntries,
    required Duration? retention,
    required int maximumBodyBytes,
    required bool prune,
  }) => _run(() async {
    this.maximumEntries = maximumEntries;
    this.retention = retention;
    _localDataSource.maximumBodyBytes = maximumBodyBytes;
    if (prune) await _prune(await _index());
    changes.value++;
  });

  @override
  Future<List<NetworkTransaction>> getAll() => _run(() async {
    await _prune(await _index());
    final records = await _localDataSource.readAll();
    return records..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  });

  @override
  Future<void> save(NetworkTransaction transaction) => _run(() async {
    if (maximumEntries == 0 || _expired(transaction.startedAt)) return;
    final timestamps = await _index();
    await _localDataSource.put(NetworkTransactionModel.fromEntity(transaction));
    timestamps[transaction.id] = transaction.startedAt;
    await _prune(timestamps);
    changes.value++;
  });

  Future<void> delete(Set<String> ids) => _run(() async {
    await _localDataSource.deleteAll(ids);
    _timestamps?.removeWhere((id, _) => ids.contains(id));
    changes.value++;
  });

  @override
  Future<void> clear() => _run(() async {
    await _localDataSource.clear();
    _timestamps?.clear();
    changes.value++;
  });

  @override
  Future<void> dispose() => _run(() async {
    await _localDataSource.close();
    _timestamps = null;
  });

  Future<Map<String, DateTime>> _index() async => _timestamps ??= {
    for (final value in await _localDataSource.readAll())
      value.id: value.startedAt,
  };

  bool _expired(DateTime startedAt) {
    final age = retention;
    return age != null && startedAt.isBefore(DateTime.now().subtract(age));
  }

  Future<void> _prune(Map<String, DateTime> timestamps) async {
    final newest = timestamps.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final retained = newest
        .where((entry) => !_expired(entry.value))
        .take(maximumEntries)
        .map((entry) => entry.key)
        .toSet();
    final removed = timestamps.keys
        .where((id) => !retained.contains(id))
        .toSet();
    await _localDataSource.deleteAll(removed);
    timestamps.removeWhere((id, _) => removed.contains(id));
  }
}
