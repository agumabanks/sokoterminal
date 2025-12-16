class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.connectTimeoutMs,
    required this.receiveTimeoutMs,
    required this.logLevel,
  });

  final String apiBaseUrl;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;
  final String logLevel;

  factory AppConfig.fromEnv(Map<String, String> env) {
    return AppConfig(
      apiBaseUrl: env['API_BASE_URL'] ?? 'https://soko.sanaa.ug/api/',
      connectTimeoutMs: int.tryParse(env['CONNECT_TIMEOUT_MS'] ?? '') ?? 15000,
      receiveTimeoutMs: int.tryParse(env['RECEIVE_TIMEOUT_MS'] ?? '') ?? 20000,
      logLevel: env['LOG_LEVEL'] ?? 'info',
    );
  }
}
