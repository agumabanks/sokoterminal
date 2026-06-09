import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soko_seller_terminal/src/core/app_providers.dart';
import 'package:soko_seller_terminal/src/core/auth/pin_hash_service.dart';
import 'package:soko_seller_terminal/src/core/auth/pos_session_controller.dart';
import 'package:soko_seller_terminal/src/core/config/app_config.dart';
import 'package:soko_seller_terminal/src/core/db/app_database.dart';
import 'package:soko_seller_terminal/src/core/security/manager_approval.dart';
import 'package:soko_seller_terminal/src/core/storage/secure_storage.dart';
import 'package:soko_seller_terminal/src/core/sync/sync_service.dart';
import 'package:soko_seller_terminal/src/features/settings/staff_pin_controller.dart';

import 'helpers/test_helpers.dart';

class _MockSecureStorage extends Mock implements SecureStorage {}

class _PinProbe extends ConsumerStatefulWidget {
  const _PinProbe({required this.reason, required this.onResult});

  final String reason;
  final ValueChanged<bool> onResult;

  @override
  ConsumerState<_PinProbe> createState() => _PinProbeState();
}

class _PinProbeState extends ConsumerState<_PinProbe> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final ok = await requireManagerPin(
          context,
          ref,
          reason: widget.reason,
        );
        widget.onResult(ok);
      },
      child: const Text('Run gated action'),
    );
  }
}

void main() {
  late _MockSecureStorage storage;
  late AppDatabase db;
  const appConfig = AppConfig(
    apiBaseUrl: 'https://example.test/api',
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    logLevel: 'error',
  );

  setUp(() async {
    storage = _MockSecureStorage();
    db = createTestDatabase();
    SharedPreferences.setMockInitialValues({});
    when(() => storage.readPin()).thenAnswer((_) async => '4242');
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> pinTestOverrides(SharedPreferences prefs) {
    return [
      appConfigProvider.overrideWithValue(appConfig),
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStorageProvider.overrideWithValue(storage),
      appDatabaseProvider.overrideWithValue(db),
      sellerApiProvider.overrideWithValue(MockSellerApi()),
      syncServiceProvider.overrideWithValue(MockSyncService()),
      posSessionProvider.overrideWith(
        (ref) => PosSessionController(
          storage: storage,
          api: ref.watch(sellerApiProvider),
          db: db,
          syncService: ref.watch(syncServiceProvider),
          prefs: prefs,
          pinHash: PinHashService(storage: storage),
        )..state = const PosSessionState(),
      ),
    ];
  }

  testWidgets('requireManagerPin blocks refund until legacy device PIN matches',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    bool? approved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinTestOverrides(prefs),
          staffPinProvider.overrideWith(
            (ref) => StaffPinController(storage)
              ..state = const StaffPinState(enabled: true, locked: true),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _PinProbe(
              reason: 'process a refund',
              onResult: (ok) => approved = ok,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Run gated action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Manager approval required'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(approved, isNull);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(approved, isFalse);

    await tester.tap(find.text('Run gated action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), '4242');
    await tester.tap(find.text('Approve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(approved, isTrue);
  });

  testWidgets('requireManagerPin allows void when legacy PIN lock is disabled',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    bool? approved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pinTestOverrides(prefs),
          staffPinProvider.overrideWith(
            (ref) => StaffPinController(storage)
              ..state = const StaffPinState(enabled: false, locked: false),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: _PinProbe(
              reason: 'void this sale',
              onResult: (ok) => approved = ok,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Run gated action'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Manager approval required'), findsNothing);
    expect(approved, isTrue);
  });
}