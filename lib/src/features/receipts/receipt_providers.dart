import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import 'print_queue_service.dart';
import 'receipt_service.dart';

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return ReceiptService(db, prefs: prefs);
});

final printQueueServiceProvider = Provider<PrintQueueService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final receipt = ref.watch(receiptServiceProvider);
  return PrintQueueService(db: db, prefs: prefs, receiptService: receipt);
});
