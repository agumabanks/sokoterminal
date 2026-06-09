import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../wallet/seller_wallet_payment_screen.dart';

class SellerWalletScreen extends ConsumerStatefulWidget {
  const SellerWalletScreen({super.key});

  @override
  ConsumerState<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends ConsumerState<SellerWalletScreen> {
  static const _uuid = Uuid();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  _WalletDashboard? _wallet;
  int _smsCreditBalance = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        ref.read(sellerApiProvider).fetchSellerWalletDashboard(),
        ref.read(sellerApiProvider).fetchSmsDashboard(),
      ]);

      final walletBody = responses[0].data is Map<String, dynamic>
          ? Map<String, dynamic>.from(responses[0].data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final walletData = walletBody['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              walletBody['data'] as Map<String, dynamic>,
            )
          : walletBody;

      final smsBody = responses[1].data is Map<String, dynamic>
          ? Map<String, dynamic>.from(responses[1].data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final smsData = smsBody['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(smsBody['data'] as Map<String, dynamic>)
          : smsBody;
      final credits = smsData['credits'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              smsData['credits'] as Map<String, dynamic>,
            )
          : const <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _wallet = _WalletDashboard.fromJson(walletData);
        _smsCreditBalance = _asInt(credits['balance']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startTopup() async {
    final amount = await _promptForInteger(
      title: 'Add money to Sanaa Wallet',
      hint: 'Enter amount in UGX',
      initialValue: '10000',
      minValue: 1000,
    );
    if (amount == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final response = await ref
          .read(sellerApiProvider)
          .createSellerWalletTopup(
            amount.toDouble(),
            idempotencyKey: 'wallet-topup-${_uuid.v4()}',
          );
      final body = response.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final topup = data['topup'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['topup'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final topupId = _asInt(topup['id']);
      final redirectUrl = topup['redirect_url']?.toString() ?? '';

      if (topupId <= 0 || redirectUrl.trim().isEmpty) {
        throw Exception('Payment session is missing redirect details.');
      }

      if (!mounted) return;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SellerWalletPaymentScreen(
            topupId: topupId,
            initialUrl: redirectUrl,
            amountLabel: 'UGX ${_formatMoney(amount.toDouble())}',
          ),
        ),
      );

      if (!mounted) return;
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sanaa Wallet updated successfully')),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start top-up: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _buySmsCredits() async {
    final wallet = _wallet;
    if (wallet == null) return;

    final quantity = await _promptForInteger(
      title: 'Buy SMS credits',
      hint: 'Number of credits',
      initialValue: '100',
      minValue: 100,
    );
    if (quantity == null || !mounted) return;

    final unitPrice = wallet.smsCatalog?.unitPrice ?? 30;
    final total = quantity * unitPrice;
    if (wallet.balance < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sanaa Wallet balance is too low. Need UGX ${_formatMoney(total)}, have UGX ${_formatMoney(wallet.balance)}.',
          ),
          action: SnackBarAction(label: 'Top up', onPressed: _startTopup),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await ref
          .read(sellerApiProvider)
          .createSellerWalletPurchase(
            type: 'sms_credits',
            quantity: quantity,
            idempotencyKey: 'wallet-purchase-${_uuid.v4()}',
          );
      final body = response.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};

      if (!mounted) return;
      final smsCredits = _asInt(data['sms_credit_balance']);
      final walletBalance = _asDouble(data['wallet_balance']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bought $quantity SMS credits. Sanaa Wallet: UGX ${_formatMoney(walletBalance)}, SMS credits: $smsCredits.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _buySubscription(_WalletProduct product) async {
    if (product.planId == null || product.planId! <= 0) return;
    final wallet = _wallet;
    if (wallet == null) return;
    final amount = product.unitPrice;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This plan is free or trial-backed. Choose it during signup or through the seller setup flow.',
          ),
        ),
      );
      return;
    }
    if (wallet.balance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sanaa Wallet balance is too low. Need UGX ${_formatMoney(amount)}, have UGX ${_formatMoney(wallet.balance)}.',
          ),
          action: SnackBarAction(label: 'Top up', onPressed: _startTopup),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Activate ${product.label}?'),
        content: Text(
          'This will charge UGX ${_formatMoney(amount)} from Sanaa Wallet for one month of ${product.label}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final response = await ref
          .read(sellerApiProvider)
          .createSellerWalletPurchase(
            type: 'seller_subscription',
            extra: {'plan_id': product.planId},
            idempotencyKey: 'wallet-subscription-${_uuid.v4()}',
          );
      final body = response.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};
      final walletBalance = _asDouble(data['wallet_balance']);
      final subscription = data['subscription'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              data['subscription'] as Map<String, dynamic>,
            )
          : const <String, dynamic>{};
      final plan = subscription['plan'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              subscription['plan'] as Map<String, dynamic>,
            )
          : const <String, dynamic>{};
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${plan['name'] ?? product.label} is active. Sanaa Wallet balance: UGX ${_formatMoney(walletBalance)}.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription purchase failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<int?> _promptForInteger({
    required String title,
    required String hint,
    required String initialValue,
    required int minValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? errorText;

    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value == null || value < minValue) {
                      setModalState(() {
                        errorText = 'Minimum is $minValue.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Sanaa Wallet'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _startTopup,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_card_outlined),
        label: const Text('Add money'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            if (_loading && wallet == null)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_error ?? '').isNotEmpty)
              _WalletSectionCard(
                title: 'Sanaa Wallet unavailable',
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                child: Text(_error!, style: DesignTokens.textSmall),
              )
            else if (wallet != null) ...[
              _WalletHero(
                wallet: wallet,
                smsCreditBalance: _smsCreditBalance,
                onTopUp: _startTopup,
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              if (wallet.subscription != null) ...[
                _WalletSectionCard(
                  title: 'Current subscription',
                  child: _InfoStrip(
                    icon: Icons.workspace_premium_outlined,
                    text:
                        '${wallet.subscription!.planName} • ${wallet.subscription!.statusLabel} • ${wallet.subscription!.expiresLabel}',
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
              ],
              _WalletSectionCard(
                title: 'Spend from Sanaa Wallet',
                trailing: Flexible(
                  child: Text(
                    'Offline POS keeps working. Top-up requires internet.',
                    style: DesignTokens.textSmall,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                child: Column(
                  children: [
                    _PurchaseTile(
                      title: 'SMS credits',
                      subtitle:
                          'UGX ${_formatMoney(wallet.smsCatalog?.unitPrice ?? 30)} per credit. Current balance: $_smsCreditBalance.',
                      trailingLabel: 'Buy now',
                      onPressed: _busy ? null : _buySmsCredits,
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    _InfoStrip(
                      icon: Icons.auto_awesome_outlined,
                      text:
                          'Sanaa Wallet is the shared spend account for seller add-ons. SMS credits are live now, and subscription payments can plug into the same balance without a second payment flow.',
                    ),
                    if (wallet.subscriptionPlans.isNotEmpty) ...[
                      const SizedBox(height: DesignTokens.spaceSm),
                      ...wallet.subscriptionPlans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: DesignTokens.spaceSm,
                          ),
                          child: _PurchaseTile(
                            title: plan.label,
                            subtitle:
                                '${plan.description ?? 'Seller subscription plan'} ${plan.trialDays > 0 ? '• ${plan.trialDays}-day trial for new sellers' : ''}',
                            trailingLabel: plan.unitPrice <= 0
                                ? 'Included'
                                : 'Activate',
                            onPressed: _busy || plan.unitPrice <= 0
                                ? null
                                : () => _buySubscription(plan),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (wallet.pendingTopups.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceLg),
                _WalletSectionCard(
                  title: 'Pending top-ups',
                  child: Column(
                    children: wallet.pendingTopups
                        .map(
                          (topup) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.hourglass_top_outlined),
                            title: Text('UGX ${_formatMoney(topup.amount)}'),
                            subtitle: Text(
                              topup.statusMessage ?? topup.status.toUpperCase(),
                            ),
                            trailing: Text(
                              _compactTime(topup.createdAt),
                              style: DesignTokens.textSmall,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spaceLg),
              _WalletSectionCard(
                title: 'Sanaa Wallet history',
                child: wallet.history.isEmpty
                    ? Text(
                        'No Sanaa Wallet activity yet.',
                        style: DesignTokens.textSmall,
                      )
                    : Column(
                        children: wallet.history
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: item.amount >= 0
                                      ? DesignTokens.success.withValues(
                                          alpha: 0.12,
                                        )
                                      : DesignTokens.error.withValues(
                                          alpha: 0.12,
                                        ),
                                  child: Icon(
                                    item.amount >= 0
                                        ? Icons.arrow_downward_outlined
                                        : Icons.arrow_upward_outlined,
                                    color: item.amount >= 0
                                        ? DesignTokens.success
                                        : DesignTokens.error,
                                  ),
                                ),
                                title: Text(_reasonLabel(item.reason)),
                                subtitle: Text(_compactTime(item.createdAt)),
                                trailing: Text(
                                  '${item.amount >= 0 ? '+' : '-'}UGX ${_formatMoney(item.amount.abs())}',
                                  style: DesignTokens.textBody.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 96),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({
    required this.wallet,
    required this.smsCreditBalance,
    required this.onTopUp,
  });

  final _WalletDashboard wallet;
  final int smsCreditBalance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        borderRadius: DesignTokens.borderRadiusLg,
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3D62), Color(0xFF177E89)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance',
            style: DesignTokens.textSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            'UGX ${_formatMoney(wallet.balance)}',
            style: DesignTokens.textTitle.copyWith(
              color: Colors.white,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Use one Sanaa Wallet for terminal purchases. The backend stays authoritative, and the terminal only spends after the wallet confirms.',
            style: DesignTokens.textSmall.copyWith(color: Colors.white),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: onTopUp,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0A3D62),
                    ),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Add money'),
                  ),
                  if (!isNarrow) const SizedBox(height: DesignTokens.spaceSm),
                  if (isNarrow)
                    const SizedBox(height: DesignTokens.spaceXs)
                  else
                    Chip(
                      avatar: const Icon(Icons.sms_outlined, size: 18, color: Colors.white),
                      label: Text('SMS credits: $smsCreditBalance'),
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      labelStyle: DesignTokens.textSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WalletSectionCard extends StatelessWidget {
  const _WalletSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: DesignTokens.textBody.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          child,
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: DesignTokens.borderRadiusMd,
        color: DesignTokens.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: DesignTokens.textSmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onPressed,
              child: Text(trailingLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: DesignTokens.brandAccent.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DesignTokens.brandAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: DesignTokens.textSmall)),
        ],
      ),
    );
  }
}

class _WalletDashboard {
  const _WalletDashboard({
    required this.balance,
    required this.currency,
    required this.history,
    required this.pendingTopups,
    required this.catalog,
    required this.subscription,
  });

  factory _WalletDashboard.fromJson(Map<String, dynamic> json) {
    final history = json['history'] is List
        ? (json['history'] as List)
              .whereType<Map>()
              .map(
                (e) =>
                    _WalletHistoryItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : const <_WalletHistoryItem>[];
    final pending = json['pending_topups'] is List
        ? (json['pending_topups'] as List)
              .whereType<Map>()
              .map((e) => _WalletTopup.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const <_WalletTopup>[];
    final catalog = json['purchase_catalog'] is List
        ? (json['purchase_catalog'] as List)
              .whereType<Map>()
              .map((e) => _WalletProduct.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const <_WalletProduct>[];

    return _WalletDashboard(
      balance: _asDouble(json['balance']),
      currency: json['currency']?.toString() ?? 'UGX',
      history: history,
      pendingTopups: pending,
      catalog: catalog,
      subscription: json['subscription'] is Map<String, dynamic>
          ? _WalletSubscription.fromJson(
              Map<String, dynamic>.from(
                json['subscription'] as Map<String, dynamic>,
              ),
            )
          : null,
    );
  }

  final double balance;
  final String currency;
  final List<_WalletHistoryItem> history;
  final List<_WalletTopup> pendingTopups;
  final List<_WalletProduct> catalog;
  final _WalletSubscription? subscription;

  _WalletProduct? get smsCatalog {
    for (final item in catalog) {
      if (item.type == 'sms_credits') return item;
    }
    return null;
  }

  List<_WalletProduct> get subscriptionPlans {
    return catalog.where((item) => item.type == 'seller_subscription').toList();
  }
}

class _WalletHistoryItem {
  const _WalletHistoryItem({
    required this.id,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory _WalletHistoryItem.fromJson(Map<String, dynamic> json) {
    return _WalletHistoryItem(
      id: _asInt(json['id']),
      amount: _asDouble(json['amount']),
      reason: json['reason']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  final int id;
  final double amount;
  final String reason;
  final String? createdAt;
}

class _WalletTopup {
  const _WalletTopup({
    required this.id,
    required this.amount,
    required this.status,
    required this.statusMessage,
    required this.createdAt,
  });

  factory _WalletTopup.fromJson(Map<String, dynamic> json) {
    return _WalletTopup(
      id: _asInt(json['id']),
      amount: _asDouble(json['amount']),
      status: json['status']?.toString() ?? '',
      statusMessage: json['status_message']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  final int id;
  final double amount;
  final String status;
  final String? statusMessage;
  final String? createdAt;
}

class _WalletProduct {
  const _WalletProduct({
    required this.type,
    required this.label,
    required this.unitPrice,
    this.planId,
    this.planSlug,
    this.description,
    this.trialDays = 0,
  });

  factory _WalletProduct.fromJson(Map<String, dynamic> json) {
    return _WalletProduct(
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      unitPrice: _asDouble(json['unit_price']),
      planId: _asNullableInt(json['plan_id']),
      planSlug: json['plan_slug']?.toString(),
      description: json['description']?.toString(),
      trialDays: _asInt(json['trial_days']),
    );
  }

  final String type;
  final String label;
  final double unitPrice;
  final int? planId;
  final String? planSlug;
  final String? description;
  final int trialDays;
}

class _WalletSubscription {
  const _WalletSubscription({
    required this.planName,
    required this.status,
    required this.expiresAt,
  });

  factory _WalletSubscription.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['plan'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    return _WalletSubscription(
      planName: (plan['name'] ?? 'Plan').toString(),
      status: (json['status'] ?? '').toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }

  final String planName;
  final String status;
  final String? expiresAt;

  String get statusLabel {
    if (status.trim().isEmpty) return 'Status unknown';
    return status.replaceAll('_', ' ');
  }

  String get expiresLabel {
    if (expiresAt == null || expiresAt!.trim().isEmpty) {
      return 'No renewal date';
    }
    final parsed = DateTime.tryParse(expiresAt!);
    if (parsed == null) return expiresAt!;
    return 'Renews ${parsed.day}/${parsed.month}/${parsed.year}';
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _asInt(value);
  return parsed == 0 && value.toString().trim() != '0' ? null : parsed;
}

String _formatMoney(double value) {
  final rounded = value.round();
  final digits = rounded.toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString().split('').reversed.join();
}

String _compactTime(String? value) {
  if (value == null || value.trim().isEmpty) return 'Just now';
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final hour = parsed.hour == 0
      ? 12
      : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${parsed.day}/${parsed.month}/${parsed.year} $hour:$minute $suffix';
}

String _reasonLabel(String reason) {
  switch (reason) {
    case 'seller_wallet_topup':
    case 'sanaa_wallet_topup':
      return 'Pesapal top-up';
    case 'sms_credit_purchase':
      return 'SMS credit purchase';
    case 'seller_purchase_refund':
      return 'Seller purchase refund';
    default:
      if (reason.trim().isEmpty) return 'Sanaa Wallet activity';
      return reason.replaceAll('_', ' ');
  }
}
