import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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
import '../../core/settings/shop_payment_settings.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/auth/pos_staff_prefs.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../core/util/tax_calculator.dart';
import '../../core/audio/pos_sound_service.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/offline_cached_image.dart';
import 'cart_controller.dart';
import 'parked_sales_controller.dart';
import '../receipts/receipt_details_sheet.dart';
import '../receipts/receipt_providers.dart';

/// All locally-synced items are eligible for POS checkout.
/// The backend [PosSyncController] already filters out digital/auction/wholesale
/// Items eligible for POS checkout: either published (Live) or synced from backend.
/// Local draft items (publishedOnline=false AND synced=false) are hidden.
final itemsStreamProvider = StreamProvider<List<Item>>((ref) {
  return ref
      .watch(appDatabaseProvider)
      .watchItems()
      .map((items) => items.where((i) => i.publishedOnline || i.synced).toList());
});

/// Services eligible for POS checkout: either published (Live) or synced from backend.
/// Local draft services (publishedOnline=false AND synced=false) are hidden.
final servicesStreamProvider = StreamProvider<List<Service>>((ref) {
  return ref
      .watch(appDatabaseProvider)
      .watchServices()
      .map((svcs) => svcs.where((s) => s.publishedOnline || s.synced).toList());
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(appDatabaseProvider).watchCustomers();
});

