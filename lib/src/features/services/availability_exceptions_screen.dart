import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/design_tokens.dart';
import 'availability_controller.dart';

/// Manage date-level availability exceptions (blocked days, custom hours).
class AvailabilityExceptionsScreen extends ConsumerStatefulWidget {
  const AvailabilityExceptionsScreen({super.key});

  @override
  ConsumerState<AvailabilityExceptionsScreen> createState() =>
      _AvailabilityExceptionsScreenState();
}

class _AvailabilityExceptionsScreenState
    extends ConsumerState<AvailabilityExceptionsScreen> {
  final _dateFormat = DateFormat('EEE, dd MMM yyyy');

  Future<void> _addException() async {
    final result = await showModalBottomSheet<_ExceptionData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddExceptionSheet(),
    );
    if (result == null) return;

    await ref.read(availabilityControllerProvider.notifier).addException(
      date: result.date,
      isAvailable: result.isAvailable,
      startTime: result.startTime,
      endTime: result.endTime,
      reason: result.reason,
    );
  }

  Future<void> _deleteException(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Exception'),
        content: const Text('Remove this date exception?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(availabilityControllerProvider.notifier).removeException(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availabilityControllerProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: const Text('Blocked Dates')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addException,
        backgroundColor: DesignTokens.brandPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: state.loading && state.exceptions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.exceptions.isEmpty
              ? _EmptyState(onTap: _addException)
              : ListView.builder(
                  padding: DesignTokens.paddingScreen,
                  itemCount: state.exceptions.length,
                  itemBuilder: (context, index) {
                    final e = state.exceptions[index];
                    final date = DateTime.tryParse(e.date);
                    return Dismissible(
                      key: ValueKey('exc_${e.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: DesignTokens.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteException(e.id),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: e.isAvailable
                                ? DesignTokens.brandAccent.withValues(alpha: 0.15)
                                : DesignTokens.error.withValues(alpha: 0.15),
                            child: Icon(
                              e.isAvailable ? Icons.event_available : Icons.event_busy,
                              color: e.isAvailable ? DesignTokens.brandAccent : DesignTokens.error,
                            ),
                          ),
                          title: Text(
                            date != null ? _dateFormat.format(date) : e.date,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.startTime != null && e.endTime != null)
                                Text('${e.startTime} — ${e.endTime}'),
                              if (e.reason != null && e.reason!.isNotEmpty)
                                Text(e.reason!, style: const TextStyle(color: DesignTokens.grayMedium)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: DesignTokens.grayMedium),
                            onPressed: () => _deleteException(e.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 64, color: DesignTokens.grayLight),
          const SizedBox(height: 16),
          const Text(
            'No blocked dates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: DesignTokens.grayMedium),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to block a day or set custom hours',
            style: TextStyle(color: DesignTokens.grayMedium),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: const Text('Add Exception'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExceptionData {
  _ExceptionData({
    required this.date,
    required this.isAvailable,
    this.startTime,
    this.endTime,
    this.reason,
  });
  final String date;
  final bool isAvailable;
  final String? startTime;
  final String? endTime;
  final String? reason;
}

class _AddExceptionSheet extends StatefulWidget {
  const _AddExceptionSheet();

  @override
  State<_AddExceptionSheet> createState() => _AddExceptionSheetState();
}

class _AddExceptionSheetState extends State<_AddExceptionSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isAvailable = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _reasonCtrl = TextEditingController();
  bool _hasCustomHours = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 17, minute: 0));
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
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _submit() {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    Navigator.pop(
      context,
      _ExceptionData(
        date: dateStr,
        isAvailable: _isAvailable,
        startTime: _hasCustomHours && _startTime != null ? _fmt(_startTime!) : null,
        endTime: _hasCustomHours && _endTime != null ? _fmt(_endTime!) : null,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            'Add Date Exception',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(
              DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available'),
            subtitle: Text(_isAvailable ? 'Open for bookings' : 'Blocked / Day off'),
            value: _isAvailable,
            onChanged: (v) => setState(() => _isAvailable = v),
            activeThumbColor: DesignTokens.brandAccent,
          ),
          if (_isAvailable)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom hours'),
              value: _hasCustomHours,
              onChanged: (v) => setState(() => _hasCustomHours = v ?? false),
              activeColor: DesignTokens.brandAccent,
            ),
          if (_isAvailable && _hasCustomHours)
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(_startTime != null ? _fmt(_startTime!) : '—'),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(_endTime != null ? _fmt(_endTime!) : '—'),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. Public holiday, Training day',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Exception', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
