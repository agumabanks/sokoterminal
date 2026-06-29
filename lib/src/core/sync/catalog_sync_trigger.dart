import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_auth_utils.dart';
import 'sync_service.dart';

/// Push products/services to the cloud immediately when online.
///
/// When offline, ops stay queued and sync fires on reconnect via [SyncService].
Future<CatalogSyncOutcome> triggerCatalogSync(
  WidgetRef ref, {
  bool notify = true,
}) async {
  final sync = ref.read(syncServiceProvider);
  return sync.syncCatalogImmediately(notify: notify);
}

/// Fire-and-forget variant for save handlers.
void triggerCatalogSyncUnawaited(
  WidgetRef ref, {
  bool notify = false,
}) {
  unawaited(triggerCatalogSync(ref, notify: notify));
}

/// Check connectivity without reading the full sync service.
Future<bool> isDeviceOnline() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}

/// Show appropriate feedback after a catalog save.
Future<void> afterCatalogSave(WidgetRef ref, {bool showSynced = false}) async {
  final online = await isDeviceOnline();
  if (!online) {
    DioAuthUtils.notifyCatalogQueued();
    return;
  }
  unawaited(
    ref.read(syncServiceProvider).syncCatalogImmediately(notify: showSynced),
  );
}