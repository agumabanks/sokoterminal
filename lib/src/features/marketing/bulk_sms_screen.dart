import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(appDatabaseProvider).watchCustomers();
});

class BulkSmsScreen extends ConsumerStatefulWidget {
  const BulkSmsScreen({super.key});

  @override
  ConsumerState<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends ConsumerState<BulkSmsScreen> {
  final _campaignTitleController = TextEditingController();
  final _campaignMessageController = TextEditingController();
  final _singleNameController = TextEditingController();
  final _singlePhoneController = TextEditingController();
  final _singleMessageController = TextEditingController();

  bool _confirmConsent = false;
  bool _sendingCampaign = false;
  bool _sendingSingle = false;
  bool _savingTemplate = false;
  bool _loading = true;
  String? _error;
  _SmsDashboardData? _dashboard;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDashboard());
  }

  @override
  void dispose() {
    _campaignTitleController.dispose();
    _campaignMessageController.dispose();
    _singleNameController.dispose();
    _singlePhoneController.dispose();
    _singleMessageController.dispose();
    super.dispose();
  }

  int _segmentCount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    if (trimmed.length <= 160) return 1;
    return (trimmed.length / 153).ceil();
  }

  Future<void> _loadDashboard({bool syncContacts = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (syncContacts) {
        await ref.read(syncServiceProvider).syncNow();
      }
      final res = await ref.read(sellerApiProvider).fetchSmsDashboard();
      final body = res.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(res.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
          : body;
      if (!mounted) return;
      setState(() {
        _dashboard = _SmsDashboardData.fromJson(data);
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

  Future<void> _openPurchaseUrl() async {
    if (!mounted) return;
    context.go('/home/more/wallet');
  }

  Future<void> _saveCurrentAsTemplate() async {
    final message = _campaignMessageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a campaign message first')),
      );
      return;
    }
    final title = _campaignTitleController.text.trim().isEmpty
        ? 'Terminal template'
        : _campaignTitleController.text.trim();

    setState(() => _savingTemplate = true);
    try {
      await ref.read(sellerApiProvider).createSmsTemplate({
        'name': title,
        'message': message,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Template saved')));
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save template: $e')));
    } finally {
      if (mounted) {
        setState(() => _savingTemplate = false);
      }
    }
  }

  Future<void> _sendCampaign(List<Customer> customers) async {
    final message = _campaignMessageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message is required')));
      return;
    }
    if (!_confirmConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm customer consent before sending'),
        ),
      );
      return;
    }

    final contacts = customers
        .where((c) => (c.phone ?? '').trim().isNotEmpty)
        .map(
          (c) => {
            'name': c.name,
            'phone': (c.phone ?? '').trim(),
            if ((c.remoteId ?? '').trim().isNotEmpty)
              'crm_contact_id': c.remoteId!.trim(),
          },
        )
        .toList();

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No synced customers with phone numbers')),
      );
      return;
    }

    final neededCredits = contacts.length * _segmentCount(message);
    if ((_dashboard?.credits.balance ?? 0) < neededCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough credits. Need $neededCredits, have ${_dashboard?.credits.balance ?? 0}.',
          ),
          action: SnackBarAction(label: 'Buy', onPressed: _openPurchaseUrl),
        ),
      );
      return;
    }

    final approved = await requireManagerPin(
      context,
      ref,
      reason: 'send bulk SMS campaign',
    );
    if (!approved) return;

    setState(() => _sendingCampaign = true);
    try {
      final res = await ref.read(sellerApiProvider).createSmsCampaign({
        'name': _campaignTitleController.text.trim().isEmpty
            ? 'Terminal SMS Campaign'
            : _campaignTitleController.text.trim(),
        'message': message,
        'contacts': contacts,
        'send_now': true,
      });

      final payload = res.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(res.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final dispatch = payload['data'] is Map<String, dynamic>
          ? (payload['data'] as Map<String, dynamic>)['dispatch']
          : null;
      final remainingCredits = dispatch is Map<String, dynamic>
          ? _asInt(dispatch['remaining_credits'])
          : _dashboard?.credits.balance ?? 0;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Campaign queued for ${contacts.length} recipients. Remaining credits: $remainingCredits.',
          ),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      _campaignTitleController.clear();
      _campaignMessageController.clear();
      setState(() => _confirmConsent = false);
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send campaign: $e')));
    } finally {
      if (mounted) {
        setState(() => _sendingCampaign = false);
      }
    }
  }

  Future<void> _sendSingleSms() async {
    final phone = _singlePhoneController.text.trim();
    final message = _singleMessageController.text.trim();
    if (phone.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone and message are required')),
      );
      return;
    }

    final neededCredits = _segmentCount(message).clamp(1, 9999);
    if ((_dashboard?.credits.balance ?? 0) < neededCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough credits. Need $neededCredits, have ${_dashboard?.credits.balance ?? 0}.',
          ),
          action: SnackBarAction(label: 'Buy', onPressed: _openPurchaseUrl),
        ),
      );
      return;
    }

    final approved = await requireManagerPin(
      context,
      ref,
      reason: 'send individual SMS',
    );
    if (!approved) return;

    setState(() => _sendingSingle = true);
    try {
      final res = await ref.read(sellerApiProvider).sendSingleSms({
        'phone': phone,
        'message': message,
        if (_singleNameController.text.trim().isNotEmpty)
          'customer_name': _singleNameController.text.trim(),
        'context': 'single_sms',
      });
      final payload = res.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(res.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final data = payload['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload['data'] as Map<String, dynamic>)
          : const <String, dynamic>{};

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SMS sent. Remaining credits: ${data['remaining_credits'] ?? _dashboard?.credits.balance ?? 0}.',
          ),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      _singleMessageController.clear();
      _singlePhoneController.clear();
      _singleNameController.clear();
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send SMS: $e')));
    } finally {
      if (mounted) {
        setState(() => _sendingSingle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final recipients = customersAsync.maybeWhen(
      data: (rows) =>
          rows.where((c) => (c.phone ?? '').trim().isNotEmpty).toList(),
      orElse: () => const <Customer>[],
    );
    final campaignSegments = _segmentCount(_campaignMessageController.text);
    final campaignCreditsNeeded = recipients.length * campaignSegments;
    final singleSegments = _segmentCount(
      _singleMessageController.text,
    ).clamp(0, 9999);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Seller SMS'),
        actions: [
          IconButton(
            tooltip: 'Sanaa Wallet',
            icon: const Icon(Icons.add_card_outlined),
            onPressed: _openPurchaseUrl,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.sync),
            onPressed: () => _loadDashboard(syncContacts: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            if (_loading && _dashboard == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_error ?? '').isNotEmpty)
              _SectionCard(
                title: 'Unable to load SMS module',
                trailing: IconButton(
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh),
                ),
                child: Text(_error!, style: DesignTokens.textSmall),
              )
            else ...[
              _CreditsHero(
                dashboard: _dashboard,
                onBuyCredits: _openPurchaseUrl,
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              Wrap(
                spacing: DesignTokens.spaceSm,
                runSpacing: DesignTokens.spaceSm,
                children: [
                  _StatCard(
                    title: 'Campaigns',
                    value: (_dashboard?.stats.totalCampaigns ?? 0).toString(),
                    subtitle: 'All time',
                    icon: Icons.campaign_outlined,
                  ),
                  _StatCard(
                    title: 'SMS Sent',
                    value: (_dashboard?.stats.totalSmsSent ?? 0).toString(),
                    subtitle: 'Delivered attempts',
                    icon: Icons.sms_outlined,
                  ),
                  _StatCard(
                    title: 'Spent',
                    value:
                        'UGX ${(_dashboard?.stats.totalSpent ?? 0).toStringAsFixed(0)}',
                    subtitle: 'Campaign costs',
                    icon: Icons.payments_outlined,
                  ),
                  _StatCard(
                    title: 'Queued',
                    value: (_dashboard?.stats.queuedCampaigns ?? 0).toString(),
                    subtitle: 'Pending delivery',
                    icon: Icons.schedule_send_outlined,
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              _SectionCard(
                title: 'Bulk campaign',
                trailing: customersAsync.maybeWhen(
                  data: (_) => Text(
                    '${recipients.length} recipients',
                    style: DesignTokens.textSmallBold,
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _campaignTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Campaign name',
                        hintText: 'Weekend promo',
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    TextField(
                      controller: _campaignMessageController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Write the SMS your customers will receive',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if ((_dashboard?.templates ?? const <_SmsTemplateData>[])
                        .isNotEmpty) ...[
                      const SizedBox(height: DesignTokens.spaceSm),
                      Text('Templates', style: DesignTokens.textSmallBold),
                      const SizedBox(height: DesignTokens.spaceXs),
                      Wrap(
                        spacing: DesignTokens.spaceXs,
                        runSpacing: DesignTokens.spaceXs,
                        children: _dashboard!.templates
                            .map(
                              (template) => ActionChip(
                                label: Text(template.name),
                                onPressed: () {
                                  _campaignMessageController.text =
                                      template.message;
                                  if (_campaignTitleController.text
                                      .trim()
                                      .isEmpty) {
                                    _campaignTitleController.text =
                                        template.name;
                                  }
                                  setState(() {});
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: DesignTokens.spaceSm),
                    _InfoRow(
                      label: 'Estimated cost',
                      value:
                          '$campaignSegments segment(s) x ${recipients.length} contacts = $campaignCreditsNeeded credits',
                    ),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Row(
                      children: [
                        Checkbox(
                          value: _confirmConsent,
                          onChanged: (value) =>
                              setState(() => _confirmConsent = value ?? false),
                        ),
                        Expanded(
                          child: Text(
                            'I confirm these customers have consented to receive marketing SMS.',
                            style: DesignTokens.textSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _savingTemplate
                                ? null
                                : _saveCurrentAsTemplate,
                            icon: _savingTemplate
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Save template'),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spaceSm),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sendingCampaign
                                ? null
                                : () => _sendCampaign(recipients),
                            icon: _sendingCampaign
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(
                              _sendingCampaign
                                  ? 'Sending...'
                                  : 'Queue campaign',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.brandAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              _SectionCard(
                title: 'Individual SMS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _singleNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer name (optional)',
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    TextField(
                      controller: _singlePhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: '0756549963 or 256756549963',
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    TextField(
                      controller: _singleMessageController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Message for one customer',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    _InfoRow(
                      label: 'Estimated credits',
                      value: singleSegments <= 0
                          ? '0'
                          : singleSegments.toString(),
                    ),
                    const SizedBox(height: DesignTokens.spaceSm),
                    ElevatedButton.icon(
                      onPressed: _sendingSingle ? null : _sendSingleSms,
                      icon: _sendingSingle
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sms_outlined),
                      label: Text(_sendingSingle ? 'Sending...' : 'Send SMS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              _SectionCard(
                title: 'Recent campaigns',
                child:
                    (_dashboard?.campaigns ?? const <_SmsCampaignData>[])
                        .isEmpty
                    ? Text('No campaigns yet.', style: DesignTokens.textSmall)
                    : Column(
                        children: _dashboard!.campaigns
                            .map(
                              (campaign) => _CampaignTile(campaign: campaign),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              _SectionCard(
                title: 'Credit activity',
                child:
                    (_dashboard?.transactions ?? const <_SmsCreditTxData>[])
                        .isEmpty
                    ? Text(
                        'No SMS credit activity yet.',
                        style: DesignTokens.textSmall,
                      )
                    : Column(
                        children: _dashboard!.transactions
                            .map((tx) => _TransactionTile(transaction: tx))
                            .toList(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditsHero extends StatelessWidget {
  const _CreditsHero({required this.dashboard, required this.onBuyCredits});

  final _SmsDashboardData? dashboard;
  final VoidCallback onBuyCredits;

  @override
  Widget build(BuildContext context) {
    final credits = dashboard?.credits.balance ?? 0;
    final threshold = dashboard?.credits.lowCreditThreshold ?? 50;
    final isLow = credits < threshold;

    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        borderRadius: DesignTokens.borderRadiusLg,
        gradient: LinearGradient(
          colors: isLow
              ? const [Color(0xFF8C2F39), Color(0xFFC84A4A)]
              : const [Color(0xFF0B6E4F), Color(0xFF19A974)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SMS Credits',
            style: DesignTokens.textSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            credits.toString(),
            style: DesignTokens.textTitle.copyWith(
              color: Colors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            isLow
                ? 'Credits are running low. Top up before you miss customer updates.'
                : 'Campaigns, POS buyer messages, and seller alerts now share this balance.',
            style: DesignTokens.textSmall.copyWith(color: Colors.white),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Wrap(
            spacing: DesignTokens.spaceSm,
            runSpacing: DesignTokens.spaceSm,
            children: [
              FilledButton.icon(
                onPressed: onBuyCredits,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isLow
                      ? const Color(0xFF8C2F39)
                      : const Color(0xFF0B6E4F),
                ),
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Open Sanaa Wallet'),
              ),
              if ((dashboard?.credits.moduleUrl ?? '').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onBuyCredits,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Top up here'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

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
        border: Border.all(color: DesignTokens.grayLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: DesignTokens.textBodyBold)),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(color: DesignTokens.grayLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: DesignTokens.brandAccent),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(title, style: DesignTokens.textSmallBold),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(value, style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(subtitle, style: DesignTokens.textSmall),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: DesignTokens.textSmall)),
        const SizedBox(width: DesignTokens.spaceSm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: DesignTokens.textSmallBold,
          ),
        ),
      ],
    );
  }
}

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({required this.campaign});

  final _SmsCampaignData campaign;

  Color _statusColor() {
    switch (campaign.status) {
      case 'completed':
        return DesignTokens.success;
      case 'queued':
      case 'sending':
        return DesignTokens.brandAccent;
      case 'failed':
        return DesignTokens.error;
      default:
        return DesignTokens.grayMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Container(
        padding: DesignTokens.paddingMd,
        decoration: BoxDecoration(
          color: DesignTokens.grayLight.withValues(alpha: 0.25),
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(campaign.name, style: DesignTokens.textSmallBold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    campaign.status.toUpperCase(),
                    style: DesignTokens.textSmall.copyWith(
                      color: _statusColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              campaign.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DesignTokens.textSmall,
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              '${campaign.contactCount} contacts • ${campaign.successCount} sent • ${campaign.failedCount} failed • UGX ${campaign.totalCost.toStringAsFixed(0)}',
              style: DesignTokens.textSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final _SmsCreditTxData transaction;

  @override
  Widget build(BuildContext context) {
    final isUsage = transaction.type == 'usage';
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                (isUsage ? DesignTokens.warning : DesignTokens.success)
                    .withValues(alpha: 0.16),
            child: Icon(
              isUsage ? Icons.sms_failed_outlined : Icons.add_card_outlined,
              size: 18,
              color: isUsage ? DesignTokens.warning : DesignTokens.success,
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUsage ? 'Credits used' : 'Credits purchased',
                  style: DesignTokens.textSmallBold,
                ),
                Text(
                  transaction.createdAt ?? '-',
                  style: DesignTokens.textSmall,
                ),
              ],
            ),
          ),
          Text(
            '${isUsage ? '-' : '+'}${transaction.amount}',
            style: DesignTokens.textBodyBold.copyWith(
              color: isUsage ? DesignTokens.error : DesignTokens.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsDashboardData {
  const _SmsDashboardData({
    required this.credits,
    required this.stats,
    required this.campaigns,
    required this.templates,
    required this.transactions,
  });

  factory _SmsDashboardData.fromJson(Map<String, dynamic> json) {
    return _SmsDashboardData(
      credits: _SmsCreditsData.fromJson(_asMap(json['credits'])),
      stats: _SmsStatsData.fromJson(_asMap(json['stats'])),
      campaigns: _asList(
        json['campaigns'],
      ).map((item) => _SmsCampaignData.fromJson(_asMap(item))).toList(),
      templates: _asList(
        json['templates'],
      ).map((item) => _SmsTemplateData.fromJson(_asMap(item))).toList(),
      transactions: _asList(
        json['transactions'],
      ).map((item) => _SmsCreditTxData.fromJson(_asMap(item))).toList(),
    );
  }

  final _SmsCreditsData credits;
  final _SmsStatsData stats;
  final List<_SmsCampaignData> campaigns;
  final List<_SmsTemplateData> templates;
  final List<_SmsCreditTxData> transactions;
}

class _SmsCreditsData {
  const _SmsCreditsData({
    required this.balance,
    required this.costPerSms,
    required this.lowCreditThreshold,
    required this.purchaseUrl,
    required this.moduleUrl,
  });

  factory _SmsCreditsData.fromJson(Map<String, dynamic> json) {
    return _SmsCreditsData(
      balance: _asInt(json['balance']),
      costPerSms: _asInt(json['cost_per_sms']),
      lowCreditThreshold: _asInt(json['low_credit_threshold']),
      purchaseUrl: json['purchase_url']?.toString(),
      moduleUrl: json['module_url']?.toString(),
    );
  }

  final int balance;
  final int costPerSms;
  final int lowCreditThreshold;
  final String? purchaseUrl;
  final String? moduleUrl;
}

class _SmsStatsData {
  const _SmsStatsData({
    required this.totalCampaigns,
    required this.totalSmsSent,
    required this.totalSpent,
    required this.queuedCampaigns,
  });

  factory _SmsStatsData.fromJson(Map<String, dynamic> json) {
    return _SmsStatsData(
      totalCampaigns: _asInt(json['total_campaigns']),
      totalSmsSent: _asInt(json['total_sms_sent']),
      totalSpent: _asDouble(json['total_spent']),
      queuedCampaigns: _asInt(json['queued_campaigns']),
    );
  }

  final int totalCampaigns;
  final int totalSmsSent;
  final double totalSpent;
  final int queuedCampaigns;
}

class _SmsCampaignData {
  const _SmsCampaignData({
    required this.id,
    required this.name,
    required this.message,
    required this.status,
    required this.contactCount,
    required this.successCount,
    required this.failedCount,
    required this.totalCost,
  });

  factory _SmsCampaignData.fromJson(Map<String, dynamic> json) {
    return _SmsCampaignData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Campaign',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      contactCount: _asInt(json['contact_count']),
      successCount: _asInt(json['success_count']),
      failedCount: _asInt(json['failed_count']),
      totalCost: _asDouble(json['total_cost']),
    );
  }

  final String id;
  final String name;
  final String message;
  final String status;
  final int contactCount;
  final int successCount;
  final int failedCount;
  final double totalCost;
}

class _SmsTemplateData {
  const _SmsTemplateData({
    required this.id,
    required this.name,
    required this.message,
  });

  factory _SmsTemplateData.fromJson(Map<String, dynamic> json) {
    return _SmsTemplateData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Template',
      message: json['message']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String message;
}

class _SmsCreditTxData {
  const _SmsCreditTxData({
    required this.type,
    required this.amount,
    required this.createdAt,
  });

  factory _SmsCreditTxData.fromJson(Map<String, dynamic> json) {
    return _SmsCreditTxData(
      type: json['type']?.toString() ?? 'usage',
      amount: _asInt(json['amount']),
      createdAt: json['created_at']?.toString(),
    );
  }

  final String type;
  final int amount;
  final String? createdAt;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<dynamic> _asList(Object? value) {
  if (value is List) return value;
  return const <dynamic>[];
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
