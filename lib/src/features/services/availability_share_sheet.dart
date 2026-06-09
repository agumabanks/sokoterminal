import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import 'availability_controller.dart';

/// Generates a shareable text message with the seller's availability.
class AvailabilityShareSheet extends ConsumerWidget {
  const AvailabilityShareSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(availabilityControllerProvider);
    final message = _buildMessage(state.schedules);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share Your Availability',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Copy this message and send it to your customers on WhatsApp.',
            style: TextStyle(color: DesignTokens.grayMedium),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceGrouped,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DesignTokens.grayLight),
            ),
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  String _buildMessage(List<AvailabilitySchedule> schedules) {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final buffer = StringBuffer();
    buffer.writeln('Hello! 👋');
    buffer.writeln('');
    buffer.writeln('Here is my availability this week:');
    buffer.writeln('');

    final sorted = List<AvailabilitySchedule>.from(schedules)
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    for (final s in sorted) {
      final dayName = days[s.dayOfWeek % 7];
      if (s.isAvailable) {
        buffer.writeln('• $dayName: ${s.startTime} — ${s.endTime}');
      } else {
        buffer.writeln('• $dayName: Unavailable');
      }
    }

    buffer.writeln('');
    buffer.writeln('Book your slot and I\'ll confirm. Thank you! 🙏');
    return buffer.toString();
  }
}
