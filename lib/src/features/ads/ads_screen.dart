import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../checkout/checkout_screen.dart';

class AdsScreen extends ConsumerWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ads Builder')),
      body: items.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Add items first to generate ads'));
          }
          final item = list.first;
          final message =
              'Check out ${item.name} at UGX ${item.price.toStringAsFixed(0)} on Soko24!';
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('UGX ${item.price.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        QrImageView(
                          data: 'https://soko24.co/product/${item.id}',
                          version: QrVersions.auto,
                          size: 120,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Share.share(message),
                  icon: const Icon(Icons.share),
                  label: const Text('Share to social'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
