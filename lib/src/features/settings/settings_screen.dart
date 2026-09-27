import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/app_providers.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/security/manager_approval.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/firebase/remote_config_service.dart';
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
    final remoteConfig = ref.watch(remoteConfigProvider);
    final posSession = ref.watch(posSessionProvider);
    final config = ref.watch(appConfigProvider);
    final enabled = printer.printerEnabled;
    final printerLabel = printer.preferredPrinterLabel();
    final privacyPolicyUrl = _privacyPolicyUrl(config.apiBaseUrl);

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
              if (v && !await _ensurePrinterPermission()) return;
              if (!mounted) return;
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
              if (!await _ensurePrinterPermission() || !context.mounted) return;
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
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (!context.mounted) return;
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
                                if (!context.mounted) return;
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
          if (remoteConfig.ffPrintDiagnostics)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Print diagnostics'),
              subtitle: const Text('Permissions, connection, and test prints'),
              onTap: () => context.go('/home/more/print-diagnostics'),
            ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Test print'),
            subtitle: const Text('Send a test slip to the selected printer'),
            onTap: () async {
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
          FutureBuilder<bool>(
            future: ref.read(syncServiceProvider).isDeviceContactsOptedIn(),
            builder: (context, snapshot) {
              final optedIn = snapshot.data ?? false;
              return SwitchListTile(
                secondary: const Icon(Icons.contacts_outlined),
                title: const Text('Sync device contacts'),
                subtitle: const Text(
                  'Upload contact names, phone numbers and emails to Soko24 for your shop’s customer list across terminals. Optional; turn off to stop future sync.',
                ),
                value: optedIn,
                onChanged: (v) async {
                  final syncService = ref.read(syncServiceProvider);
                  await syncService.setDeviceContactsOptIn(v);
                  if (v) {
                    final status = await Permission.contacts.request();
                    if (status.isGranted) {
                      try {
                        await syncService.syncDeviceContacts(force: true);
                      } catch (_) {}
                      try {
                        await syncService.pullCrmContacts();
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contacts synced'),
                            backgroundColor: DesignTokens.brandAccent,
                          ),
                        );
                      }
                    } else if (status.isPermanentlyDenied) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Permission permanently denied. Enable it in Settings.',
                            ),
                          ),
                        );
                      }
                    }
                  }
                  if (mounted) setState(() {});
                },
              );
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
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & restore'),
            subtitle: const Text('Secure and recover local business data'),
            onTap: () => context.go('/home/more/backup'),
          ),
          if (posSession.isManager)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Staff menu access'),
              subtitle: const Text('Control what staff can see in More'),
              onTap: () => context.go('/home/more/staff-menu-access'),
            ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Delivery settings'),
            subtitle: const Text('Enable seller delivery, set fees'),
            onTap: () => context.go('/home/more/delivery-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Tax settings'),
            subtitle: const Text('Configure tax rate and inclusion mode'),
            onTap: () => context.go('/home/more/tax-settings'),
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Accounting'),
            subtitle: const Text('Sales summary and tax collected'),
            onTap: () => context.go('/home/more/accounting'),
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('Void reason codes'),
            subtitle: const Text('Required reasons for voids'),
            onTap: () async {
              final ok = await requireManagerPin(
                context,
                ref,
                reason: 'edit void reason codes',
              );
              if (!ok || !context.mounted) return;
              context.go('/home/more/void-reason-codes');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              try {
                await ref.read(authControllerProvider.notifier).logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            subtitle: Text(privacyPolicyUrl, style: DesignTokens.textSmall),
            onTap: () async {
              final uri = Uri.tryParse(privacyPolicyUrl);
              if (uri == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid privacy policy URL')),
                );
                return;
              }
              final ok = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open privacy policy'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Request account deletion'),
            subtitle: const Text(
              'Ask Soko24 to delete your account and associated data',
            ),
            onTap: () async {
              final uri = Uri.parse(
                privacyPolicyUrl,
              ).replace(path: '/account/delete-request');
              try {
                if (await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  return;
                }
              } catch (_) {}
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not open the deletion request page. Please try again.',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support'),
            subtitle: const Text('Soko24 help and contact information'),
            onTap: () => launchUrl(
              Uri.parse(privacyPolicyUrl).replace(path: '/contact-us'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensurePrinterPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.bluetoothConnect.request();
    if (status.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow nearby devices in app permissions to connect a receipt printer.',
          ),
        ),
      );
    }
    return false;
  }

  String _privacyPolicyUrl(String apiBaseUrl) {
    var base = apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return '$base/privacy-policy';
  }
}
