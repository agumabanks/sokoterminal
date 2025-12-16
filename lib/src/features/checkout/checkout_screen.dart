import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/security/manager_approval.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import 'cart_controller.dart';
import 'parked_sales_controller.dart';

final itemsStreamProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(appDatabaseProvider).watchItems();
});

final servicesStreamProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(appDatabaseProvider).watchServices();
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(appDatabaseProvider).watchCustomers();
});

/// Checkout Screen — The primary POS interface for sellers.
/// 
/// Redesigned with premium UI following "Steve Jobs standard":
/// - Clean product/service tiles
/// - Smooth cart interactions
/// - Bottom sheet modals instead of dialogs
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const _uuid = Uuid();
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _scanLocked = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);
    final cart = ref.watch(cartControllerProvider);
    final parked = ref.watch(parkedSalesProvider);
    final cartController = ref.read(cartControllerProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Point of Sale', style: DesignTokens.textTitle),
        actions: [
          if (parked.isNotEmpty)
            Badge(
              label: Text('${parked.length}'),
              child: IconButton(
                icon: const Icon(Icons.playlist_add_check),
                onPressed: () => _showParkedSales(context, ref),
                tooltip: 'Parked sales',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref),
            tooltip: 'More options',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;

          // ─────────────────────────────────────────────────────────────────
          // CATALOG PANE
          // ─────────────────────────────────────────────────────────────────
          final catalogPane = CustomScrollView(
            slivers: [
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: DesignTokens.paddingScreen,
                  child: _SearchBar(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    onScan: () => _openScanner(context),
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
              ),
              
              // Products section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spaceMd,
                    DesignTokens.spaceSm,
                    DesignTokens.spaceMd,
                    DesignTokens.spaceSm,
                  ),
                  child: Text('Products', style: DesignTokens.textBodyBold),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                sliver: itemsAsync.when(
                  data: (items) {
                    final filtered = _query.isEmpty
                        ? items
                        : items.where((item) => _matchesItem(item, _query)).toList();
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptySearchState(
                          message: _query.isEmpty ? 'No products yet' : 'No matching products',
                        ),
                      );
                    }
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 4 : 3,
                        mainAxisSpacing: DesignTokens.spaceSm,
                        crossAxisSpacing: DesignTokens.spaceSm,
                        childAspectRatio: 0.9,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filtered[index];
                          return _ProductTile(
                            name: item.name,
                            price: item.price,
                            stock: item.stockQty,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(cartControllerProvider.notifier).addItem(item: item);
                            },
                          );
                        },
                        childCount: filtered.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: DesignTokens.paddingMd,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _ErrorState(message: 'Failed to load products'),
                  ),
                ),
              ),
              
              // Services section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spaceMd,
                    DesignTokens.spaceLg,
                    DesignTokens.spaceMd,
                    DesignTokens.spaceSm,
                  ),
                  child: Text('Services', style: DesignTokens.textBodyBold),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                sliver: servicesAsync.when(
                  data: (services) {
                    final filtered = _query.isEmpty
                        ? services
                        : services.where((s) => _matchesService(s, _query)).toList();
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptySearchState(
                          message: _query.isEmpty ? 'No services yet' : 'No matching services',
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final service = filtered[index];
                          return _ServiceTile(
                            title: service.title,
                            price: service.price,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(cartControllerProvider.notifier).addService(service: service);
                            },
                          );
                        },
                        childCount: filtered.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: DesignTokens.paddingMd,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _ErrorState(message: 'Failed to load services'),
                  ),
                ),
              ),
              
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );

          // ─────────────────────────────────────────────────────────────────
          // CART PANE
          // ─────────────────────────────────────────────────────────────────
          final cartPane = _CartPane(
            cart: cart,
            customer: cart.customer,
            parkedCount: parked.length,
            onSelectCustomer: () => _selectCustomer(context),
            onUpdateQuantity: (id, quantity) => cartController.updateQuantity(id, quantity),
            onEditPrice: (line) => _showPriceOverride(context, line),
            onPark: () => _showParkSale(context, ref),
            onCheckout: () => _handleCheckout(context, ref),
            onClear: () => cartController.clear(),
          );

          // ─────────────────────────────────────────────────────────────────
          // LAYOUT
          // ─────────────────────────────────────────────────────────────────
          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 6, child: catalogPane),
                Container(
                  width: 1,
                  color: DesignTokens.grayLight,
                ),
                SizedBox(
                  width: 360,
                  child: cartPane,
                ),
              ],
            );
          }

          // Narrow layout with floating cart summary
          return Stack(
            children: [
              catalogPane,
              if (cart.lines.isNotEmpty)
                Positioned(
                  left: DesignTokens.spaceMd,
                  right: DesignTokens.spaceMd,
                  bottom: DesignTokens.spaceMd,
                  child: _FloatingCartSummary(
                    itemCount: cart.lines.length,
                    total: cart.subtotal,
                    onTap: () => _showCartSheet(context, ref),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesItem(Item item, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (item.name.toLowerCase().contains(q)) return true;
    if (item.id.toLowerCase().contains(q)) return true;
    final sku = item.sku?.toLowerCase();
    if (sku != null && sku.contains(q)) return true;
    final barcode = item.barcode?.toLowerCase();
    if (barcode != null && barcode.contains(q)) return true;
    return false;
  }

  bool _matchesService(Service service, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (service.title.toLowerCase().contains(q)) return true;
    if (service.id.toLowerCase().contains(q)) return true;
    final desc = service.description?.toLowerCase();
    if (desc != null && desc.contains(q)) return true;
    return false;
  }

  Future<void> _openScanner(BuildContext context) async {
    if (_scanLocked) return;
    _scanLocked = true;
    try {
      final code = await BottomSheetModal.show<String>(
        context: context,
        title: 'Scan Barcode / QR',
        subtitle: 'Point camera at a code',
        maxHeight: 520,
        child: const _BarcodeScannerSheet(),
      );
      if (code == null || code.trim().isEmpty) return;
      await _handleScannedCode(code.trim());
    } finally {
      _scanLocked = false;
    }
  }

  Future<void> _handleScannedCode(String code) async {
    _searchCtrl.text = code;
    setState(() => _query = code.toLowerCase());

    final db = ref.read(appDatabaseProvider);
    final match = await (db.select(db.items)
          ..where((t) =>
              t.barcode.equals(code) | t.sku.equals(code) | t.id.equals(code)))
        .getSingleOrNull();

    if (match == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No matching product for "$code"')),
      );
      return;
    }

    ref.read(cartControllerProvider.notifier).addItem(item: match);
    HapticFeedback.selectionClick();
    _searchCtrl.clear();
    setState(() => _query = '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${match.name}"'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  Future<void> _selectCustomer(BuildContext context) async {
    const walkIn = '__walkin__';

    String filter = '';
    final selectedId = await BottomSheetModal.show<String>(
      context: context,
      title: 'Customer',
      subtitle: 'Walk-in or saved customer',
      maxHeight: 520,
      child: StatefulBuilder(
        builder: (sheetContext, setState) {
          return Consumer(
            builder: (context, ref, _) {
              final customersAsync = ref.watch(customersStreamProvider);
              return customersAsync.when(
                data: (customers) {
                  final filtered = filter.isEmpty
                      ? customers
                      : customers
                          .where((c) =>
                              c.name.toLowerCase().contains(filter) ||
                              (c.phone ?? '').toLowerCase().contains(filter))
                          .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => filter = v.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          labelText: 'Search customers',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      Container(
                        decoration: BoxDecoration(
                          color: DesignTokens.surfaceWhite,
                          borderRadius: DesignTokens.borderRadiusMd,
                          border: Border.all(color: DesignTokens.grayLight),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.directions_walk),
                          title: const Text('Walk-in customer'),
                          subtitle: const Text('No customer attached'),
                          onTap: () => Navigator.of(sheetContext).pop(walkIn),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('No customers found', style: DesignTokens.textSmall),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final c = filtered[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(c.name),
                                    subtitle: Text(c.phone ?? c.email ?? ''),
                                    onTap: () => Navigator.of(sheetContext).pop(c.id),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: DesignTokens.spaceSm),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final createdId = await _addCustomer(sheetContext);
                          if (createdId == null) return;
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop(createdId);
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Add new customer'),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              );
            },
          );
        },
      ),
    );

    if (selectedId == null) return;

    final cartController = ref.read(cartControllerProvider.notifier);
    if (selectedId == walkIn) {
      cartController.setCustomer(null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk-in customer selected')),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final customer =
        await (db.select(db.customers)..where((t) => t.id.equals(selectedId))).getSingleOrNull();
    cartController.setCustomer(customer);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(customer == null ? 'Customer selected' : 'Customer: ${customer.name}'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  Future<String?> _addCustomer(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final created = await BottomSheetModal.show<String>(
      context: context,
      title: 'New Customer',
      subtitle: 'Quick add',
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
          const SizedBox(height: DesignTokens.spaceSm),
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
              final id = _uuid.v4();
              await ref.read(appDatabaseProvider).upsertCustomer(
                    CustomersCompanion.insert(
                      id: Value(id),
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? const Value.absent()
                          : Value(phoneCtrl.text.trim()),
                      updatedAt: Value(DateTime.now().toUtc()),
                    ),
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop(id);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Customer'),
          ),
        ],
      ),
    );

    if (!mounted) return null;
    return created;
  }

  Future<void> _showPriceOverride(BuildContext context, CartLine line) async {
    final ok = await requireManagerPin(context, ref, reason: 'Price override: ${line.title}');
    if (!context.mounted) return;
    if (!ok) return;

    final priceCtrl = TextEditingController(text: line.price.toStringAsFixed(0));
    final newPrice = await BottomSheetModal.show<double>(
      context: context,
      title: 'Price Override',
      subtitle: line.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Original: UGX ${line.price.toStringAsFixed(0)}',
            style: DesignTokens.textSmall,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'New price (UGX)',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton.icon(
            onPressed: () {
              final p = double.tryParse(priceCtrl.text.trim());
              if (p == null || p <= 0) return;
              Navigator.of(context).pop(p);
            },
            icon: const Icon(Icons.check),
            label: const Text('Apply'),
          ),
        ],
      ),
    );

    if (newPrice == null) return;
    ref.read(cartControllerProvider.notifier).updatePrice(line.id, newPrice);
    await ref.read(appDatabaseProvider).recordAuditLog(
          action: 'price_override',
          payload: {
            'line_id': line.id,
            'title': line.title,
            'from': line.price,
            'to': newPrice,
            'at': DateTime.now().toUtc().toIso8601String(),
          },
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Price updated to UGX ${newPrice.toStringAsFixed(0)}'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  void _showCartSheet(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartControllerProvider);
    final parked = ref.read(parkedSalesProvider);
    final cartController = ref.read(cartControllerProvider.notifier);
    
    BottomSheetModal.show(
      context: context,
      title: 'Cart',
      subtitle: '${cart.lines.length} items',
      child: _CartPane(
        cart: cart,
        customer: cart.customer,
        parkedCount: parked.length,
        onSelectCustomer: () {
          Navigator.pop(context);
          _selectCustomer(context);
        },
        onUpdateQuantity: (id, quantity) => cartController.updateQuantity(id, quantity),
        onEditPrice: (line) {
          Navigator.pop(context);
          _showPriceOverride(context, line);
        },
        onPark: () {
          Navigator.pop(context);
          _showParkSale(context, ref);
        },
        onCheckout: () {
          Navigator.pop(context);
          _handleCheckout(context, ref);
        },
        onClear: () {
          cartController.clear();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _handleCheckout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartControllerProvider);
    if (cart.lines.isEmpty) return;
    
    // Show payment method selection
    final paymentMethod = await BottomSheetModal.show<String>(
      context: context,
      title: 'Select Payment Method',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PaymentMethodTile(
            icon: Icons.money,
            title: 'Cash',
            subtitle: 'Pay with cash',
            onTap: () => Navigator.pop(context, 'cash'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          _PaymentMethodTile(
            icon: Icons.phone_android,
            title: 'Mobile Money',
            subtitle: 'MTN, Airtel, etc.',
            onTap: () => Navigator.pop(context, 'mobile_money'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          _PaymentMethodTile(
            icon: Icons.credit_card,
            title: 'Card',
            subtitle: 'Visa, Mastercard',
            onTap: () => Navigator.pop(context, 'card'),
          ),
        ],
      ),
    );

    if (paymentMethod == null || !context.mounted) return;

    final id = await ref
        .read(cartControllerProvider.notifier)
        .checkout(paymentMethod: paymentMethod);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: DesignTokens.surfaceWhite),
              const SizedBox(width: DesignTokens.spaceSm),
              Text('Sale completed! Receipt #$id'),
            ],
          ),
          backgroundColor: DesignTokens.brandAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showParkSale(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartControllerProvider);
    if (cart.lines.isEmpty) return;
    
    final labelCtrl = TextEditingController(
      text: 'Parked ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
    
    BottomSheetModal.show(
      context: context,
      title: 'Park Sale',
      subtitle: 'Save this sale to resume later',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'E.g., "Table 5" or "John\'s order"',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Container(
            padding: DesignTokens.paddingMd,
            decoration: BoxDecoration(
              color: DesignTokens.grayLight.withOpacity(0.3),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${cart.lines.length} items', style: DesignTokens.textBody),
                Text(
                  'UGX ${cart.subtotal.toStringAsFixed(0)}',
                  style: DesignTokens.textBodyBold,
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(parkedSalesProvider.notifier).parkSale(cart, label: labelCtrl.text.trim());
              ref.read(cartControllerProvider.notifier).clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sale parked successfully')),
              );
            },
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Park Sale'),
          ),
        ],
      ),
    );
  }

  void _showParkedSales(BuildContext context, WidgetRef ref) {
    final parked = ref.read(parkedSalesProvider);
    if (parked.isEmpty) return;
    
    BottomSheetModal.show(
      context: context,
      title: 'Parked Sales',
      subtitle: '${parked.length} sales waiting',
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: parked.length,
        itemBuilder: (context, index) {
          final sale = parked[index];
          return Container(
            margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusMd,
              border: Border.all(color: DesignTokens.grayLight),
            ),
            child: ListTile(
              leading: Container(
                padding: DesignTokens.paddingSm,
                decoration: BoxDecoration(
                  color: DesignTokens.brandPrimary.withOpacity(0.1),
                  borderRadius: DesignTokens.borderRadiusSm,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: DesignTokens.brandPrimary,
                ),
              ),
              title: Text(sale.label, style: DesignTokens.textBodyBold),
              subtitle: Text(
                '${sale.lines.length} items • UGX ${sale.total.toStringAsFixed(0)}',
                style: DesignTokens.textSmall,
              ),
              trailing: Text(
                '${sale.createdAt.hour}:${sale.createdAt.minute.toString().padLeft(2, '0')}',
                style: DesignTokens.textSmall,
              ),
              onTap: () {
                final cartState = ref.read(parkedSalesProvider.notifier).resume(sale.id);
                if (cartState != null) {
                  ref.read(cartControllerProvider.notifier).apply(cartState);
                }
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    ActionBottomSheet.show(
      context: context,
      title: 'Options',
      actions: [
        ActionSheetItem(
          label: 'Seed demo items',
          icon: Icons.add_box_outlined,
          onTap: () => _seedDemoDataIfEmpty(ref),
        ),
        ActionSheetItem(
          label: 'View transactions',
          icon: Icons.receipt_long_outlined,
          onTap: () => context.go('/home/transactions'),
        ),
        ActionSheetItem(
          label: 'Open shift',
          icon: Icons.lock_clock,
          onTap: () => context.go('/home/more/shifts'),
        ),
      ],
    );
  }

  Future<void> _seedDemoDataIfEmpty(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final items = await db.getAllItems();
    if (items.isNotEmpty) return;
    await db.upsertItem(
      ItemsCompanion.insert(name: 'Coffee', price: 6000, stockQty: const Value(20)),
    );
    await db.upsertItem(
      ItemsCompanion.insert(name: 'Snack Box', price: 14000, stockQty: const Value(15)),
    );
    await db.upsertItem(
      ItemsCompanion.insert(name: 'Water Bottle', price: 2000, stockQty: const Value(50)),
    );
    await db.upsertItem(
      ItemsCompanion.insert(name: 'Sandwich', price: 8500, stockQty: const Value(10)),
    );
    await db.upsertService(ServicesCompanion.insert(title: 'Consultation', price: 30000));
    await db.upsertService(ServicesCompanion.insert(title: 'Express Delivery', price: 15000));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onScan,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onScan;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search products or scan…',
              hintStyle: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
              prefixIcon: const Icon(Icons.search, color: DesignTokens.grayMedium),
              suffixIcon: SizedBox(
                width: hasText ? 96 : 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasText)
                      IconButton(
                        icon: const Icon(Icons.clear, color: DesignTokens.grayMedium),
                        tooltip: 'Clear',
                        onPressed: onClear,
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: DesignTokens.grayMedium),
                      tooltip: 'Scan',
                      onPressed: onScan,
                    ),
                  ],
                ),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spaceMd,
                vertical: DesignTokens.spaceMd,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.name,
    required this.price,
    this.stock,
    this.onTap,
  });

  final String name;
  final double price;
  final int? stock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lowStock = stock != null && stock! < 5;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: DesignTokens.paddingSm,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
          border: lowStock 
              ? Border.all(color: DesignTokens.warning.withOpacity(0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product icon placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: DesignTokens.grayLight.withOpacity(0.3),
                  borderRadius: DesignTokens.borderRadiusSm,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: DesignTokens.grayMedium,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              name,
              style: DesignTokens.textSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: DesignTokens.grayDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DesignTokens.spaceXxs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'UGX ${price.toStringAsFixed(0)}',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.brandAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stock != null)
                  Text(
                    '$stock',
                    style: DesignTokens.textSmall.copyWith(
                      color: lowStock ? DesignTokens.warning : DesignTokens.grayMedium,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.title,
    required this.price,
    this.onTap,
  });

  final String title;
  final double price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: DesignTokens.brandAccent.withOpacity(0.1),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: const Icon(
                Icons.room_service_outlined,
                color: DesignTokens.brandAccent,
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Text(title, style: DesignTokens.textBodyBold),
            ),
            Text(
              'UGX ${price.toStringAsFixed(0)}',
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.brandAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPane extends StatelessWidget {
  const _CartPane({
    required this.cart,
    required this.customer,
    required this.parkedCount,
    required this.onSelectCustomer,
    required this.onUpdateQuantity,
    required this.onEditPrice,
    required this.onPark,
    required this.onCheckout,
    required this.onClear,
  });

  final CartState cart;
  final Customer? customer;
  final int parkedCount;
  final VoidCallback onSelectCustomer;
  final void Function(String id, int quantity) onUpdateQuantity;
  final void Function(CartLine line) onEditPrice;
  final VoidCallback onPark;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.surfaceWhite,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Cart', style: DesignTokens.textTitle),
                    const Spacer(),
                    if (cart.lines.isNotEmpty)
                      TextButton(
                        onPressed: onPark,
                        child: const Text('Park'),
                      ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                InkWell(
                  onTap: onSelectCustomer,
                  borderRadius: DesignTokens.borderRadiusSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSm,
                      vertical: DesignTokens.spaceXs,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: DesignTokens.grayMedium),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: Text(
                            customer?.name ?? 'Walk-in customer',
                            style: DesignTokens.textBody.copyWith(color: DesignTokens.grayDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Change',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.brandPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Cart items
          Expanded(
            child: cart.lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: DesignTokens.grayMedium,
                        ),
                        const SizedBox(height: DesignTokens.spaceMd),
                        Text(
                          'Cart is empty',
                          style: DesignTokens.textBody.copyWith(
                            color: DesignTokens.grayMedium,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceXs),
                        Text(
                          'Tap items to add them',
                          style: DesignTokens.textSmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
                    itemCount: cart.lines.length,
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return _CartItem(
                        title: line.title,
                        price: line.price,
                        quantity: line.quantity,
                        onIncrement: () => onUpdateQuantity(line.id, line.quantity + 1),
                        onDecrement: () => onUpdateQuantity(line.id, line.quantity - 1),
                        onEditPrice: () => onEditPrice(line),
                      );
                    },
                  ),
          ),
          
          // Footer with totals
          Container(
            padding: DesignTokens.paddingMd,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.grayDark.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: DesignTokens.textBody),
                    Text(
                      'UGX ${cart.subtotal.toStringAsFixed(0)}',
                      style: DesignTokens.textBodyBold,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                ElevatedButton(
                  onPressed: cart.lines.isEmpty ? null : onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                    padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
                  ),
                  child: Text(
                    'Charge UGX ${cart.subtotal.toStringAsFixed(0)}',
                    style: DesignTokens.textBody.copyWith(
                      color: DesignTokens.surfaceWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (cart.lines.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.spaceSm),
                  TextButton(
                    onPressed: onClear,
                    child: Text(
                      'Clear cart',
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.grayMedium,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({
    required this.title,
    required this.price,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditPrice,
  });

  final String title;
  final double price;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditPrice;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onEditPrice,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceXs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesignTokens.textBody),
                  Row(
                    children: [
                      Text(
                        'UGX ${price.toStringAsFixed(0)}',
                        style: DesignTokens.textSmall,
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Icon(Icons.edit, size: 14, color: DesignTokens.grayMedium.withOpacity(0.7)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: DesignTokens.grayLight.withOpacity(0.3),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: onDecrement,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('$quantity', style: DesignTokens.textBodyBold),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: onIncrement,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingCartSummary extends StatelessWidget {
  const _FloatingCartSummary({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceMd,
        ),
        decoration: BoxDecoration(
          gradient: DesignTokens.brandGradient,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowLg,
        ),
        child: Row(
          children: [
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: DesignTokens.surfaceWhite.withOpacity(0.2),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Text(
                '$itemCount',
                style: DesignTokens.textBodyBold.copyWith(
                  color: DesignTokens.surfaceWhite,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Text(
                'View Cart',
                style: DesignTokens.textBodyBold.copyWith(
                  color: DesignTokens.surfaceWhite,
                ),
              ),
            ),
            Text(
              'UGX ${total.toStringAsFixed(0)}',
              style: DesignTokens.textBodyBold.copyWith(
                color: DesignTokens.surfaceWhite,
              ),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            const Icon(
              Icons.arrow_forward,
              color: DesignTokens.surfaceWhite,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.grayLight.withOpacity(0.3),
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        child: Row(
          children: [
            Container(
              padding: DesignTokens.paddingSm,
              decoration: BoxDecoration(
                color: DesignTokens.brandPrimary.withOpacity(0.1),
                borderRadius: DesignTokens.borderRadiusSm,
              ),
              child: Icon(icon, color: DesignTokens.brandPrimary),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DesignTokens.textBodyBold),
                  Text(subtitle, style: DesignTokens.textSmall),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: DesignTokens.grayMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        children: [
          Icon(Icons.error_outline, color: DesignTokens.error),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(message, style: DesignTokens.textSmall),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        children: [
          Icon(Icons.search_off, color: DesignTokens.grayMedium),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(message, style: DesignTokens.textSmall),
        ],
      ),
    );
  }
}

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  late final MobileScannerController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: DesignTokens.grayLight.withOpacity(0.25),
            borderRadius: DesignTokens.borderRadiusMd,
          ),
          child: ClipRRect(
            borderRadius: DesignTokens.borderRadiusMd,
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_handled) return;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final code = barcodes.first.rawValue;
                if (code == null || code.trim().isEmpty) return;
                _handled = true;
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(code.trim());
              },
              errorBuilder: (context, error, child) {
                return Center(
                  child: Text('Camera unavailable', style: DesignTokens.textBody),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Torch',
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Text(
          'Scan a product barcode or receipt QR',
          style: DesignTokens.textSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
