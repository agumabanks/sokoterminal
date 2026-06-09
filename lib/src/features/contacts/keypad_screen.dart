import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/design_tokens.dart';

class KeypadScreen extends ConsumerStatefulWidget {
  const KeypadScreen({super.key});

  @override
  ConsumerState<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends ConsumerState<KeypadScreen> {
  String _digits = '';

  void _addDigit(String digit) {
    if (_digits.length < 15) {
      setState(() => _digits += digit);
    }
  }

  void _backspace() {
    if (_digits.isNotEmpty) {
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  Future<void> _makeCall() async {
    if (_digits.isEmpty) return;
    final uri = Uri.parse('tel:$_digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesignTokens.surface,
      child: Column(
        children: [
        const SizedBox(height: 40),
        SizedBox(
          height: 80,
          child: Center(
            child: Text(
              _digits,
              style: DesignTokens.textTitle.copyWith(fontSize: 40),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_digits.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              // Open a simple save-contact bottom sheet
              showModalBottomSheet(
                context: context,
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Save \$_digits', style: DesignTokens.textTitle),
                      const SizedBox(height: 16),
                      Text(
                        'Use your device contacts app to save this number.',
                        style: DesignTokens.textBody,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add to Contacts'),
          ),
        const Spacer(),
        _buildKeypad(),
        const SizedBox(height: 40),
        _buildActions(),
        const SizedBox(height: 40),
      ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: [
          ...[
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '*',
            '0',
            '#',
          ].map(_buildKey),
        ],
      ),
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _addDigit(label),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignTokens.grayLight,
        ),
        child: Center(
          child: Text(
            label,
            style: DesignTokens.textTitle.copyWith(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 72), // Placeholder for symmetry
        const SizedBox(width: 48),
        InkWell(
          onTap: _makeCall,
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DesignTokens.success,
            ),
            child: const Icon(Icons.call, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(width: 48),
        IconButton(
          onPressed: _backspace,
          icon: const Icon(Icons.backspace_outlined, size: 32),
          color: DesignTokens.grayMedium,
        ),
      ],
    );
  }
}
