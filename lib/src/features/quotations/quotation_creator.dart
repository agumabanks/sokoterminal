import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/app_button.dart';
import '../ads/studio_editor_launcher.dart';
import '../../widgets/app_input.dart';
import '../../widgets/bottom_sheet_modal.dart';

class QuotationCreator extends ConsumerStatefulWidget {
  const QuotationCreator({super.key});

  @override
  ConsumerState<QuotationCreator> createState() => _QuotationCreatorState();
}

class _QuotationCreatorState extends ConsumerState<QuotationCreator> {
  Customer? _selectedCustomer;
  final List<QuotationLineItem> _lines = [];
  final _notesCtrl = TextEditingController();
  final _quotationId = const Uuid().v4();
  int _validityDays = 7;
  bool _saving = false;

  double get _total =>
      _lines.fold(0, (sum, line) => sum + (line.unitPrice * line.quantity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Create Quotation'),
        actions: [
          IconButton(
            tooltip: 'Design in Studio',
            icon: const Icon(Icons.design_services_rounded),
            onPressed: () async {
              await launchFullStudioWeb(
                context,
                ref,
                quotationId: _quotationId,
                openPanel: 'business-branding',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: DesignTokens.paddingScreen,
              children: [
                // Customer Section
                _buildSectionHeader('Customer'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: DesignTokens.brandPrimary.withValues(
                      alpha: 0.1,
                    ),
                    child: _selectedCustomer != null
                        ? Text(
                            _selectedCustomer!.name.isNotEmpty
                                ? _selectedCustomer!.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: DesignTokens.brandPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Icon(Icons.person, color: DesignTokens.brandPrimary),
                  ),
                  title: Text(_selectedCustomer?.name ?? 'Select Customer'),
                  subtitle: _selectedCustomer != null
                      ? Text(_selectedCustomer!.phone ?? '')
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectCustomer,
                ),
                const Divider(),

                // Items Section
                _buildSectionHeader('Items'),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No items added',
                        style: DesignTokens.textSmall,
                      ),
                    ),
                  )
                else
                  ..._lines.asMap().entries.map(
                    (entry) => _buildLineItem(entry.key, entry.value),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '+ Products / Services',
                        onPressed: _pickFromProducts,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: '+ Custom Item',
                        variant: AppButtonVariant.outline,
                        onPressed: _addLineItem,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceLg),

                // Validity Section
                _buildSectionHeader('Validity & Notes'),
                Wrap(
                  spacing: 8,
                  children: [3, 7, 14, 30].map((days) {
                    final isSelected = _validityDays == days;
                    return ChoiceChip(
                      label: Text('$days Days'),
                      selected: isSelected,
                      onSelected: (v) => setState(() => _validityDays = days),
                    );
                  }).toList(),
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                AppInput(
                  controller: _notesCtrl,
                  label: 'Notes (Optional)',
                  maxLines: 2,
                ),
              ],
            ),
          ),

          // Bottom Bar
          Container(
            padding: DesignTokens.paddingScreen,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              boxShadow: DesignTokens.shadowSm,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: DesignTokens.textBody),
                      Text(_total.toUgx(), style: DesignTokens.textTitle),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  AppButton(
                    label: _saving ? 'Saving…' : 'Save Quotation',
                    isLoading: _saving,
                    onPressed:
                        _saving || _selectedCustomer == null || _lines.isEmpty
                        ? null
                        : _saveQuotation,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: DesignTokens.spaceSm,
        top: DesignTokens.spaceMd,
      ),
      child: Text(title, style: DesignTokens.textBodyBold),
    );
  }

