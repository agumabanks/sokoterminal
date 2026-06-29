
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';

/// Client Directory — aggregates local customers + remote service clients.
///
/// Design: search-as-you-type, one-tap call/WhatsApp, tap to see history.
final _clientsProvider = FutureProvider.autoDispose<List<_ClientView>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(sellerApiProvider);

  // 1. Local customers
  final localCustomers = await db.select(db.customers).get();

  // 2. Try remote service clients
  List<Map<String, dynamic>> remoteClients = [];
  try {
    final res = await api.fetchServiceClients();
    final data = res.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      final list = data['data'];
      if (list is Map && list['data'] is List) {
        remoteClients = List<Map<String, dynamic>>.from(
          (list['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    }
  } catch (_) {
    // Offline — use locals only
  }

  // Merge: remote takes precedence for overlapping phones
  final merged = <String, _ClientView>{};
  for (final r in remoteClients) {
    final phone = r['phone']?.toString() ?? '';
    merged[phone] = _ClientView(
      name: r['name']?.toString() ?? 'Unknown',
      phone: phone,
      email: r['email']?.toString(),
      totalBookings: r['total_bookings'] ?? 0,
      totalSpent: (r['total_spent'] ?? 0).toDouble(),
      notes: r['notes']?.toString(),
      source: 'remote',
    );
  }
  for (final c in localCustomers) {
    final phone = c.phone ?? '';
    if (phone.isNotEmpty && merged.containsKey(phone)) continue;
    merged[phone] = _ClientView(
      name: c.name,
      phone: phone,
      email: c.email,
      totalBookings: 0,
      totalSpent: 0,
      notes: c.note,
      source: 'local',
    );
  }

  final list = merged.values.toList();
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

class _ClientView {
  _ClientView({
    required this.name,
    required this.phone,
    this.email,
    this.totalBookings = 0,
    this.totalSpent = 0,
    this.notes,
    required this.source,
  });
  final String name;
  final String phone;
  final String? email;
  final int totalBookings;
  final double totalSpent;
  final String? notes;
  final String source;
}

class ClientDirectoryScreen extends ConsumerStatefulWidget {
  const ClientDirectoryScreen({super.key});

  @override
  ConsumerState<ClientDirectoryScreen> createState() => _ClientDirectoryScreenState();
}

class _ClientDirectoryScreenState extends ConsumerState<ClientDirectoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(_clientsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Clients'),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: DesignTokens.paddingScreen,
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: DesignTokens.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: clientsAsync.when(
              data: (all) {
                final filtered = _search.isEmpty
                    ? all
                    : all.where((c) =>
                        c.name.toLowerCase().contains(_search) ||
                        c.phone.contains(_search)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No clients found'));
                }

                return ListView.builder(
                  padding: DesignTokens.paddingScreen,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    return _ClientCard(client: c);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});
  final _ClientView client;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: DesignTokens.borderRadiusMd,
        onTap: () => _showClientDetail(context),
        child: Padding(
          padding: DesignTokens.paddingMd,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                child: Text(
                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: DesignTokens.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: DesignTokens.textBodyBold),
                    if (client.phone.isNotEmpty)
                      Text(
                        client.phone,
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (client.totalBookings > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DesignTokens.brandAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${client.totalBookings} booking${client.totalBookings == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.brandAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClientDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: DesignTokens.brandPrimary.withValues(alpha: 0.1),
                    child: Text(
                      client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        color: DesignTokens.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: DesignTokens.textHeadline),
                        if (client.phone.isNotEmpty)
                          Text(client.phone, style: DesignTokens.textBody),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (client.totalBookings > 0) ...[
                _StatRow(label: 'Total Bookings', value: client.totalBookings.toString()),
                _StatRow(
                  label: 'Total Spent',
                  value: 'UGX ${client.totalSpent.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 16),
              ],
              if (client.notes != null && client.notes!.isNotEmpty) ...[
                Text('Notes', style: DesignTokens.textSmallBold),
                const SizedBox(height: 4),
                Text(client.notes!, style: DesignTokens.textBody),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (client.phone.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {/* launch dialer */},
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DesignTokens.textBody.copyWith(color: DesignTokens.textSecondary)),
          Text(value, style: DesignTokens.textBodyBold),
        ],
      ),
    );
  }
}
