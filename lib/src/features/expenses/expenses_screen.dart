import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/comma_number_formatter.dart';
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

// ─── Screen ───────────────────────────────────────────────────────────────────

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesStreamProvider);

    return Scaffold(
      backgroundColor: DesignTokens.canvasParchment,
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: DesignTokens.canvas,
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync_rounded),
            color: DesignTokens.inkMuted,
            onPressed: () async {
              await ref.read(syncServiceProvider).syncNow();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sync finished'),
                  backgroundColor: DesignTokens.ink,
                  behavior: SnackBarBehavior.floating,
                  shape: const StadiumBorder(),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpense(context, ref),
        backgroundColor: DesignTokens.brandAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Record',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        shape: const StadiumBorder(),
      ),
      body: expenses.when(
        data: (rows) => rows.isEmpty ? _EmptyState(onAdd: () => _showAddExpense(context, ref)) : _ExpenseList(rows: rows),
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

      final approved = await requireManagerPin(context, ref, reason: 'record an expense');
      if (!approved) return;
      if (!context.mounted) return;

      final form = await BottomSheetModal.show<_ExpenseFormResult>(
        context: context,
        title: 'Record Expense',
        child: const _ExpenseForm(),
      );
      if (form == null) return;

      final db = ref.read(appDatabaseProvider);
      final outletId = (await db.getPrimaryOutlet())?.id;
      final staffId = ref.read(posSessionProvider).staffId?.toString();
      final occurredAt = DateTime.now().toUtc();

      try {
        unawaited(telemetry?.event(
          'expense_create_submit',
          props: {'method': form.method, 'category': form.category},
        ));

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
            final tag = (form.category == 'supplier' || form.supplierId != null) ? 'supplier' : 'expense';
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
            backgroundColor: DesignTokens.ink,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
        unawaited(telemetry?.event(
          'expense_create_success',
          props: {'method': form.method, 'category': form.category},
        ));
      } catch (e, st) {
        unawaited(telemetry?.recordError(e, st, hint: 'expense_create'));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record expense: $e'),
            backgroundColor: DesignTokens.error,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
        unawaited(telemetry?.event('expense_create_failed', props: {'error': e.toString()}));
      }
    }());
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DesignTokens.canvasCloud,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: DesignTokens.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text('No expenses yet', style: DesignTokens.textTitle),
            const SizedBox(height: 8),
            Text(
              'Track operating costs — rent, utilities,\nsupplier payments, and more.',
              style: DesignTokens.textSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Record first expense'),
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List ─────────────────────────────────────────────────────────────────────

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.rows});
  final List<Expense> rows;

  @override
  Widget build(BuildContext context) {
    // Group by date
    final groups = <String, List<Expense>>{};
    for (final e in rows) {
      final d = e.occurredAt.toLocal();
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(e);
    }
    final keys = groups.keys.toList();

    return RefreshIndicator(
      color: DesignTokens.brandAccent,
      onRefresh: () async {},
      child: CustomScrollView(
        slivers: [
          // Summary bar
          SliverToBoxAdapter(child: _SummaryBar(rows: rows)),
          for (final key in keys) ...[
            SliverToBoxAdapter(child: _DateHeader(dateKey: key)),
            SliverList.separated(
              itemCount: groups[key]!.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
              ),
              itemBuilder: (context, i) => _ExpenseRow(expense: groups[key]![i]),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.rows});
  final List<Expense> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, e) => s + e.amount);
    final today = rows.where((e) {
      final d = e.occurredAt.toLocal();
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).fold<double>(0, (s, e) => s + e.amount);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusLg,
        border: Border.all(color: DesignTokens.hairline, width: 0.5),
      ),
      child: Row(
        children: [
          _SumCell(label: 'Total', amount: total),
          Container(width: 0.5, height: 40, color: DesignTokens.hairline, margin: const EdgeInsets.symmetric(horizontal: 20)),
          _SumCell(label: 'Today', amount: today),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DesignTokens.canvasCloud,
              borderRadius: DesignTokens.borderRadiusFull,
            ),
            child: Text(
              '${rows.length} entries',
              style: DesignTokens.textCaption.copyWith(color: DesignTokens.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SumCell extends StatelessWidget {
  const _SumCell({required this.label, required this.amount});
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesignTokens.textCaption),
        const SizedBox(height: 2),
        Text(
          'UGX ${_fmt(amount)}',
          style: DesignTokens.textMono.copyWith(fontSize: 17, letterSpacing: -0.3),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.dateKey});
  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final parts = dateKey.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final isYesterday = d.year == now.year && d.month == now.month && d.day == now.day - 1;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : '${d.day} ${months[d.month - 1]} ${d.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: DesignTokens.textCaption.copyWith(
          color: DesignTokens.inkMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final method = _methodIcon(expense.method);
    final pending = !expense.synced;

    return Container(
      color: DesignTokens.canvas,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: DesignTokens.canvasCloud,
            shape: BoxShape.circle,
          ),
          child: Icon(method.$1, size: 20, color: DesignTokens.inkSubtle),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                expense.category,
                style: DesignTokens.textBody.copyWith(
                  color: DesignTokens.ink,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pending)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DesignTokens.canvasCloud,
                  borderRadius: DesignTokens.borderRadiusFull,
                  border: Border.all(color: DesignTokens.hairline, width: 0.5),
                ),
                child: Text(
                  'Syncing',
                  style: DesignTokens.textCaption.copyWith(color: DesignTokens.inkMuted),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            [
              method.$2,
              if ((expense.note ?? '').trim().isNotEmpty) expense.note!.trim(),
              _timeLabel(expense.occurredAt),
            ].join(' · '),
            style: DesignTokens.textSmall.copyWith(color: DesignTokens.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Text(
          'UGX ${_fmtAmount(expense.amount)}',
          style: DesignTokens.textMono.copyWith(
            fontSize: 15,
            color: DesignTokens.ink,
          ),
        ),
      ),
    );
  }

  (IconData, String) _methodIcon(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'cash' => (Icons.payments_outlined, 'Cash'),
      'mobile_money' => (Icons.phone_android_outlined, 'Mobile money'),
      'bank_transfer' => (Icons.account_balance_outlined, 'Bank'),
      'card' => (Icons.credit_card_outlined, 'Card'),
      _ => (Icons.receipt_outlined, 'Other'),
    };
  }

  String _fmtAmount(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _timeLabel(DateTime utc) {
    final local = utc.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Form ─────────────────────────────────────────────────────────────────────

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

  static const _methods = [
    ('cash', 'Cash', Icons.payments_outlined),
    ('mobile_money', 'Mobile Money', Icons.phone_android_outlined),
    ('bank_transfer', 'Bank', Icons.account_balance_outlined),
    ('card', 'Card', Icons.credit_card_outlined),
    ('other', 'Other', Icons.receipt_outlined),
  ];

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount — hero field, largest element
        _buildAmountField(),
        const SizedBox(height: 20),

        // Payment method
        _buildLabel('Payment Method'),
        const SizedBox(height: 8),
        _buildMethodChips(),
        const SizedBox(height: 20),

        // Category
        _buildCategoryHeader(context),
        const SizedBox(height: 8),
        categoriesAsync.when(
          data: (cats) => _buildCategoryChips(cats),
          loading: () => const LinearProgressIndicator(color: DesignTokens.brandAccent),
          error: (e, _) => Text('Error loading categories: $e',
              style: DesignTokens.textSmall.copyWith(color: DesignTokens.error)),
        ),
        const SizedBox(height: 20),

        // Supplier dropdown (only for supplier category)
        if (_category.toLowerCase() == 'supplier') ...[
          suppliers.when(
            data: (rows) => _buildSupplierDropdown(rows),
            loading: () => const LinearProgressIndicator(color: DesignTokens.brandAccent),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
        ],

        // Note
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: const Icon(Icons.notes_outlined, size: 20),
            filled: true,
            fillColor: DesignTokens.canvasCloud,
            border: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.hairline, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.hairline, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.brandAccent, width: 1.5),
            ),
          ),
          style: DesignTokens.textBody.copyWith(color: DesignTokens.ink),
        ),
        const SizedBox(height: 28),

        // Save button
        FilledButton(
          onPressed: _onSave,
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.brandAccent,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            minimumSize: const Size(double.infinity, 52),
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
          child: const Text('Save Expense'),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Amount (UGX)'),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            const CommaNumberFormatter(),
          ],
          style: _interDisplayStyle(fontSize: 26, fontWeight: FontWeight.w700, color: DesignTokens.ink, letterSpacing: -0.5),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: _interDisplayStyle(fontSize: 26, fontWeight: FontWeight.w700, color: DesignTokens.inkDisabled, letterSpacing: -0.5),
            prefixText: 'UGX  ',
            prefixStyle: DesignTokens.textBody.copyWith(color: DesignTokens.inkMuted, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: DesignTokens.canvasCloud,
            border: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.hairline, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.hairline, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.brandAccent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _methods.map((item) {
        final selected = _method == item.$1;
        return GestureDetector(
          onTap: () => setState(() => _method = item.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? DesignTokens.ink : DesignTokens.canvasCloud,
              borderRadius: DesignTokens.borderRadiusFull,
              border: Border.all(
                color: selected ? DesignTokens.ink : DesignTokens.hairline,
                width: selected ? 0 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.$3,
                  size: 15,
                  color: selected ? Colors.white : DesignTokens.inkMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  item.$2,
                  style: DesignTokens.textSmall.copyWith(
                    color: selected ? Colors.white : DesignTokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLabel('Category'),
        GestureDetector(
          onTap: () => _showAddCategoryDialog(context),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 16, color: DesignTokens.brandAccent),
              const SizedBox(width: 4),
              Text(
                'New',
                style: DesignTokens.textSmall.copyWith(
                  color: DesignTokens.brandAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<ExpenseCategory> cats) {
    if (cats.isEmpty) {
      return Text(
        'No categories. Add one above or sync.',
        style: DesignTokens.textSmall.copyWith(color: DesignTokens.inkMuted),
      );
    }

    if (_category.isEmpty && cats.isNotEmpty) {
      Future.microtask(() {
        if (mounted && _category.isEmpty) setState(() => _category = cats.first.name);
      });
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cats.map((cat) {
        final selected = _category == cat.name;
        return GestureDetector(
          onTap: () => setState(() => _category = cat.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? DesignTokens.brandAccentDim : DesignTokens.canvasCloud,
              borderRadius: DesignTokens.borderRadiusFull,
              border: Border.all(
                color: selected ? DesignTokens.brandAccent : DesignTokens.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              cat.name,
              style: DesignTokens.textSmall.copyWith(
                color: selected ? DesignTokens.brandAccent : DesignTokens.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupplierDropdown(List<Supplier> rows) {
    return DropdownButtonFormField<int?>(
      initialValue: _supplierId,
      decoration: InputDecoration(
        labelText: 'Supplier (optional)',
        prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20),
        filled: true,
        fillColor: DesignTokens.canvasCloud,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMd,
          borderSide: const BorderSide(color: DesignTokens.brandAccent, width: 1.5),
        ),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Select supplier')),
        ...rows.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
      ],
      onChanged: (v) => setState(() => _supplierId = v),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: DesignTokens.textSmall.copyWith(
        fontWeight: FontWeight.w600,
        color: DesignTokens.inkSubtle,
        letterSpacing: 0,
      ),
    );
  }

  void _onSave() {
    final rawAmount = CommaNumberFormatter.unformat(_amountCtrl.text.trim());
    final amount = double.tryParse(rawAmount) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount greater than 0'),
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
      return;
    }
    if (_category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a category'),
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
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
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.canvas,
        shape: const RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusLg),
        title: Text('New Category', style: DesignTokens.textTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. Repairs, Internet, Transport',
            hintStyle: DesignTokens.textBody.copyWith(color: DesignTokens.inkDisabled),
            filled: true,
            fillColor: DesignTokens.canvasCloud,
            border: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DesignTokens.borderRadiusMd,
              borderSide: const BorderSide(color: DesignTokens.brandAccent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: DesignTokens.inkMuted, shape: const StadiumBorder()),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, ctrl.text.trim());
            },
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final db = ref.read(appDatabaseProvider);
      final sync = ref.read(syncServiceProvider);

      final tempId = -(DateTime.now().microsecondsSinceEpoch % 2147483647);
      await db.upsertExpenseCategory(
        ExpenseCategoriesCompanion(
          id: drift.Value(tempId),
          name: drift.Value(result),
          type: const drift.Value('expense'),
          isActive: const drift.Value(true),
        ),
      );

      setState(() => _category = result);

      final idempotencyKey =
          'cat_${result.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      await sync.enqueue('expense_category_create', {
        'name': result,
        'type': 'expense',
        'idempotency_key': idempotencyKey,
      });

      unawaited(sync.syncNow());
    }
  }
}

// ─── Typography helper (Inter Display weight for amount field) ─────────────────

TextStyle _interDisplayStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: 'Inter',
    package: 'google_fonts',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: [const FontFeature.tabularFigures()],
  );
}
