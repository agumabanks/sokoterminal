import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../receipts/receipt_providers.dart';

final _printDiagnosticsJobsProvider = StreamProvider<List<PrintJob>>((ref) {
  return ref.watch(appDatabaseProvider).watchPrintJobs(limit: 50);
});

class PrintDiagnosticsScreen extends ConsumerStatefulWidget {
  const PrintDiagnosticsScreen({super.key});

  @override
  ConsumerState<PrintDiagnosticsScreen> createState() => _PrintDiagnosticsScreenState();
}

class _PrintDiagnosticsScreenState extends ConsumerState<PrintDiagnosticsScreen> {
  bool _loading = false;
  Map<String, PermissionStatus> _permissions = const {};
  List<BluetoothDevice> _paired = const [];
  bool _connected = false;
  String? _error;

  static const _certifiedPrinterHints = <String>[
    'XPRINTER (XP-P323B / XP-58)',
    'ZJ-58 / ZJ-5890',
    'MTP-II / MTP-2',
    'SPRT',
    'Gprinter',
  ];

  static const _certifiedPrinterMatchers = <String>[
    'xprinter',
    'xp-',
    'zj-58',
    'zj-5890',
    'mtp-ii',
    'mtp-2',
    'sprt',
    'gprinter',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = <String, PermissionStatus>{};
      if (Platform.isAndroid) {
        statuses['bluetoothConnect'] = await Permission.bluetoothConnect.status;
        statuses['bluetoothScan'] = await Permission.bluetoothScan.status;
        statuses['bluetoothAdvertise'] = await Permission.bluetoothAdvertise.status;
        statuses['locationWhenInUse'] = await Permission.locationWhenInUse.status;
      }

      final paired = await BlueThermalPrinter.instance.getBondedDevices();
      final connected = await BlueThermalPrinter.instance.isConnected ?? false;

      if (!mounted) return;
      setState(() {
        _permissions = statuses;
        _paired = paired;
        _connected = connected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printQueueServiceProvider);
    final jobsAsync = ref.watch(_printDiagnosticsJobsProvider);

    final enabled = printer.printerEnabled;
    final printerLabel = printer.preferredPrinterLabel();
    final preferredAddr = printer.preferredPrinterAddress;
    final isPreferredCertified = _isCertifiedPrinter(printerLabel);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Print diagnostics', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          final pending = jobs.where((j) => j.status == 'pending').length;
          String? lastError;
          for (final job in jobs) {
            final err = job.lastError?.trim();
            if (err != null && err.isNotEmpty) {
              lastError = err;
              break;
            }
          }

          final diagnosticsLog = _buildDiagnosticsLog(
            printerLabel: printerLabel,
            printerEnabled: enabled,
            isPreferredCertified: isPreferredCertified,
            preferredPrinterAddress: preferredAddr,
            connected: _connected,
            compatibilityMode: printer.compatibilityMode,
            permissions: _permissions,
            pairedPrinters: _paired,
            jobs: jobs,
            pendingJobCount: pending,
            lastError: lastError,
          );

          return ListView(
            padding: DesignTokens.paddingScreen,
            children: [
              if (_error != null)
                Card(
                  color: DesignTokens.error.withValues(alpha: 0.08),
                  child: Padding(
                    padding: DesignTokens.paddingMd,
                    child: Text(
                      _error!,
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
                    ),
                  ),
                ),
              _StatusTile(
                title: 'Printer',
                subtitle: enabled
                    ? 'Enabled • $printerLabel${isPreferredCertified ? ' • Certified' : ''}'
                    : 'Disabled',
                leading: Icons.print,
              ),
              _StatusTile(
                title: 'Connection',
                subtitle: _connected ? 'Connected' : 'Not connected',
                leading: Icons.bluetooth_connected,
              ),
              _StatusTile(
                title: 'Queue',
                subtitle: '$pending pending job(s)',
                leading: Icons.queue_outlined,
              ),
              if (lastError != null)
                _StatusTile(
                  title: 'Last error',
                  subtitle: lastError,
                  leading: Icons.error_outline,
                  tone: DesignTokens.error,
                ),
              const SizedBox(height: DesignTokens.spaceMd),
              SwitchListTile(
                title: const Text('Compatibility mode'),
                subtitle: const Text('Disables QR + paper cut for reliability'),
                value: printer.compatibilityMode,
                onChanged: (v) async {
                  await ref.read(printQueueServiceProvider).setCompatibilityMode(v);
                  if (!mounted) return;
                  setState(() {});
                },
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              try {
                                await ref.read(printQueueServiceProvider).testPrint();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Test print sent'),
                                    backgroundColor: DesignTokens.brandAccent,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Test print failed: $e')),
                                );
                              }
                            },
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Test print'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              await ref.read(printQueueServiceProvider).pump();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Retry started')),
                              );
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Retry queue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Share.share(
                          diagnosticsLog,
                          subject: 'Soko POS • Print diagnostics',
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share diagnostics'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await openAppSettings();
                        if (!context.mounted) return;
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open app settings')),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open app settings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              Text('Paired printers', style: DesignTokens.textBodyBold),
              const SizedBox(height: DesignTokens.spaceSm),
              if (_paired.isEmpty)
                Text(
                  'No paired printers found. Pair in Android Bluetooth settings first.',
                  style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                )
              else
                ..._paired.map((d) {
                  final addr = (d.address ?? '').trim();
                  final name = (d.name ?? 'Printer').trim();
                  final isPreferred = preferredAddr != null && preferredAddr == addr;
                  final isCertified = _isCertifiedPrinter(name);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isPreferred
                          ? (isCertified ? Icons.verified : Icons.check_circle)
                          : (isCertified ? Icons.verified_outlined : Icons.print_outlined),
                      color: isPreferred
                          ? DesignTokens.brandAccent
                          : (isCertified ? DesignTokens.brandAccent : DesignTokens.grayMedium),
                    ),
                    title: Text(name, style: DesignTokens.textBody),
                    subtitle: Text(
                      isCertified ? '$addr • Certified' : addr,
                      style: DesignTokens.textSmall,
                    ),
                  );
                }),
              const SizedBox(height: DesignTokens.spaceLg),
              Text('Permissions', style: DesignTokens.textBodyBold),
              const SizedBox(height: DesignTokens.spaceSm),
              if (!Platform.isAndroid)
                Text('Permissions diagnostics are Android-only.', style: DesignTokens.textSmall)
              else ...[
                if (_permissions.isEmpty)
                  Text('No permission info available.', style: DesignTokens.textSmall)
                else
                  ..._permissions.entries.map(
                    (e) => _StatusTile(
                      title: e.key,
                      subtitle: e.value.toString(),
                      leading: Icons.verified_user_outlined,
                      tone: e.value.isGranted ? DesignTokens.brandAccent : DesignTokens.warning,
                    ),
                  ),
                const SizedBox(height: DesignTokens.spaceSm),
                OutlinedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Request permissions'),
                ),
              ],
              const SizedBox(height: DesignTokens.spaceLg),
              Text('Certified printers (initial list)', style: DesignTokens.textBodyBold),
              const SizedBox(height: DesignTokens.spaceSm),
              ..._certifiedPrinterHints.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $s', style: DesignTokens.textSmall),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              if (_loading)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load print diagnostics: $e')),
      ),
    );
  }

  bool _isCertifiedPrinter(String label) {
    final l = label.trim().toLowerCase();
    if (l.isEmpty) return false;
    return _certifiedPrinterMatchers.any(l.contains);
  }

  String _buildDiagnosticsLog({
    required String printerLabel,
    required bool printerEnabled,
    required bool isPreferredCertified,
    required String? preferredPrinterAddress,
    required bool connected,
    required bool compatibilityMode,
    required Map<String, PermissionStatus> permissions,
    required List<BluetoothDevice> pairedPrinters,
    required List<PrintJob> jobs,
    required int pendingJobCount,
    required String? lastError,
  }) {
    final buf = StringBuffer();
    buf.writeln('Soko Seller Terminal — Print diagnostics');
    buf.writeln('Generated: ${DateTime.now().toLocal()}');
    buf.writeln('');
    buf.writeln('Printer enabled: $printerEnabled');
    buf.writeln('Preferred printer: $printerLabel');
    if (preferredPrinterAddress != null) {
      buf.writeln('Preferred address: $preferredPrinterAddress');
    }
    buf.writeln('Certified (heuristic): $isPreferredCertified');
    buf.writeln('Connected: $connected');
    buf.writeln('Compatibility mode: $compatibilityMode');
    buf.writeln('');
    buf.writeln('Queue pending jobs: $pendingJobCount');
    if (lastError != null) {
      buf.writeln('Last error: $lastError');
    }
    buf.writeln('');

    buf.writeln('Permissions:');
    if (permissions.isEmpty) {
      buf.writeln('- (no data)');
    } else {
      for (final e in permissions.entries) {
        buf.writeln('- ${e.key}: ${e.value}');
      }
    }
    buf.writeln('');

    buf.writeln('Paired printers: ${pairedPrinters.length}');
    for (final d in pairedPrinters) {
      final name = (d.name ?? 'Printer').trim();
      final addr = (d.address ?? '').trim();
      final certified = _isCertifiedPrinter(name);
      buf.writeln('- $name ($addr)${certified ? ' [CERTIFIED_HINT]' : ''}');
    }
    buf.writeln('');

    buf.writeln('Recent jobs (max 50):');
    for (final j in jobs) {
      buf.writeln(
        '- id=${j.id} ref=${j.referenceId} status=${j.status} retry=${j.retryCount} '
        'lastTriedAt=${j.lastTriedAt?.toIso8601String()} lastError=${j.lastError}',
      );
    }
    return buf.toString();
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    this.tone,
  });

  final String title;
  final String subtitle;
  final IconData leading;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = tone ?? DesignTokens.grayMedium;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(leading, color: c),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DesignTokens.textSmallBold),
                const SizedBox(height: 2),
                Text(subtitle, style: DesignTokens.textSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
