import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/sync/sync_service.dart';
import '../../widgets/action_tile.dart';
import '../auth/auth_controller.dart';

/// More Screen — Navigation hub for all seller terminal features.
/// 
/// Redesigned with grouped sections for better visual hierarchy
/// following "Steve Jobs standard" — maximum 5-7 sections, clear grouping.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Menu', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync started…')),
              );
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync finished')),
              );
            },
            tooltip: 'Sync data',
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          // ─────────────────────────────────────────────────────────────────
          // BUSINESS Section
          // ─────────────────────────────────────────────────────────────────
          ActionTileSection(
            title: 'Business',
            icon: Icons.trending_up,
            children: [
              ActionTile(
                title: 'Dashboard',
                subtitle: 'KPIs & performance',
                icon: Icons.dashboard_outlined,
                iconColor: DesignTokens.brandAccent,
                onTap: () => context.go('/home/more/dashboard'),
              ),
              ActionTile(
                title: 'Reports',
                subtitle: 'Sales & analytics',
                icon: Icons.bar_chart_outlined,
                iconColor: DesignTokens.info,
                onTap: () => context.go('/home/more/reports'),
              ),
              ActionTile(
                title: 'Customers',
                subtitle: 'CRM & history',
                icon: Icons.people_alt_outlined,
                iconColor: DesignTokens.brandPrimary,
                onTap: () => context.go('/home/more/customers'),
              ),
            ],
          ),

          // ─────────────────────────────────────────────────────────────────
          // CATALOG Section
          // ─────────────────────────────────────────────────────────────────
          ActionTileSection(
            title: 'Catalog',
            icon: Icons.inventory_2_outlined,
            children: [
              ActionTile(
                title: 'Products',
                subtitle: 'Inventory & pricing',
                icon: Icons.inventory_2_outlined,
                iconColor: DesignTokens.brandPrimary,
                onTap: () => context.go('/home/more/items'),
              ),
              ActionTile(
                title: 'Services',
                subtitle: 'Bookings & availability',
                icon: Icons.room_service_outlined,
                iconColor: DesignTokens.warning,
                onTap: () => context.go('/home/more/services'),
              ),
              ActionTile(
                title: 'Wholesale & Digital',
                subtitle: 'Bulk offers & downloads',
                icon: Icons.storefront_outlined,
                iconColor: DesignTokens.grayMedium,
                onTap: () => context.go('/home/more/wholesale'),
              ),
            ],
          ),

          // ─────────────────────────────────────────────────────────────────
          // SALES Section
          // ─────────────────────────────────────────────────────────────────
          ActionTileSection(
            title: 'Sales',
            icon: Icons.receipt_long_outlined,
            children: [
              ActionTile(
                title: 'Shifts & Cash',
                subtitle: 'Open/close, cash in/out',
                icon: Icons.lock_clock_outlined,
                iconColor: DesignTokens.brandPrimary,
                onTap: () => context.go('/home/more/shifts'),
              ),
              ActionTile(
                title: 'Orders',
                subtitle: 'Marketplace & pickups',
                icon: Icons.list_alt_outlined,
                iconColor: DesignTokens.brandAccent,
                onTap: () => context.go('/home/more/orders'),
              ),
              ActionTile(
                title: 'Auctions',
                subtitle: 'Bids & offers',
                icon: Icons.gavel_outlined,
                iconColor: DesignTokens.warning,
                onTap: () => context.go('/home/more/auctions'),
              ),
              ActionTile(
                title: 'Refunds',
                subtitle: 'Returns & disputes',
                icon: Icons.assignment_return_outlined,
                iconColor: DesignTokens.error,
                onTap: () => context.go('/home/more/refunds'),
              ),
            ],
          ),

          // ─────────────────────────────────────────────────────────────────
          // MARKETING Section
          // ─────────────────────────────────────────────────────────────────
          ActionTileSection(
            title: 'Marketing',
            icon: Icons.campaign_outlined,
            children: [
              ActionTile(
                title: 'Ads & Creatives',
                subtitle: 'Generate social media posts',
                icon: Icons.campaign_outlined,
                iconColor: Colors.purple,
                onTap: () => context.go('/home/more/ads'),
              ),
              ActionTile(
                title: 'Coupons',
                subtitle: 'Discounts & promotions',
                icon: Icons.confirmation_number_outlined,
                iconColor: DesignTokens.brandAccent,
                onTap: () => context.go('/home/more/coupons'),
              ),
              ActionTile(
                title: 'Messages',
                subtitle: 'Chat with customers',
                icon: Icons.chat_bubble_outline,
                iconColor: DesignTokens.info,
                onTap: () => context.go('/home/more/chat'),
              ),
            ],
          ),

          // ─────────────────────────────────────────────────────────────────
          // SETTINGS Section
          // ─────────────────────────────────────────────────────────────────
          ActionTileSection(
            title: 'Settings',
            icon: Icons.settings_outlined,
            children: [
              ActionTile(
                title: 'Profile',
                subtitle: 'Account & security',
                icon: Icons.person_outline,
                iconColor: DesignTokens.brandPrimary,
                onTap: () => context.go('/home/more/profile'),
              ),
              ActionTile(
                title: 'Shop Settings',
                subtitle: 'Brand, address, SEO',
                icon: Icons.store_mall_directory_outlined,
                iconColor: DesignTokens.grayMedium,
                onTap: () => context.go('/home/more/shop-info'),
              ),
              ActionTile(
                title: 'Verification',
                subtitle: 'KYC & packages',
                icon: Icons.verified_user_outlined,
                iconColor: DesignTokens.brandAccent,
                onTap: () => context.go('/home/more/verification'),
              ),
              ActionTile(
                title: 'Payment Settings',
                subtitle: 'Bank, mobile money',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: DesignTokens.success,
                onTap: () => context.go('/home/more/payment-settings'),
              ),
              ActionTile(
                title: 'Staff & Roles',
                subtitle: 'Team access & PINs',
                icon: Icons.badge_outlined,
                iconColor: DesignTokens.warning,
                onTap: () => context.go('/home/more/staff'),
              ),
              ActionTile(
                title: 'App Settings',
                subtitle: 'Printers, sync, cache',
                icon: Icons.settings_applications_outlined,
                iconColor: DesignTokens.grayMedium,
                onTap: () => context.go('/home/more/settings'),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spaceMd),

          // ─────────────────────────────────────────────────────────────────
          // LOGOUT Button
          // ─────────────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusMd,
              boxShadow: DesignTokens.shadowSm,
            ),
            child: ActionTile(
              title: 'Sign Out',
              subtitle: 'Log out of this device',
              icon: Icons.logout,
              iconColor: DesignTokens.error,
              iconBackgroundColor: DesignTokens.error.withOpacity(0.1),
              showChevron: false,
              onTap: () {
                ref.read(authControllerProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ),

          const SizedBox(height: DesignTokens.spaceXl),

          // Footer with version
          Center(
            child: Text(
              'Soko24 Seller Terminal v1.0',
              style: DesignTokens.textSmall,
            ),
          ),

          const SizedBox(height: DesignTokens.spaceLg),
        ],
      ),
    );
  }
}
