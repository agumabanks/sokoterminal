import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/logout_dialog.dart';

/// Me Screen — A simple, clean settings/profile screen.
///
/// Design principles:
/// - Profile at top (familiar pattern)
/// - Only essential items
/// - Search for power users
/// - Sign out at bottom
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _businessName = 'My Business';
  final String _roleLabel = 'Owner';

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
        _businessName = profile?.shopName ?? profile?.sellerName ?? 'My Business';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      body: SafeArea(
        child: ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            // Profile header
            _buildProfileHeader(),
            const SizedBox(height: DesignTokens.spaceMd),

            // Search
            _buildSearchBar(),
            const SizedBox(height: DesignTokens.spaceMd),

            // Quick actions (most used)
            _buildQuickActions(),
            const SizedBox(height: DesignTokens.spaceMd),

            // All tools
            _buildTools(),
            const SizedBox(height: DesignTokens.spaceMd),

            // Sign out
            _buildSignOut(),
            const SizedBox(height: DesignTokens.spaceMd),

            // Version
            Center(
              child: Text(
                'Soko Seller Terminal v2.0.0',
                style: DesignTokens.textCaption.copyWith(
                  color: DesignTokens.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DesignTokens.brandAccentSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _businessName.isNotEmpty ? _businessName[0].toUpperCase() : 'S',
              style: DesignTokens.textHeadline.copyWith(
                color: DesignTokens.brandAccent,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_businessName, style: DesignTokens.textTitle),
                Text(_roleLabel, style: DesignTokens.textSmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/home/more/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignTokens.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: DesignTokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: DesignTokens.textBody,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: DesignTokens.textBody.copyWith(
                  color: DesignTokens.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.payments_rounded,
            label: 'Record Expense',
            color: DesignTokens.error,
            onTap: () => context.go('/home/more/expenses'),
          ),
        ),
        const SizedBox(width: DesignTokens.spaceSm),
        Expanded(
          child: _QuickAction(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            color: DesignTokens.brandPrimary,
            onTap: () => context.go('/home/more/items'),
          ),
        ),
        const SizedBox(width: DesignTokens.spaceSm),
        Expanded(
          child: _QuickAction(
            icon: Icons.people_alt_outlined,
            label: 'Customers',
            color: DesignTokens.brandAccent,
            onTap: () => context.go('/home/more/contacts'),
          ),
        ),
      ],
    );
  }

  Widget _buildTools() {
    final tools = [
      _ToolItem(Icons.list_alt_outlined, 'Orders', '/home/more/orders'),
      _ToolItem(Icons.lock_clock_outlined, 'Shifts & Cash', '/home/more/shifts'),
      _ToolItem(Icons.assignment_return_outlined, 'Refunds', '/home/more/refunds'),
      _ToolItem(Icons.link, 'Payment Links', '/home/more/payment-links'),
      _ToolItem(Icons.auto_awesome_outlined, 'Soko Studio', '/home/more/ads'),
      _ToolItem(Icons.menu_book_outlined, 'Digital Catalog', '/home/more/catalog'),
      _ToolItem(Icons.confirmation_number_outlined, 'Coupons', '/home/more/coupons'),
      _ToolItem(Icons.sms_outlined, 'Bulk SMS', '/home/more/bulk-sms'),
      _ToolItem(Icons.store_mall_directory_outlined, 'Shop Settings', '/home/more/shop-info'),
      _ToolItem(Icons.account_balance_wallet_outlined, 'Wallet', '/home/more/wallet'),
      _ToolItem(Icons.verified_user_outlined, 'Verification', '/home/more/verification'),
      _ToolItem(Icons.settings_applications_outlined, 'App Settings', '/home/more/settings'),
      _ToolItem(Icons.bar_chart_outlined, 'Reports', '/home/more/reports'),
      _ToolItem(Icons.backup_outlined, 'Backup & Restore', '/home/more/backup'),
      _ToolItem(Icons.local_shipping_outlined, 'Suppliers', '/home/more/suppliers'),
      _ToolItem(Icons.playlist_add_check_outlined, 'Purchase Orders', '/home/more/purchase-orders'),
      _ToolItem(Icons.warning_amber_outlined, 'Low Stock', '/home/more/low-stock'),
      _ToolItem(Icons.request_quote_outlined, 'Quotations', '/home/more/quotations'),
      _ToolItem(Icons.badge_outlined, 'Staff & Roles', '/home/more/staff'),
    ];

    // Filter by query
    final filtered = _query.isEmpty
        ? tools
        : tools.where((t) => t.label.toLowerCase().contains(_query.toLowerCase())).toList();

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        children: filtered.asMap().entries.map((entry) {
          final tool = entry.value;
          final isLast = entry.key == filtered.length - 1;
          return Column(
            children: [
              ListTile(
                leading: Icon(tool.icon, size: 22, color: DesignTokens.inkSubtle),
                title: Text(tool.label, style: DesignTokens.textBody),
                trailing: const Icon(Icons.chevron_right, size: 20, color: DesignTokens.textTertiary),
                onTap: () => context.go(tool.route),
                contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                visualDensity: VisualDensity.compact,
              ),
              if (!isLast) const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSignOut() {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: DesignTokens.error),
        title: const Text('Sign Out'),
        subtitle: const Text('Lock, switch staff, or end the session'),
        onTap: () => LogoutDialog.show(context),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
          decoration: BoxDecoration(
            color: DesignTokens.canvas,
            borderRadius: DesignTokens.borderRadiusMd,
            border: Border.all(color: DesignTokens.hairline),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: DesignTokens.spaceXs),
              Text(
                label,
                style: DesignTokens.textCaption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}
