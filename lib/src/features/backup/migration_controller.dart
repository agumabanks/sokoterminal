import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/api_client.dart';

class MigrationState {
  final bool checking;
  final Map<String, dynamic>? pendingBackup;
  final bool restoring;
  final String? error;

  MigrationState({
    this.checking = false,
    this.pendingBackup,
    this.restoring = false,
    this.error,
  });

  MigrationState copyWith({
    bool? checking,
    Map<String, dynamic>? pendingBackup,
    bool? restoring,
    String? error,
  }) {
    return MigrationState(
      checking: checking ?? this.checking,
      pendingBackup: pendingBackup ?? this.pendingBackup,
      restoring: restoring ?? this.restoring,
      error: error ?? this.error,
    );
  }
}

final migrationProvider = StateNotifierProvider<MigrationController, MigrationState>((ref) {
  return MigrationController(ref);
});

class MigrationController extends StateNotifier<MigrationState> {
  MigrationController(this.ref) : super(MigrationState());

  final Ref ref;

  Future<void> checkForBackups() async {
    state = state.copyWith(checking: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>('/v2/seller/backups/latest');
      
      if (response.data?['available'] == true) {
        state = state.copyWith(
          checking: false,
          pendingBackup: response.data?['backup'] as Map<String, dynamic>?,
        );
      } else {
        state = state.copyWith(checking: false);
      }
    } catch (e) {
      state = state.copyWith(checking: false, error: e.toString());
    }
  }

  Future<bool> restoreBackup(int backupId) async {
    state = state.copyWith(restoring: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>('/v2/seller/backups/$backupId');
      
      if (response.data?['success'] == true) {
        final backupData = response.data?['data'] as Map<String, dynamic>?;
        if (backupData != null) {
          final db = ref.read(appDatabaseProvider);
          await db.importBackupData(backupData);
          state = state.copyWith(restoring: false, pendingBackup: null);
          return true;
        }
      }
      throw Exception('Invalid backup data received');
    } catch (e) {
      state = state.copyWith(restoring: false, error: e.toString());
      return false;
    }
  }

  void dismiss() {
    state = state.copyWith(pendingBackup: null);
  }
}
