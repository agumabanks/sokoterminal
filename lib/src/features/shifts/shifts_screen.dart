import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/util/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/security/manager_approval.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';

final openShiftProvider = StreamProvider<Shift?>((ref) {
  return ref.watch(appDatabaseProvider).watchOpenShift();
});

final cashMovementsProvider = StreamProvider<List<CashMovement>>((ref) {
  return ref.watch(appDatabaseProvider).watchCashMovements(limit: 100);
});

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openShift = ref.watch(openShiftProvider);
    final movements = ref.watch(cashMovementsProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Shifts & Cash', style: DesignTokens.textTitle),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sync started…')));
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
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          openShift.when(
            data: (shift) => _ShiftStatusCard(shift: shift),
            loading: () => const _CardLoading(),
            error: (e, _) => _CardError(title: 'Shift status failed', error: e),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          if (openShift.hasValue)
            _ActionsCard(openShift: openShift.asData?.value),
          const SizedBox(height: DesignTokens.spaceLg),
          Text('Recent cash activity', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          movements.when(
            data: (rows) => rows.isEmpty
                ? _EmptyMovements()
                : Column(
                    children: rows
                        .map((m) => _MovementTile(movement: m))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load cash movements: $e'),
          ),
        ],
      ),
    );
  }
}

final _shiftTransactionsProvider = StreamProvider(
  (ref) => ref.watch(appDatabaseProvider).watchTransactions(),
);
final _shiftSummaryProvider = FutureProvider.autoDispose
    .family<_ShiftCashSummary, Shift>((ref, shift) async {
      ref.watch(cashMovementsProvider);
      ref.watch(_shiftTransactionsProvider);
      final db = ref.watch(appDatabaseProvider);
      return _ShiftCashSummary(
        opening: shift.openingFloat,
        cashSales: await db.computeCashSalesSince(shift.openedAt),
        netMovements: await db.computeCashMovementsNetSince(shift.openedAt),
      );
    });

