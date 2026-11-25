import 'package:chopper/chopper.dart' as chopper;
import 'package:chucker_flutter_plus/chopper_network_logger.dart' as logging;
import 'package:chucker_flutter_plus/chucker_flutter_plus.dart' show Inspector;
import 'package:chucker_flutter_plus/dio_network_logger.dart';
import 'package:chucker_flutter_plus/http_network_logger.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../../data/datasources/posts_remote_data_source.dart';
import '../../data/repositories/posts_repository_impl.dart';
import '../../domain/repositories/posts_repository.dart';
import '../config/demo_config.dart';

final class DependencyInjection {
  const DependencyInjection._();

  static final _logger = NetworkLogger(
    config: const NetworkLogConfig(
      logRequestHeaders: false,
      logRequestBody: false,
      logResponseHeaders: false,
      logResponseBody: false,
      logErrorBody: false,
      logCurlCommand: false,
    ),
  );

  static PostsRepository createPostsRepository() {
    final dio = Inspector.attachDio(
      Dio(
        BaseOptions(
          baseUrl: DemoConfig.apiBaseUrl,
          connectTimeout: DemoConfig.requestTimeout,
          receiveTimeout: DemoConfig.requestTimeout,
          headers: const {'Accept': 'application/json'},
        ),
      ),
    );
    dio.interceptors.add(DioNetworkLoggerInterceptor(logger: _logger));
    return PostsRepositoryImpl(PostsRemoteDataSource(dio));
  }

  static http.Client createHttpClient() => Inspector.attachHttp(
    LoggingHttpClient(inner: http.Client(), logger: _logger),
  );

  static chopper.ChopperClient createChopperClient() => chopper.ChopperClient(
    baseUrl: Uri.parse(DemoConfig.apiBaseUrl),
    interceptors: [logging.ChopperNetworkLoggerInterceptor(logger: _logger)],
  );
}
