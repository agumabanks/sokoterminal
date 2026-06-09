import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/network/seller_api.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';
import 'package:soko_seller_terminal/src/core/storage/secure_storage.dart';

class MockAppDatabase extends Mock implements AppDatabase {
  MockAppDatabase() {
    // Stub new methods so cart controller tests don't crash on init.
    when(() => getLatestParkedSale()).thenAnswer((_) async => null);
    when(() => clearParkedSales()).thenAnswer((_) async {});
    when(() => clearActiveCartSale()).thenAnswer((_) async {});
    when(() => saveParkedSale(any())).thenAnswer((_) async {});
  }
}

void registerTestFallbacks() {
  registerFallbackValue(
    ParkedSalesCompanion.insert(
      id: const Value('active-cart'),
      saleKind: const Value('active_cart'),
      linesJson: '[]',
    ),
  );
}

class MockSellerApi extends Mock implements SellerApi {}

class MockSyncService extends Mock implements SyncService {}

class MockSecureStorage extends Mock implements SecureStorage {}

/// Creates a real in-memory AppDatabase for testing sync and DB operations.
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
