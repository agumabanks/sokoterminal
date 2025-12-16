import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/sync/sync_service.dart';
import '../auth/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Bluetooth printer enabled'),
            subtitle: const Text('Pair in OS settings, we will reuse the last device'),
            value: true,
            onChanged: (_) {},
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Choose printer'),
            onTap: () async {
              final devices = await BlueThermalPrinter.instance.getBondedDevices();
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                builder: (_) => ListView(
                  children: devices
                      .map(
                        (d) => ListTile(
                          title: Text(d.name ?? 'Printer'),
                          subtitle: Text(d.address ?? ''),
                          onTap: () async {
                            await BlueThermalPrinter.instance.connect(d);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync started…')),
              );
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync finished')),
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
