import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DesignTokens.brandPrimary, Color(0xFF123B33)],
              ),
              borderRadius: DesignTokens.borderRadiusLg,
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Soko24 identity',
                        style: DesignTokens.textTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Keep the app, web shop and buyer experience in sync.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: DesignTokens.brandAccentLight,
                child: Icon(Icons.palette_outlined),
              ),
              title: const Text('Shop appearance'),
              subtitle: const Text('Logo, profile photo and banners'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/home/more/brand-media'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('Seller profile'),
              subtitle: const Text('Edit name, email, phone'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/home/more/seller-profile'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Shop settings'),
              subtitle: const Text('Brand info, address, contacts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/home/more/shop-info'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Shop SEO'),
              subtitle: const Text('Meta title, description, tags'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/home/more/shop-seo'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Payment settings'),
              subtitle: const Text('Bank, mobile money, cash'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/home/more/payment-settings'),
            ),
          ),
        ],
      ),
    );
  }
}
