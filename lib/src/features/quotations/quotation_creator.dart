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
  int _validityDays = 7;
  DateTime _createdAt = DateTime.now();

  double get _total => _lines.fold(0, (sum, line) => sum + (line.unitPrice * line.quantity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: const Text('Create Quotation')),
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
                    backgroundColor: DesignTokens.brandPrimary.withOpacity(0.1),
                    child: Icon(Icons.person, color: DesignTokens.brandPrimary),
                  ),
                  title: Text(_selectedCustomer?.name ?? 'Select Customer'),
                  subtitle: _selectedCustomer != null ? Text(_selectedCustomer!.phone ?? '') : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectCustomer,
                ),
                const Divider(),

                // Items Section
                _buildSectionHeader('Items'),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No items added', style: DesignTokens.textSmall)),
                  )
                else
                  ..._lines.asMap().entries.map((entry) => _buildLineItem(entry.key, entry.value)),
                
                AppButton(
                  label: 'Add Item',
                  variant: AppButtonVariant.outline,
                  onPressed: _addLineItem,
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
              boxShadow: DesignTokens.shadowSm, // Fixed: shadowUp -> shadowSm
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: DesignTokens.textBody),
                      Text(
                        _total.toUgx(),
                        style: DesignTokens.textTitle, 
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  AppButton(
                    label: 'Save Quotation',
                    onPressed: _selectedCustomer == null || _lines.isEmpty ? null : _saveQuotation,
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
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm, top: DesignTokens.spaceMd),
      child: Text(title, style: DesignTokens.textBodyBold),
    );
  }

  Widget _buildLineItem(int index, QuotationLineItem line) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: ListTile(
        title: Text(line.description),
        subtitle: Text('${line.quantity} x ${line.unitPrice.toUgx()}'),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: () => setState(() => _lines.removeAt(index)),
        ),
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final customers = await ref.read(appDatabaseProvider).select(ref.read(appDatabaseProvider).customers).get();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: customers.length,
        itemBuilder: (ctx, i) {
          final c = customers[i];
          return ListTile(
            title: Text(c.name),
            subtitle: Text(c.phone ?? ''),
            onTap: () {
              setState(() => _selectedCustomer = c);
              Navigator.pop(ctx);
            },
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
              Expanded(child: AppInput(controller: qtyCtrl, label: 'Qty', keyboardType: TextInputType.number)),
              const SizedBox(width: 16),
              Expanded(child: AppInput(controller: priceCtrl, label: 'Price', keyboardType: TextInputType.number)),
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
                   _lines.add(QuotationLineItem(description: desc, quantity: qty, unitPrice: price));
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

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    
    final quotationId = const Uuid().v4();
    final number = 'QT-${DateFormat('yyyy').format(DateTime.now())}-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    final expiry = DateTime.now().add(Duration(days: _validityDays));

    await db.saveQuotation(
      header: QuotationsCompanion.insert(
        id: Value(quotationId), // Wrapped in Value
        customerId: Value(_selectedCustomer!.id),
        number: number,
        date: Value(DateTime.now().toUtc()), // Wrapped in Value
        validUntil: Value(expiry.toUtc()),
        totalAmount: _total,
        status: const Value('draft'), // draft, sent, accepted
        notes: Value(_notesCtrl.text),
        synced: const Value(true),
      ),
      lines: _lines.map((l) => QuotationLinesCompanion.insert(
        id: Value(const Uuid().v4()), // Wrapped in Value
        quotationId: quotationId, // Not wrapped (non-nullable Ref often allows raw value in insert, but let's be safe?) - Actually refs usually take Value if checking logic is strict, but References usually allow raw. The ERROR was on id, customerId, date? Let's verify.
        description: l.description,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        total: l.quantity * l.unitPrice,
      )).toList(),
    );

    // Enqueue sync - assuming sync keys exist
    await sync.enqueue('quotation_create', {
      'local_id': quotationId,
      'customer_id': _selectedCustomer!.id,
      'number': number,
      'total': _total,
      'valid_until': expiry.toIso8601String(),
      'lines': _lines.map((l) => {
        'description': l.description,
        'qty': l.quantity,
        'price': l.unitPrice
      }).toList(),
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation saved')));
  }
}

class QuotationLineItem {
  final String description;
  final int quantity;
  final double unitPrice;

  QuotationLineItem({required this.description, required this.quantity, required this.unitPrice});
}
