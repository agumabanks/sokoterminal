import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'config/app_config.dart';
import 'db/app_database.dart';
import 'network/api_client.dart';
import 'network/seller_api.dart';
import 'storage/secure_storage.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in main.dart');
});

final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final secureStorageProvider = Provider<SecureStorage>((ref) {
  throw UnimplementedError('secureStorageProvider must be overridden in main.dart');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden in main.dart');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(config: config, secureStorage: storage);
});

final sellerApiProvider = Provider<SellerApi>((ref) {
  final client = ref.watch(apiClientProvider);
  final config = ref.watch(appConfigProvider);
  final storage = ref.watch(secureStorageProvider);
  return SellerApi(client: client, config: config, storage: storage);
});

// Drift does not need a provider for the connection itself; keep a reference for quick access.
final dbExecutorProvider = Provider<drift.QueryExecutor>((ref) {
  return ref.watch(appDatabaseProvider).executor;
});

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
   return Connectivity().onConnectivityChanged;
});
