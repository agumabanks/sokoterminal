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
    const apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
    const connectTimeoutOverride = int.fromEnvironment(
      'CONNECT_TIMEOUT_MS',
      defaultValue: 0,
    );
    const receiveTimeoutOverride = int.fromEnvironment(
      'RECEIVE_TIMEOUT_MS',
      defaultValue: 0,
    );
    const logLevelOverride = String.fromEnvironment('LOG_LEVEL');

    return AppConfig(
      apiBaseUrl: apiBaseUrlOverride.isNotEmpty
          ? apiBaseUrlOverride
          : (env['API_BASE_URL'] ?? 'https://soko.sanaa.ug/api/'),
      connectTimeoutMs: connectTimeoutOverride > 0
          ? connectTimeoutOverride
          : (int.tryParse(env['CONNECT_TIMEOUT_MS'] ?? '') ?? 15000),
      receiveTimeoutMs: receiveTimeoutOverride > 0
          ? receiveTimeoutOverride
          : (int.tryParse(env['RECEIVE_TIMEOUT_MS'] ?? '') ?? 20000),
      logLevel: logLevelOverride.isNotEmpty
          ? logLevelOverride
          : (env['LOG_LEVEL'] ?? 'info'),
    );
  }
}
