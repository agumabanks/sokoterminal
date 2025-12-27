import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/app_database.dart';
import '../../core/telemetry/telemetry.dart';
import 'receipt_service.dart';

class PrintQueueService {
  PrintQueueService({
    required this.db,
    required this.prefs,
    required this.receiptService,
  });

  final AppDatabase db;
  final SharedPreferences prefs;
  final ReceiptService receiptService;

  static const String printerEnabledKey = 'pos.printer.enabled';
  static const String preferredPrinterAddressKey = 'pos.printer.bt.address';
  static const String preferredPrinterNameKey = 'pos.printer.bt.name';

  Timer? _timer;
  bool _isPumping = false;
  bool _pumpQueued = false;

  bool get printerEnabled => prefs.getBool(printerEnabledKey) ?? true;

  String? get preferredPrinterAddress {
    final addr = prefs.getString(preferredPrinterAddressKey);
    return (addr == null || addr.trim().isEmpty) ? null : addr.trim();
  }

  String? get preferredPrinterName {
    final name = prefs.getString(preferredPrinterNameKey);
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  bool get hasPreferredPrinter => preferredPrinterAddress != null;

  String preferredPrinterLabel() {
    final name = preferredPrinterName;
    if (name != null) return name;
    final addr = preferredPrinterAddress;
    return addr ?? 'Not set';
  }

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 25), (_) => pump());
    unawaited(pump());
  }

  Future<void> setPrinterEnabled(bool enabled) async {
    await prefs.setBool(printerEnabledKey, enabled);
    if (enabled) {
      unawaited(pump());
    }
  }

  Future<void> setPreferredPrinter(BluetoothDevice device) async {
    final address = device.address?.trim();
    if (address == null || address.isEmpty) {
      throw ArgumentError('Selected printer has no Bluetooth address.');
    }
    await prefs.setString(preferredPrinterAddressKey, address);
    final name = device.name?.trim();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(preferredPrinterNameKey, name);
    }
  }

  Future<int> enqueueReceipt(String entryId, {bool tryNow = true}) async {
    final jobId = await db.enqueueReceiptPrintJob(entryId);
    final telemetry = Telemetry.instance;
    if (telemetry != null) {
      unawaited(
        telemetry.event(
          'print_receipt_queued',
          props: {'entry_id': entryId, 'job_id': jobId},
        ),
      );
    }
    if (tryNow) {
      unawaited(pump());
    }
    return jobId;
  }

  Future<void> testPrint() async {
    if (!printerEnabled) {
      throw StateError('Printing is disabled.');
    }
    final device = await _resolvePreferredDevice();
    final printer = BlueThermalPrinter.instance;
    final isConnected = await printer.isConnected ?? false;
    if (!isConnected) {
      await printer.connect(device);
    }
    printer.printCustom('Soko Seller Terminal', 2, 1);
    printer.printCustom('Test print OK', 1, 1);
    printer.printCustom(DateTime.now().toLocal().toString(), 0, 1);
    printer.printNewLine();
    printer.paperCut();
  }

  Future<void> pump() async {
    if (_isPumping) {
      _pumpQueued = true;
      return;
    }
    if (!printerEnabled) return;

    _isPumping = true;
    try {
      final jobs = await db.pendingPrintJobs();
      if (jobs.isEmpty) return;

      for (final job in jobs) {
        if (!_isDue(job)) continue;
        try {
          final device = await _resolvePreferredDevice();
          await receiptService.printBluetooth(job.referenceId, device: device);
          await db.markPrintJobPrinted(job.id);
        } catch (e) {
          await db.markPrintJobFailed(
            job.id,
            retryCount: job.retryCount + 1,
            lastError: _formatError(e),
          );
        }
      }
    } finally {
      _isPumping = false;
    }

    if (_pumpQueued) {
      _pumpQueued = false;
      unawaited(pump());
    }
  }

  bool _isDue(PrintJob job) {
    if (job.lastTriedAt == null) return true;
    final delay = _backoff(job.retryCount);
    final nextAttemptAt = job.lastTriedAt!.toUtc().add(delay);
    return DateTime.now().toUtc().isAfter(nextAttemptAt);
  }

  Duration _backoff(int retryCount) {
    const base = Duration(seconds: 3);
    const max = Duration(minutes: 2);
    final multiplier = 1 << retryCount.clamp(0, 16);
    final delay = Duration(seconds: base.inSeconds * multiplier);
    return delay > max ? max : delay;
  }

  Future<BluetoothDevice> _resolvePreferredDevice() async {
    final addr = preferredPrinterAddress;
    if (addr == null) {
      throw StateError(
        'No preferred printer selected. Choose one in Settings.',
      );
    }
    final devices = await BlueThermalPrinter.instance.getBondedDevices();
    for (final d in devices) {
      if ((d.address ?? '').trim() == addr) return d;
    }
    throw StateError(
      'Preferred printer not found. Pair it in OS Bluetooth settings, then choose again.',
    );
  }

  String _formatError(Object error) {
    final raw = error.toString();
    if (raw.length <= 500) return raw;
    return raw.substring(0, 500);
  }
}
