import '../../features/network_inspector/data/datasources/local/network_transaction_local_data_source.dart';
import '../../features/network_inspector/data/repositories/network_transaction_repository_impl.dart';
import '../../features/network_inspector/domain/usecases/record_network_transaction.dart';

class ChuckerDependencies {
  ChuckerDependencies({
    required this.transactions,
    required this.recordTransaction,
  });

  factory ChuckerDependencies.create({
    int maximumEntries = 100,
    Duration? retention,
    int maximumBodyBytes = 64 * 1024,
  }) {
    final repository = NetworkTransactionRepositoryImpl(
      NetworkTransactionLocalDataSource(maximumBodyBytes: maximumBodyBytes),
      maximumEntries: maximumEntries,
      retention: retention,
    );
    return ChuckerDependencies(
      transactions: repository,
      recordTransaction: RecordNetworkTransaction(repository),
    );
  }

  final NetworkTransactionRepositoryImpl transactions;
  final RecordNetworkTransaction recordTransaction;
}