class _ShiftStatusCard extends ConsumerWidget {
  const _ShiftStatusCard({required this.shift});
  final Shift? shift;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = shift;
    if (active == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.storefront_outlined, size: 32),
            SizedBox(height: 12),
            Text(
              'Ready to start your day?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Count the cash already in your till and start a shift. During the day, record money added or taken out. End by counting the till again.',
            ),
          ],
        ),
      );
    }
    final summary = ref.watch(_shiftSummaryProvider(active));
    final time = active.openedAt.toLocal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.brandPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text(
                'Shift in progress',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Started ${time.day}/${time.month} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Expected cash in the till',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          summary.when(
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.expected.toUgx(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                for (final row in [
                  ('Opening cash', value.opening),
                  ('Cash sales', value.cashSales),
                  ('Added / taken out', value.netMovements),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.$1,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        Text(
                          row.$2.toUgx(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text(
              'Could not calculate cash. Tap sync to retry.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mobile money and card payments are not cash in your till.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ShiftCashSummary {
  const _ShiftCashSummary({
    required this.opening,
    required this.cashSales,
    required this.netMovements,
  });

  final double opening;
  final double cashSales;
  final double netMovements;

  double get expected => opening + cashSales + netMovements;
}

class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({required this.openShift});

  final Shift? openShift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            openShift == null ? 'Start here' : 'Manage your till',
            style: DesignTokens.textBodyBold,
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          if (openShift == null)
            ElevatedButton.icon(
              onPressed: () => _openShiftSheet(context, ref),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start shift'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.brandAccent,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(() async {
                      final approved = await requireManagerPin(
                        context,
                        ref,
                        reason: 'record a cash in (float)',
                      );
                      if (!approved || !context.mounted) return;
                      _cashMovementSheet(context, ref, type: 'float');
                    }()),
                    icon: const Icon(Icons.add),
                    label: const Text('Cash in'),
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(() async {
                      final approved = await requireManagerPin(
                        context,
                        ref,
                        reason: 'record a cash out',
                      );
                      if (!approved || !context.mounted) return;
                      _cashMovementSheet(context, ref, type: 'withdrawal');
                    }()),
                    icon: const Icon(Icons.remove),
                    label: const Text('Cash out'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            ElevatedButton.icon(
              onPressed: () => _closeShiftSheet(context, ref, openShift!),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End shift & count cash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openShiftSheet(BuildContext context, WidgetRef ref) {
    _showCashForm(
      context,
      title: 'Start shift',
      label: 'Cash already in the till (UGX)',
      help: 'Count your opening cash. Enter 0 if the till is empty.',
      allowZero: true,
      submit: (amount, note, category) async {
        final db = ref.read(appDatabaseProvider);
        final sync = ref.read(syncServiceProvider);
        await db.transaction(() async {
          if (await db.getOpenShift() != null) {
            throw StateError('A shift is already open.');
          }
          final outletId = (await db.getPrimaryOutlet())?.id;
          final staffId = ref.read(posSessionProvider).staffId?.toString();
          final shiftId = await db.openShift(
            openingFloat: amount,
            outletId: outletId,
            staffId: staffId,
          );
          await sync.enqueue('shift_open', {
            'idempotency_key': shiftId,
            'shift_id': shiftId,
            'opened_at': DateTime.now().toUtc().toIso8601String(),
            'opening_float': amount,
            if (staffId != null) 'staff_id': staffId,
            if (outletId != null) 'outlet_id': outletId,
          });
          await db.recordCashMovement(
            type: 'open',
            amount: amount,
            note: 'Open shift ($shiftId)',
            outletId: outletId,
            staffId: staffId,
          );
        });
        unawaited(sync.syncNow());
      },
    );
  }

  void _cashMovementSheet(
    BuildContext context,
    WidgetRef ref, {
    required String type,
  }) {
    final withdrawal = type == 'withdrawal';
    _showCashForm(
      context,
      title: withdrawal ? 'Take cash out' : 'Add cash',
      label: 'Amount (UGX)',
      help: withdrawal
          ? 'Record money leaving the till, such as an expense or owner withdrawal.'
          : 'Record extra cash added to the till. Sales are counted automatically.',
      allowZero: false,
      categories: withdrawal
          ? const [
              ('expense', 'Expense'),
              ('supplier', 'Supplier'),
              ('owner', 'Owner'),
              ('other', 'Other'),
            ]
          : const [
              ('topup', 'Top-up'),
              ('change', 'Change'),
              ('other', 'Other'),
            ],
      submit: (amount, note, category) async {
        final db = ref.read(appDatabaseProvider);
        await db.transaction(() async {
          final shift = await db.getOpenShift();
          if (shift == null) {
            throw StateError('Start a shift before recording cash.');
          }
          final staffId = ref.read(posSessionProvider).staffId?.toString();
          String? expenseId;
          if (withdrawal && category != 'owner') {
            expenseId = await db.recordExpense(
              amount: amount,
              method: 'cash',
              category: category,
              note: note.isEmpty ? null : note,
              outletId: shift.outletId,
              staffId: staffId,
              occurredAt: DateTime.now().toUtc(),
            );
          }
          final id = await db.recordCashMovement(
            type: type,
            amount: amount,
            note: '[$category] $note',
            linkedExpenseId: expenseId,
            outletId: shift.outletId,
            staffId: staffId,
          );
          await db.recordAuditLog(
            actorStaffId: staffId,
            action: 'cash_movement_$type',
            payload: {
              'movement_id': id,
              if (expenseId != null) 'linked_expense_id': expenseId,
              'amount': amount,
              'tag': category,
              'note': note,
            },
          );
        });
        unawaited(ref.read(syncServiceProvider).syncNow());
      },
    );
  }

  Future<void> _closeShiftSheet(
    BuildContext context,
    WidgetRef ref,
    Shift shift,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final expected =
        shift.openingFloat +
        await db.computeCashSalesSince(shift.openedAt) +
        await db.computeCashMovementsNetSince(shift.openedAt);
    if (!context.mounted) return;
    _showCashForm(
      context,
      title: 'End shift',
      label: 'Cash you counted (UGX)',
      help: 'Count the cash in your till before ending the shift.',
      allowZero: true,
      expected: expected,
      submit: (amount, note, category) async {
        final sync = ref.read(syncServiceProvider);
        await db.transaction(() async {
          if ((await db.getOpenShift())?.id != shift.id) {
            throw StateError('This shift is no longer open.');
          }
          await db.closeShift(shiftId: shift.id, closingFloat: amount);
          await sync.enqueue('shift_close', {
            'idempotency_key': shift.id,
            'shift_id': shift.id,
            'closed_at': DateTime.now().toUtc().toIso8601String(),
            'closing_float': amount,
          });
          await db.recordCashMovement(
            type: 'close',
            amount: amount,
            note: 'Close shift (${shift.id})',
            outletId: shift.outletId,
            staffId: shift.staffId,
          );
        });
        unawaited(sync.syncNow());
      },
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final CashMovement movement;

  @override
  Widget build(BuildContext context) {
    final isOut = movement.type == 'withdrawal';
    final isClose = movement.type == 'close';
    final isOpen = movement.type == 'open';

    Color color = DesignTokens.brandAccent;
    IconData icon = Icons.add;
    String label = 'Cash in';
    final tag = _extractTag(movement.note);
    if (isOut) {
      color = DesignTokens.error;
      icon = Icons.remove;
      label = switch (tag) {
        'expense' => 'Expense',
        'supplier' => 'Supplier payment',
        'owner' => 'Owner withdrawal',
        _ => 'Cash out',
      };
    } else if (isOpen) {
      color = DesignTokens.brandPrimary;
      icon = Icons.play_circle_outline;
      label = 'Open shift';
    } else if (isClose) {
      color = DesignTokens.brandPrimary;
      icon = Icons.stop_circle_outlined;
      label = 'Close shift';
    }

    final created = movement.createdAt.toLocal();
    final time =
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: ListTile(
        leading: Container(
          padding: DesignTokens.paddingSm,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: DesignTokens.borderRadiusSm,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: DesignTokens.textBodyBold),
        subtitle: Text(
          _stripTag(movement.note) ?? '',
          style: DesignTokens.textSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${movement.amount.toStringAsFixed(0)} /=',
              style: DesignTokens.textBodyBold.copyWith(
                color: isOut ? DesignTokens.error : DesignTokens.grayDark,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXxs),
            Text(time, style: DesignTokens.textSmall),
          ],
        ),
      ),
    );
  }

  String? _extractTag(String? note) {
    if (note == null) return null;
    final trimmed = note.trimLeft();
    if (!trimmed.startsWith('[')) return null;
    final end = trimmed.indexOf(']');
    if (end <= 1) return null;
    return trimmed.substring(1, end).trim().toLowerCase();
  }

  String? _stripTag(String? note) {
    if (note == null) return null;
    final trimmed = note.trimLeft();
    if (!trimmed.startsWith('[')) return note;
    final end = trimmed.indexOf(']');
    if (end == -1) return note;
    final rest = trimmed.substring(end + 1).trimLeft();
    return rest.isEmpty ? null : rest;
  }
}

class _EmptyMovements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            padding: DesignTokens.paddingSm,
            decoration: BoxDecoration(
              color: DesignTokens.grayLight.withValues(alpha: 0.4),
              borderRadius: DesignTokens.borderRadiusSm,
            ),
            child: const Icon(Icons.money_off, color: DesignTokens.grayMedium),
          ),
          const SizedBox(width: DesignTokens.spaceMd),
          Expanded(
            child: Text(
              'No cash movements yet.',
              style: DesignTokens.textBodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError({required this.title, required this.error});

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(error.toString(), style: DesignTokens.textSmall),
        ],
      ),
    );
  }
}

Future<void> _showCashForm(
  BuildContext context, {
  required String title,
  required String label,
  required String help,
  required bool allowZero,
  double? expected,
  List<(String, String)> categories = const [],
  required Future<void> Function(double, String, String) submit,
}) async {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String category = categories.isEmpty ? '' : categories.first.$1;
  bool saving = false;
  String? error;
  await BottomSheetModal.show(
    context: context,
    title: title,
    showCloseButton: false,
    isDismissible: false,
    enableDrag: false,
    child: StatefulBuilder(
      builder: (ctx, update) => PopScope(
        canPop: !saving,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(help),
              const SizedBox(height: 16),
              if (expected != null)
                Text(
                  'Expected: ${expected.toUgx()}',
                  style: DesignTokens.textBodyBold,
                ),
              TextField(
                controller: amountCtrl,
                enabled: !saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => update(() {}),
                decoration: InputDecoration(
                  labelText: label,
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (expected != null && double.tryParse(amountCtrl.text) != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Difference: ${(double.parse(amountCtrl.text) - expected).toUgx()}',
                    style: DesignTokens.textBodyBold,
                  ),
                ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in categories)
                      ChoiceChip(
                        label: Text(entry.$2),
                        selected: category == entry.$1,
                        onSelected: saving
                            ? null
                            : (_) => update(() => category = entry.$1),
                      ),
                  ],
                ),
                TextField(
                  controller: noteCtrl,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text);
                        if (amount == null ||
                            !amount.isFinite ||
                            amount < 0 ||
                            (!allowZero && amount == 0)) {
                          update(
                            () => error = allowZero
                                ? 'Enter the amount you counted, including 0.'
                                : 'Enter an amount above 0.',
                          );
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await submit(amount, noteCtrl.text.trim(), category);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() {
                              saving = false;
                              error = '$e';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : title),
              ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future.delayed(const Duration(seconds: 1), () {
    amountCtrl.dispose();
    noteCtrl.dispose();
  });
}
