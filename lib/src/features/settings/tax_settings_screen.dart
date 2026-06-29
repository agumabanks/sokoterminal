import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/comma_number_formatter.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

/// Configure tax rate, label, and inclusion mode for the business.
class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  final _rateCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _enabled = false;
  String _inclusionMode = 'exclusive'; // inclusive, exclusive
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final profile = await db.getBusinessProfile();
    if (mounted) {
      setState(() {
        _enabled = profile?.taxEnabled ?? false;
        _inclusionMode = profile?.taxInclusionMode ?? 'exclusive';
        _rateCtrl.text = CommaNumberFormatter.format(
          (profile?.taxRate ?? 0).toStringAsFixed(0),
        );
        _labelCtrl.text = profile?.taxLabel ?? 'VAT';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final db = ref.read(appDatabaseProvider);
    final rate = double.tryParse(
          CommaNumberFormatter.unformat(_rateCtrl.text.trim()),
        ) ??
        0;
    final label = _labelCtrl.text.trim().isEmpty ? 'VAT' : _labelCtrl.text.trim();

    await db.upsertBusinessProfile(
      BusinessProfilesCompanion(
        id: const Value('primary'),
        taxEnabled: Value(_enabled),
        taxRate: Value(rate),
        taxLabel: Value(label),
        taxInclusionMode: Value(_inclusionMode),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceRaised,
        elevation: 0,
        title: Text('Tax Settings', style: DesignTokens.textTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: DesignTokens.paddingScreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enable tax
                  _buildCard(
                    child: SwitchListTile(
                      title: const Text('Enable tax'),
                      subtitle: Text(
                        _enabled
                            ? 'Tax will be applied to orders'
                            : 'No tax will be calculated',
                        style: DesignTokens.textSmall,
                      ),
                      value: _enabled,
                      activeThumbColor: DesignTokens.brandPrimary,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tax label
                  _buildCard(
                    child: Padding(
                      padding: DesignTokens.paddingMd,
                      child: AppInput(
                        controller: _labelCtrl,
                        label: 'Tax label',
                        hint: 'VAT, GST, Sales Tax',
                        prefixIcon: Icons.label_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tax rate
                  _buildCard(
                    child: Padding(
                      padding: DesignTokens.paddingMd,
                      child: AppInput(
                        controller: _rateCtrl,
                        label: 'Tax rate (%)',
                        hint: '18',
                        prefixIcon: Icons.percent,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [CommaNumberFormatter()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Inclusion mode
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: DesignTokens.paddingMd,
                          child: Text(
                            'How prices include tax',
                            style: DesignTokens.textBodyBold,
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            _inclusionMode == 'exclusive'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _inclusionMode == 'exclusive'
                                ? DesignTokens.brandPrimary
                                : DesignTokens.grayLight,
                          ),
                          title: const Text('Tax exclusive'),
                          subtitle: const Text(
                            'Prices do NOT include tax. Tax is added on top at checkout.',
                          ),
                          onTap: () => setState(() => _inclusionMode = 'exclusive'),
                        ),
                        ListTile(
                          leading: Icon(
                            _inclusionMode == 'inclusive'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _inclusionMode == 'inclusive'
                                ? DesignTokens.brandPrimary
                                : DesignTokens.grayLight,
                          ),
                          title: const Text('Tax inclusive'),
                          subtitle: const Text(
                            'Prices already include tax. Receipt shows tax breakdown.',
                          ),
                          onTap: () => setState(() => _inclusionMode = 'inclusive'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    label: 'Save Tax Settings',
                    onPressed: _save,
                    expand: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceRaised,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
