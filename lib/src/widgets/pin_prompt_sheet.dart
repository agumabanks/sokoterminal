import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/design_tokens.dart';
import 'bottom_sheet_modal.dart';

class PinPromptSheet extends StatefulWidget {
  const PinPromptSheet({
    required this.title,
    this.subtitle,
    this.actionLabel = 'Confirm',
    this.pinLabel = 'PIN',
    super.key,
  });

  final String title;
  final String? subtitle;
  final String actionLabel;
  final String pinLabel;

  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    String actionLabel = 'Confirm',
    String pinLabel = 'PIN',
  }) {
    return BottomSheetModal.show<String>(
      context: context,
      title: title,
      subtitle: subtitle,
      isDismissible: true,
      enableDrag: true,
      child: PinPromptSheet(
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        pinLabel: pinLabel,
      ),
    );
  }

  @override
  State<PinPromptSheet> createState() => _PinPromptSheetState();
}

class _PinPromptSheetState extends State<PinPromptSheet> {
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: widget.pinLabel,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: DesignTokens.spaceLg),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }

  void _submit() {
    HapticFeedback.selectionClick();
    final pin = _pinCtrl.text.trim();
    Navigator.of(context).pop(pin.isEmpty ? null : pin);
  }
}
