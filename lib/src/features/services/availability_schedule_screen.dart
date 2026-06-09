import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import 'availability_controller.dart';
import 'availability_exceptions_screen.dart';
import 'availability_share_sheet.dart';

final List<String> _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Weekly availability schedule editor.
class AvailabilityScheduleScreen extends ConsumerStatefulWidget {
  const AvailabilityScheduleScreen({super.key});

  @override
  ConsumerState<AvailabilityScheduleScreen> createState() =>
      _AvailabilityScheduleScreenState();
}

class _DayConfig {
  _DayConfig({required this.dayOfWeek, required this.start, required this.end, required this.isAvailable});
  final int dayOfWeek; // 0=Mon … 6=Sun (UI order)
  TimeOfDay start;
  TimeOfDay end;
  bool isAvailable;
}

class _AvailabilityScheduleScreenState
    extends ConsumerState<AvailabilityScheduleScreen> {
  late List<_DayConfig> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (i) => _DayConfig(
      dayOfWeek: i,
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 17, minute: 0),
      isAvailable: i < 5, // Mon-Fri default
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromState());
  }

  void _loadFromState() {
    final state = ref.read(availabilityControllerProvider);
    for (final s in state.schedules) {
      // Map 0=Sun…6=Sat (backend) to 0=Mon…6=Sun (UI)
      final backendDow = s.dayOfWeek; // 0=Sun … 6=Sat
      final uiIndex = backendDow == 0 ? 6 : backendDow - 1;
      if (uiIndex >= 0 && uiIndex < 7) {
        _days[uiIndex].isAvailable = s.isAvailable;
        final startParts = s.startTime.split(':');
        final endParts = s.endTime.split(':');
        _days[uiIndex].start = TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
        );
        _days[uiIndex].end = TimeOfDay(
          hour: int.parse(endParts[0]),
          minute: int.parse(endParts[1]),
        );
      }
    }
    setState(() {});
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final day = _days[index];
    final initial = isStart ? day.start : day.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        day.start = picked;
        if (_timeToMinutes(day.start) >= _timeToMinutes(day.end)) {
          day.end = TimeOfDay(hour: picked.hour + 1, minute: picked.minute);
        }
      } else {
        day.end = picked;
        if (_timeToMinutes(day.end) <= _timeToMinutes(day.start)) {
          day.start = TimeOfDay(hour: picked.hour - 1, minute: picked.minute);
        }
      }
    });
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _copyToAll(int sourceIndex) {
    final source = _days[sourceIndex];
    setState(() {
      for (final d in _days) {
        d.isAvailable = source.isAvailable;
        d.start = TimeOfDay(hour: source.start.hour, minute: source.start.minute);
        d.end = TimeOfDay(hour: source.end.hour, minute: source.end.minute);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final schedules = _days.map((d) {
      // Map 0=Mon…6=Sun (UI) to 0=Sun…6=Sat (backend)
      final backendDow = d.dayOfWeek == 6 ? 0 : d.dayOfWeek + 1;
      return {
        'day_of_week': backendDow,
        'start_time': _fmt(d.start),
        'end_time': _fmt(d.end),
        'is_available': d.isAvailable,
      };
    }).toList();

    await ref.read(availabilityControllerProvider.notifier).updateSchedules(schedules);
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availabilityControllerProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Working Hours'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share availability',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AvailabilityShareSheet(),
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: DesignTokens.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(state.error!, style: const TextStyle(color: DesignTokens.error)),
            ),
          ...List.generate(7, (i) {
            final day = _days[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dayNames[i],
                            style: DesignTokens.textBody.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: day.isAvailable,
                          onChanged: (v) => setState(() => day.isAvailable = v),
                          activeColor: DesignTokens.brandAccent,
                        ),
                      ],
                    ),
                    if (day.isAvailable)
                      Row(
                        children: [
                          _TimeChip(
                            label: _fmt(day.start),
                            onTap: () => _pickTime(i, true),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('—', style: TextStyle(color: DesignTokens.grayMedium)),
                          ),
                          _TimeChip(
                            label: _fmt(day.end),
                            onTap: () => _pickTime(i, false),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _copyToAll(i),
                            child: const Text('Copy to all'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AvailabilityExceptionsScreen()),
            ),
            icon: const Icon(Icons.block),
            label: const Text('Block Dates / Custom Hours'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceGrouped,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}
