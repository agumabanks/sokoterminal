import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/error_page.dart';

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(appDatabaseProvider).watchExpenses(limit: 200);
});

final activeSuppliersProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(appDatabaseProvider).watchSuppliers(activeOnly: true);
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sync finished'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpense(context, ref),
        backgroundColor: DesignTokens.brandAccent,
        child: const Icon(Icons.add),
      ),
      body: expenses.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: DesignTokens.paddingScreen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_outlined, size: 56, color: DesignTokens.grayMedium),
                    const SizedBox(height: DesignTokens.spaceMd),
                    Text('No expenses yet', style: DesignTokens.textBodyBold),
                    const SizedBox(height: DesignTokens.spaceXs),
                    Text(
                      'Track operating costs like rent, utilities, and supplier payments.',
                      style: DesignTokens.textSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),
                    ElevatedButton.icon(
                      onPressed: () => _showAddExpense(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Record expense'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(syncServiceProvider).syncNow(),
            child: ListView.separated(
              padding: DesignTokens.paddingScreen,
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spaceSm),
              itemBuilder: (context, index) => _ExpenseCard(expense: rows[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPage(
          title: 'Failed to load expenses',
          message: e.toString(),
          onRetry: () => ref.read(syncServiceProvider).syncNow(),
        ),
      ),
    );
  }

  void _showAddExpense(BuildContext context, WidgetRef ref) {
    unawaited(() async {
      final telemetry = Telemetry.instance;
      unawaited(telemetry?.event('expense_create_open'));

      final approved = await requireManagerPin(
        context,
        ref,
        reason: 'record an expense',
      );
      if (!approved) return;

      if (!context.mounted) return;
      final form = await BottomSheetModal.show<_ExpenseFormResult>(
        context: context,
        title: 'Record expense',
        child: const _ExpenseForm(),
      );
      if (form == null) return;

      final db = ref.read(appDatabaseProvider);
      final outletId = (await db.getPrimaryOutlet())?.id;
      final staffId = ref.read(posSessionProvider).staffId?.toString();
      final occurredAt = DateTime.now().toUtc();

      try {
        unawaited(telemetry?.event('expense_create_submit', props: {'method': form.method, 'category': form.category}));

        String? expenseId;
        await db.transaction(() async {
          expenseId = await db.recordExpense(
            amount: form.amount,
            method: form.method,
            category: form.category,
            supplierId: form.supplierId,
            note: form.note,
            outletId: outletId,
            staffId: staffId,
            occurredAt: occurredAt,
          );

          if (form.method == 'cash') {
            final tag =
                (form.category == 'supplier' || form.supplierId != null) ? 'supplier' : 'expense';
            final label = form.category.trim();
            final storedNote = (form.note ?? '').trim().isEmpty
                ? '[$tag] $label'
                : '[$tag] $label • ${form.note!.trim()}';
            final movementId = await db.recordCashMovement(
              type: 'withdrawal',
              amount: form.amount,
              note: storedNote,
              linkedExpenseId: expenseId,
              outletId: outletId,
              staffId: staffId,
              occurredAt: occurredAt,
            );
            await db.recordAuditLog(
              actorStaffId: staffId,
              action: 'cash_movement_withdrawal',
              payload: {
                'movement_id': movementId,
                'linked_expense_id': expenseId,
                'amount': form.amount,
                'tag': tag,
                'note': form.note,
              },
            );
          }
        });

        unawaited(ref.read(syncServiceProvider).syncNow());

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense recorded'),
            backgroundColor: DesignTokens.success,
          ),
        );
        unawaited(telemetry?.event('expense_create_success', props: {'method': form.method, 'category': form.category}));
      } catch (e, st) {
        unawaited(telemetry?.recordError(e, st, hint: 'expense_create'));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record expense: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
        unawaited(telemetry?.event('expense_create_failed', props: {'error': e.toString()}));
      }
    }());
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final occurred = expense.occurredAt.toLocal();
    final date =
        '${occurred.year}-${occurred.month.toString().padLeft(2, '0')}-${occurred.day.toString().padLeft(2, '0')}';
    final time =
        '${occurred.hour.toString().padLeft(2, '0')}:${occurred.minute.toString().padLeft(2, '0')}';

    final methodLabel = _methodLabel(expense.method);
    final pending = !expense.synced;

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListTile(
        leading: Container(
          padding: DesignTokens.paddingSm,
          decoration: BoxDecoration(
            color: DesignTokens.error.withValues(alpha: 0.12),
            borderRadius: DesignTokens.borderRadiusSm,
          ),
          child: const Icon(Icons.payments_outlined, color: DesignTokens.error),
        ),
        title: Text(
          expense.category,
          style: DesignTokens.textBodyBold,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if ((expense.note ?? '').trim().isNotEmpty) expense.note!.trim(),
            '$methodLabel • $date $time',
            if (pending) 'Pending sync',
          ].join('\n'),
          style: DesignTokens.textSmall,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          'UGX ${expense.amount.toStringAsFixed(0)}',
          style: DesignTokens.textBodyBold.copyWith(color: DesignTokens.grayDark),
        ),
      ),
    );
  }

  String _methodLabel(String raw) {
    final m = raw.trim().toLowerCase();
    return switch (m) {
      'cash' => 'Cash',
      'mobile_money' => 'Mobile money',
      'bank_transfer' => 'Bank transfer',
      'card' => 'Card',
      _ => m.isEmpty ? 'Other' : m.replaceAll('_', ' '),
    };
  }
}

