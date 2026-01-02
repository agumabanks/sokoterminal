import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../app_providers.dart';
import 'sync_service.dart';

enum SyncState { idle, syncing, error, offline }

class SyncStatus {
  final SyncState state;
  final int pendingCount;
  final String? message;
  final DateTime? lastSyncTime;

  SyncStatus({
    required this.state,
    required this.pendingCount,
    this.message,
    this.lastSyncTime,
  });

  factory SyncStatus.initial() {
    return SyncStatus(
      state: SyncState.idle,
      pendingCount: 0,
      lastSyncTime: DateTime.now(),
    );
  }

  SyncStatus copyWith({
    SyncState? state,
    int? pendingCount,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      pendingCount: pendingCount ?? this.pendingCount,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier(this.ref) : super(SyncStatus.initial()) {
    _init();
  }

  final Ref ref;

  void _init() {
    // Watch connectivity
    ref.listen(connectivityProvider, (previous, next) {
      final connectivity = next.asData?.value ?? [];
      final isOnline = connectivity.any((r) => r != ConnectivityResult.none);
      if (!isOnline) {
        state = state.copyWith(state: SyncState.offline);
      } else if (state.state == SyncState.offline) {
        state = state.copyWith(state: SyncState.idle);
      }
    });

    // Watch pending count from DB
    ref.listen(pendingSyncCountProvider, (previous, next) {
      final count = next.asData?.value ?? 0;
      state = state.copyWith(pendingCount: count);
    });

    // Listen to sync messages from service
    final syncService = ref.read(syncServiceProvider);
    syncService.syncStatusStream.listen((msg) {
      if (msg.toLowerCase().contains('failed') || msg.toLowerCase().contains('error')) {
        state = state.copyWith(state: SyncState.error, message: msg);
      } else if (msg.toLowerCase().contains('syncing')) {
        state = state.copyWith(state: SyncState.syncing, message: msg);
      } else {
        state = state.copyWith(message: msg);
      }
    });
  }

  void setSyncing(bool syncing) {
    if (syncing) {
      state = state.copyWith(state: SyncState.syncing);
    } else {
      state = state.copyWith(state: SyncState.idle, message: null);
      if (state.pendingCount == 0) {
        state = state.copyWith(lastSyncTime: DateTime.now());
      }
    }
  }

  void setError(String error) {
    state = state.copyWith(state: SyncState.error, message: error);
  }
}

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).watchPendingSyncOpsCount();
});

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier(ref);
});
