import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/error_page.dart';
import 'quotation_creator.dart';

final quotationsStreamProvider = StreamProvider<List<QuotationWithCustomer>>((ref) {
  return ref.watch(appDatabaseProvider).watchQuotationsWithCustomer();
});

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshRemote(silent: true));
  }

  Future<void> _refreshRemote({bool silent = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
    });

    try {
      final api = ref.read(sellerApiProvider);
      final db = ref.read(appDatabaseProvider);
      var page = 1;
      var fetchedAny = false;
      while (page <= 10) {
        final res = await api.fetchQuotations(page: page);
        final body = res.data;
        final root = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
        final data = root['data'];

        final paginator = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        final rawList = paginator['data'];
        final list = rawList is List ? rawList : const <dynamic>[];
        if (list.isEmpty) break;
        fetchedAny = true;

        for (final raw in list) {
          if (raw is! Map) continue;
          final q = Map<String, dynamic>.from(raw);
          final id = (q['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;

          final quotationNumber = (q['quotation_number'] ?? '').toString().trim();
          final total = (q['total'] as num?)?.toDouble() ?? 0;
          final validityDays = (q['validity_days'] as num?)?.toInt() ?? 30;
          final createdAt =
              DateTime.tryParse((q['created_at'] ?? '').toString())?.toUtc() ??
                  DateTime.now().toUtc();
          final validUntil = createdAt.add(Duration(days: validityDays));

          final remoteCustomerId = (q['customer_id'] ?? '').toString().trim();
          String? localCustomerId;
          if (remoteCustomerId.isNotEmpty) {
            final customer = await db.getCustomerByRemoteId(remoteCustomerId);
            localCustomerId = customer?.id;
          }

          final notes = (q['notes'] ?? '').toString();
          final rawLines = q['lines'];
          final lineList = rawLines is List ? rawLines : const <dynamic>[];

          final lineCompanions = <QuotationLinesCompanion>[];
          for (final rawLine in lineList) {
            if (rawLine is! Map) continue;
            final line = Map<String, dynamic>.from(rawLine);
            final title = (line['title'] ?? '').toString();
            final qty = (line['quantity'] as num?)?.toInt() ?? 1;
            final price = (line['price'] as num?)?.toDouble() ?? 0;
            final lineTotal = (line['total'] as num?)?.toDouble() ?? (price * qty);
            lineCompanions.add(
              QuotationLinesCompanion.insert(
                quotationId: id,
                description: title.isEmpty ? 'Item' : title,
                quantity: qty <= 0 ? 1 : qty,
                unitPrice: price,
                total: lineTotal,
              ),
            );
          }

          await db.upsertQuotationWithLines(
            quotationId: id,
            header: QuotationsCompanion.insert(
              id: Value(id),
              customerId: Value(localCustomerId),
              number: quotationNumber.isEmpty ? id : quotationNumber,
              date: Value(createdAt),
              validUntil: Value(validUntil),
              totalAmount: total,
              status: const Value('draft'),
              notes: notes.trim().isEmpty ? const Value.absent() : Value(notes),
              synced: const Value(true),
            ),
            lines: lineCompanions,
          );
        }

        final hasMore = (paginator['next_page_url'] ?? '').toString().trim().isNotEmpty;
        if (!hasMore) break;
        page++;
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fetchedAny ? 'Quotations updated' : 'No quotations found'),
            backgroundColor: DesignTokens.brandAccent,
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotations = ref.watch(quotationsStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshRemote(),
            ),
          IconButton(
            tooltip: 'Create quotation',
            icon: const Icon(Icons.add),
            onPressed: () => _createQuotation(context),
          ),
        ],
      ),
      body: quotations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPage(
          title: 'Failed to load quotations',
          message: e.toString(),
          onRetry: () => _refreshRemote(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: DesignTokens.paddingScreen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 64, color: DesignTokens.grayMedium),
                    const SizedBox(height: DesignTokens.spaceMd),
                    Text('No quotations yet', style: DesignTokens.textBody),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Text(
                      'Create a quotation to send to your customers',
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Quotation'),
                      onPressed: () => _createQuotation(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshRemote,
            child: ListView.builder(
              padding: DesignTokens.paddingScreen,
              itemCount: list.length,
              itemBuilder: (context, index) => _QuotationCard(row: list[index]),
            ),
          );
        },
      ),
    );
  }

  void _createQuotation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuotationCreator()),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  const _QuotationCard({required this.row});

  final QuotationWithCustomer row;

  @override
  Widget build(BuildContext context) {
    final quotation = row.quotation;
    final customer = row.customer;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final createdAt = quotation.date.toLocal();
    final isExpired = quotation.validUntil != null && DateTime.now().isAfter(quotation.validUntil!.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${quotation.number}',
                    style: DesignTokens.textBodyBold,
                  ),
                  Row(
                    children: [
                      _SyncBadge(synced: quotation.synced),
                      const SizedBox(width: 8),
                      _StatusBadge(isExpired: isExpired),
                    ],
                  ),
                ],
              ),
              if (customer != null) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: DesignTokens.grayMedium),
                    const SizedBox(width: 4),
                    Text(
                      customer.name,
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: DesignTokens.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    quotation.totalAmount.toUgx(),
                    style: DesignTokens.textTitle.copyWith(color: DesignTokens.brandPrimary),
                  ),
                  Text(
                    dateFormat.format(createdAt),
                    style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
                  ),
                ],
              ),
              if (quotation.notes != null && quotation.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceSm),
                Text(
                  quotation.notes!.trim(),
                  style: DesignTokens.textSmall.copyWith(
                    fontStyle: FontStyle.italic,
                    color: DesignTokens.grayMedium,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isExpired});

  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? DesignTokens.error.withValues(alpha: 0.1)
            : DesignTokens.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        isExpired ? 'EXPIRED' : 'VALID',
        style: DesignTokens.textSmall.copyWith(
          color: isExpired ? DesignTokens.error : DesignTokens.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: synced
            ? DesignTokens.brandAccent.withValues(alpha: 0.1)
            : DesignTokens.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        synced ? 'SYNCED' : 'PENDING',
        style: DesignTokens.textSmall.copyWith(
          color: synced ? DesignTokens.brandAccent : DesignTokens.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
