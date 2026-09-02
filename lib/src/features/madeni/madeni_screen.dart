import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';

/// Madeni Ledger Screen — Customer Debt Book
///
/// Shows all customer debts with status, due dates, and actions.
/// This is the digital version of the exercise book that every
/// East African merchant keeps.
class MadeniScreen extends ConsumerStatefulWidget {
  const MadeniScreen({super.key});

  @override
  ConsumerState<MadeniScreen> createState() => _MadeniScreenState();
}

class _MadeniScreenState extends ConsumerState<MadeniScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      appBar: AppBar(
        title: Text('Madeni Ledger', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDebt(context),
            tooltip: 'Add debt',
          ),
        ],
      ),
      body: StreamBuilder<List<MadeniEntry>>(
        stream: db.watchMadeniEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState();
          }

          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No debts yet',
              subtitle: 'Track customer debts here',
            );
          }

          return ListView.builder(
            padding: DesignTokens.paddingScreen,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _MadeniEntryCard(entry: entry);
            },
          );
        },
      ),
    );
  }

  void _showAddDebt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddDebtSheet(),
    );
  }
}

class _MadeniEntryCard extends StatelessWidget {
  const _MadeniEntryCard({required this.entry});

  final MadeniEntry entry;

  @override
  Widget build(BuildContext context) {
    final remaining = entry.amount - entry.amountPaid;
    final isOverdue = entry.dueDate != null &&
        entry.dueDate!.isBefore(DateTime.now()) &&
        entry.status != 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusMd,
        border: Border.all(
          color: isOverdue ? DesignTokens.error : DesignTokens.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.customerName,
                  style: DesignTokens.textTitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(entry.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.status.toUpperCase(),
                  style: DesignTokens.textCaption.copyWith(
                    color: _getStatusColor(entry.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(entry.description, style: DesignTokens.textBody),
          const SizedBox(height: DesignTokens.spaceSm),
          Row(
            children: [
              Text(
                'Amount: ${entry.amount.toUgx()}',
                style: DesignTokens.textSmall,
              ),
              const Spacer(),
              if (remaining > 0)
                Text(
                  'Remaining: ${remaining.toUgx()}',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.error,
                  ),
                ),
            ],
          ),
          if (entry.dueDate != null) ...[
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              'Due: ${_formatDate(entry.dueDate!)}',
              style: DesignTokens.textCaption.copyWith(
                color: isOverdue ? DesignTokens.error : DesignTokens.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return DesignTokens.success;
      case 'partial':
        return DesignTokens.warning;
      case 'overdue':
        return DesignTokens.error;
      default:
        return DesignTokens.inkMuted;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _AddDebtSheet extends ConsumerStatefulWidget {
  const _AddDebtSheet();

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Customer Debt', style: DesignTokens.textHeadline),
          const SizedBox(height: DesignTokens.spaceMd),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Customer name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount (UGX)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          ListTile(
            title: Text(_dueDate == null
                ? 'Due date (optional)'
                : 'Due: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
            leading: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          ElevatedButton(
            onPressed: _saveDebt,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save Debt'),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
        ],
      ),
    );
  }

  Future<void> _saveDebt() async {
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and amount are required')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    await db.addMadeniEntry(
      customerName: _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? 'Credit sale' : _descCtrl.text.trim(),
      amount: amount,
      dueDate: _dueDate,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt added')),
      );
    }
  }
}