final productsLastPulledAtProvider = FutureProvider<DateTime?>((ref) async {
  return ref.watch(appDatabaseProvider).getLastPulledAt('products');
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
  Timer? _searchDebounce;
  String _query = '';
  bool _scanLocked = false;
  bool _addingProduct = false;
  bool _syncingCatalog = false;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    // WhatsApp-style silent auto-sync on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncCatalogSilently());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String raw) {
    final next = raw.trim().toLowerCase();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _query = next);
    });
  }

  /// Returns true if the currently logged-in seller is the shop owner
  /// (bypasses staff PIN requirement for solo sellers).
  Future<bool> _isOwnerSoloSeller() async {
    final sellerId = await ref.read(secureStorageProvider).readSellerId();
    if (sellerId == null || sellerId.isEmpty) return false;
    final profile =
        await ref.read(appDatabaseProvider).getBusinessProfile();
    return profile?.sellerId == sellerId;
  }

  /// Creates an implicit offline manager session for the shop owner
  /// so that backend APIs receive a valid X-POS-Session header.
  Future<void> _ensureOwnerPosSession() async {
    final storage = ref.read(secureStorageProvider);
    final existingToken = await storage.readPosSessionToken();
    if (existingToken != null && existingToken.trim().isNotEmpty) return;

    final ownerToken =
        'OFFLINE_owner_${DateTime.now().millisecondsSinceEpoch}';
    await storage.writePosSessionToken(ownerToken);
    await storage.writePosSessionMeta(
      staffId: 0,
      staffName: 'Owner',
      staffRole: 'manager',
    );
    await ref
        .read(sharedPreferencesProvider)
        .setBool(posStaffInitializedPrefKey, true);
  }

  /// WhatsApp-style silent sync — no UI feedback, no SnackBars.
  Future<void> _syncCatalogSilently() async {
    if (_syncingCatalog) return;
    setState(() => _syncingCatalog = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final staffInitialized =
          prefs.getBool(posStaffInitializedPrefKey) ?? false;
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity.any((r) => r != ConnectivityResult.none);
      if (online && staffInitialized) {
        final token = await ref
            .read(secureStorageProvider)
            .readPosSessionToken();
        if (token == null || token.trim().isEmpty) {
          // Solo sellers (owner account) bypass staff PIN requirement
          if (await _isOwnerSoloSeller()) {
            await _ensureOwnerPosSession();
          } else {
            return; // Silent fail — will retry on next cycle
          }
        }
      }

      final items = await ref.read(appDatabaseProvider).getAllItems();
      final syncService = ref.read(syncServiceProvider);

      if (items.isEmpty) {
        await syncService.forceFullResync();
      } else {
        await syncService.syncNow();
      }

      ref.invalidate(productsLastPulledAtProvider);
    } catch (_) {
      // Silent fail — sync service handles retries automatically
    } finally {
      if (mounted) {
        setState(() => _syncingCatalog = false);
      }
    }
  }

  Future<String?> _addProduct(BuildContext context, Item item) async {
    if (_addingProduct) return null;
    _addingProduct = true;
    try {
      return await _addProductInner(context, item);
    } finally {
      _addingProduct = false;
    }
  }

  Future<String?> _addProductInner(BuildContext context, Item item) async {
    final cartController = ref.read(cartControllerProvider.notifier);
    final db = ref.read(appDatabaseProvider);
    final stocks = await db.getItemStocksForItem(item.id);
    if (!context.mounted) return null;

    if (item.stockEnabled && item.stockQty <= 0) {
      await _showOutOfStockAlert(context, item.name);
      return null;
    }

    if (stocks.isEmpty) {
      Haptics.selection();
      final msg = cartController.addItem(item: item);
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        if (msg.startsWith('Out of stock')) return null;
      }
      PosSoundService().playAddToCart();
      return item.name;
    }

    final hasChoices =
        stocks.length > 1 ||
        (stocks.length == 1 && stocks.first.variant.trim().isNotEmpty);
    if (!hasChoices) {
      Haptics.selection();
      final s = stocks.first;
      final msg = cartController.addItem(
        item: item,
        availableStock: s.stockQty,
      );
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        if (msg.startsWith('Out of stock')) return null;
      }
      PosSoundService().playAddToCart();
      return item.name;
    }

    final pickedVariant = await BottomSheetModal.show<String>(
      context: context,
      title: item.name,
      subtitle: 'Choose a variant',
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: stocks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final s = stocks[i];
          final label = s.variant.trim().isEmpty
              ? 'Default'
              : s.variant.replaceAll('-', ' • ');
          final outOfStock = item.stockEnabled && s.stockQty <= 0;
          return ListTile(
            title: Text(label, style: DesignTokens.textBodyBold),
            subtitle: Text(
              'Stock: ${s.stockQty}',
              style: DesignTokens.textSmall,
            ),
            trailing: Text(s.price.toUgx(), style: DesignTokens.textBodyBold),
            onTap: () async {
              if (outOfStock) {
                await _showOutOfStockAlert(
                  context,
                  '${item.name} • ${label == 'Default' ? 'default variant' : label}',
                );
                return;
              }
              Haptics.selection();
              Navigator.of(context).pop(s.variant);
            },
          );
        },
      ),
    );

    if (!context.mounted) return null;
    if (pickedVariant == null) return null;
    final normalized = pickedVariant.trim();
    final pickedStock = stocks.firstWhere(
      (e) => e.variant.trim() == normalized,
      orElse: () => stocks.first,
    );
    if (normalized.isEmpty) {
      final msg = cartController.addItem(
        item: item,
        availableStock: pickedStock.stockQty,
      );
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        if (msg.startsWith('Out of stock')) return null;
      }
      PosSoundService().playAddToCart();
      return item.name;
    }
    final msg = cartController.addItemVariant(
      item: item,
      variant: normalized,
      price: pickedStock.price,
      availableStock: pickedStock.stockQty,
    );
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (msg.startsWith('Out of stock')) return null;
    }
    PosSoundService().playAddToCart();
    return '${item.name} • $normalized';
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final servicesAsync = ref.watch(servicesStreamProvider);
    final cart = ref.watch(cartControllerProvider);
    final parked = ref.watch(parkedSalesProvider);
    final profileAsync = ref.watch(businessProfileProvider);
    final cartController = ref.read(cartControllerProvider.notifier);
    final profile = profileAsync.valueOrNull;

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
                    onChanged: _onSearchChanged,
                    onScan: () => _openScanner(context),
                    onClear: () {
                      _searchDebounce?.cancel();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceMd,
                ),
                sliver: itemsAsync.when(
                  data: (items) {
                    final filtered = _query.isEmpty
                        ? items
                        : items
                              .where((item) => _matchesItem(item, _query))
                              .toList();
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptySearchState(
                          message: _query.isEmpty
                              ? 'No products yet'
                              : 'No matching products',
                        ),
                      );
                    }
                    return SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: DesignTokens.spaceSm,
                            crossAxisSpacing: DesignTokens.spaceSm,
                            childAspectRatio: 0.8,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = filtered[index];
                        final threshold = item.lowStockWarning ?? 5;
                        final outOfStock =
                            item.stockEnabled && item.stockQty <= 0;
                        return _ProductTile(
                          name: item.name,
                          price: item.price,
                          stock: item.stockQty,
                          stockEnabled: item.stockEnabled,
                          lowStockThreshold: threshold,
                          imageUrl: item.imageUrl,
                          onTap: () {
                            if (outOfStock) {
                              unawaited(
                                _showOutOfStockAlert(context, item.name),
                              );
                              return;
                            }
                            unawaited(_addProduct(context, item));
                          },
                        );
                      }, childCount: filtered.length),
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

              // Services section (only show if seller has services)
              servicesAsync.when(
                data: (services) {
                  if (services.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  final filtered = _query.isEmpty
                      ? services
                      : services
                            .where((s) => _matchesService(s, _query))
                            .toList();
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DesignTokens.spaceMd,
                            DesignTokens.spaceLg,
                            DesignTokens.spaceMd,
                            DesignTokens.spaceSm,
                          ),
                          child: Text(
                            'Services',
                            style: DesignTokens.textBodyBold,
                          ),
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: _EmptySearchState(
                            message: 'No matching services',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spaceMd,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 200,
                                  mainAxisSpacing: DesignTokens.spaceSm,
                                  crossAxisSpacing: DesignTokens.spaceSm,
                                  childAspectRatio: 0.85,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final service = filtered[index];
                              return _ServiceCard(
                                title: service.title,
                                price: service.price,
                                imageUrl: service.imageUrl,
                                description: service.description,
                                onTap: () => _addServiceWithVariantPicker(
                                  context,
                                  service,
                                ),
                              );
                            }, childCount: filtered.length),
                          ),
                        ),
                    ],
                  );
                },
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (e, _) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
            onUpdateQuantity: (id, quantity) async {
              final msg = await cartController.updateQuantityWithFreshStock(
                id,
                quantity,
              );
              if (msg == null) return;
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
            },
            onEditPrice: (line) => _showPriceOverride(context, line),
            onPark: () => _showParkSale(context, ref),
            onCheckout: () => _handleCheckout(context, ref),
            onClear: () => cartController.clear(),
            onRemove: (id) => cartController.removeLine(id),
            taxEnabled: profile?.taxEnabled ?? false,
            taxRate: profile?.taxRate ?? 0,
            taxLabel: profile?.taxLabel ?? 'VAT',
            taxInclusionMode: profile?.taxInclusionMode ?? 'exclusive',
          );

          // ─────────────────────────────────────────────────────────────────
          // LAYOUT
          // ─────────────────────────────────────────────────────────────────
          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 6, child: catalogPane),
                Container(width: 1, color: DesignTokens.grayLight),
                SizedBox(width: 360, child: cartPane),
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
                    itemCount: cart.lines.fold<int>(
                      0,
                      (sum, line) => sum + line.quantity,
                    ),
                    total: cart.subtotal,
                    onTap: () => _showCartSheet(context, ref),
                    taxEnabled: profile?.taxEnabled ?? false,
                    taxRate: profile?.taxRate ?? 0,
                    taxInclusionMode: profile?.taxInclusionMode ?? 'exclusive',
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

  /// Add a service to cart with variant picker support.
  /// - 0 variants: use base service price
  /// - 1 variant: auto-use that variant
  /// - 2+ variants: show 1-tap picker
  Future<void> _addServiceWithVariantPicker(
    BuildContext context,
    Service service,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final cartController = ref.read(cartControllerProvider.notifier);

    final variants = await db.getServiceVariantsForService(service.id);

    // No variants: use base price
    if (variants.isEmpty) {
      Haptics.selection();
      cartController.addService(service: service);
      return;
    }

    // Single variant: auto-use it
    if (variants.length == 1) {
      final v = variants.first;
      Haptics.selection();
      cartController.addService(
        service: service,
        variant: v.name,
        variantPrice: v.price,
      );
      return;
    }

    // Multiple variants: show picker
    if (!context.mounted) return;
    final picked = await BottomSheetModal.show<ServiceVariant>(
      context: context,
      title: service.title,
      subtitle: 'Select pricing option',
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: variants.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final v = variants[i];
          return ListTile(
            title: Text(v.name, style: DesignTokens.textBodyBold),
            subtitle: v.unit != null ? Text('per ${v.unit}') : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'UGX ${v.price.toStringAsFixed(0)}',
                  style: DesignTokens.textBodyBold,
                ),
                if (v.isDefault) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Default'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            onTap: () {
              Haptics.selection();
              Navigator.of(ctx).pop(v);
            },
          );
        },
      ),
    );

    if (picked == null || !context.mounted) return;
    cartController.addService(
      service: service,
      variant: picked.name,
      variantPrice: picked.price,
    );
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
    _searchDebounce?.cancel();
    _searchCtrl.text = code;
    if (mounted) setState(() => _query = code.toLowerCase());

    final db = ref.read(appDatabaseProvider);
    final cartController = ref.read(cartControllerProvider.notifier);

    // Prefer variant SKU matches (more specific than product SKU/barcode).
    final stockMatches = await (db.select(
      db.itemStocks,
    )..where((t) => t.sku.equals(code))).get();
    if (stockMatches.isNotEmpty) {
      String? addedLabel;
      if (stockMatches.length == 1) {
        final stock = stockMatches.first;
        final item = await db.getItemById(stock.itemId);
        if (item != null) {
          if (stock.variant.trim().isEmpty) {
            final msg = cartController.addItem(
              item: item,
              availableStock: stock.stockQty,
            );
            if (msg != null) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
              if (msg.startsWith('Out of stock')) return;
            }
            addedLabel = item.name;
          } else {
            final msg = cartController.addItemVariant(
              item: item,
              variant: stock.variant,
              price: stock.price,
              availableStock: stock.stockQty,
            );
            if (msg != null) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
              if (msg.startsWith('Out of stock')) return;
            }
            addedLabel = '${item.name} • ${stock.variant.trim()}';
          }
        }
      } else {
        // Multiple matches: let the seller choose.
        if (!mounted) return;
        final picked = await BottomSheetModal.show<ItemStock>(
          context: context,
          title: 'Pick variant',
          subtitle: 'Multiple matches for "$code"',
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: stockMatches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = stockMatches[i];
              return FutureBuilder<Item?>(
                future: db.getItemById(s.itemId),
                builder: (context, snap) {
                  final name = snap.data?.name ?? s.itemId;
                  final label = s.variant.trim().isEmpty
                      ? 'Default'
                      : s.variant.replaceAll('-', ' • ');
                  final enabled =
                      !(snap.data?.stockEnabled ?? true) || s.stockQty > 0;
                  return ListTile(
                    title: Text(name, style: DesignTokens.textBodyBold),
                    subtitle: Text(
                      '$label • Stock ${s.stockQty}',
                      style: DesignTokens.textSmall,
                    ),
                    trailing: Text(
                      s.price.toUgx(),
                      style: DesignTokens.textSmallBold,
                    ),
                    onTap: () async {
                      if (!enabled) {
                        await _showOutOfStockAlert(
                          context,
                          '$name • ${label == 'Default' ? 'default variant' : label}',
                        );
                        return;
                      }
                      Navigator.of(context).pop(s);
                    },
                  );
                },
              );
            },
          ),
        );
        if (picked != null) {
          final item = await db.getItemById(picked.itemId);
          if (item != null) {
            if (picked.variant.trim().isEmpty) {
              final msg = cartController.addItem(
                item: item,
                availableStock: picked.stockQty,
              );
              if (msg != null) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
                if (msg.startsWith('Out of stock')) return;
              }
              addedLabel = item.name;
            } else {
              final msg = cartController.addItemVariant(
                item: item,
                variant: picked.variant,
                price: picked.price,
                availableStock: picked.stockQty,
              );
              if (msg != null) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
                if (msg.startsWith('Out of stock')) return;
              }
              addedLabel = '${item.name} • ${picked.variant.trim()}';
            }
          }
        }
      }

      if (addedLabel == null) return;
      Haptics.selection();
      _searchCtrl.clear();
      if (!mounted) return;
      setState(() => _query = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$addedLabel"'),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      return;
    }

    final match =
        await (db.select(db.items)..where(
              (t) =>
                  t.barcode.equals(code) |
                  t.sku.equals(code) |
                  t.id.equals(code),
            ))
            .getSingleOrNull();

    if (match == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No matching product for "$code"')),
      );
      return;
    }

    if (!mounted) return;
    final addedLabel = await _addProduct(context, match);
    if (addedLabel == null) return;
    Haptics.selection();
    _searchCtrl.clear();
    if (!mounted) return;
    setState(() => _query = '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$addedLabel"'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  Future<void> _showOutOfStockAlert(BuildContext context, String itemLabel) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Out of stock'),
        content: Text('$itemLabel is currently out of stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
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
                            .where(
                              (c) =>
                                  c.name.toLowerCase().contains(filter) ||
                                  (c.phone ?? '').toLowerCase().contains(
                                    filter,
                                  ),
                            )
                            .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        onChanged: (v) =>
                            setState(() => filter = v.trim().toLowerCase()),
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
                                child: Text(
                                  'No customers found',
                                  style: DesignTokens.textSmall,
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final c = filtered[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(c.name),
                                    subtitle: Text(c.phone ?? c.email ?? ''),
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(c.id),
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
    final customer = await (db.select(
      db.customers,
    )..where((t) => t.id.equals(selectedId))).getSingleOrNull();
    cartController.setCustomer(customer);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          customer == null ? 'Customer selected' : 'Customer: ${customer.name}',
        ),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  Future<String?> _addCustomer(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool saving = false;
    String? error;
    final created = await BottomSheetModal.show<String>(
      context: context,
      title: 'New Customer',
      subtitle: 'Quick add',
      child: StatefulBuilder(
        builder: (sheetContext, setLocalState) {
          return Column(
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
              if ((error ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Text(
                  error!,
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.error,
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          setLocalState(() => error = 'Name is required');
                          return;
                        }

                        setLocalState(() {
                          saving = true;
                          error = null;
                        });

                        final id = _uuid.v4();
                        final now = DateTime.now().toUtc();
                        final phone = phoneCtrl.text.trim();
                        final db = ref.read(appDatabaseProvider);
                        final sync = ref.read(syncServiceProvider);

                        try {
                          await db.upsertCustomer(
                            CustomersCompanion.insert(
                              id: Value(id),
                              name: name,
                              phone: phone.isEmpty
                                  ? const Value.absent()
                                  : Value(phone),
                              synced: const Value(false),
                              updatedAt: Value(now),
                            ),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save customer: $e'),
                                backgroundColor: DesignTokens.error,
                              ),
                            );
                          }
                          return;
                        }

                        // Try immediate cloud sync; fallback to outbox when offline or blocked.
                        try {
                          final api = ref.read(sellerApiProvider);
                          final res = await api.pushCustomer({
                            'customer_id': id,
                            'display_name': name,
                            if (phone.isNotEmpty) 'phone': phone,
                            if (phone.isNotEmpty) 'phones': [phone],
                            'emails': const [],
                            'source': 'pos_terminal',
                            'shared_with_business': true,
                          }, idempotencyKey: id);

                          final data = res.data is Map
                              ? Map<String, dynamic>.from(res.data as Map)
                              : null;
                          final remoteId = data?['contact_id']?.toString();
                          final updatedAt = DateTime.tryParse(
                            data?['updated_at']?.toString() ?? '',
                          )?.toUtc();

                          await (db.update(
                            db.customers,
                          )..where((t) => t.id.equals(id))).write(
                            CustomersCompanion(
                              remoteId: remoteId == null
                                  ? const Value.absent()
                                  : Value(remoteId),
                              synced: const Value(true),
                              updatedAt: Value(updatedAt ?? now),
                            ),
                          );
                        } catch (_) {
                          try {
                            await sync.enqueue('customer_push', {
                              'idempotency_key': id,
                              'customer_id': id,
                              'display_name': name,
                              if (phone.isNotEmpty) 'phone': phone,
                              'phones': phone.isEmpty ? const [] : [phone],
                              'emails': const [],
                              'source': 'pos_terminal',
                              'shared_with_business': true,
                            });
                          } catch (e) {
                            debugPrint('[Checkout] Customer push enqueue failed: $e');
                          }
                        }

                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop(id);
                      },
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? 'Saving…' : 'Save Customer'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return null;
    return created;
  }

  Future<void> _showPriceOverride(BuildContext context, CartLine line) async {
    final ok = await requireManagerPin(
      context,
      ref,
      reason: 'Price override: ${line.title}',
    );
    if (!context.mounted) return;
    if (!ok) return;

    final priceCtrl = TextEditingController(text: line.price.formatCommas());
    final newPrice = await BottomSheetModal.show<double>(
      context: context,
      title: 'Price Override',
      subtitle: line.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Original: ${line.price.toUgx()}',
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
    await ref
        .read(appDatabaseProvider)
        .recordAuditLog(
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
        content: Text('Price updated to ${newPrice.toUgx()}'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  void _showCartSheet(BuildContext context, WidgetRef ref) {
    final rootContext = context;
    final rootRef = ref;
    final cartController = rootRef.read(cartControllerProvider.notifier);

    BottomSheetModal.show(
      context: rootContext,
      title: 'Cart',
      subtitle: 'Review items and charge',
      child: Consumer(
        builder: (sheetContext, sheetRef, _) {
          final cart = sheetRef.watch(cartControllerProvider);
          final parked = sheetRef.watch(parkedSalesProvider);
          final profile = sheetRef.watch(businessProfileProvider).valueOrNull;
          return _CartPane(
            cart: cart,
            customer: cart.customer,
            parkedCount: parked.length,
            taxEnabled: profile?.taxEnabled ?? false,
            taxRate: profile?.taxRate ?? 0,
            taxLabel: profile?.taxLabel ?? 'VAT',
            taxInclusionMode: profile?.taxInclusionMode ?? 'exclusive',
            onSelectCustomer: () {
              Navigator.of(sheetContext).pop();
              _selectCustomer(rootContext);
            },
            onUpdateQuantity: (id, quantity) async {
              final msg = await cartController.updateQuantityWithFreshStock(
                id,
                quantity,
              );
              if (msg == null) return;
              if (!rootContext.mounted) return;
              ScaffoldMessenger.of(
                rootContext,
              ).showSnackBar(SnackBar(content: Text(msg)));
            },
            onEditPrice: (line) {
              Navigator.of(sheetContext).pop();
              _showPriceOverride(rootContext, line);
            },
            onPark: () {
              Navigator.of(sheetContext).pop();
              _showParkSale(rootContext, rootRef);
            },
            onCheckout: () {
              Navigator.of(sheetContext).pop();
              _handleCheckout(rootContext, rootRef);
            },
            onClear: () {
              cartController.clear();
              Navigator.of(sheetContext).pop();
            },
            onRemove: (id) => cartController.removeLine(id),
          );
        },
      ),
    );
  }

  Future<void> _handleCheckout(BuildContext context, WidgetRef ref) async {
    if (_checkingOut) return;
    final cart = ref.read(cartControllerProvider);
    if (cart.lines.isEmpty) return;
    setState(() => _checkingOut = true);
    try {
      await _handleCheckoutInner(context, ref, cart);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _handleCheckoutInner(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    final profileAsync = ref.read(businessProfileProvider);
    final profile = profileAsync.valueOrNull;
    final taxEnabled = profile?.taxEnabled ?? false;
    final taxRate = taxEnabled ? (profile?.taxRate ?? 0.0) : 0.0;
    final taxInclusionMode = profile?.taxInclusionMode ?? 'exclusive';
    final taxAmount = TaxCalculator.taxAmount(
      cart.subtotal,
      taxRate,
      inclusive: taxInclusionMode == 'inclusive',
    );
    final total = taxInclusionMode == 'inclusive'
        ? cart.subtotal
        : cart.subtotal + taxAmount;
    final prefs = ref.read(sharedPreferencesProvider);
    final staffInitialized = prefs.getBool(posStaffInitializedPrefKey) ?? false;
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);
    if (online && staffInitialized) {
      final token = await ref.read(secureStorageProvider).readPosSessionToken();
      if (token == null || token.trim().isEmpty) {
        // Solo sellers (owner account) bypass staff PIN requirement
        if (await _isOwnerSoloSeller()) {
          await _ensureOwnerPosSession();
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Staff login required to sync sales. Enter cashier PIN to continue.',
              ),
            ),
          );
          context.go('/pos-login?redirect=/home');
          return;
        }
      }
    }
    final paymentSettings = ShopPaymentSettingsCache.read(
      ref.read(sharedPreferencesProvider),
    );

    // Show payment selection (single, split, or credit).
    if (!context.mounted) return;
    final paymentOption = await BottomSheetModal.show<String>(
      context: context,
      title: 'Payment',
      subtitle: '${total.toUgx()} due',
      child: Builder(
        builder: (sheetContext) => ListView(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          children: [
            if (paymentSettings.cashEnabled) ...[
              _PaymentMethodTile(
                icon: Icons.money,
                title: 'Cash',
                subtitle: 'Pay with cash',
                onTap: () => Navigator.of(sheetContext).pop('cash'),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
            ],
            if (paymentSettings.mobileMoneyEnabled) ...[
              _PaymentMethodTile(
                icon: Icons.phone_android,
                title: 'Mobile Money',
                subtitle: 'MTN, Airtel, etc.',
                onTap: () => Navigator.of(sheetContext).pop('mobile_money'),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
            ],
            if (paymentSettings.bankEnabled) ...[
              _PaymentMethodTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank transfer',
                subtitle: 'Record as bank transfer',
                onTap: () => Navigator.of(sheetContext).pop('bank_transfer'),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
            ],
            _PaymentMethodTile(
              icon: Icons.credit_card,
              title: 'Card',
              subtitle: 'Visa, Mastercard',
              onTap: () => Navigator.of(sheetContext).pop('card'),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            if (_paymentMethods(
                  hasCustomer: cart.customer != null,
                  paymentSettings: paymentSettings,
                ).where((m) => m.$1 != 'credit').length >=
                2) ...[
              _PaymentMethodTile(
                icon: Icons.splitscreen_outlined,
                title: 'Split payment',
                subtitle: 'Mix methods (optional credit)',
                onTap: () => Navigator.of(sheetContext).pop('split'),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
            ],
            _PaymentMethodTile(
              icon: Icons.handshake_outlined,
              title: 'Credit / Pay later',
              subtitle: 'Record as credit sale (customer required)',
              onTap: () => Navigator.of(sheetContext).pop('credit'),
            ),
          ],
        ),
      ),
    );

    if (paymentOption == null || !context.mounted) return;

    List<CheckoutPayment>? payments;
    String? note;

    switch (paymentOption) {
      case 'cash':
        final received = await _cashReceivedFlow(context, total: total);
        if (received == null || !context.mounted) return;
        payments = [CheckoutPayment(method: 'cash', amount: total)];
        if ((received - total).abs() > 0.01) {
          final change = (received - total).clamp(0, double.infinity);
          note = 'Cash received ${received.toUgx()} • Change ${change.toUgx()}';
        }
        break;
      case 'mobile_money':
        final refCode = await _referenceFlow(
          context,
          title: 'Mobile Money',
          hint: 'Transaction ID (optional)',
        );
        if (!context.mounted) return;
        if (refCode == null) return;
        payments = [
          CheckoutPayment(
            method: 'mobile_money',
            amount: total,
            externalRef: refCode.trim().isEmpty ? null : refCode.trim(),
          ),
        ];
        break;
      case 'card':
        final refCode = await _referenceFlow(
          context,
          title: 'Card',
          hint: 'Card receipt / auth code (optional)',
        );
        if (!context.mounted) return;
        if (refCode == null) return;
        payments = [
          CheckoutPayment(
            method: 'card',
            amount: total,
            externalRef: refCode.trim().isEmpty ? null : refCode.trim(),
          ),
        ];
        break;
      case 'bank_transfer':
        final refCode = await _referenceFlow(
          context,
          title: 'Bank transfer',
          hint: 'Reference (optional)',
        );
        if (!context.mounted) return;
        if (refCode == null) return;
        payments = [
          CheckoutPayment(
            method: 'bank_transfer',
            amount: total,
            externalRef: refCode.trim().isEmpty ? null : refCode.trim(),
          ),
        ];
        break;
      case 'split':
        payments = await _splitPaymentFlow(
          context,
          total: total,
          hasCustomer: cart.customer != null,
          paymentSettings: paymentSettings,
        );
        if (!context.mounted) return;
        break;
      case 'credit':
        if (cart.customer == null) {
          await _selectCustomer(context);
          if (!context.mounted) return;
        }
        final nextCart = ref.read(cartControllerProvider);
        if (nextCart.customer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Select a customer to record a credit sale'),
            ),
          );
          return;
        }
        final creditNote = await _creditFlow(
          context,
          customerName: nextCart.customer!.name,
          total: total,
        );
        if (!context.mounted) return;
        if (creditNote == null) return;
        payments = [CheckoutPayment(method: 'credit', amount: total)];
        note = creditNote.trim().isEmpty ? null : creditNote.trim();
        break;
      default:
        return;
    }

    if (payments == null || payments.isEmpty || !context.mounted) return;

    String id;
    try {
      id = await ref
          .read(cartControllerProvider.notifier)
          .checkout(
            payments: payments,
            notes: note,
            taxAmount: taxAmount,
            taxRate: taxRate,
            taxInclusionMode: taxInclusionMode,
          );
    } catch (e) {
      if (!context.mounted) return;
      PosSoundService().playError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
      return;
    }

    Haptics.impact();
    PosSoundService().playSuccess();

    if (context.mounted) {
      _showPostCheckoutActions(context, ref, id);
    }
  }

  void _showPostCheckoutActions(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: DesignTokens.surfaceWhite),
            const SizedBox(width: DesignTokens.spaceSm),
            Text('Sale completed! Receipt #$entryId'),
          ],
        ),
        backgroundColor: DesignTokens.brandAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    BottomSheetModal.show(
      context: context,
      title: 'Receipt actions',
      subtitle: entryId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final printer = ref.read(printQueueServiceProvider);
              if (!printer.printerEnabled) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Printing is disabled in Settings'),
                  ),
                );
                return;
              }
              if (!printer.hasPreferredPrinter) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Choose a printer in Settings to print receipts',
                    ),
                  ),
                );
                return;
              }
              try {
                await printer.enqueueReceipt(entryId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Print failed: $e')),
                  );
                }
                return;
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt queued for printing')),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('Print receipt'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              BottomSheetModal.show(
                context: context,
                title: 'Receipt',
                subtitle: entryId,
                child: ReceiptDetailsSheet(entryId: entryId),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('View details'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          OutlinedButton.icon(
            onPressed: () async {
              final sent = await _sendCustomerReceiptSms(context, ref, entryId);
              if (sent && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Send SMS receipt'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref.read(receiptServiceProvider).shareWhatsapp(entryId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share failed: $e')),
                  );
                }
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.chat),
            label: const Text('Send via WhatsApp'),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref.read(receiptServiceProvider).sharePdf(entryId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share failed: $e')),
                  );
                }
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Share PDF'),
          ),
        ],
      ),
    );
  }

  Future<bool> _sendCustomerReceiptSms(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final bundle = await db.fetchLedgerEntryBundle(entryId);
    if (bundle == null) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt details are not available yet')),
      );
      return false;
    }

    final customerId = bundle.entry.customerId;
    if (customerId == null || customerId.trim().isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach a customer with a phone number to send SMS'),
        ),
      );
      return false;
    }

    final customer = await (db.select(
      db.customers,
    )..where((t) => t.id.equals(customerId))).getSingleOrNull();
    final phone = (customer?.phone ?? '').trim();
    if (phone.isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected customer does not have a phone number'),
        ),
      );
      return false;
    }

    final payload = <String, dynamic>{
      'phone': phone,
      'context': 'pos_receipt',
      'customer_id': customerId,
      'customer_name': customer?.name ?? 'Customer',
      'reference': bundle.entry.receiptNumber ?? entryId,
      'entry_id': entryId,
      'total': bundle.entry.total,
    };
    final idempotencyKey = _uuid.v4();
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);

    if (!online) {
      try {
        await ref.read(syncServiceProvider).enqueue('sms_send', {
          ...payload,
          'idempotency_key': idempotencyKey,
        });
      } catch (e) {
        debugPrint('[Checkout] SMS sync enqueue failed: $e');
      }
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SMS receipt queued. It will send when the terminal reconnects.',
          ),
        ),
      );
      return true;
    }

    try {
      final res = await ref
          .read(sellerApiProvider)
          .sendSingleSms(payload, idempotencyKey: idempotencyKey);
      final body = res.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(res.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      if (!context.mounted) return true;
      final remainingCredits = data['remaining_credits']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remainingCredits == null
                ? 'SMS receipt sent'
                : 'SMS receipt sent. Remaining credits: $remainingCredits',
          ),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send SMS receipt: $e')));
      return false;
    }
  }

  Future<double?> _cashReceivedFlow(
    BuildContext context, {
    required double total,
  }) async {
    final ctrl = TextEditingController(text: total.formatCommas());
    try {
      return await BottomSheetModal.show<double>(
        context: context,
        title: 'Cash payment',
        subtitle: 'Total ${total.toUgx()}',
        child: StatefulBuilder(
          builder: (sheetContext, setState) {
            final received = _parseAmount(ctrl.text) ?? 0;
            final ok = received >= total - 0.01;
            final change = (received - total).clamp(0, double.infinity);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount received',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                Container(
                  padding: DesignTokens.paddingMd,
                  decoration: BoxDecoration(
                    color: DesignTokens.grayLight.withValues(alpha: 0.25),
                    borderRadius: DesignTokens.borderRadiusMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ok ? 'Change' : 'Remaining',
                          style: DesignTokens.textSmallBold,
                        ),
                      ),
                      Text(
                        (ok
                                ? change
                                : (total - received).clamp(0, double.infinity))
                            .toUgx(),
                        style: DesignTokens.textBodyBold.copyWith(
                          color: ok
                              ? DesignTokens.brandAccent
                              : DesignTokens.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                ElevatedButton.icon(
                  onPressed: ok
                      ? () => Navigator.of(sheetContext).pop(received)
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete sale'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  Future<String?> _referenceFlow(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
    final ctrl = TextEditingController();
    try {
      return await BottomSheetModal.show<String>(
        context: context,
        title: title,
        subtitle: 'Optional reference',
        child: Builder(
          builder: (sheetContext) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: hint,
                  prefixIcon: const Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(ctrl.text),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  Future<String?> _creditFlow(
    BuildContext context, {
    required String customerName,
    required double total,
  }) async {
    final noteCtrl = TextEditingController();
    try {
      return await BottomSheetModal.show<String>(
        context: context,
        title: 'Credit / Pay later',
        subtitle: customerName,
        child: Builder(
          builder: (sheetContext) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: DesignTokens.paddingMd,
                decoration: BoxDecoration(
                  color: DesignTokens.brandAccentLight,
                  borderRadius: DesignTokens.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      color: DesignTokens.brandPrimary,
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Text(
                        'Record ${total.toUgx()} as credit for this customer.',
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceSm),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(noteCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.brandPrimary,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm credit sale'),
              ),
            ],
          ),
        ),
      );
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<List<CheckoutPayment>?> _splitPaymentFlow(
    BuildContext context, {
    required double total,
    required bool hasCustomer,
    required ShopPaymentSettings paymentSettings,
  }) async {
    final methods = _paymentMethods(
      hasCustomer: hasCustomer,
      paymentSettings: paymentSettings,
    );
    final initialMethod =
        methods.where((m) => m.$1 != 'credit').firstOrNull?.$1 ?? 'card';

    final drafts = <_PaymentDraft>[
      _PaymentDraft(
        method: initialMethod,
        amountCtrl: TextEditingController(text: total.formatCommas()),
        refCtrl: TextEditingController(),
      ),
    ];

    List<CheckoutPayment>? result;
    try {
      result = await BottomSheetModal.show<List<CheckoutPayment>>(
        context: context,
        title: 'Split payment',
        subtitle: 'Total ${total.toUgx()}',
        maxHeight: 620,
        child: StatefulBuilder(
          builder: (sheetContext, setState) {
            final sum = drafts.fold<double>(
              0,
              (p, d) => p + (_parseAmount(d.amountCtrl.text) ?? 0),
            );
            final remaining = total - sum;
            final ok =
                remaining.abs() < 0.01 &&
                drafts.isNotEmpty &&
                drafts.every(
                  (d) => (_parseAmount(d.amountCtrl.text) ?? 0) > 0,
                ) &&
                drafts.every((d) => d.method != 'credit' || hasCustomer);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: DesignTokens.paddingMd,
                  decoration: BoxDecoration(
                    color: DesignTokens.grayLight.withValues(alpha: 0.25),
                    borderRadius: DesignTokens.borderRadiusMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Remaining',
                          style: DesignTokens.textSmallBold,
                        ),
                      ),
                      Text(
                        remaining.toUgx(),
                        style: DesignTokens.textBodyBold.copyWith(
                          color: remaining.abs() < 0.01
                              ? DesignTokens.brandAccent
                              : DesignTokens.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                ...drafts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final draft = entry.value;
                  final showRef = draft.method != 'cash';
                  final methods = _paymentMethods(
                    hasCustomer: hasCustomer,
                    paymentSettings: paymentSettings,
                  );
                  final methodValue = methods.any((m) => m.$1 == draft.method)
                      ? draft.method
                      : methods.first.$1;
                  draft.method = methodValue;
                  return Container(
                    margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
                    padding: DesignTokens.paddingMd,
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceWhite,
                      borderRadius: DesignTokens.borderRadiusMd,
                      border: Border.all(color: DesignTokens.grayLight),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: methodValue,
                                items: methods
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.$1,
                                        child: Text(m.$2),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(
                                  () => draft.method = v ?? draft.method,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Method',
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spaceSm),
                            Expanded(
                              child: TextField(
                                controller: draft.amountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (drafts.length > 1) ...[
                              const SizedBox(width: DesignTokens.spaceXs),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: () => setState(() {
                                  final removed = drafts.removeAt(index);
                                  removed.dispose();
                                }),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ],
                        ),
                        if (showRef) ...[
                          const SizedBox(height: DesignTokens.spaceSm),
                          TextField(
                            controller: draft.refCtrl,
                            decoration: InputDecoration(
                              labelText: draft.method == 'credit'
                                  ? 'Note (optional)'
                                  : 'Reference (optional)',
                              prefixIcon: const Icon(Icons.tag_outlined),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: DesignTokens.spaceSm),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    final clampLow = total < 0 ? total : 0.0;
                    final clampHigh = total < 0 ? 0.0 : total;
                    final remainingAmount = remaining.isFinite
                        ? remaining.clamp(clampLow, clampHigh)
                        : total;
                    final methods = _paymentMethods(
                      hasCustomer: hasCustomer,
                      paymentSettings: paymentSettings,
                    );
                    final method =
                        methods
                            .where((m) => m.$1 != 'credit')
                            .firstOrNull
                            ?.$1 ??
                        'card';
                    drafts.add(
                      _PaymentDraft(
                        method: method,
                        amountCtrl: TextEditingController(
                          text: remainingAmount.formatCommas(),
                        ),
                        refCtrl: TextEditingController(),
                      ),
                    );
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add payment'),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                ElevatedButton.icon(
                  onPressed: ok
                      ? () {
                          final payments = drafts.map((d) {
                            final amount = _parseAmount(d.amountCtrl.text) ?? 0;
                            final ref = d.refCtrl.text.trim();
                            return CheckoutPayment(
                              method: d.method,
                              amount: amount,
                              externalRef: ref.isEmpty ? null : ref,
                            );
                          }).toList();
                          Navigator.of(sheetContext).pop(payments);
                        }
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete sale'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      for (final d in drafts) {
        d.dispose();
      }
    }

    return result;
  }

  double? _parseAmount(String input) {
    final normalized = input.trim().replaceAll(',', '');
    return double.tryParse(normalized);
  }

  List<(String, String)> _paymentMethods({
    required bool hasCustomer,
    ShopPaymentSettings? paymentSettings,
  }) {
    final settings =
        paymentSettings ??
        ShopPaymentSettingsCache.read(ref.read(sharedPreferencesProvider));
    final methods = <(String, String)>[];
    if (settings.cashEnabled) {
      methods.add(('cash', 'Cash'));
    }
    if (settings.mobileMoneyEnabled) {
      methods.add(('mobile_money', 'Mobile Money'));
    }
    if (settings.bankEnabled) {
      methods.add(('bank_transfer', 'Bank transfer'));
    }
    methods.add(('card', 'Card'));
    if (hasCustomer) {
      methods.add(('credit', 'Credit'));
    }
    return methods;
  }

  void _showParkSale(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartControllerProvider);
    if (cart.lines.isEmpty) return;

    final labelCtrl = TextEditingController(
      text:
          'Parked ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
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
              color: DesignTokens.grayLight.withValues(alpha: 0.3),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cart.lines.length} items',
                  style: DesignTokens.textBody,
                ),
                Text(cart.subtotal.toUgx(), style: DesignTokens.textBodyBold),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(parkedSalesProvider.notifier)
                  .parkSale(cart, label: labelCtrl.text.trim());
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
                  color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: DesignTokens.borderRadiusSm,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: DesignTokens.brandPrimary,
                ),
              ),
              title: Text(sale.label, style: DesignTokens.textBodyBold),
              subtitle: Text(
                '${sale.lines.length} items • ${sale.total.toUgx()}',
                style: DesignTokens.textSmall,
              ),
              trailing: Text(
                '${sale.createdAt.hour}:${sale.createdAt.minute.toString().padLeft(2, '0')}',
                style: DesignTokens.textSmall,
              ),
              onTap: () {
                final cartState = ref
                    .read(parkedSalesProvider.notifier)
                    .resume(sale.id);
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
      ItemsCompanion.insert(
        name: 'Coffee',
        price: 6000,
        stockQty: const Value(20),
      ),
    );
    await db.upsertItem(
      ItemsCompanion.insert(
        name: 'Snack Box',
        price: 14000,
        stockQty: const Value(15),
      ),
    );
    await db.upsertItem(
      ItemsCompanion.insert(
        name: 'Water Bottle',
        price: 2000,
        stockQty: const Value(50),
      ),
    );
    await db.upsertItem(
      ItemsCompanion.insert(
        name: 'Sandwich',
        price: 8500,
        stockQty: const Value(10),
      ),
    );
    await db.upsertService(
      ServicesCompanion.insert(title: 'Consultation', price: 30000),
    );
    await db.upsertService(
      ServicesCompanion.insert(title: 'Express Delivery', price: 15000),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
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
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceGrouped,
          borderRadius: BorderRadius.circular(10),
          border: _focused
              ? Border.all(color: DesignTokens.brandAccent, width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSm + DesignTokens.spaceXs,
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: DesignTokens.textTertiary),
            const SizedBox(width: DesignTokens.spaceSm),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                style: DesignTokens.textBody,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search products…',
                  hintStyle: DesignTokens.textBody.copyWith(
                    color: DesignTokens.textTertiary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.spaceMd - DesignTokens.spaceXxs,
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              duration: DesignTokens.durationFast,
              offset: _focused ? Offset.zero : const Offset(0.5, 0),
              child: AnimatedOpacity(
                duration: DesignTokens.durationFast,
                opacity: _focused ? 1.0 : 0.0,
                child: TextButton(
                  onPressed: () {
                    widget.onClear();
                    FocusScope.of(context).unfocus();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 32),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
            if (!_focused)
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 20, color: DesignTokens.textTertiary),
                tooltip: 'Scan',
                onPressed: widget.onScan,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.name,
    required this.price,
    this.stock,
    this.stockEnabled = true,
    this.lowStockThreshold = 5,
    this.imageUrl,
    this.onTap,
  });

  final String name;
  final double price;
  final int? stock;
  final bool stockEnabled;
  final int lowStockThreshold;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveStock = stockEnabled ? stock : null;
    final outOfStock = effectiveStock != null && effectiveStock <= 0;
    final lowStock =
        effectiveStock != null &&
        effectiveStock > 0 &&
        effectiveStock <= lowStockThreshold;

    return _ScaleButton(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DesignTokens.borderRadiusMd,
          child: Container(
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusMd,
              boxShadow: DesignTokens.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(DesignTokens.radiusMd),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImage(),
                        if (outOfStock)
                          Container(
                            color: Colors.black.withValues(alpha: 0.4),
                            alignment: Alignment.center,
                            child: Text(
                              'Out of Stock',
                              style: DesignTokens.textSmallBold.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Positioned(
                          left: DesignTokens.spaceSm,
                          bottom: DesignTokens.spaceSm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: DesignTokens.brandAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              price.toUgx(),
                              style: DesignTokens.textCaption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (lowStock)
                          Positioned(
                            top: DesignTokens.spaceSm,
                            right: DesignTokens.spaceSm,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: DesignTokens.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: DesignTokens.textBody.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DesignTokens.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (effectiveStock != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceXs + DesignTokens.spaceXxs,
                              vertical: DesignTokens.spaceXxs,
                            ),
                            decoration: BoxDecoration(
                              color: outOfStock
                                  ? DesignTokens.error.withValues(alpha: 0.12)
                                  : lowStock
                                  ? DesignTokens.warning.withValues(alpha: 0.12)
                                  : DesignTokens.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              outOfStock ? 'Out' : lowStock ? 'Low' : 'In stock',
                              style: DesignTokens.textCaption.copyWith(
                                color: outOfStock
                                    ? DesignTokens.error
                                    : lowStock
                                    ? DesignTokens.warning
                                    : DesignTokens.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return _buildPlaceholder();

    return OfflineCachedImage(
      imageUrl: raw,
      fit: BoxFit.cover,
      placeholder: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesignTokens.surfaceGrouped,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: DesignTokens.textTertiary,
        size: 32,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.price,
    this.imageUrl,
    this.description,
    this.onTap,
  });

  final String title;
  final double price;
  final String? imageUrl;
  final String? description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _ScaleButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: DesignTokens.borderRadiusMd,
          boxShadow: DesignTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DesignTokens.radiusMd),
                ),
                child: (imageUrl?.trim().isNotEmpty ?? false)
                    ? OfflineCachedImage(
                        imageUrl: imageUrl!.trim(),
                        fit: BoxFit.cover,
                        placeholder: _buildPlaceholder(),
                        errorWidget: _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignTokens.textBody.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DesignTokens.spaceXxs),
                  Text(
                    price.toUgx(),
                    style: DesignTokens.textSmall.copyWith(
                      color: DesignTokens.brandAccent,
                      fontWeight: FontWeight.w600,
                      fontFeatures: DesignTokens.textMono.fontFeatures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesignTokens.surfaceGrouped,
      alignment: Alignment.center,
      child: const Icon(
        Icons.room_service_outlined,
        color: DesignTokens.textTertiary,
        size: 32,
      ),
    );
  }
}

class _ScaleButton extends StatefulWidget {
  const _ScaleButton({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        curve: Curves.easeOut,
        child: widget.child,
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
    required this.onRemove,
    this.taxEnabled = false,
    this.taxRate = 0.0,
    this.taxLabel = 'VAT',
    this.taxInclusionMode = 'exclusive',
  });

  final CartState cart;
  final Customer? customer;
  final int parkedCount;
  final VoidCallback onSelectCustomer;
  final Future<void> Function(String id, int quantity) onUpdateQuantity;
  final void Function(CartLine line) onEditPrice;
  final VoidCallback onPark;
  final VoidCallback onCheckout;
  final VoidCallback onClear;
  final void Function(String id) onRemove;
  final bool taxEnabled;
  final double taxRate;
  final String taxLabel;
  final String taxInclusionMode;

  @override
  Widget build(BuildContext context) {
    final taxAmount = TaxCalculator.taxAmount(
      cart.subtotal,
      taxEnabled ? taxRate : 0,
      inclusive: taxInclusionMode == 'inclusive',
    );
    final total = taxInclusionMode == 'inclusive'
        ? cart.subtotal
        : cart.subtotal + taxAmount;

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
                      TextButton(onPressed: onPark, child: const Text('Park')),
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
                        const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: DesignTokens.grayMedium,
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: Text(
                            customer?.name ?? 'Walk-in customer',
                            style: DesignTokens.textBody.copyWith(
                              color: DesignTokens.grayDark,
                            ),
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
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceSm,
                    ),
                    itemCount: cart.lines.length,
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return _CartItem(
                        title: line.title,
                        price: line.price,
                        quantity: line.quantity,
                        variant: line.variant,
                        availableStock: line.availableStock,
                        onIncrement: () => unawaited(
                          onUpdateQuantity(line.id, line.quantity + 1),
                        ),
                        onDecrement: () => unawaited(
                          onUpdateQuantity(line.id, line.quantity - 1),
                        ),
                        onEditPrice: () => onEditPrice(line),
                        onRemove: () => onRemove(line.id),
                      );
                    },
                  ),
          ),

          // Footer with totals
          Container(
            padding: DesignTokens.paddingMd,
            margin: const EdgeInsets.all(DesignTokens.spaceMd),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusMd,
              boxShadow: DesignTokens.shadowMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: DesignTokens.textBody),
                    Text(
                      cart.subtotal.toUgx(),
                      style: DesignTokens.textBodyBold,
                    ),
                  ],
                ),
                if (taxEnabled && taxAmount > 0) ...[
                  const SizedBox(height: DesignTokens.spaceSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$taxLabel (${taxRate.toStringAsFixed(0)}%)',
                        style: DesignTokens.textBody,
                      ),
                      Text(
                        taxAmount.toUgx(),
                        style: DesignTokens.textBodyBold,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: DesignTokens.spaceMd),
                ElevatedButton(
                  onPressed: cart.lines.isEmpty ? null : onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spaceMd,
                    ),
                  ),
                  child: Text(
                    'Charge ${total.toUgx()}',
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
    this.variant,
    this.availableStock,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditPrice,
    required this.onRemove,
  });

  final String title;
  final double price;
  final int quantity;
  final String? variant;
  final int? availableStock;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditPrice;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final atMax = availableStock != null && quantity >= availableStock!;
    final subtotal = (price * quantity).roundToDouble();
    final initials = title
        .trim()
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    final thumbColor = Colors.primaries[title.hashCode % Colors.primaries.length];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceXs,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: thumbColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: DesignTokens.textCaption.copyWith(
                color: thumbColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignTokens.textBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variant != null && variant!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceXs + DesignTokens.spaceXxs,
                      vertical: DesignTokens.spaceXxs,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.grayLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      variant!,
                      style: DesignTokens.textCaption,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                GestureDetector(
                  onLongPress: onEditPrice,
                  child: Text(
                    '${price.toUgx()} each',
                    style: DesignTokens.textSmall.copyWith(
                      color: DesignTokens.grayMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                icon: Icons.remove,
                onPressed: () {
                  Haptics.selection();
                  PosSoundService().playClick();
                  onDecrement();
                },
              ),
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text('$quantity', style: DesignTokens.textBodyBold),
              ),
              _StepperButton(
                icon: Icons.add,
                onPressed: atMax
                    ? null
                    : () {
                        Haptics.selection();
                        PosSoundService().playClick();
                        onIncrement();
                      },
              ),
            ],
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subtotal.toUgx(),
                style: DesignTokens.textBodyBold,
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: DesignTokens.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: DesignTokens.brandAccent),
          shape: const CircleBorder(),
          foregroundColor: DesignTokens.brandAccent,
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _FloatingCartSummary extends StatelessWidget {
  const _FloatingCartSummary({
    required this.itemCount,
    required this.total,
    required this.onTap,
    this.taxEnabled = false,
    this.taxRate = 0.0,
    this.taxInclusionMode = 'exclusive',
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;
  final bool taxEnabled;
  final double taxRate;
  final String taxInclusionMode;

  @override
  Widget build(BuildContext context) {
    final taxAmount = TaxCalculator.taxAmount(
      total,
      taxEnabled ? taxRate : 0,
      inclusive: taxInclusionMode == 'inclusive',
    );
    final displayTotal = taxInclusionMode == 'inclusive'
        ? total
        : total + taxAmount;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      offset: itemCount > 0 ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: itemCount > 0 ? 1.0 : 0.0,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(DesignTokens.spaceMd),
            padding: DesignTokens.paddingPage.copyWith(
              top: DesignTokens.spaceMd - DesignTokens.spaceXxs,
              bottom: DesignTokens.spaceMd - DesignTokens.spaceXxs,
            ),
            decoration: BoxDecoration(
              gradient: DesignTokens.accentGradient,
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.brandAccent.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$itemCount',
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.brandAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: DesignTokens.spaceSm + DesignTokens.spaceXs,
                ),
                Text(
                  'View Cart',
                  style: DesignTokens.textBodyBold.copyWith(
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  displayTotal.toUgx(),
                  style: DesignTokens.textTitle.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          PosSoundService().playClick();
          onTap();
        },
        borderRadius: DesignTokens.borderRadiusMd,
        child: Ink(
          padding: DesignTokens.paddingMd,
          decoration: BoxDecoration(
            color: DesignTokens.grayLight.withValues(alpha: 0.3),
            borderRadius: DesignTokens.borderRadiusMd,
          ),
          child: Row(
            children: [
              Container(
                padding: DesignTokens.paddingSm,
                decoration: BoxDecoration(
                  color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
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
              const Icon(Icons.chevron_right, color: DesignTokens.grayMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentDraft {
  _PaymentDraft({
    required this.method,
    required this.amountCtrl,
    required this.refCtrl,
  });

  String method;
  final TextEditingController amountCtrl;
  final TextEditingController refCtrl;

  void dispose() {
    amountCtrl.dispose();
    refCtrl.dispose();
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
  const _EmptySearchState({
    required this.message,
  });
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingMd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: DesignTokens.textTertiary,
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(
            message,
            style: DesignTokens.textHeadline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          SizedBox(
            width: 260,
            child: Text(
              'Add products to start selling, or sync from your online store.',
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
            color: DesignTokens.grayLight.withValues(alpha: 0.25),
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
                Haptics.impact();
                if (mounted) Navigator.of(context).pop(code.trim());
              },
              errorBuilder:
                  (BuildContext context, MobileScannerException error) {
                    return Center(
                      child: Text(
                        'Camera unavailable',
                        style: DesignTokens.textBody,
                      ),
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
