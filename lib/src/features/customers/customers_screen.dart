import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_state.dart';
import '../widgets/section_header.dart';

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(appDatabaseProvider).watchCustomers();
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshSilently());
  }

  Future<void> _refreshSilently() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});
    try {
      await ref.read(syncServiceProvider).pullCustomers();
    } catch (_) {
      // The local CRM remains usable while offline.
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersStreamProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _refreshing
                ? const Padding(
                    key: ValueKey('syncing'),
                    padding: EdgeInsets.all(16),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('synced'),
                    tooltip: 'Refresh customers',
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: _refreshSilently,
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCustomer(context, ref),
          ),
        ],
      ),
      body: customers.when(
        data: (list) => RefreshIndicator(
          onRefresh: _refreshSilently,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: DesignTokens.paddingScreen,
            children: [
              Text(
                '${list.length} customer${list.length == 1 ? '' : 's'}',
                style: DesignTokens.textTitle,
              ),
              const SizedBox(height: DesignTokens.spaceXs),
              Text(
                _refreshing
                    ? 'Updating quietly…'
                    : 'Available instantly, even when you are offline',
                style: DesignTokens.textCaption,
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              const SectionHeader(title: 'Contacts'),
              ...list.map(
                (c) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DesignTokens.brandPrimary.withValues(
                        alpha: 0.08,
                      ),
                      child: Text(
                        c.name.trim().isEmpty
                            ? '?'
                            : c.name.trim()[0].toUpperCase(),
                      ),
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.phone ?? 'No phone number'),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const LoadingState(label: 'Opening customers…'),
        error: (e, _) => ErrorState(
          message: 'Your saved customers are safe. Try opening them again.',
          onRetry: () => ref.invalidate(customersStreamProvider),
        ),
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
              await ref
                  .read(appDatabaseProvider)
                  .upsertCustomer(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
            ),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
  }
}
