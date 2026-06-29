import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';

import '../../core/storage/secure_storage.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/bug_logger.dart';
import '../../core/telemetry/bug_report_sync.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/auth/auth_controller.dart';
import '../../widgets/bottom_sheet_modal.dart';

/// Unified device health, auth diagnostics, and self-troubleshooting screen.
///
/// Shows:
///   • Device compatibility (OS, storage, memory pressure)
///   • Auth health (token status, secure-storage integrity)
///   • Network health (connectivity, API latency)
///   • Permission health (camera, bluetooth, contacts, notifications)
///   • Sync health (pending ops, blocked ops, last errors)
///   • One-tap self-diagnostic tests with actionable repair buttons.
class DeviceHealthScreen extends ConsumerStatefulWidget {
  const DeviceHealthScreen({super.key});

  @override
  ConsumerState<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends ConsumerState<DeviceHealthScreen> {
  late Future<_DeviceHealthSnapshot> _future;
  bool _runningDiagnostics = false;
  _DiagnosticResults? _lastDiagnostics;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DeviceHealthSnapshot> _load() async {
    final db = ref.read(appDatabaseProvider);
    final secureStorage = ref.read(secureStorageProvider);

    // Device info
    final deviceOS = Platform.operatingSystem;
    final deviceVersion = Platform.operatingSystemVersion;

    // Storage
    // Real free-space APIs require platform channels; we report DB size
    // as a proxy for "local data pressure".
    try {
      await getApplicationDocumentsDirectory();
    } catch (_) {}

    // DB size proxy
    int dbSizeBytes = 0;
    try {
      final dbFile = File('${(await getApplicationDocumentsDirectory()).path}/app_database.sqlite');
      if (await dbFile.exists()) {
        dbSizeBytes = await dbFile.length();
      }
    } catch (_) {}

    // Permissions
    final perms = await _checkPermissions();

    // Connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);

    // Auth
    final accessToken = await secureStorage.readAccessToken();
    final posToken = await secureStorage.readPosSessionToken();
    final sellerUUID = await secureStorage.readSellerUUID();
    final storageHealth = secureStorage.checkHealth();

    // Sync
    final pendingOps = await db.pendingSyncOps();
    final blockedOps = await db.blockedSyncOps();
    final pendingCount = pendingOps.length;
    final blockedCount = blockedOps.length;

    final recentFailures = [...blockedOps, ...pendingOps]
        .where((op) => (op.lastError ?? '').trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final at = a.lastTriedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final bt = b.lastTriedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return bt.compareTo(at);
      });

    final unresolvedBugs = await BugLogger.instance.getUnresolvedBugs();
    final pendingUploads = await BugLogger.instance.getPendingUploads();

    return _DeviceHealthSnapshot(
      deviceOS: deviceOS,
      deviceVersion: deviceVersion,
      dbSizeBytes: dbSizeBytes,
      permissions: perms,
      online: online,
      connectivityTypes: connectivity.map((e) => e.name).toList(),
      accessTokenPresent: accessToken != null && accessToken.isNotEmpty,
      accessTokenLength: accessToken?.length ?? 0,
      posTokenPresent: posToken != null && posToken.isNotEmpty,
      sellerUUID: sellerUUID,
      storageHealth: storageHealth,
      pendingSyncOps: pendingCount,
      blockedSyncOps: blockedCount,
      recentFailures: recentFailures.take(5).toList(),
      unresolvedBugCount: unresolvedBugs.length,
      pendingBugUploadCount: pendingUploads.length,
    );
  }

