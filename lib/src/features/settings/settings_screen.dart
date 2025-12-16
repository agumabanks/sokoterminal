import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../auth/auth_controller.dart';
import '../receipts/receipt_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printQueueServiceProvider);
    final enabled = printer.printerEnabled;
    final printerLabel = printer.preferredPrinterLabel();

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: Text('Settings', style: DesignTokens.textTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Bluetooth printing'),
            subtitle: Text(
              enabled ? 'Enabled • Printer: $printerLabel' : 'Disabled',
              style: DesignTokens.textSmall,
            ),
            value: enabled,
            onChanged: (v) async {
              await ref.read(printQueueServiceProvider).setPrinterEnabled(v);
              if (!mounted) return;
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Choose printer'),
            subtitle: Text(
              'Current: $printerLabel',
              style: DesignTokens.textSmall,
            ),
            onTap: () async {
              final devices = await BlueThermalPrinter.instance
                  .getBondedDevices();
              if (!context.mounted) return;
              await BottomSheetModal.show<void>(
                context: context,
                title: 'Choose printer',
                subtitle: 'Pair in OS Bluetooth first',
                maxHeight: 520,
                child: devices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: DesignTokens.paddingMd,
                          child: Text(
                            'No paired printers found',
                            style: DesignTokens.textBody,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: devices.length,
                        itemBuilder: (sheetContext, index) {
                          final d = devices[index];
                          return ListTile(
                            leading: const Icon(Icons.print_outlined),
                            title: Text(d.name ?? 'Printer'),
                            subtitle: Text(
                              d.address ?? '',
                              style: DesignTokens.textSmall,
                            ),
                            onTap: () async {
                              try {
                                await ref
                                    .read(printQueueServiceProvider)
                                    .setPreferredPrinter(d);
                                await BlueThermalPrinter.instance.connect(d);
                                unawaited(
                                  ref.read(printQueueServiceProvider).pump(),
                                );
                                if (sheetContext.mounted)
                                  Navigator.of(sheetContext).pop();
                                if (!mounted) return;
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Selected printer: ${d.name ?? d.address ?? ''}',
                                    ),
                                    backgroundColor: DesignTokens.brandAccent,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to select printer: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_outlined),
            title: const Text('Print queue'),
            subtitle: const Text('Pending receipts, retries, errors'),
            onTap: () => context.go('/home/more/print-queue'),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Test print'),
            subtitle: const Text('Send a test slip to the selected printer'),
            onTap: () async {
              try {
                await ref.read(printQueueServiceProvider).testPrint();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Test print sent'),
                    backgroundColor: DesignTokens.brandAccent,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Test print failed: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            onTap: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sync started…')));
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sync finished')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Sync health'),
            subtitle: const Text('Queue size, last pull, failures'),
            onTap: () => context.go('/home/more/sync-health'),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export'),
            subtitle: const Text('Share CSV exports'),
            onTap: () => context.go('/home/more/export'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const ListTile(
            leading: Icon(Icons.support_agent),
            title: Text('Support'),
            subtitle: Text('WhatsApp: +256-700-000000'),
          ),
        ],
      ),
    );
  }
}
