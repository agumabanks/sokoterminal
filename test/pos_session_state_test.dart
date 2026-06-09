import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/auth/pos_session_controller.dart';

void main() {
  group('PosSessionState', () {
    test('empty state is not active', () {
      expect(PosSessionState.empty.isActive, isFalse);
      expect(PosSessionState.empty.isManager, isFalse);
    });

    test('state with token is active', () {
      const state = PosSessionState(token: 'abc123');
      expect(state.isActive, isTrue);
    });

    test('whitespace-only token is not active', () {
      const state = PosSessionState(token: '   ');
      expect(state.isActive, isFalse);
    });

    test('manager role is recognized', () {
      const state = PosSessionState(token: 'abc', staffRole: 'manager');
      expect(state.isManager, isTrue);
    });

    test('cashier role is not manager', () {
      const state = PosSessionState(token: 'abc', staffRole: 'cashier');
      expect(state.isManager, isFalse);
    });

    test('null role defaults to non-manager', () {
      const state = PosSessionState(token: 'abc');
      expect(state.isManager, isFalse);
    });

    test('copyWith preserves existing values when null', () {
      const state = PosSessionState(
        token: 'abc',
        staffId: 1,
        staffName: 'Alice',
        staffRole: 'manager',
      );
      final updated = state.copyWith(loading: true);
      expect(updated.token, 'abc');
      expect(updated.staffId, 1);
      expect(updated.staffName, 'Alice');
      expect(updated.staffRole, 'manager');
      expect(updated.loading, isTrue);
    });

    test('copyWith can clear error explicitly', () {
      const state = PosSessionState(error: 'oops');
      // Note: copyWith uses `error` parameter directly, not ?? fallback,
      // so passing null clears it.
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });
  });
}
