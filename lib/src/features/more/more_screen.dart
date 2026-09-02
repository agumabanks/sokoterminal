import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/settings/staff_menu_visibility.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/sync/sync_service.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../widgets/action_tile.dart';
import '../../widgets/logout_dialog.dart';
import '../../core/firebase/remote_config_service.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _businessName = 'S';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadBusinessName();
  }

  Future<void> _loadBusinessName() async {
    final db = ref.read(appDatabaseProvider);
    final profile = await db.getBusinessProfile();
    if (mounted) {
      setState(() {
        _businessName = profile?.shopName ?? profile?.sellerName ?? 'S';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_MoreAction> _filter(List<_MoreAction> actions) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return actions;
    return actions
        .where(
          (a) =>
              a.title.toLowerCase().contains(q) ||
              a.subtitle.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = ref.watch(remoteConfigProvider);
    final posSession = ref.watch(posSessionProvider);
    final staffMenuAccess = ref.watch(staffMenuAccessProvider);
    final isManager = posSession.isManager;
    final isStaffSession = posSession.isActive && !isManager;

    bool allow(String featureId) {
      if (!isStaffSession) return true;
      if (!staffMenuAccess.loaded) {
        return defaultStaffVisibleFeatureIds.contains(featureId);
      }
      return staffMenuAccess.isVisible(featureId);
    }

    final todayActions = [
      // Expenses is a daily action — shown first for fast access
      if (allow('expenses'))
        _MoreAction(
          title: 'Record Expense',
          subtitle: 'Log operating costs and cashouts',
          icon: Icons.payments_rounded,
          color: DesignTokens.error,
          route: '/home/more/expenses',
          badge: 'DAILY',
        ),
      if (allow('dashboard'))
        _MoreAction(
          title: 'Dashboard',
          subtitle: 'Today\'s KPIs and sales pulse',
          icon: Icons.dashboard_outlined,
          color: DesignTokens.brandPrimary,
          route: '/home/more/dashboard',
        ),
      if (isManager && allow('reports'))
        _MoreAction(
          title: 'Reports',
          subtitle: 'Revenue, margin, and performance',
          icon: Icons.bar_chart_outlined,
          color: DesignTokens.info,
          route: '/home/more/reports',
        ),
      if (allow('customers'))
        _MoreAction(
          title: 'Customers',
          subtitle: 'Contacts, notes, and WhatsApp reach',
          icon: Icons.people_alt_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/contacts',
        ),
      if (allow('orders'))
        _MoreAction(
          title: 'Orders',
          subtitle: 'Marketplace orders and pickups',
          icon: Icons.list_alt_outlined,
          color: DesignTokens.warning,
          route: '/home/more/orders',
        ),
      if (allow('shifts'))
        _MoreAction(
          title: 'Shifts & Cash',
          subtitle: 'Open, close, and reconcile tills',
          icon: Icons.lock_clock_outlined,
          color: DesignTokens.brandPrimary,
          route: '/home/more/shifts',
        ),
      if (allow('refunds'))
        _MoreAction(
          title: 'Refunds',
          subtitle: 'Returns, disputes, and reversals',
          icon: Icons.assignment_return_outlined,
          color: DesignTokens.error,
          route: '/home/more/refunds',
        ),
    ];

    final catalogActions = [
      if (allow('products'))
        _MoreAction(
          title: 'Products',
          subtitle: 'Inventory, pricing, and stock',
          icon: Icons.inventory_2_outlined,
          color: DesignTokens.brandPrimary,
          route: '/home/more/items',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Suppliers',
          subtitle: 'Vendors and restock relationships',
          icon: Icons.local_shipping_outlined,
          color: DesignTokens.grayMedium,
          route: '/home/more/suppliers',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Purchase Orders',
          subtitle: 'Supplier POs and approvals',
          icon: Icons.playlist_add_check_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/purchase-orders',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Receive Stock',
          subtitle: 'Goods received and stock intake',
          icon: Icons.call_received_outlined,
          color: DesignTokens.success,
          route: '/home/more/receive-stock',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Stock Count',
          subtitle: 'Physical count and variance review',
          icon: Icons.fact_check_outlined,
          color: DesignTokens.info,
          route: '/home/more/stocktake',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Low Stock',
          subtitle: 'Reorder pressure and alerts',
          icon: Icons.warning_amber_outlined,
          color: DesignTokens.warning,
          route: '/home/more/low-stock',
        ),
      if (allow('services'))
        _MoreAction(
          title: 'Services',
          subtitle: 'Service menu and booking flow',
          icon: Icons.room_service_outlined,
          color: DesignTokens.info,
          route: '/home/more/services',
        ),
      if (allow('quotations'))
        _MoreAction(
          title: 'Quotations',
          subtitle: 'Prepare and send quotes',
          icon: Icons.request_quote_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/quotations',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Digital Catalog',
          subtitle: 'Generate and share catalog pages',
          icon: Icons.menu_book_outlined,
          color: DesignTokens.success,
          route: '/home/more/catalog',
        ),
    ];

    final growthActions = [
      if (!isStaffSession)
        _MoreAction(
          title: 'Payment Links',
          subtitle: 'Create shareable payment links',
          icon: Icons.link,
          color: DesignTokens.brandAccent,
          route: '/home/more/payment-links',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Sanaa Wallet',
          subtitle: 'Credits, add-ons, and balances',
          icon: Icons.account_balance_wallet_outlined,
          color: DesignTokens.success,
          route: '/home/more/wallet',
        ),
      if (!isStaffSession && remoteConfig.ffSokoStudio)
        _MoreAction(
          title: 'Soko Studio',
          subtitle: 'Designs, ads, campaigns & marketing tools',
          icon: Icons.auto_awesome_outlined,
          color: DesignTokens.brandPrimary,
          route: '/home/more/ads',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Bulk SMS',
          subtitle: 'Broadcast offers to saved contacts',
          icon: Icons.sms_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/bulk-sms',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Coupons',
          subtitle: 'Discount campaigns and promos',
          icon: Icons.confirmation_number_outlined,
          color: DesignTokens.warning,
          route: '/home/more/coupons',
        ),
      if (isManager)
        _MoreAction(
          title: 'Insights & Analytics',
          subtitle: 'Visual trends and decision support',
          icon: Icons.insights,
          color: DesignTokens.brandPrimary,
          route: '/home/more/analytics',
        ),
    ];

    final dataActions = [
      if (!isStaffSession)
        _MoreAction(
          title: 'Backup & Restore',
          subtitle: 'Protect and recover terminal data',
          icon: Icons.backup_outlined,
          color: DesignTokens.info,
          route: '/home/more/backup',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Exports',
          subtitle: 'Download ledger, products, and contacts',
          icon: Icons.download_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/export',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Sync Health',
          subtitle: 'Queue status, conflicts, and diagnostics',
          icon: Icons.sync_problem_outlined,
          color: DesignTokens.warning,
          route: '/home/more/sync-health',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Device Health',
          subtitle: 'Compatibility, auth, and self-diagnostics',
          icon: Icons.health_and_safety_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/device-health',
        ),
    ];

    final controlActions = [
      if (remoteConfig.ffBusinessSetupWizard && isManager)
        _MoreAction(
          title: 'Business Setup',
          subtitle: 'Finish setup checklist and readiness',
          icon: Icons.checklist_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/business-setup',
        ),
      if (allow('profile'))
        _MoreAction(
          title: 'Profile',
          subtitle: 'Account and business identity',
          icon: Icons.person_outline,
          color: DesignTokens.brandPrimary,
          route: '/home/more/profile',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Shop Settings',
          subtitle: 'Brand, address, and SEO surfaces',
          icon: Icons.store_mall_directory_outlined,
          color: DesignTokens.grayMedium,
          route: '/home/more/shop-info',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Verification',
          subtitle: 'KYC and package status',
          icon: Icons.verified_user_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/verification',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Payment Settings',
          subtitle: 'Bank, mobile money, and payout setup',
          icon: Icons.account_balance_wallet_outlined,
          color: DesignTokens.success,
          route: '/home/more/payment-settings',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Delivery Options',
          subtitle: 'Seller delivery and fee rules',
          icon: Icons.local_shipping_outlined,
          color: DesignTokens.info,
          route: '/home/more/delivery-settings',
        ),
      if (isManager)
        _MoreAction(
          title: 'Staff & Roles',
          subtitle: 'People, PINs, and session control',
          icon: Icons.badge_outlined,
          color: DesignTokens.warning,
          route: '/home/more/staff',
        ),
      if (isManager)
        _MoreAction(
          title: 'Staff Menu Access',
          subtitle: 'Choose what staff can see in More',
          icon: Icons.visibility_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/staff-menu-access',
        ),
      if (isManager)
        _MoreAction(
          title: 'App Settings',
          subtitle: 'Printers, sync, cache, and exports',
          icon: Icons.settings_applications_outlined,
          color: DesignTokens.grayMedium,
          route: '/home/more/settings',
        ),
      if (!isStaffSession)
        _MoreAction(
          title: 'Receipt Templates',
          subtitle: 'Tune receipt layout and branding',
          icon: Icons.receipt_outlined,
          color: DesignTokens.brandAccent,
          route: '/home/more/receipt-templates',
        ),
    ];

    final filteredToday = _filter(todayActions);
    final filteredCatalog = _filter(catalogActions);
    final filteredGrowth = _filter(growthActions);
    final filteredData = _filter(dataActions);
    final filteredControl = _filter(controlActions);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceGrouped,
        title: Text('More', style: DesignTokens.textHeadline),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _syncing ? null : _syncNow,
            tooltip: 'Sync data',
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          _MoreHeroCard(
            title: _businessName,
            roleLabel: isManager ? 'Manager' : 'Staff',
            statusLabel: posSession.isActive
                ? 'Active on this device'
                : 'Owner session',
            businessName: _businessName,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          _SearchBar(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          if (_query.isNotEmpty &&
              filteredToday.isEmpty &&
              filteredCatalog.isEmpty &&
              filteredGrowth.isEmpty &&
              filteredData.isEmpty &&
              filteredControl.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: DesignTokens.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tool matches “$_query”',
                    style: DesignTokens.textBodyBold,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    child: const Text('Clear search'),
                  ),
                ],
              ),
            ),
          if (filteredToday.isNotEmpty) ...[
            _MoreSection(
              title: 'Today',
              icon: Icons.bolt_outlined,
              actions: filteredToday,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
          ],
          if (filteredCatalog.isNotEmpty) ...[
            _MoreSection(
              title: 'Catalog & Operations',
              icon: Icons.inventory_2_outlined,
              actions: filteredCatalog,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
          ],
          if (filteredGrowth.isNotEmpty) ...[
            _MoreSection(
              title: 'Growth',
              icon: Icons.trending_up,
              actions: filteredGrowth,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
          ],
          if (filteredData.isNotEmpty) ...[
            _MoreSection(
              title: 'Data & Memory',
              icon: Icons.storage_outlined,
              actions: filteredData,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
          ],
          if (filteredControl.isNotEmpty) ...[
            _MoreSection(
              title: 'Control',
              icon: Icons.tune_outlined,
              actions: filteredControl,
            ),
            const SizedBox(height: DesignTokens.spaceLg),
          ],
          Container(
            decoration: BoxDecoration(
              color: DesignTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: ActionTile(
              title: 'Sign Out',
              subtitle: 'Lock, switch staff, or end the current session',
              icon: Icons.logout,
              iconColor: DesignTokens.error,
              iconBackgroundColor: DesignTokens.error.withValues(alpha: 0.12),
              showChevron: false,
              onTap: () => LogoutDialog.show(context),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXl),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: DesignTokens.textTertiary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Seller Terminal · v2.0.0',
                  style: DesignTokens.textCaption.copyWith(
                    color: DesignTokens.textTertiary,
                  ),
                ),
                Text(
                  'Made with ♥ for African business',
                  style: DesignTokens.textCaption.copyWith(
                    color: DesignTokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await ref.read(syncServiceProvider).syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Everything is up to date')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh now. Your saved data is safe.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: DesignTokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: DesignTokens.textBody,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                hintText: 'Search features…',
                hintStyle: DesignTokens.textBody.copyWith(
                  color: DesignTokens.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spaceMd,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.clear,
                  size: 20,
                  color: DesignTokens.textTertiary,
                ),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoreHeroCard extends StatelessWidget {
  const _MoreHeroCard({
    required this.title,
    required this.roleLabel,
    required this.statusLabel,
    required this.businessName,
  });

  final String title;
  final String roleLabel;
  final String statusLabel;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final avatarLetter = businessName.trim().isNotEmpty
        ? businessName.trim()[0].toUpperCase()
        : 'S';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.brandGradient,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            child: Text(
              avatarLetter,
              style: DesignTokens.textTitle.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignTokens.textBodyBold.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  statusLabel,
                  style: DesignTokens.textCaption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: DesignTokens.borderRadiusFull,
            ),
            child: Text(
              roleLabel,
              style: DesignTokens.textCaption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({
    required this.title,
    required this.icon,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final List<_MoreAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: DesignTokens.spaceMd,
            bottom: DesignTokens.spaceSm,
          ),
          child: Text(
            title.toUpperCase(),
            style: DesignTokens.textSmall.copyWith(
              letterSpacing: 0.8,
              color: DesignTokens.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: DesignTokens.surfaceRaised,
            borderRadius: DesignTokens.borderRadiusSm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                Stack(
                  children: [
                    ActionTile(
                      title: actions[i].title,
                      subtitle: actions[i].subtitle,
                      icon: actions[i].icon,
                      iconColor: actions[i].color,
                      onTap: () => context.go(actions[i].route),
                    ),
                    if (actions[i].badge != null)
                      Positioned(
                        right: DesignTokens.spaceMd,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spaceSm,
                              vertical: DesignTokens.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              color: actions[i].color.withValues(alpha: 0.15),
                              borderRadius: DesignTokens.borderRadiusFull,
                              border: Border.all(
                                color: actions[i].color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              actions[i].badge!,
                              style: DesignTokens.textCaption.copyWith(
                                color: actions[i].color,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (i != actions.length - 1)
                  const Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: 76,
                    color: DesignTokens.dividerSolid,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreAction {
  const _MoreAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;
}