  Widget _buildLineItem(int index, QuotationLineItem line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.description,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${line.unitPrice.toUgx()} each',
                    style: DesignTokens.textSmall),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (line.quantity > 1) {
                    setState(() => _lines[index] = QuotationLineItem(
                      description: line.description,
                      quantity: line.quantity - 1,
                      unitPrice: line.unitPrice,
                    ));
                  }
                },
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, size: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${line.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              GestureDetector(
                onTap: () => setState(() => _lines[index] = QuotationLineItem(
                  description: line.description,
                  quantity: line.quantity + 1,
                  unitPrice: line.unitPrice,
                )),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 16, color: DesignTokens.brandAccent),
                ),
              ),
              const SizedBox(width: 8),
              Text((line.unitPrice * line.quantity).toUgx(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _lines.removeAt(index)),
            child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Product + Services picker (tabbed)
  // -------------------------------------------------------------------------

  Future<void> _pickFromProducts() async {
    final db = ref.read(appDatabaseProvider);
    final allItems = await db.getAllItems();
    final allServices = await db.getAllServices();
    if (!mounted) return;

    String query = '';
    // 0 = Products, 1 = Services
    int tabIndex = 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filteredItems = query.isEmpty
              ? allItems
              : allItems.where((i) =>
                  i.name.toLowerCase().contains(query.toLowerCase()) ||
                  (i.categoryName?.toLowerCase().contains(query.toLowerCase()) ?? false))
                .toList();

          final filteredServices = query.isEmpty
              ? allServices
              : allServices.where((s) =>
                  s.title.toLowerCase().contains(query.toLowerCase()) ||
                  (s.category?.toLowerCase().contains(query.toLowerCase()) ?? false))
                .toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.80,
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Tab toggle: Products | Services
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _pickerTab(
                        label: 'Products (${allItems.length})',
                        selected: tabIndex == 0,
                        onTap: () => setModal(() {
                          tabIndex = 0;
                          query = '';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _pickerTab(
                        label: 'Services (${allServices.length})',
                        selected: tabIndex == 1,
                        onTap: () => setModal(() {
                          tabIndex = 1;
                          query = '';
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    key: ValueKey('search_$tabIndex'),
                    autofocus: false,
                    onChanged: (v) => setModal(() => query = v),
                    decoration: InputDecoration(
                      hintText: tabIndex == 0
                          ? 'Search products…'
                          : 'Search services…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                // List
                Expanded(
                  child: tabIndex == 0
                      ? _buildProductList(ctx, filteredItems)
                      : _buildServiceList(ctx, filteredServices),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pickerTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? DesignTokens.brandPrimary
                : DesignTokens.brandPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : DesignTokens.brandPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(BuildContext ctx, List<Item> filtered) {
    if (filtered.isEmpty) {
      return const Center(child: Text('No products found'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final item = filtered[i];
        return ListTile(
          leading: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    item.imageUrl!,
                    width: 40, height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.inventory_2_rounded),
                  ),
                )
              : const Icon(Icons.inventory_2_rounded),
          title: Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${item.categoryName ?? 'General'} · ${item.price.toUgx()}',
            style: DesignTokens.textSmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: DesignTokens.brandAccent),
            onPressed: () {
              setState(() {
                _lines.add(QuotationLineItem(
                  description: item.name,
                  quantity: 1,
                  unitPrice: item.price,
                ));
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${item.name} added')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceList(BuildContext ctx, List<Service> filtered) {
    if (filtered.isEmpty) {
      return const Center(child: Text('No services found'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final svc = filtered[i];
        return ListTile(
          leading: svc.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    svc.imageUrl!,
                    width: 40, height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.room_service_rounded),
                  ),
                )
              : const Icon(Icons.room_service_rounded),
          title: Text(svc.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${svc.category ?? 'Service'} · ${svc.price.toUgx()}',
            style: DesignTokens.textSmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: DesignTokens.brandAccent),
            onPressed: () {
              setState(() {
                _lines.add(QuotationLineItem(
                  description: svc.title,
                  quantity: 1,
                  unitPrice: svc.price,
                ));
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${svc.title} added')),
              );
            },
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Searchable customer picker with inline quick-add
  // -------------------------------------------------------------------------

  Future<void> _selectCustomer() async {
    final db = ref.read(appDatabaseProvider);
    final customers = await db
        .select(db.customers)
        .get();
    if (!mounted) return;

    String query = '';
    bool showAddForm = false;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = query.isEmpty
              ? customers
              : customers.where((c) =>
                  c.name.toLowerCase().contains(query.toLowerCase()) ||
                  (c.phone?.toLowerCase().contains(query.toLowerCase()) ?? false))
                .toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Customer',
                          style: DesignTokens.textBodyBold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Quick Add'),
                        onPressed: () => setModal(() {
                          showAddForm = !showAddForm;
                        }),
                      ),
                    ],
                  ),
                ),
                // Inline quick-add form
                if (showAddForm)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.brandPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: DesignTokens.brandPrimary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('New Contact',
                              style: DesignTokens.textBodyBold.copyWith(fontSize: 13)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              final phone = phoneCtrl.text.trim();
                              final newId = const Uuid().v4();
                              await db.upsertCustomer(
                                CustomersCompanion.insert(
                                  id: Value(newId),
                                  name: name,
                                  phone: phone.isEmpty
                                      ? const Value.absent()
                                      : Value(phone),
                                  synced: const Value(false),
                                ),
                              );
                              final newCustomer =
                                  await db.getCustomerById(newId);
                              if (newCustomer != null && mounted) {
                                setState(
                                  () => _selectedCustomer = newCustomer,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$name added')),
                                );
                              }
                            },
                            child: const Text('Save & Select'),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) => setModal(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                // Customer list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 48, color: DesignTokens.grayMedium),
                              const SizedBox(height: 12),
                              Text(
                                customers.isEmpty
                                    ? 'No customers yet — add one above'
                                    : 'No results',
                                style: DesignTokens.textSmall.copyWith(
                                  color: DesignTokens.grayMedium,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final c = filtered[i];
                            final initials = c.name.trim().isNotEmpty
                                ? c.name.trim()[0].toUpperCase()
                                : '?';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: DesignTokens.brandPrimary
                                    .withValues(alpha: 0.12),
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: DesignTokens.brandPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: c.phone?.isNotEmpty == true
                                  ? Text(c.phone!)
                                  : null,
                              onTap: () {
                                setState(() => _selectedCustomer = c);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addLineItem() async {
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    await BottomSheetModal.show<void>(
      context: context,
      title: 'Add Item',
      child: Column(
        children: [
          AppInput(controller: descCtrl, label: 'Description'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  controller: qtyCtrl,
                  label: 'Qty',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppInput(
                  controller: priceCtrl,
                  label: 'Price',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Add',
            onPressed: () {
              final desc = descCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (desc.isNotEmpty && price > 0) {
                setState(() {
                  _lines.add(
                    QuotationLineItem(
                      description: desc,
                      quantity: qty,
                      unitPrice: price,
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveQuotation() async {
    if (_selectedCustomer == null) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);

      final number =
          'QT-${DateFormat('yyyy').format(DateTime.now())}-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
      final expiry = DateTime.now().add(Duration(days: _validityDays));

      await db.saveQuotation(
        header: QuotationsCompanion.insert(
          id: Value(_quotationId),
          customerId: Value(_selectedCustomer!.id),
          number: number,
          date: Value(DateTime.now().toUtc()),
          validUntil: Value(expiry.toUtc()),
          totalAmount: _total,
          status: const Value('draft'),
          notes: Value(_notesCtrl.text),
          synced: const Value(false),
        ),
        lines: _lines
            .map(
              (l) => QuotationLinesCompanion.insert(
                id: Value(const Uuid().v4()),
                quotationId: _quotationId,
                description: l.description,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
                total: l.quantity * l.unitPrice,
              ),
            )
            .toList(),
      );

      final customerId = _selectedCustomer!.remoteId ?? _selectedCustomer!.id;
      final notes = _notesCtrl.text.trim();
      await sync.enqueue('quotation_push', {
        'idempotency_key': _quotationId,
        'id': _quotationId,
        'quotation_number': number,
        'customer_id': customerId,
        'validity_days': _validityDays,
        'total': _total,
        if (notes.isNotEmpty) 'notes': notes,
        'lines': _lines
            .map(
              (l) => {
                'title': l.description,
                'price': l.unitPrice,
                'quantity': l.quantity,
                'total': l.quantity * l.unitPrice,
              },
            )
            .toList(),
      });
      unawaited(sync.syncNow());

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quotation saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save quotation: $e'),
          backgroundColor: DesignTokens.error,
        ),
      );
    }
  }
}

class QuotationLineItem {
  final String description;
  final int quantity;
  final double unitPrice;

  QuotationLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });
}
