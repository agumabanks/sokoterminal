import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'payment_link_share.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/haptics.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

/// Payment Links Screen — Generate and manage payment links for products/services.
class PaymentLinksScreen extends ConsumerStatefulWidget {
  const PaymentLinksScreen({super.key});

  @override
  ConsumerState<PaymentLinksScreen> createState() => _PaymentLinksScreenState();
}

class _PaymentLinksScreenState extends ConsumerState<PaymentLinksScreen> {
  String? _loadError;
  bool _loading = true;
  List<Map<String, dynamic>> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(sellerApiProvider);
      final links = await api.fetchPaymentLinks();
      if (mounted) {
        setState(() {
          _links = links;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError =
              'Could not load payment links. Check your connection and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Payment Links', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLinks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chooseItem,
        icon: const Icon(Icons.add_link),
        label: const Text('Create link'),
      ),
      body: _loadError != null
          ? Center(
              child: TextButton(
                onPressed: _loadLinks,
                child: Text(_loadError!),
              ),
            )
          : _loading
          ? const LoadingState()
          : _links.isEmpty
          ? EmptyState(
              icon: Icons.link,
              title: 'No payment links yet',
              subtitle:
                  'Generate a payment link from any product or service to share with customers.',
              action: TextButton(
                onPressed: () => _showHelp(context),
                child: const Text('Learn more'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLinks,
              child: ListView.builder(
                padding: DesignTokens.paddingScreen,
                itemCount: _links.length,
                itemBuilder: (context, index) {
                  final link = _links[index];
                  return _PaymentLinkCard(
                    link: link,
                    onTap: () => _showLinkDetails(context, link),
                    onShare: () => _shareLink(link),
                    onCopy: () => _copyLink(link),
                    onDeactivate: () => _deactivateLink(link),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _chooseItem() async {
    final db = ref.read(appDatabaseProvider);
    final products = await db.getAllItems();
    final services = await db.getAllServices();
    final choices = <({String type, int id, String title, double price})>[
      for (final p in products)
        if (p.remoteId != null)
          (type: 'product', id: p.remoteId!, title: p.name, price: p.price),
      for (final s in services)
        if (s.remoteId != null)
          (type: 'service', id: s.remoteId!, title: s.title, price: s.price),
    ];
    if (!mounted) return;
    final selected = await Navigator.of(context).push<PaymentLinkChoice>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaymentLinkItemPicker(choices: choices),
      ),
    );
    if (selected == null || !mounted) return;
    await showGeneratePaymentLinkSheet(
      context,
      ref,
      type: selected.type,
      remoteId: selected.id,
      title: selected.title,
      defaultAmount: selected.price,
    );
    if (mounted) await _loadLinks();
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: DesignTokens.canvas,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: DesignTokens.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Links', style: DesignTokens.textHeadline),
            const SizedBox(height: DesignTokens.spaceMd),
            Text(
              'Create shareable payment links for your products or services. '
              'Send them via WhatsApp, SMS, or any messaging app. '
              'Customers pay securely via Mobile Money — the money goes directly to your wallet.',
              style: DesignTokens.textBody,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('How it works:', style: DesignTokens.textTitle),
            const SizedBox(height: DesignTokens.spaceSm),
            _howItWorksStep('1', 'Open a product and tap "Payment link"'),
            _howItWorksStep('2', 'Share the link with your customer'),
            _howItWorksStep('3', 'Customer pays via Mobile Money'),
            _howItWorksStep('4', 'Money lands in your Soko wallet'),
            const SizedBox(height: DesignTokens.spaceLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.brandAccent,
                  foregroundColor: DesignTokens.canvas,
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignTokens.borderRadiusFull,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Got it'),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: DesignTokens.brandAccentSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: DesignTokens.textSmall.copyWith(
                color: DesignTokens.brandAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: DesignTokens.textBody),
            ),
          ),
        ],
      ),
    );
  }

  void _shareLink(Map<String, dynamic> link) {
    unawaited(sharePaymentLink(context, link));
  }

  void _copyLink(Map<String, dynamic> link) {
    final url = link['url']?.toString() ?? '';
    Clipboard.setData(ClipboardData(text: url));
    Haptics.selection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Link copied to clipboard'),
          ],
        ),
        backgroundColor: DesignTokens.brandAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _deactivateLink(Map<String, dynamic> link) async {
    final id = link['id'];
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate link?'),
        content: const Text(
          'This payment link will stop working immediately. '
          'You can generate a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: DesignTokens.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final api = ref.read(sellerApiProvider);
      await api.deactivatePaymentLink(id as int);
      if (mounted) {
        Haptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment link deactivated'),
            backgroundColor: DesignTokens.brandAccent,
          ),
        );
        _loadLinks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showLinkDetails(BuildContext context, Map<String, dynamic> link) {
    final id = link['id'];
    if (id == null) return;
    context.go('/home/more/payment-links/$id');
  }
}

class _PaymentLinkCard extends StatelessWidget {
  const _PaymentLinkCard({
    required this.link,
    required this.onTap,
    required this.onShare,
    required this.onCopy,
    required this.onDeactivate,
  });

  final Map<String, dynamic> link;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final isActive = link['is_active'] == true;
    final status = link['status']?.toString() ?? 'active';
    final title = link['title']?.toString() ?? 'Payment';
    final amount = (link['amount'] as num?)?.toDouble() ?? 0;
    final paymentsCount = link['successful_payments_count'] as int? ?? 0;
    final totalCollected = (link['total_collected'] as num?)?.toDouble() ?? 0;
    final type = link['linkable_type']?.toString() ?? 'Product';

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DesignTokens.borderRadiusMd,
          child: Padding(
            padding: DesignTokens.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive
                            ? DesignTokens.brandAccentSubtle
                            : DesignTokens.canvasCloud,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        type == 'ServiceOffering'
                            ? Icons.room_service_outlined
                            : Icons.inventory_2_outlined,
                        color: isActive
                            ? DesignTokens.brandAccent
                            : DesignTokens.inkMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: DesignTokens.textTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? DesignTokens.brandAccentSubtle
                                      : DesignTokens.canvasCloud,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isActive ? 'Active' : status,
                                  style: DesignTokens.textCaption.copyWith(
                                    color: isActive
                                        ? DesignTokens.brandAccent
                                        : DesignTokens.inkMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(type, style: DesignTokens.textCaption),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(amount.toUgx(), style: DesignTokens.textMono),
                        if (paymentsCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$paymentsCount paid',
                            style: DesignTokens.textCaption.copyWith(
                              color: DesignTokens.brandAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (totalCollected > 0) ...[
                  const SizedBox(height: DesignTokens.spaceSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceSm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.brandAccentSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          size: 14,
                          color: DesignTokens.brandAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Collected: ${totalCollected.toUgx()}',
                          style: DesignTokens.textCaption.copyWith(
                            color: DesignTokens.brandAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: DesignTokens.spaceSm),
                Row(
                  children: [
                    _MiniActionButton(
                      icon: Icons.copy_outlined,
                      label: 'Copy',
                      onTap: onCopy,
                    ),
                    const SizedBox(width: DesignTokens.spaceXs),
                    _MiniActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: onShare,
                    ),
                    const SizedBox(width: DesignTokens.spaceXs),
                    _MiniActionButton(
                      icon: Icons.delete_outline,
                      label: 'Deactivate',
                      onTap: onDeactivate,
                      color: DesignTokens.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DesignTokens.inkMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spaceSm,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 4),
              Text(label, style: DesignTokens.textCaption.copyWith(color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Payment Link Details Screen — Shows payments received for a specific link.
class PaymentLinkDetailsScreen extends ConsumerStatefulWidget {
  const PaymentLinkDetailsScreen({super.key, required this.linkId});
  final int linkId;

  @override
  ConsumerState<PaymentLinkDetailsScreen> createState() =>
      _PaymentLinkDetailsScreenState();
}

class _PaymentLinkDetailsScreenState
    extends ConsumerState<PaymentLinkDetailsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(sellerApiProvider);
      final result = await api.getPaymentLinkPayments(widget.linkId);
      if (mounted) {
        setState(() {
          _payments = result?['payments'] ?? [];
          _summary = result?['summary'] ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(title: Text('Payments', style: DesignTokens.textTitle)),
      body: _loading
          ? const LoadingState()
          : Column(
              children: [
                // Summary card
                Container(
                  margin: DesignTokens.paddingScreen,
                  padding: DesignTokens.paddingMd,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandAccentSubtle,
                    borderRadius: DesignTokens.borderRadiusMd,
                    border: Border.all(
                      color: DesignTokens.brandAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Collected',
                              style: DesignTokens.textSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ((_summary['total_collected'] as num?)
                                          ?.toDouble() ??
                                      0)
                                  .toUgx(),
                              style: DesignTokens.textMonoDisplay.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.brandAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_summary['total_payments'] ?? 0} payments',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.canvas,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Payments list
                Expanded(
                  child: _payments.isEmpty
                      ? const EmptyState(
                          icon: Icons.payments_outlined,
                          title: 'No payments yet',
                          subtitle:
                              'When customers pay using your link, payments will appear here.',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPayments,
                          child: ListView.builder(
                            padding: DesignTokens.paddingHorizontalMd,
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];
                              return Container(
                                margin: const EdgeInsets.only(
                                  bottom: DesignTokens.spaceSm,
                                ),
                                padding: DesignTokens.paddingMd,
                                decoration: BoxDecoration(
                                  color: DesignTokens.canvas,
                                  borderRadius: DesignTokens.borderRadiusMd,
                                  border: Border.all(
                                    color: DesignTokens.hairline,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: DesignTokens.brandAccentSubtle,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: DesignTokens.brandAccent,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: DesignTokens.spaceSm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            payment['buyer_name']?.toString() ??
                                                'Customer',
                                            style: DesignTokens.textTitle,
                                          ),
                                          Text(
                                            payment['buyer_phone']
                                                    ?.toString() ??
                                                '',
                                            style: DesignTokens.textSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          ((payment['amount'] as num?)
                                                      ?.toDouble() ??
                                                  0)
                                              .toUgx(),
                                          style: DesignTokens.textMono,
                                        ),
                                        Text(
                                          payment['completed_at']
                                                  ?.toString()
                                                  .substring(0, 10) ??
                                              '',
                                          style: DesignTokens.textCaption,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Generate Payment Link Bottom Sheet — Quick generate from product/service.
Future<Map<String, dynamic>?> showGeneratePaymentLinkSheet(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required int remoteId,
  required String title,
  required double defaultAmount,
  List<Map<String, dynamic>>? checkoutLines,
  double taxAmount = 0,
}) async {
  final amountCtrl = TextEditingController(
    text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
  );
  final quantityCtrl = TextEditingController(text: '1');
  final feeCtrl = TextEditingController(text: '5');
  final idempotencyKey = const Uuid().v4();
  bool generating = false;
  bool submitted = false;
  String? error;
  Map<String, dynamic>? result;

  await BottomSheetModal.show(
    context: context,
    title: 'Payment Link',
    isDismissible: false,
    enableDrag: false,
    showCloseButton: false,
    subtitle: 'Share for "$title"',
    child: StatefulBuilder(
      builder: (sheetContext, setLocalState) {
        final quantity = int.tryParse(quantityCtrl.text) ?? 0;
        final parsedFee = double.tryParse(feeCtrl.text) ?? -1;
        final feePercent = parsedFee.isFinite ? parsedFee : -1.0;
        final unit = double.tryParse(amountCtrl.text) ?? 0;
        final subtotal = checkoutLines == null
            ? unit * quantity
            : defaultAmount;
        final fee =
            ((subtotal + taxAmount) * feePercent / 100 * 100).roundToDouble() /
            100;
        final total = subtotal + taxAmount + fee;
        return PopScope(
          canPop: !generating,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Share one link with your customer. Payment is confirmed by the payment provider.',
                  style: DesignTokens.textSmall,
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                TextField(
                  controller: amountCtrl,
                  enabled: checkoutLines == null && !submitted && !generating,
                  onChanged: (_) => setLocalState(() {}),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: checkoutLines == null
                        ? 'Unit price (UGX)'
                        : 'Cart subtotal (UGX)',
                    hintText: defaultAmount > 0
                        ? 'Default: ${defaultAmount.toUgx()}'
                        : 'Enter amount',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(
                      borderRadius: DesignTokens.borderRadiusSm,
                    ),
                  ),
                ),
                if (checkoutLines == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityCtrl,
                    enabled: !submitted && !generating,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: feeCtrl,
                  enabled: !submitted && !generating,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Mobile money charges (%)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Subtotal: ${subtotal.toUgx()}'),
                if (taxAmount > 0) Text('Tax: ${taxAmount.toUgx()}'),
                Text('Mobile money charges: ${fee.toUgx()}'),
                Text(
                  'Customer pays: ${total.toUgx()}',
                  style: DesignTokens.textTitle,
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                if (result != null) ...[
                  const SizedBox(height: DesignTokens.spaceMd),
                  Container(
                    padding: DesignTokens.paddingMd,
                    decoration: BoxDecoration(
                      color: DesignTokens.brandAccentSubtle,
                      borderRadius: DesignTokens.borderRadiusSm,
                      border: Border.all(
                        color: DesignTokens.brandAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: DesignTokens.brandAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Link generated!',
                              style: DesignTokens.textSmall.copyWith(
                                color: DesignTokens.brandAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Center(
                          child: QrImageView(
                            data: result!['url']?.toString() ?? '',
                            size: 200,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                        const Center(
                          child: Text('Scan to pay in your browser'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result!['url']?.toString() ?? '',
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.inkSubtle,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: result!['url']?.toString() ?? '',
                                  ),
                                );
                                Haptics.selection();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Link copied'),
                                    backgroundColor: DesignTokens.brandAccent,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                unawaited(
                                  sharePaymentLink(context, {
                                    ...result!,
                                    'title': result!['title'] ?? title,
                                  }),
                                );
                              },
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Share QR'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                TextButton(
                  onPressed: generating
                      ? null
                      : () => Navigator.pop(sheetContext),
                  child: Text(result == null ? 'Close' : 'Done'),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                ElevatedButton.icon(
                  onPressed: generating || result != null
                      ? null
                      : () async {
                          if (unit <= 0 ||
                              quantity < 1 ||
                              quantity > 10000 ||
                              !feePercent.isFinite ||
                              feePercent < 0 ||
                              feePercent > 100) {
                            setLocalState(
                              () => error =
                                  'Enter a positive price, quantity 1–10,000 and fee 0–100%.',
                            );
                            return;
                          }
                          setLocalState(() {
                            generating = true;
                            submitted = true;
                            error = null;
                          });
                          try {
                            final api = ref.read(sellerApiProvider);
                            final amount = double.tryParse(
                              amountCtrl.text.trim(),
                            );
                            final link = checkoutLines != null
                                ? await api.generateCheckoutPaymentLink(
                                    lines: checkoutLines,
                                    taxAmount: taxAmount,
                                    serviceFeePercent: feePercent,
                                    idempotencyKey: idempotencyKey,
                                  )
                                : await api.generatePaymentLink(
                                    type: type,
                                    remoteId: remoteId,
                                    amount: amount,
                                    quantity: quantity,
                                    serviceFeePercent: feePercent,
                                  );
                            if (!sheetContext.mounted) return;
                            if (link != null) {
                              setLocalState(() {
                                result = link;
                                generating = false;
                              });
                              Haptics.success();
                            } else {
                              setLocalState(() => generating = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to generate link'),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (!sheetContext.mounted) return;
                            setLocalState(() => generating = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  icon: generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    result != null
                        ? 'Link ready — copy or share above'
                        : generating
                        ? 'Generating...'
                        : 'Generate Link',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                    foregroundColor: DesignTokens.canvas,
                    shape: RoundedRectangleBorder(
                      borderRadius: DesignTokens.borderRadiusFull,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMd),
              ],
            ),
          ),
        );
      },
    ),
  ); // Controllers remain alive until the closing sheet animation completes.
  Future.delayed(const Duration(seconds: 1), () {
    amountCtrl.dispose();
    quantityCtrl.dispose();
    feeCtrl.dispose();
  });
  return result;
}

typedef PaymentLinkChoice = ({String type, int id, String title, double price});

class PaymentLinkItemPicker extends StatefulWidget {
  const PaymentLinkItemPicker({super.key, required this.choices});
  final List<PaymentLinkChoice> choices;
  @override
  State<PaymentLinkItemPicker> createState() => _PaymentLinkItemPickerState();
}

class _PaymentLinkItemPickerState extends State<PaymentLinkItemPicker> {
  String _query = '';
  String _type = 'all';
  @override
  Widget build(BuildContext context) {
    final visible = widget.choices
        .where(
          (c) =>
              (_type == 'all' || c.type == _type) &&
              c.title.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(title: const Text('Choose an item')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search products and services',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final type in [
                    ('all', 'All'),
                    ('product', 'Products'),
                    ('service', 'Services'),
                  ])
                    ChoiceChip(
                      label: Text(type.$2),
                      selected: _type == type.$1,
                      onSelected: (_) => setState(() => _type = type.$1),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${visible.length} items • Tap one to set quantity and charges',
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching synced items. Try another search, or sync your catalog from Me.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = visible[i];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Icon(
                              item.type == 'product'
                                  ? Icons.inventory_2_outlined
                                  : Icons.room_service_outlined,
                              color: DesignTokens.brandPrimary,
                            ),
                            title: Text(
                              item.title,
                              style: DesignTokens.textBodyBold,
                            ),
                            subtitle: Text(
                              '${item.type == 'product' ? 'Product' : 'Service'} • ${item.price.toUgx()}',
                              style: DesignTokens.textSmall,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: DesignTokens.ink,
                            ),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(context, item);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