  Future<void> _uploadFeedback(BuildContext context) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Sending feedback to Soko24…')),
    );
    try {
      final api = ref.read(sellerApiProvider);
      final count = await BugReportSync.uploadPending(api);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Sent $count report${count == 1 ? '' : 's'} to support'
                  : 'No new reports to send',
            ),
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<Map<Permission, PermissionStatus>> _checkPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.contacts,
      Permission.notification,
      Permission.photos,
    ];
    final statuses = <Permission, PermissionStatus>{};
    for (final p in permissions) {
      try {
        statuses[p] = await p.status;
      } catch (_) {
        statuses[p] = PermissionStatus.denied;
      }
    }
    return statuses;
  }

  void _refresh() {
    setState(() {
      _future = _load();
      _lastDiagnostics = null;
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() => _runningDiagnostics = true);
    final results = _DiagnosticResults();
    final apiClient = ref.read(apiClientProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final syncService = ref.read(syncServiceProvider);

    // Test 1: Secure storage read/write
    try {
      const testKey = '_health_test_key_';
      const testValue = 'ok';
      await secureStorage.write(key: testKey, value: testValue);
      final readBack = await secureStorage.read(key: testKey);
      await secureStorage.delete(key: testKey);
      results.storageReadWrite = readBack == testValue;
    } catch (e) {
      results.storageReadWrite = false;
      results.storageError = e.toString();
    }

    // Test 2: Token validation
    try {
      final token = await secureStorage.readAccessToken();
      if (token == null || token.isEmpty) {
        results.tokenValid = false;
        results.tokenError = 'No access token found';
      } else {
        final response = await apiClient.get<Map<String, dynamic>>('/v2/auth/user');
        results.tokenValid = response.statusCode == 200;
        if (results.tokenValid != true) {
          results.tokenError = 'HTTP ${response.statusCode}';
        }
      }
    } on DioException catch (e) {
      results.tokenValid = false;
      results.tokenError = 'Dio ${e.response?.statusCode ?? e.type}';
    } catch (e) {
      results.tokenValid = false;
      results.tokenError = e.toString();
    }

    // Test 3: API reachability
    try {
      final stopwatch = Stopwatch()..start();
      final response = await apiClient.get('/v2/seller/products/categories');
      stopwatch.stop();
      results.apiReachable = response.statusCode == 200;
      results.apiLatencyMs = stopwatch.elapsedMilliseconds;
    } on DioException catch (e) {
      results.apiReachable = false;
      results.apiError = 'Dio ${e.response?.statusCode ?? e.type}';
    } catch (e) {
      results.apiReachable = false;
      results.apiError = e.toString();
    }

    // Test 4: Sync pump
    try {
      await syncService.syncNow();
      results.syncPumpOk = true;
    } catch (e) {
      results.syncPumpOk = false;
      results.syncError = e.toString();
    }

    if (mounted) {
      setState(() {
        _runningDiagnostics = false;
        _lastDiagnostics = results;
      });
    }
  }

  Future<void> _repairSecureStorage(BuildContext context) async {
    final secureStorage = ref.read(secureStorageProvider);
    secureStorage.clearFailureCounters();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secure storage counters cleared. Restart app if issues persist.')),
    );
    _refresh();
  }

  Future<void> _repairSync(BuildContext context) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Running sync repair…')),
    );
    final syncService = ref.read(syncServiceProvider);
    await syncService.syncNow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync repair finished')),
    );
    _refresh();
  }

  Future<void> _clearMemoryFallbacks(BuildContext context) async {
    // Memory fallbacks are internal; the only real "repair" is re-login.
    final confirmed = await BottomSheetModal.show<bool>(
      context: context,
      title: 'Re-authenticate?',
      subtitle: 'Clear memory tokens and log in again',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your device is storing tokens in memory because secure storage failed. '
            'The safest fix is to sign out and sign back in.',
            style: DesignTokens.textSmall,
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final auth = ref.read(authControllerProvider.notifier);
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Device Health', style: DesignTokens.textHeadline),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_DeviceHealthSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: DesignTokens.paddingScreen,
                child: Text(
                  'Failed to load health data: ${snapshot.error}',
                  style: DesignTokens.textBody,
                ),
              ),
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: DesignTokens.paddingScreen,
              children: [
                _OverallStatusCard(data: data),
                const SizedBox(height: DesignTokens.spaceLg),
                _AuthCard(
                  data: data,
                  diagnostics: _lastDiagnostics,
                  onRepairStorage: () => _repairSecureStorage(context),
                  onClearMemory: () => _clearMemoryFallbacks(context),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                _DeviceCard(data: data),
                const SizedBox(height: DesignTokens.spaceLg),
                _NetworkCard(data: data, diagnostics: _lastDiagnostics),
                const SizedBox(height: DesignTokens.spaceLg),
                _PermissionsCard(data: data),
                const SizedBox(height: DesignTokens.spaceLg),
                _SyncCard(
                  data: data,
                  diagnostics: _lastDiagnostics,
                  onRepairSync: () => _repairSync(context),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                if (data.recentFailures.isNotEmpty) ...[
                  _FailuresCard(failures: data.recentFailures),
                  const SizedBox(height: DesignTokens.spaceLg),
                ],
                _FeedbackCard(
                  data: data,
                  onUpload: () => _uploadFeedback(context),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                _DiagnosticsActionCard(
                  running: _runningDiagnostics,
                  onRun: _runDiagnostics,
                  results: _lastDiagnostics,
                ),
                const SizedBox(height: DesignTokens.spaceXl),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _OverallStatusCard extends StatelessWidget {
  const _OverallStatusCard({required this.data});
  final _DeviceHealthSnapshot data;

  @override
  Widget build(BuildContext context) {
    final issues = <String>[];
    if (!data.accessTokenPresent) issues.add('No access token');
    if (!data.storageHealth.isHealthy) issues.add('Secure storage errors');
    if (!data.online) issues.add('Offline');
    if (data.blockedSyncOps > 0) issues.add('${data.blockedSyncOps} blocked syncs');
    if (data.pendingSyncOps > 20) issues.add('${data.pendingSyncOps} pending syncs');

    final hasIssues = issues.isNotEmpty;
    final color = hasIssues ? DesignTokens.warning : DesignTokens.success;
    final label = hasIssues ? '${issues.length} issue${issues.length > 1 ? 's' : ''}' : 'All clear';

    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: hasIssues ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(
          color: hasIssues ? DesignTokens.warning.withValues(alpha: 0.4) : DesignTokens.success.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasIssues ? Icons.warning_amber_rounded : Icons.check_circle,
                color: color,
                size: 28,
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                label,
                style: DesignTokens.textBodyBold.copyWith(color: color),
              ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spaceSm),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: DesignTokens.warning),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Text(issue, style: DesignTokens.textSmall),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.data,
    this.diagnostics,
    required this.onRepairStorage,
    required this.onClearMemory,
  });

  final _DeviceHealthSnapshot data;
  final _DiagnosticResults? diagnostics;
  final VoidCallback onRepairStorage;
  final VoidCallback onClearMemory;

  @override
  Widget build(BuildContext context) {
    final tokenOk = data.accessTokenPresent;
    final storageOk = data.storageHealth.isHealthy;
    final memoryFallback = data.storageHealth.keys.any((k) => k.key == 'access_token' && !k.isHealthy) ||
        data.storageHealth.keys.any((k) => k.readFailures > 0 || k.writeFailures > 0);

    return _Section(
      title: 'Auth & Session',
      icon: Icons.shield_outlined,
      children: [
        _kv('Access token', tokenOk ? 'Present (${data.accessTokenLength} chars)' : 'Missing',
            valueColor: tokenOk ? DesignTokens.success : DesignTokens.error),
        _kv('POS session', data.posTokenPresent ? 'Active' : 'None'),
        _kv('Seller UUID', data.sellerUUID ?? '—'),
        _kv('Secure storage', storageOk ? 'Healthy' : 'Errors detected',
            valueColor: storageOk ? DesignTokens.success : DesignTokens.error),
        if (diagnostics?.tokenValid != null)
          _kv('Token API check', diagnostics!.tokenValid! ? 'Valid' : 'Failed',
              valueColor: diagnostics!.tokenValid! ? DesignTokens.success : DesignTokens.error),
        if (diagnostics?.tokenError != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spaceXs),
            child: Text(
              'Token error: ${diagnostics!.tokenError}',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
            ),
          ),
        if (!storageOk || memoryFallback) ...[
          const SizedBox(height: DesignTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRepairStorage,
                  icon: const Icon(Icons.healing, size: 18),
                  label: const Text('Repair Storage'),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearMemory,
                  icon: const Icon(Icons.memory, size: 18),
                  label: const Text('Clear Memory'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.data});
  final _DeviceHealthSnapshot data;

  @override
  Widget build(BuildContext context) {
    final dbSizeMb = (data.dbSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return _Section(
      title: 'Device',
      icon: Icons.phone_android_outlined,
      children: [
        _kv('Operating system', data.deviceOS),
        _kv('OS version', data.deviceVersion),
        _kv('Local DB size', '$dbSizeMb MB'),
        _kv('Compatibility', _compatibilityLabel(data)),
      ],
    );
  }

  String _compatibilityLabel(_DeviceHealthSnapshot data) {
    if (data.deviceOS == 'android') {
      // Very rough heuristic based on OS version string
      final versionString = data.deviceVersion.toLowerCase();
      if (versionString.contains('api level 2') || versionString.contains('5.') || versionString.contains('6.')) {
        return 'Legacy — some features may be limited';
      }
    }
    return 'Compatible';
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.data, this.diagnostics});
  final _DeviceHealthSnapshot data;
  final _DiagnosticResults? diagnostics;

  @override
  Widget build(BuildContext context) {
    final latencyText = diagnostics?.apiLatencyMs != null
        ? '${diagnostics!.apiLatencyMs} ms'
        : '—';
    return _Section(
      title: 'Network',
      icon: Icons.wifi_outlined,
      children: [
        _kv('Status', data.online ? 'Online' : 'Offline',
            valueColor: data.online ? DesignTokens.success : DesignTokens.error),
        _kv('Connection types', data.connectivityTypes.join(', ')),
        if (diagnostics?.apiReachable != null)
          _kv('API reachable', diagnostics!.apiReachable! ? 'Yes' : 'No',
              valueColor: diagnostics!.apiReachable! ? DesignTokens.success : DesignTokens.error),
        _kv('API latency', latencyText),
        if (diagnostics?.apiError != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spaceXs),
            child: Text(
              'API error: ${diagnostics!.apiError}',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
            ),
          ),
      ],
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.data});
  final _DeviceHealthSnapshot data;

  @override
  Widget build(BuildContext context) {
    final entries = data.permissions.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

    return _Section(
      title: 'Permissions',
      icon: Icons.security_outlined,
      children: [
        for (final entry in entries)
          _kv(
            _permissionName(entry.key),
            _statusName(entry.value),
            valueColor: entry.value.isGranted
                ? DesignTokens.success
                : entry.value.isPermanentlyDenied
                    ? DesignTokens.error
                    : DesignTokens.warning,
          ),
      ],
    );
  }

  String _permissionName(Permission p) {
    return p.toString().split('.').last;
  }

  String _statusName(PermissionStatus s) {
    if (s.isGranted) return 'Granted';
    if (s.isDenied) return 'Denied';
    if (s.isPermanentlyDenied) return 'Permanently denied';
    if (s.isRestricted) return 'Restricted';
    if (s.isLimited) return 'Limited';
    return 'Unknown';
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.data,
    required this.onUpload,
  });

  final _DeviceHealthSnapshot data;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Crash & bug reports',
      icon: Icons.bug_report_outlined,
      children: [
        _kv('Open issues on device', '${data.unresolvedBugCount}'),
        _kv(
          'Waiting to send',
          '${data.pendingBugUploadCount}',
          valueColor: data.pendingBugUploadCount > 0
              ? DesignTokens.warning
              : DesignTokens.success,
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Text(
          'Sync errors and crashes are saved locally and sent to Soko24 support when you are online.',
          style: DesignTokens.textSmall.copyWith(color: DesignTokens.textSecondary),
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        OutlinedButton.icon(
          onPressed: data.pendingBugUploadCount > 0 ? onUpload : null,
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Send reports now'),
        ),
      ],
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.data,
    this.diagnostics,
    required this.onRepairSync,
  });

  final _DeviceHealthSnapshot data;
  final _DiagnosticResults? diagnostics;
  final VoidCallback onRepairSync;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Sync',
      icon: Icons.sync_outlined,
      children: [
        _kv('Pending operations', '${data.pendingSyncOps}'),
        _kv('Blocked operations', '${data.blockedSyncOps}',
            valueColor: data.blockedSyncOps > 0 ? DesignTokens.error : DesignTokens.success),
        if (diagnostics?.syncPumpOk != null)
          _kv('Sync pump test', diagnostics!.syncPumpOk! ? 'Passed' : 'Failed',
              valueColor: diagnostics!.syncPumpOk! ? DesignTokens.success : DesignTokens.error),
        if (diagnostics?.syncError != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.spaceXs),
            child: Text(
              'Sync error: ${diagnostics!.syncError}',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
            ),
          ),
        if (data.blockedSyncOps > 0 || data.pendingSyncOps > 20) ...[
          const SizedBox(height: DesignTokens.spaceSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRepairSync,
              icon: const Icon(Icons.healing, size: 18),
              label: const Text('Repair Sync'),
            ),
          ),
        ],
      ],
    );
  }
}

