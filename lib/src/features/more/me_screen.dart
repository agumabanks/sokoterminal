import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';
import '../../widgets/logout_dialog.dart';

/// Me Screen — Settings hub, grouped for scannability.
///
/// Design principles (WhatsApp/Apple settings):
/// - Sections with semantic headers, not a flat list
/// - Surface top 3-4 tools as large cards above fold
/// - Command palette search that finds actions, not just tool names
/// - Touch targets ≥48dp for fast, imprecise taps
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;
  String _businessName = 'My Business';
  final String _roleLabel = 'Owner';

  // Tool sections — grouped semantically
  static const _sections = <_ToolSection>[
    _ToolSection(
      title: 'MONEY',
      tools: [
        _ToolItem(Icons.link, 'Payment Links', '/home/more/payment-links'),
        _ToolItem(Icons.account_balance_wallet_outlined, 'Madeni Ledger', '/home/more/madeni'),
        _ToolItem(Icons.account_balance_wallet_outlined, 'Wallet', '/home/more/wallet'),
        _ToolItem(Icons.lock_clock_outlined, 'Shifts & Cash', '/home/more/shifts'),
      ],
    ),
    _ToolSection(
      title: 'SELL',
      tools: [
        _ToolItem(Icons.list_alt_outlined, 'Orders', '/home/more/orders'),
        _ToolItem(Icons.inventory_2_outlined, 'Products', '/home/more/items'),
        _ToolItem(Icons.room_service_outlined, 'Services', '/home/more/services'),
        _ToolItem(Icons.menu_book_outlined, 'Digital Catalog', '/home/more/catalog'),
      ],
    ),
    _ToolSection(
      title: 'GROW',
      tools: [
        _ToolItem(Icons.auto_awesome_outlined, 'Soko Studio', '/home/more/ads'),
        _ToolItem(Icons.confirmation_number_outlined, 'Coupons', '/home/more/coupons'),
        _ToolItem(Icons.sms_outlined, 'Bulk SMS', '/home/more/bulk-sms'),
        _ToolItem(Icons.people_alt_outlined, 'Customers', '/home/more/contacts'),
      ],
    ),
    _ToolSection(
      title: 'SETUP & ACCOUNT',
      tools: [
        _ToolItem(Icons.store_mall_directory_outlined, 'Shop Settings', '/home/more/shop-info'),
        _ToolItem(Icons.delivery_dining, 'Delivery Area & Fees', '/home/more/delivery-settings'),
        _ToolItem(Icons.badge_outlined, 'Staff & Roles', '/home/more/staff'),
        _ToolItem(Icons.settings_applications_outlined, 'App Settings', '/home/more/settings'),
        _ToolItem(Icons.verified_user_outlined, 'Verification', '/home/more/verification'),
        _ToolItem(Icons.backup_outlined, 'Backup & Restore', '/home/more/backup'),
      ],
    ),
    _ToolSection(
      title: 'SUPPLIERS & STOCK',
      tools: [
        _ToolItem(Icons.local_shipping_outlined, 'Suppliers', '/home/more/suppliers'),
        _ToolItem(Icons.playlist_add_check_outlined, 'Purchase Orders', '/home/more/purchase-orders'),
        _ToolItem(Icons.warning_amber_outlined, 'Low Stock', '/home/more/low-stock'),
        _ToolItem(Icons.request_quote_outlined, 'Quotations', '/home/more/quotations'),
      ],
    ),
  ];

  // Top tools surfaced as cards (most used, in order)
  static const _topTools = <_ToolItem>[
    _ToolItem(Icons.inventory_2_outlined, 'Products', '/home/more/items'),
    _ToolItem(Icons.people_alt_outlined, 'Customers', '/home/more/contacts'),
    _ToolItem(Icons.list_alt_outlined, 'Orders', '/home/more/orders'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _query = _searchController.text);
      });
    });
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
    _searchDebounce?.cancel();
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

            // Command palette search
            _buildSearchBar(),
            const SizedBox(height: DesignTokens.spaceMd),

            if (_query.isEmpty) ...[
              // Top tools (most used)
              _buildTopTools(),
              const SizedBox(height: DesignTokens.spaceMd),
              // All tools grouped
              ..._sections.map((s) => _buildSection(s)),
            ] else ...[
              // Search results
              _buildSearchResults(),
            ],

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
    return Semantics(
      label: 'Profile: $_businessName, $_roleLabel',
      child: Container(
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
              tooltip: 'Edit profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Semantics(
      label: 'Search tools and actions',
      textField: true,
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.canvas,
          borderRadius: BorderRadius.circular(12),
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
                style: DesignTokens.textBody,
                decoration: InputDecoration(
                  hintText: 'Search tools, customers, actions...',
                  hintStyle: DesignTokens.textBody.copyWith(
                    color: DesignTokens.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                tooltip: 'Clear search',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTools() {
    return Semantics(
      label: 'Quick actions',
      child: Row(
        children: _topTools.map((tool) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _QuickAction(
                icon: tool.icon,
                label: tool.label,
                color: _topTools.indexOf(tool) == 0
                    ? DesignTokens.brandAccent
                    : DesignTokens.brandPrimary,
                onTap: () {
                  Haptics.selection();
                  context.go(tool.route);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(_ToolSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Semantics(
              header: true,
              child: Text(
                section.title,
                style: DesignTokens.textCaption.copyWith(
                  color: DesignTokens.inkMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: DesignTokens.canvas,
              borderRadius: DesignTokens.borderRadiusMd,
              border: Border.all(color: DesignTokens.hairline),
            ),
            child: Column(
              children: section.tools.asMap().entries.map((entry) {
                final tool = entry.value;
                final isLast = entry.key == section.tools.length - 1;
                return Column(
                  children: [
                    Semantics(
                      button: true,
                      label: tool.label,
                      child: ListTile(
                        minTileHeight: 56,
                        leading: Icon(tool.icon, size: 22, color: DesignTokens.inkSubtle),
                        title: Text(tool.label, style: DesignTokens.textBody),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: DesignTokens.textTertiary),
                        onTap: () {
                          Haptics.selection();
                          context.go(tool.route);
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 56, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final q = _query.toLowerCase();
    final results = <_ToolItem>[];
    for (final section in _sections) {
      for (final tool in section.tools) {
        if (tool.label.toLowerCase().contains(q)) {
          results.add(tool);
        }
      }
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No tools match "$_query"',
            style: DesignTokens.textBody,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        children: results.asMap().entries.map((entry) {
          final tool = entry.value;
          final isLast = entry.key == results.length - 1;
          return Column(
            children: [
              Semantics(
                button: true,
                label: tool.label,
                child: ListTile(
                  minTileHeight: 56,
                  leading: Icon(tool.icon, size: 22, color: DesignTokens.inkSubtle),
                  title: Text(tool.label, style: DesignTokens.textBody),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: DesignTokens.textTertiary),
                  onTap: () {
                    Haptics.selection();
                    context.go(tool.route);
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
                ),
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
      child: Semantics(
        button: true,
        label: 'Sign Out. Lock, switch staff, or end the session.',
        child: ListTile(
          minTileHeight: 56,
          leading: const Icon(Icons.logout, color: DesignTokens.error),
          title: const Text('Sign Out'),
          subtitle: const Text('Lock, switch staff, or end the session'),
          onTap: () {
            Haptics.selection();
            LogoutDialog.show(context);
          },
        ),
      ),
    );
  }
}

class _ToolSection {
  const _ToolSection({required this.title, required this.tools});
  final String title;
  final List<_ToolItem> tools;
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
