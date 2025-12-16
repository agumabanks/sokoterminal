import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
