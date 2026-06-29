import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import 'models/bnpl_seller_status.dart';
import 'providers/bnpl_seller_status_provider.dart';

/// Seller-facing entry point for Sanaa Finance BNPL opt-in and status.
class BnplSettingsScreen extends ConsumerStatefulWidget {
  const BnplSettingsScreen({super.key});

  @override
  ConsumerState<BnplSettingsScreen> createState() => _BnplSettingsScreenState();
}

class _BnplSettingsScreenState extends ConsumerState<BnplSettingsScreen> {
  bool _requesting = false;

  Future<void> _requestEnrollment() async {
    setState(() => _requesting = true);
    try {
      await ref.read(sellerApiProvider).requestBnplEnrollment();
      ref.invalidate(bnplSellerStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sanaa Finance BNPL request submitted.'),
            backgroundColor: DesignTokens.brandAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not submit BNPL request: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(bnplSellerStatusProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Sanaa Finance BNPL',
          style: DesignTokens.textHeadline.copyWith(fontSize: 17),
        ),
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Unable to load BNPL status: $e',
              style: DesignTokens.textBody),
        ),
        data: (status) => ListView(
          padding: DesignTokens.paddingScreen,
          children: [
            _StatusCard(status: status),
            const SizedBox(height: DesignTokens.spaceLg),
            _InfoCard(status: status),
            if (status.isNotEnrolled) ...[
              const SizedBox(height: DesignTokens.spaceLg),
              AppButton(
                label: 'Request to join Sanaa Finance BNPL',
                onPressed: _requesting ? null : _requestEnrollment,
                isLoading: _requesting,
                expand: true,
              ),
            ],
            const SizedBox(height: DesignTokens.spaceXl),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final BnplSellerStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (status.status) {
      'active' => (
          Icons.check_circle_outline,
          DesignTokens.success,
          'Active',
          'You are enrolled in Sanaa Finance BNPL. Buyers can pay later on eligible products and services.',
        ),
      'pending' => (
          Icons.hourglass_top_outlined,
          DesignTokens.warning,
          'Pending approval',
          'Your enrollment request is being reviewed. You will be notified once it is approved.',
        ),
      'suspended' => (
          Icons.block_outlined,
          DesignTokens.error,
          'Suspended',
          'Your BNPL access is temporarily suspended. Contact support for assistance.',
        ),
      _ => (
          Icons.account_balance_wallet_outlined,
          DesignTokens.grayMedium,
          'Not enrolled',
          'Let customers buy now and pay later with Sanaa Finance BNPL.',
        ),
    };

    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: DesignTokens.borderRadiusMd,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: DesignTokens.textTitle.copyWith(color: color)),
                const SizedBox(height: DesignTokens.spaceXs),
                Text(subtitle, style: DesignTokens.textSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.status});

  final BnplSellerStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          _bullet('You get paid in full at checkout.'),
          _bullet('Sanaa Finance collects installment payments from the buyer.'),
          _bullet('You control which products and services offer BNPL.'),
          if (status.isActive) ...[
            const SizedBox(height: DesignTokens.spaceMd),
            Text(
              'Go to any product or service to turn on "Allow BNPL / Pay Later".',
              style: DesignTokens.textSmall.copyWith(
                color: DesignTokens.brandAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: DesignTokens.inkMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: DesignTokens.textSmall)),
        ],
      ),
    );
  }
}
