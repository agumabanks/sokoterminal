import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/settings/pos_void_reason_codes.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class VoidReasonCodesScreen extends ConsumerStatefulWidget {
  const VoidReasonCodesScreen({super.key});

  @override
  ConsumerState<VoidReasonCodesScreen> createState() => _VoidReasonCodesScreenState();
}

class _VoidReasonCodesScreenState extends ConsumerState<VoidReasonCodesScreen> {
  final _newCtrl = TextEditingController();
  List<String> _codes = const [];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _codes = PosVoidReasonCodesCache.read(prefs);
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> next) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await PosVoidReasonCodesCache.write(prefs, next);
    if (!mounted) return;
    setState(() => _codes = next);
  }

  @override
  Widget build(BuildContext context) {
    final defaults = PosVoidReasonCodesCache.defaultCodes;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Void reason codes'),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = ref.read(sharedPreferencesProvider);
              await PosVoidReasonCodesCache.reset(prefs);
              if (!mounted) return;
              setState(() => _codes = PosVoidReasonCodesCache.read(prefs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Padding(
        padding: DesignTokens.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Required on every void', style: DesignTokens.textBodyBold),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              'Cashiers will be prompted to select one of these reason codes.',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Expanded(
              child: ListView(
                children: [
                  ..._codes.map((c) {
                    final isDefault = defaults.contains(c);
                    return Card(
                      child: ListTile(
                        title: Text(c),
                        subtitle: isDefault ? const Text('Default') : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final next = _codes.where((e) => e != c).toList();
                            if (next.isEmpty) return;
                            await _save(next);
                          },
                        ),
                      ),
                    );
                  }),
                  if (_codes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No reason codes configured.',
                        style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            AppInput(
              controller: _newCtrl,
              label: 'Add reason code',
              hint: 'e.g. CUSTOMER_CANCELLED',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            AppButton(
              label: 'Add',
              onPressed: () async {
                final raw = _newCtrl.text.trim().toUpperCase();
                if (raw.isEmpty) return;
                if (_codes.contains(raw)) return;
                final next = [..._codes, raw];
                await _save(next);
                _newCtrl.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}