class _ExpenseFormResult {
  const _ExpenseFormResult({
    required this.amount,
    required this.method,
    required this.category,
    this.supplierId,
    this.note,
  });

  final double amount;
  final String method;
  final String category;
  final int? supplierId;
  final String? note;
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm();

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _method = 'cash';
  String _category = 'utilities';
  int? _supplierId;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(activeSuppliersProvider);

    final methods = const [
      ('cash', 'Cash'),
      ('mobile_money', 'Mobile money'),
      ('bank_transfer', 'Bank'),
      ('card', 'Card'),
      ('other', 'Other'),
    ];

    final categories = const [
      ('utilities', 'Utilities'),
      ('rent', 'Rent'),
      ('transport', 'Transport'),
      ('salary', 'Salary'),
      ('marketing', 'Marketing'),
      ('supplier', 'Supplier'),
      ('other', 'Other'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Payment method', style: DesignTokens.textBodyBold),
        const SizedBox(height: DesignTokens.spaceSm),
        Wrap(
          spacing: DesignTokens.spaceSm,
          runSpacing: DesignTokens.spaceSm,
          children: [
            for (final item in methods)
              ChoiceChip(
                label: Text(item.$2),
                selected: _method == item.$1,
                onSelected: (_) => setState(() => _method = item.$1),
              ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        Text('Category', style: DesignTokens.textBodyBold),
        const SizedBox(height: DesignTokens.spaceSm),
        Wrap(
          spacing: DesignTokens.spaceSm,
          runSpacing: DesignTokens.spaceSm,
          children: [
            for (final item in categories)
              ChoiceChip(
                label: Text(item.$2),
                selected: _category == item.$1,
                onSelected: (_) => setState(() => _category = item.$1),
              ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (UGX)',
            prefixIcon: Icon(Icons.money),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        if (_category == 'supplier')
          suppliers.when(
            data: (rows) {
              return DropdownButtonFormField<int?>(
                initialValue: _supplierId,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Select supplier (optional)'),
                  ),
                  ...rows.map(
                    (s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _supplierId = v),
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        if (_category == 'supplier') const SizedBox(height: DesignTokens.spaceMd),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: DesignTokens.spaceLg),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
            if (amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid amount')),
              );
              return;
            }

            Navigator.pop(
              context,
              _ExpenseFormResult(
                amount: amount,
                method: _method,
                category: _category,
                supplierId: _supplierId,
                note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
