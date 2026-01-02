import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _confirmConsent = false;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  int _segmentCount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    return ((trimmed.length - 1) ~/ 160) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final recipients = customersAsync.maybeWhen(
      data: (rows) => rows.where((c) => (c.phone ?? '').trim().isNotEmpty).length,
      orElse: () => 0,
    );
    final segments = _segmentCount(_messageController.text);
    final totalSegments = recipients * segments;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Bulk SMS'),
        actions: [
          IconButton(
            tooltip: 'Sync contacts',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sync complete'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          _InfoCard(
            title: 'Recipients',
            child: customersAsync.when(
              data: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$recipients contacts with phone numbers',
                    style: DesignTokens.textBodyBold,
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(
                    'Messages are sent to CRM contacts (not device-only contacts).',
                    style: DesignTokens.textSmall,
                  ),
                ],
              ),
              loading: () => const Text('Loading contacts...'),
              error: (e, _) => Text(
                'Failed to load contacts: $e',
                style: DesignTokens.textSmall,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          _InfoCard(
            title: 'Campaign details',
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Campaign name (optional)',
                    hintText: 'Weekend promo',
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Write your SMS message...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DesignTokens.spaceXs),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: DesignTokens.grayMedium),
                    const SizedBox(width: DesignTokens.spaceSm),
                    Expanded(
                      child: Text(
                        'Estimated: $segments segment(s) per message, $totalSegments total segments.',
                        style: DesignTokens.textSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          _InfoCard(
            title: 'Consent',
            child: Row(
              children: [
                Checkbox(
                  value: _confirmConsent,
                  onChanged: (v) => setState(() => _confirmConsent = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'I confirm these customers have opted in to marketing SMS.',
                    style: DesignTokens.textSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : () => _sendCampaign(context, recipients),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send to all contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCampaign(BuildContext context, int recipients) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is required')),
      );
      return;
    }
    if (!_confirmConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm customer consent')),
      );
      return;
    }

    final approved = await requireManagerPin(
      context,
      ref,
      reason: 'send bulk SMS messages',
    );
    if (!approved) return;

    setState(() => _sending = true);
    try {
      final api = ref.read(sellerApiProvider);
      final name = _titleController.text.trim();
      final now = DateTime.now().toLocal();
      final fallbackName =
          'SMS Campaign ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final createRes = await api.createCrmCampaign({
        'name': name.isEmpty ? fallbackName : name,
        'channel': 'sms',
        'body': message,
        'target_mode': 'all',
      });

      final body = createRes.data;
      final data = body is Map ? body['data'] : null;
      final campaignId = data is Map ? data['id']?.toString() : null;
      if (campaignId == null || campaignId.trim().isEmpty) {
        throw Exception('Campaign creation failed');
      }

      final runRes = await api.runCrmCampaign(campaignId);
      final runBody = runRes.data;
      final runData = runBody is Map ? runBody['data'] : null;
      final sentSms = runData is Map ? runData['sent_sms'] : null;
      final failedSms = runData is Map ? runData['failed_sms'] : null;
      final skipped = runData is Map ? runData['skipped'] : null;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${sentSms ?? 0}/${recipients} (failed: ${failedSms ?? 0}, skipped: ${skipped ?? 0})',
          ),
          backgroundColor: DesignTokens.brandAccent,
        ),
      );
      _messageController.clear();
      _titleController.clear();
      setState(() => _confirmConsent = false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SMS: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          child,
        ],
      ),
    );
  }
}
