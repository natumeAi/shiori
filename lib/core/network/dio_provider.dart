import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/env.dart';

part 'dio_provider.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        logPrint: Logger('Http').fine,
      ),
    );
  }
  ref.onDispose(dio.close);
  return dio;
}
