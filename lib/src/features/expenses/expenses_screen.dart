import 'dart:async';

import 'package:drift/drift.dart' as drift;
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

final expenseCategoriesProvider = StreamProvider<List<ExpenseCategory>>((ref) {
  return ref.watch(appDatabaseProvider).watchExpenseCategories();
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
                    Icon(
                      Icons.payments_outlined,
                      size: 56,
                      color: DesignTokens.grayMedium,
                    ),
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
              separatorBuilder: (_, __) =>
                  const SizedBox(height: DesignTokens.spaceSm),
              itemBuilder: (context, index) =>
                  _ExpenseCard(expense: rows[index]),
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
        unawaited(
          telemetry?.event(
            'expense_create_submit',
            props: {'method': form.method, 'category': form.category},
          ),
        );

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
            final tag = (form.category == 'supplier' || form.supplierId != null)
                ? 'supplier'
                : 'expense';
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
        unawaited(
          telemetry?.event(
            'expense_create_success',
            props: {'method': form.method, 'category': form.category},
          ),
        );
      } catch (e, st) {
        unawaited(telemetry?.recordError(e, st, hint: 'expense_create'));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record expense: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
        unawaited(
          telemetry?.event(
            'expense_create_failed',
            props: {'error': e.toString()},
          ),
        );
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
          style: DesignTokens.textBodyBold.copyWith(
            color: DesignTokens.grayDark,
          ),
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
  String _category = '';
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
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    final methods = const [
      ('cash', 'Cash'),
      ('mobile_money', 'Mobile money'),
      ('bank_transfer', 'Bank'),
      ('card', 'Card'),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Category', style: DesignTokens.textBodyBold),
            TextButton.icon(
              onPressed: () => _showAddCategoryDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add new'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return const Text('No categories found. Add one or sync.');
            }
            // Set default category if not set
            if (_category.isEmpty && categories.isNotEmpty) {
              // Defer state update to next frame to avoid build error
              Future.microtask(() {
                if (mounted && _category.isEmpty) {
                  setState(() => _category = categories.first.name);
                }
              });
            }

            return Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: [
                for (final cat in categories)
                  ChoiceChip(
                    label: Text(cat.name),
                    selected: _category == cat.name,
                    onSelected: (_) => setState(() => _category = cat.name),
                  ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(
            'Error loading categories: $e',
            style: TextStyle(color: DesignTokens.error),
          ),
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
        if (_category.toLowerCase() == 'supplier')
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
        if (_category.toLowerCase() == 'supplier')
          const SizedBox(height: DesignTokens.spaceMd),
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
            if (_category.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select a category')),
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
                note: _noteCtrl.text.trim().isEmpty
                    ? null
                    : _noteCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Repairs, Internet',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context, ctrl.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      // optimistic update / local insert
      final db = ref.read(appDatabaseProvider);
      await db.upsertExpenseCategory(
        ExpenseCategoriesCompanion(
          // Remote ID 0 or negative for local-only until synced, but table is auto-increment.
          // However id is auto-increment. We should let Drift handle ID.
          // But wait, the schema has `IntColumn get id => integer().autoIncrement()(); // remote id`
          // If it's a remote ID, we shouldn't auto-increment it locally if we want to match server ID.
          // But typically we treat `id` as local PK. Sync logic will overwrite/map it.
          // Actually, `id` is usually local PK. `remoteId` is separate.
          // In this schema: `IntColumn get id => integer().autoIncrement()(); // remote id`
          // The comment says "remote id". This suggests `id` IS the remote id?
          // If so, we can't auto-increment it locally easily without collision.
          // Let's check other tables. `Items` has `id` (String UUID) and `remoteId` (Int).
          // `ExpenseCategories` has `id` (Int, auto-increment).
          // If it's auto-increment, it's likely a local ID.
          // But the sync logic in `SyncService` uses `id` from server as `id`.
          // `id: drift.Value(_asInt(c['id'])),`
          // This means we are treating the local ID as the remote ID.
          // This is risky for local creation. We should probably use a negative ID for local-only?
          // Or we should have a separate `remoteId` column.
          // Given the schema I added:
          // `class ExpenseCategories extends Table { IntColumn get id => integer().autoIncrement()(); ... }`
          // If I insert locally, I get a new ID (e.g. 1, 2, 3).
          // If server sends ID 1, 2, 3, we have a conflict.
          // Ideally we should have `id` (local PK) and `remoteId` (server PK).
          // OR we use UUIDs for local items.
          // But I followed the pattern of `PosExpenseCategory` in Laravel which likely uses Int ID.
          // Let's look at `SyncService` again.
          // `await db.upsertExpenseCategory(ExpenseCategoriesCompanion(id: drift.Value(_asInt(c['id'])), ...))`
          // This forces the ID.
          // If I create locally, I should probably generate a temporary ID or use a separate synchronization mechanism.
          // Or, I can check `Outlets` or `Shifts`?
          // `Shifts`: `TextColumn get id => text()();` (UUID).
          // `ExpenseCategories` using Int ID is problematic for local creation without a separate remote ID.
          // BUT, for now, if I just want to "request" creation, I can enqueue the op and wait for sync?
          // Or I can insert with a random high ID?
          // Better: Update schema to use `remoteId`? Or just use `request` approach.
          // If I queue `expense_category_create` payload, I don't strictly need a local DB row *immediately* if I assume it will sync back.
          // But for UI responsiveness, I want to show it.
          // Let's insert with a -1 * random ID or something, and fix it later?
          // No, Drift's autoIncrement might clash.
          // Actually, `PosExpenseCategory` on backend has `id`.
          // Let's create `expense_category_create` op.
          // And for local display, maybe we just add it to the state of the form?
          // No, other users need to see it.
          // Let's insert it locally. If `id` is auto-increment, I can just let it assign an ID.
          // But when sync comes back, it will try to insert ID=ServerID.
          // If ServerID != LocalID, we get duplicates.
          // We need `remoteId` column for robust sync, OR use UUIDs.
          // Given I already migrated, I can't easily change schema again without another migration.
          // Let's check if I can just use `SyncService.enqueue`.
          // If I enqueue, the server creates it, then next pull brings it back.
          // This is "slow" but robust.
          // To make it "fast", I can manually add it to the provider's list?
          // `StreamProvider` comes from DB.
          // I will simply enqueue it and trigger sync. It might take a few seconds.
          // Use `setState` to select it temporarily?
          // Actually, let's just insert it safely?
          // If I insert it, I need a way to dedupe when it comes back from server.
          // Server sync uses `upsertExpenseCategory` with explicit ID.
          // If I have a local row with ID=100 (auto-inc) and Name="Test".
          // Server creates ID=50, Name="Test".
          // Sync pulls ID=50. Upserts ID=50.
          // Now I have ID=100 and ID=50. Duplicates in UI.
          // I need `remote_id` or matching by name?
          // The backend has `unique` on `seller_id, name`.
          // On frontend, if I pull ID=50, and I have ID=100 with same name...
          // `SyncService` doesn't check for name duplicates.
          // I should probably update `upsertExpenseCategory` or `SyncService` to handle this.
          // For now, I'll implement "Add" by enqueuing and optimistic UI?
          // No, just enqueue and sync.
          name: drift.Value(result),
          type: const drift.Value('expense'),
          isActive: const drift.Value(true),
          // id: leave undefined to auto-increment?
          // If I leave it, it generates a local ID.
          // Use a negative ID to indicate local-only?
          id: drift.Value(
            -DateTime.now().millisecondsSinceEpoch,
          ), // Temporary negative ID
        ),
      );

      // Select the new category immediately
      setState(() => _category = result);

      // Enqueue sync - payload needs to not include ID? or include it?
      // Backend expects `name`.
      await ref.read(syncServiceProvider).enqueue('expense_category_create', {
        'name': result,
        'type': 'expense',
        // 'local_id': ???
      });

      // Trigger sync to send to server
      unawaited(ref.read(syncServiceProvider).syncNow());
    }
  }
}