class _FailuresCard extends StatelessWidget {
  const _FailuresCard({required this.failures});
  final List<SyncOp> failures;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Recent Failures',
      icon: Icons.error_outline,
      children: [
        for (final op in failures)
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
            child: Container(
              padding: DesignTokens.paddingMd,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withValues(alpha: 0.25),
                borderRadius: DesignTokens.borderRadiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        op.status == 'blocked' ? Icons.lock_outline : Icons.error_outline,
                        color: DesignTokens.error,
                        size: 18,
                      ),
                      const SizedBox(width: DesignTokens.spaceSm),
                      Expanded(
                        child: Text(
                          op.opType,
                          style: DesignTokens.textSmallBold,
                        ),
                      ),
                      Text(
                        op.status,
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(
                    op.lastError ?? 'No error message',
                    style: DesignTokens.textSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DiagnosticsActionCard extends StatelessWidget {
  const _DiagnosticsActionCard({
    required this.running,
    required this.onRun,
    this.results,
  });

  final bool running;
  final VoidCallback onRun;
  final _DiagnosticResults? results;

  @override
  Widget build(BuildContext context) {
    final allPassed = results != null &&
        results!.storageReadWrite == true &&
        results!.tokenValid == true &&
        results!.apiReachable == true &&
        results!.syncPumpOk == true;

    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Self Diagnostics', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Run a quick test of storage, auth, API, and sync.',
            style: DesignTokens.textSmall,
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          if (results != null) ...[
            _diagRow('Storage read/write', results!.storageReadWrite, error: results!.storageError),
            _diagRow('Token valid', results!.tokenValid, error: results!.tokenError),
            _diagRow('API reachable', results!.apiReachable, error: results!.apiError),
            _diagRow('Sync pump', results!.syncPumpOk, error: results!.syncError),
            const SizedBox(height: DesignTokens.spaceMd),
            if (allPassed)
              Container(
                padding: DesignTokens.paddingMd,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: DesignTokens.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: DesignTokens.success),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Text('All tests passed', style: DesignTokens.textBodyBold.copyWith(color: DesignTokens.success)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: DesignTokens.spaceMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: running ? null : onRun,
              icon: running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(running ? 'Running…' : 'Run Diagnostics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, bool? passed, {String? error}) {
    final icon = passed == true
        ? Icon(Icons.check_circle, color: DesignTokens.success, size: 18)
        : passed == false
            ? Icon(Icons.cancel, color: DesignTokens.error, size: 18)
            : Icon(Icons.help_outline, color: DesignTokens.grayMedium, size: 18);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
      child: Row(
        children: [
          icon,
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(child: Text(label, style: DesignTokens.textSmall)),
          if (error != null && error.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(
                error,
                style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DesignTokens.brandPrimary),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(title, style: DesignTokens.textBodyBold),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          ...children,
        ],
      ),
    );
  }
}

Widget _kv(String key, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceXs),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(key, style: DesignTokens.textSmall),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: DesignTokens.textSmallBold.copyWith(
              color: valueColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

// ── Data models ────────────────────────────────────────────────────────────

class _DeviceHealthSnapshot {
  _DeviceHealthSnapshot({
    required this.deviceOS,
    required this.deviceVersion,
    required this.dbSizeBytes,
    required this.permissions,
    required this.online,
    required this.connectivityTypes,
    required this.accessTokenPresent,
    required this.accessTokenLength,
    required this.posTokenPresent,
    required this.sellerUUID,
    required this.storageHealth,
    required this.pendingSyncOps,
    required this.blockedSyncOps,
    required this.recentFailures,
    required this.unresolvedBugCount,
    required this.pendingBugUploadCount,
  });

  final String deviceOS;
  final String deviceVersion;
  final int dbSizeBytes;
  final Map<Permission, PermissionStatus> permissions;
  final bool online;
  final List<String> connectivityTypes;
  final bool accessTokenPresent;
  final int accessTokenLength;
  final bool posTokenPresent;
  final String? sellerUUID;
  final SecureStorageHealth storageHealth;
  final int pendingSyncOps;
  final int blockedSyncOps;
  final List<SyncOp> recentFailures;
  final int unresolvedBugCount;
  final int pendingBugUploadCount;
}

class _DiagnosticResults {
  bool? storageReadWrite;
  String? storageError;
  bool? tokenValid;
  String? tokenError;
  bool? apiReachable;
  int? apiLatencyMs;
  String? apiError;
  bool? syncPumpOk;
  String? syncError;
}
