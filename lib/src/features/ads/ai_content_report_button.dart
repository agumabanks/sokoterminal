import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';

/// Reports the exact server-generated output without leaving Terminal.
class AiContentReportButton extends ConsumerWidget {
  const AiContentReportButton({super.key, this.adId, this.reportToken});
  final int? adId;
  final String? reportToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (adId == null && reportToken == null) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Report AI content'),
      onPressed: () async {
        final reason = await showDialog<String>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Why are you reporting this content?'),
            children: [
              for (final entry in const {
                'unsafe': 'Unsafe or harmful',
                'offensive': 'Offensive content',
                'misleading': 'Misleading or false claims',
                'other': 'Another concern',
              }.entries)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, entry.key),
                  child: Text(entry.value),
                ),
            ],
          ),
        );
        if (reason == null || !context.mounted) return;
        try {
          await ref.read(sellerApiProvider).reportAiContent(
            adId: adId, reportToken: reportToken, reason: reason,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Report received. Our team will review this content.'),
          ));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Report was not sent. Check your connection and try again.'),
          ));
        }
      },
    );
  }
}
