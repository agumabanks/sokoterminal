import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/offline_cached_image.dart';
import 'catalog_service.dart';

final _catalogItemsProvider = FutureProvider<List<Item>>((ref) {
  return ref.watch(appDatabaseProvider).getAllItems();
});

final _catalogServicesProvider = FutureProvider<List<Service>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.services).get();
});

final _businessProfileProvider = FutureProvider<BusinessProfile?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.businessProfiles)..limit(1)).getSingleOrNull();
});

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen>
    with SingleTickerProviderStateMixin {
  final _selectedProductIds = <String>{};
  final _selectedServiceIds = <String>{};
  bool _includeServices = false;
  bool _selectAllProducts = true;
  bool _selectAllServices = true;
  bool _generating = false;
  late TabController _tabCtrl;
  static final _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(_catalogItemsProvider);
    final servicesAsync = ref.watch(_catalogServicesProvider);
    final profileAsync = ref.watch(_businessProfileProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Digital Catalog', style: DesignTokens.textTitle),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              text: 'Products (${itemsAsync.valueOrNull?.length ?? 0})',
            ),
            Tab(
              icon: const Icon(Icons.room_service_outlined, size: 18),
              text: 'Services (${servicesAsync.valueOrNull?.length ?? 0})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildProductsTab(itemsAsync),
          _buildServicesTab(servicesAsync),
        ],
      ),
      bottomNavigationBar: _buildShareBar(
        itemsAsync.valueOrNull ?? [],
        servicesAsync.valueOrNull ?? [],
        profileAsync.valueOrNull,
      ),
    );
  }

  Widget _buildProductsTab(AsyncValue<List<Item>> itemsAsync) {
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            subtitle: 'Add products first to generate a catalog',
          );
        }
        if (_selectAllProducts && _selectedProductIds.isEmpty) {
          _selectedProductIds.addAll(items.map((i) => i.id));
        }
        return Column(
          children: [
            _selectionBar(
              selected: _selectedProductIds.length,
              total: items.length,
              selectAll: _selectAllProducts,
              onToggleAll: () {
                setState(() {
                  _selectAllProducts = !_selectAllProducts;
                  if (_selectAllProducts) {
                    _selectedProductIds.addAll(items.map((i) => i.id));
                  } else {
                    _selectedProductIds.clear();
                  }
                });
              },
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final sel = _selectedProductIds.contains(item.id);
                  return _ProductTile(
                    item: item,
                    selected: sel,
                    onToggle: () => setState(() {
                      if (sel) {
                        _selectedProductIds.remove(item.id);
                        _selectAllProducts = false;
                      } else {
                        _selectedProductIds.add(item.id);
                        if (_selectedProductIds.length == items.length) {
                          _selectAllProducts = true;
                        }
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServicesTab(AsyncValue<List<Service>> servicesAsync) {
    return servicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (services) {
        if (services.isEmpty) {
          return _emptyState(
            icon: Icons.room_service_outlined,
            title: 'No services yet',
            subtitle: 'Add services first to include them in the catalog',
          );
        }
        if (_selectAllServices && _selectedServiceIds.isEmpty) {
          _selectedServiceIds.addAll(services.map((s) => s.id));
        }
        return Column(
          children: [
            // Include services toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: DesignTokens.surfaceWhite,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, size: 18, color: DesignTokens.brandPrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Include services in catalog', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Switch(
                    value: _includeServices,
                    onChanged: (v) => setState(() => _includeServices = v),
                  ),
                ],
              ),
            ),
            if (_includeServices) ...[
              _selectionBar(
                selected: _selectedServiceIds.length,
                total: services.length,
                selectAll: _selectAllServices,
                onToggleAll: () {
                  setState(() {
                    _selectAllServices = !_selectAllServices;
                    if (_selectAllServices) {
                      _selectedServiceIds.addAll(services.map((s) => s.id));
                    } else {
                      _selectedServiceIds.clear();
                    }
                  });
                },
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: services.length,
                  itemBuilder: (_, i) {
                    final svc = services[i];
                    final sel = _selectedServiceIds.contains(svc.id);
                    return _ServiceTile(
                      service: svc,
                      selected: sel,
                      onToggle: () => setState(() {
                        if (sel) {
                          _selectedServiceIds.remove(svc.id);
                          _selectAllServices = false;
                        } else {
                          _selectedServiceIds.add(svc.id);
                          if (_selectedServiceIds.length == services.length) {
                            _selectAllServices = true;
                          }
                        }
                      }),
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: _emptyState(
                  icon: Icons.toggle_off_outlined,
                  title: 'Services not included',
                  subtitle: 'Toggle the switch above to add services to your catalog',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _selectionBar({
    required int selected,
    required int total,
    required bool selectAll,
    required VoidCallback onToggleAll,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: DesignTokens.surfaceWhite,
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: selected > 0 ? DesignTokens.success : DesignTokens.grayMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$selected of $total selected', style: DesignTokens.textBody),
          ),
          TextButton(
            onPressed: onToggleAll,
            child: Text(selectAll ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: DesignTokens.grayMedium),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: DesignTokens.grayMedium, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildShareBar(List<Item> allItems, List<Service> allServices, BusinessProfile? profile) {
    final selectedProducts = allItems.where((i) => _selectedProductIds.contains(i.id)).toList();
    final selectedServices = _includeServices
        ? allServices.where((s) => _selectedServiceIds.contains(s.id)).toList()
        : <Service>[];
    final totalSelected = selectedProducts.length + selectedServices.length;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalSelected == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Select items to share', style: TextStyle(color: DesignTokens.grayMedium)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$totalSelected item${totalSelected == 1 ? '' : 's'} selected'
                  '${selectedServices.isNotEmpty ? ' (${selectedProducts.length} products, ${selectedServices.length} services)' : ''}',
                  style: DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _generating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Share PDF'),
                      onPressed: _generating ? null : () => _sharePdf(selectedProducts, selectedServices, profile),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _generating ? null : () => _shareWhatsApp(selectedProducts, selectedServices, profile),
                    ),
                  ),
                ],
              ),
              if (profile?.shopId != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.storefront, size: 18),
                    label: const Text('Open Shop Link'),
                    onPressed: () => _openShopLink(profile!.shopId!),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf(List<Item> items, List<Service> services, BusinessProfile? profile) async {
    if (items.isEmpty && services.isEmpty || _generating) return;
    setState(() => _generating = true);
    try {
      final service = CatalogService(ref.read(appDatabaseProvider));
      await service.sharePdf(
        items: items,
        services: services,
        shopName: profile?.shopName ?? 'My Shop',
        shopPhone: profile?.shopPhone,
        shopAddress: profile?.shopAddress,
        logoUrl: profile?.logoUrl,
        shopId: profile?.shopId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _shareWhatsApp(List<Item> items, List<Service> services, BusinessProfile? profile) async {
    if (items.isEmpty && services.isEmpty || _generating) return;
    setState(() => _generating = true);
    try {
      final svc = CatalogService(ref.read(appDatabaseProvider));
      await svc.shareWhatsApp(
        items: items,
        services: services,
        shopName: profile?.shopName ?? 'My Shop',
        shopId: profile?.shopId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openShopLink(String shopId) async {
    final svc = CatalogService(ref.read(appDatabaseProvider));
    await svc.openShopLink(shopId);
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item, required this.selected, required this.onToggle});
  final Item item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final price = 'UGX ${_CatalogScreenState._currencyFormat.format(item.price.round())}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected
            ? const BorderSide(color: DesignTokens.brandPrimary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _buildImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(price, style: const TextStyle(color: DesignTokens.success, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (item.stockEnabled && item.stockQty > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${item.stockQty} in stock',
                            style: const TextStyle(fontSize: 11, color: DesignTokens.grayMedium)),
                      ),
                  ],
                ),
              ),
              Checkbox(value: selected, onChanged: (_) => onToggle()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = item.thumbnailUrl ?? item.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: OfflineCachedImage(
            imageUrl: url.trim(),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: _placeholder(),
            errorWidget: _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: DesignTokens.grayLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, color: DesignTokens.grayMedium, size: 24),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.selected, required this.onToggle});
  final Service service;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final price = 'UGX ${_CatalogScreenState._currencyFormat.format(service.price.round())}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected
            ? const BorderSide(color: DesignTokens.brandPrimary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _buildImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(price, style: const TextStyle(color: DesignTokens.success, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (service.durationMinutes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 12, color: DesignTokens.grayMedium),
                            const SizedBox(width: 4),
                            Text('${service.durationMinutes} min',
                                style: const TextStyle(fontSize: 11, color: DesignTokens.grayMedium)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Checkbox(value: selected, onChanged: (_) => onToggle()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = service.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: OfflineCachedImage(
            imageUrl: url.trim(),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: _placeholder(),
            errorWidget: _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: DesignTokens.grayLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.room_service_outlined, color: DesignTokens.grayMedium, size: 24),
    );
  }
}
