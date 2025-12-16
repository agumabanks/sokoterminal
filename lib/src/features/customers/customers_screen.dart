import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../widgets/section_header.dart';

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(appDatabaseProvider).watchCustomers();
});

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersStreamProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCustomer(context, ref),
          ),
        ],
      ),
      body: customers.when(
        data: (list) => ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            const SectionHeader(title: 'Contacts'),
            ...list.map((c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(c.name),
                    subtitle: Text(c.phone ?? '-'),
                  ),
                )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showAddCustomer(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final parentContext = context;

    await BottomSheetModal.show<void>(
      context: context,
      title: 'Add customer',
      subtitle: 'Save to local CRM',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton.icon(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await ref.read(appDatabaseProvider).upsertCustomer(
                    CustomersCompanion.insert(
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? const Value.absent()
                          : Value(phoneCtrl.text.trim()),
                    ),
                  );
              if (!parentContext.mounted) return;
              Navigator.pop(parentContext);
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: const Text('Customer added'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
  }
}
