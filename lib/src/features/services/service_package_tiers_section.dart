import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/comma_number_formatter.dart';
import '../../core/util/service_pricing_utils.dart';
import '../../widgets/app_input.dart';

class ServicePackageTiersSection extends StatelessWidget {
  const ServicePackageTiersSection({
    super.key,
    required this.tiers,
    required this.onChanged,
  });

  final List<ServicePricingTier> tiers;
  final ValueChanged<List<ServicePricingTier>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pricing packages',
          style: DesignTokens.textSmallBold,
        ),
        const SizedBox(height: 4),
        Text(
          'Optional tiers like Upwork — buyers pick Basic, Standard, or Premium on your shop.',
          style: DesignTokens.textSmall,
        ),
        const SizedBox(height: 12),
        ...tiers.map((tier) => _TierCard(
              tier: tier,
              onUpdate: (updated) {
                final next = List<ServicePricingTier>.from(tiers);
                final i = next.indexWhere((t) => t.tier == tier.tier);
                if (i >= 0) next[i] = updated;
                onChanged(next);
              },
            )),
      ],
    );
  }
}

class _TierCard extends StatefulWidget {
  const _TierCard({required this.tier, required this.onUpdate});

  final ServicePricingTier tier;
  final ValueChanged<ServicePricingTier> onUpdate;

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _daysCtrl;
  late final TextEditingController _revisionsCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.tier.price != null
          ? CommaNumberFormatter.format(widget.tier.price!.toStringAsFixed(0))
          : '',
    );
    _daysCtrl = TextEditingController(
      text: widget.tier.deliveryDays?.toString() ?? '',
    );
    _revisionsCtrl = TextEditingController(
      text: widget.tier.revisions?.toString() ?? '',
    );
    _descCtrl = TextEditingController(text: widget.tier.description ?? '');
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _daysCtrl.dispose();
    _revisionsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final price = double.tryParse(
      CommaNumberFormatter.unformat(_priceCtrl.text.trim()),
    );
    widget.onUpdate(
      widget.tier.copyWith(
        price: price,
        deliveryDays: int.tryParse(_daysCtrl.text.trim()),
        revisions: int.tryParse(_revisionsCtrl.text.trim()),
        description: _descCtrl.text.trim(),
      ),
    );
  }

  String get _label => switch (widget.tier.tier) {
        'basic' => 'Basic',
        'standard' => 'Standard',
        'premium' => 'Premium',
        _ => widget.tier.tier,
      };

  Color get _accent => switch (widget.tier.tier) {
        'basic' => DesignTokens.info,
        'standard' => DesignTokens.brandAccent,
        'premium' => DesignTokens.brandPrimary,
        _ => DesignTokens.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.04),
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: DesignTokens.borderRadiusFull,
                ),
                child: Text(
                  _label,
                  style: DesignTokens.textSmallBold.copyWith(color: _accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppInput(
                  controller: _priceCtrl,
                  label: 'Price (UGX)',
                  hint: 'Optional',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CommaNumberFormatter()],
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppInput(
                  controller: _daysCtrl,
                  label: 'Days',
                  hint: '7',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppInput(
                  controller: _revisionsCtrl,
                  label: 'Revisions',
                  hint: '1',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppInput(
            controller: _descCtrl,
            label: "What's included",
            hint: 'e.g. 3 logo concepts, source files',
            onChanged: (_) => _emit(),
          ),
        ],
      ),
    );
  }
}