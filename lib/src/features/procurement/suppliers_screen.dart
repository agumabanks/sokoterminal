import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/error_page.dart';

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(appDatabaseProvider).watchSuppliers(activeOnly: false);
});

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Refreshed'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSupplier(context, ref),
        backgroundColor: DesignTokens.brandAccent,
        child: const Icon(Icons.add),
      ),
      body: suppliers.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: DesignTokens.paddingScreen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 56, color: DesignTokens.grayMedium),
                    const SizedBox(height: DesignTokens.spaceMd),
                    Text('No suppliers yet', style: DesignTokens.textBodyBold),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'Add suppliers to track purchasing and stock receiving.',
                      style: DesignTokens.textSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateSupplier(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add supplier'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(syncServiceProvider).syncNow(),
            child: ListView.separated(
              padding: DesignTokens.paddingScreen,
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spaceSm),
              itemBuilder: (context, index) {
                final s = rows[index];
                return _SupplierCard(
                  supplier: s,
                  onTap: () => _showEditSupplier(context, ref, s),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPage(
          title: 'Failed to load suppliers',
          message: e.toString(),
          onRetry: () => ref.read(syncServiceProvider).syncNow(),
        ),
      ),
    );
  }

  void _showCreateSupplier(BuildContext context, WidgetRef ref) {
    unawaited(() async {
      final approved = await requireManagerPin(
        context,
        ref,
        reason: 'add a supplier',
      );
      if (!approved) return;

      if (!context.mounted) return;
      final form = await BottomSheetModal.show<_SupplierFormResult>(
        context: context,
        title: 'Add Supplier',
        child: const _SupplierForm(),
      );
      if (form == null) return;
      if (!context.mounted) return;

      final api = ref.read(sellerApiProvider);
      final idempotencyKey = const Uuid().v4();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final connectivity = await Connectivity().checkConnectivity();
        final online = connectivity.any((r) => r != ConnectivityResult.none);
        if (!online) {
          throw Exception(
            'Internet required to create suppliers (POS session + idempotency).',
          );
        }

        await api.createSupplier(
          {
            'name': form.name,
            if (form.contactName?.trim().isNotEmpty == true) 'contact_name': form.contactName!.trim(),
            if (form.phone?.trim().isNotEmpty == true) 'phone': form.phone!.trim(),
            if (form.email?.trim().isNotEmpty == true) 'email': form.email!.trim(),
            if (form.address?.trim().isNotEmpty == true) 'address': form.address!.trim(),
            if (form.notes?.trim().isNotEmpty == true) 'notes': form.notes!.trim(),
            'active': form.active,
          },
          idempotencyKey: idempotencyKey,
        );

        await ref.read(syncServiceProvider).syncNow();
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Supplier created'),
            backgroundColor: DesignTokens.success,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create supplier: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }());
  }

  void _showEditSupplier(BuildContext context, WidgetRef ref, Supplier supplier) {
    unawaited(() async {
      final approved = await requireManagerPin(
        context,
        ref,
        reason: 'edit a supplier',
      );
      if (!approved) return;

      if (!context.mounted) return;
      final form = await BottomSheetModal.show<_SupplierFormResult>(
        context: context,
        title: 'Edit Supplier',
        child: _SupplierForm(
          initial: _SupplierFormResult(
            name: supplier.name,
            contactName: supplier.contactName,
            phone: supplier.phone,
            email: supplier.email,
            address: supplier.address,
            notes: supplier.notes,
            active: supplier.active,
          ),
          allowDelete: true,
        ),
      );
      if (form == null) return;
      if (!context.mounted) return;

      final api = ref.read(sellerApiProvider);
      final idempotencyKey = const Uuid().v4();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        if (form.delete == true) {
          await api.deleteSupplier(
            supplier.id,
            idempotencyKey: idempotencyKey,
          );
        } else {
          await api.updateSupplier(
            supplier.id,
            {
              'name': form.name,
              'contact_name': form.contactName,
              'phone': form.phone,
              'email': form.email,
              'address': form.address,
              'notes': form.notes,
              'active': form.active,
            },
            idempotencyKey: idempotencyKey,
          );
        }

        await ref.read(syncServiceProvider).syncNow();
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(form.delete == true ? 'Supplier removed' : 'Supplier updated'),
            backgroundColor: DesignTokens.success,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update supplier: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }());
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier, this.onTap});

  final Supplier supplier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if ((supplier.phone ?? '').trim().isNotEmpty) subtitleParts.add(supplier.phone!.trim());
    if ((supplier.contactName ?? '').trim().isNotEmpty) subtitleParts.add(supplier.contactName!.trim());
    final subtitle = subtitleParts.join(' • ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: supplier.active ? DesignTokens.brandPrimary : DesignTokens.grayMedium,
          child: const Icon(Icons.local_shipping_outlined, color: Colors.white),
        ),
        title: Text(supplier.name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SupplierFormResult {
  _SupplierFormResult({
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.active = true,
    this.delete,
  });

  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool active;
  final bool? delete;
}

class _SupplierForm extends StatefulWidget {
  const _SupplierForm({this.initial, this.allowDelete = false});

  final _SupplierFormResult? initial;
  final bool allowDelete;

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _contactCtrl = TextEditingController(text: widget.initial?.contactName ?? '');
    _phoneCtrl = TextEditingController(text: widget.initial?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.initial?.email ?? '');
    _addressCtrl = TextEditingController(text: widget.initial?.address ?? '');
    _notesCtrl = TextEditingController(text: widget.initial?.notes ?? '');
    _active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Supplier name'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _contactCtrl,
            decoration: const InputDecoration(labelText: 'Contact person (optional)'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address (optional)'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Row(
            children: [
              if (widget.allowDelete)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: DesignTokens.error),
                    onPressed: () => Navigator.pop(context, _SupplierFormResult(name: '', delete: true)),
                    child: const Text('Remove'),
                  ),
                ),
              if (widget.allowDelete) const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      _SupplierFormResult(
                        name: name,
                        contactName: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                        active: _active,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceSm),
        ],
      ),
    );
  }
}
