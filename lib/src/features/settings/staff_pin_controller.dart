import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage.dart';
import '../../core/app_providers.dart';

final staffPinProvider =
    StateNotifierProvider<StaffPinController, StaffPinState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return StaffPinController(storage)..load();
});

class StaffPinState {
  const StaffPinState({this.enabled = false, this.locked = false});
  final bool enabled;
  final bool locked;
}

class StaffPinController extends StateNotifier<StaffPinState> {
  StaffPinController(this.storage) : super(const StaffPinState());
  final SecureStorage storage;

  Future<void> load() async {
    final pin = await storage.readPin();
    state = StaffPinState(enabled: pin != null, locked: pin != null);
  }

  Future<void> setPin(String pin) async {
    await storage.writePin(pin);
    state = StaffPinState(enabled: true, locked: true);
  }

  Future<bool> unlock(String pin) async {
    final saved = await storage.readPin();
    if (saved != null && saved == pin) {
      state = StaffPinState(enabled: true, locked: false);
      return true;
    }
    return false;
  }

  Future<void> clear() async {
    await storage.deletePin();
    state = const StaffPinState(enabled: false, locked: false);
  }
}
