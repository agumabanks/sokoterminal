import 'dart:async';

import 'package:flutter/material.dart';
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync started…')),
              );
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
          _ActionsCard(openShift: openShift.asData?.value),
          const SizedBox(height: DesignTokens.spaceLg),
          Text('Cash movements', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceSm),
          movements.when(
            data: (rows) => rows.isEmpty
                ? _EmptyMovements()
                : Column(
                    children: rows.map((m) => _MovementTile(movement: m)).toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load cash movements: $e'),
          ),
        ],
      ),
    );
  }
}

class _ShiftStatusCard extends ConsumerWidget {
  const _ShiftStatusCard({required this.shift});

  final Shift? shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shift == null) {
      return Container(
        padding: DesignTokens.paddingLg,
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite,
          borderRadius: DesignTokens.borderRadiusLg,
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
              child: const Icon(Icons.lock_clock, color: DesignTokens.grayMedium),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No shift open', style: DesignTokens.textBodyBold),
                  const SizedBox(height: DesignTokens.spaceXxs),
                  Text(
                    'Open a shift to track cash in/out and close with counted cash.',
                    style: DesignTokens.textSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final openedAt = shift!.openedAt.toLocal();
    final openedText =
        '${openedAt.year}-${openedAt.month.toString().padLeft(2, '0')}-${openedAt.day.toString().padLeft(2, '0')} '
        '${openedAt.hour.toString().padLeft(2, '0')}:${openedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: DesignTokens.paddingLg,
      decoration: BoxDecoration(
        gradient: DesignTokens.brandGradient,
        borderRadius: DesignTokens.borderRadiusLg,
        boxShadow: DesignTokens.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock, color: DesignTokens.surfaceWhite),
              const SizedBox(width: DesignTokens.spaceSm),
              Text('Shift open', style: DesignTokens.textTitleLight),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceSm,
                  vertical: DesignTokens.spaceXxs,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceWhite.withValues(alpha: 0.18),
                  borderRadius: DesignTokens.borderRadiusSm,
                ),
                child: Text(openedText, style: DesignTokens.textSmallLight),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          FutureBuilder<_ShiftCashSummary>(
            future: _computeSummary(ref, shift!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text('Calculating…', style: DesignTokens.textSmallLight);
              }
              final summary = snapshot.data;
              if (summary == null) {
                return Text('Cash summary unavailable', style: DesignTokens.textSmallLight);
              }

              return Row(
                children: [
                  _MetricPill(label: 'Opening', value: 'UGX ${summary.opening.toStringAsFixed(0)}'),
                  const SizedBox(width: DesignTokens.spaceSm),
                  _MetricPill(label: 'Cash sales', value: 'UGX ${summary.cashSales.toStringAsFixed(0)}'),
                  const SizedBox(width: DesignTokens.spaceSm),
                  _MetricPill(label: 'Net in/out', value: 'UGX ${summary.netMovements.toStringAsFixed(0)}'),
                ],
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          FutureBuilder<_ShiftCashSummary>(
            future: _computeSummary(ref, shift!),
            builder: (context, snapshot) {
              final expected = snapshot.data?.expected ?? shift!.openingFloat;
              return Text(
                'Expected cash now: UGX ${expected.toStringAsFixed(0)}',
                style: DesignTokens.textBodyLight.copyWith(fontWeight: FontWeight.w700),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<_ShiftCashSummary> _computeSummary(WidgetRef ref, Shift shift) async {
    final db = ref.read(appDatabaseProvider);
    final cashSales = await db.computeCashSalesSince(shift.openedAt);
    final netMovements = await db.computeCashMovementsNetSince(shift.openedAt);
    return _ShiftCashSummary(
      opening: shift.openingFloat,
      cashSales: cashSales,
      netMovements: netMovements,
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSm,
          vertical: DesignTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceWhite.withValues(alpha: 0.16),
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: DesignTokens.textSmallLight),
            const SizedBox(height: DesignTokens.spaceXxs),
            Text(
              value,
              style: DesignTokens.textBodyLight.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
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
          Text('Actions', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceMd),
          if (openShift == null)
            ElevatedButton.icon(
              onPressed: () => _openShiftSheet(context, ref),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Open shift'),
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.brandAccent),
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
              label: const Text('Close shift'),
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.error),
            ),
          ],
        ],
      ),
    );
  }

  void _openShiftSheet(BuildContext context, WidgetRef ref) {
    final floatCtrl = TextEditingController(text: '0');
    BottomSheetModal.show(
      context: context,
      title: 'Open shift',
      subtitle: 'Enter opening float',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: floatCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Opening cash (UGX)',
              prefixIcon: Icon(Icons.money),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton(
            onPressed: () async {
              final opening = double.tryParse(floatCtrl.text.trim()) ?? 0;
              final db = ref.read(appDatabaseProvider);
              final outletId = (await db.getPrimaryOutlet())?.id;
              final staffId = ref.read(posSessionProvider).staffId?.toString();
              final shiftId = await db.openShift(
                openingFloat: opening,
                outletId: outletId,
                staffId: staffId,
              );
              await db.recordCashMovement(
                type: 'open',
                amount: opening,
                note: 'Open shift ($shiftId)',
                outletId: outletId,
                staffId: staffId,
              );
              unawaited(ref.read(syncServiceProvider).syncNow());
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Shift opened'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
            child: const Text('Open shift'),
          ),
        ],
      ),
    );
  }

  void _cashMovementSheet(
    BuildContext context,
    WidgetRef ref, {
    required String type,
  }) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final title = type == 'withdrawal' ? 'Cash out' : 'Cash in';
    String category = type == 'withdrawal' ? 'expense' : 'topup';
    BottomSheetModal.show(
      context: context,
      title: title,
      subtitle: 'Record a ${type == 'withdrawal' ? 'withdrawal' : 'float'}',
      child: StatefulBuilder(
        builder: (context, setState) {
          final categories = type == 'withdrawal'
              ? const [
                  ('expense', 'Expense'),
                  ('supplier', 'Supplier payment'),
                  ('owner', 'Owner withdrawal'),
                  ('other', 'Other'),
                ]
              : const [
                  ('topup', 'Top-up'),
                  ('change', 'Change / float'),
                  ('other', 'Other'),
                ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reason', style: DesignTokens.textBodyBold),
              const SizedBox(height: DesignTokens.spaceSm),
              Wrap(
                spacing: DesignTokens.spaceSm,
                runSpacing: DesignTokens.spaceSm,
                children: [
                  for (final item in categories)
                    ChoiceChip(
                      label: Text(item.$2),
                      selected: category == item.$1,
                      onSelected: (_) => setState(() => category = item.$1),
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (UGX)',
                  prefixIcon: Icon(Icons.money),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amount <= 0) return;

                  final note = noteCtrl.text.trim();
                  final storedNote = note.isEmpty ? '[$category]' : '[$category] $note';

                  final db = ref.read(appDatabaseProvider);
                  final outletId = (await db.getPrimaryOutlet())?.id;
                  final staffId = ref.read(posSessionProvider).staffId?.toString();

                  final movementId = await db.recordCashMovement(
                        type: type,
                        amount: amount,
                        note: storedNote,
                        outletId: outletId,
                        staffId: staffId,
                      );
                  if (type == 'withdrawal' || type == 'float') {
                    await db.recordAuditLog(
                      actorStaffId: staffId,
                      action: 'cash_movement_$type',
                      payload: {
                        'movement_id': movementId,
                        'amount': amount,
                        'tag': category,
                        'note': note,
                      },
                    );
                  }
                  unawaited(ref.read(syncServiceProvider).syncNow());
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${type == 'withdrawal' ? 'Cash out' : 'Cash in'} recorded'),
                      backgroundColor: DesignTokens.brandAccent,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _closeShiftSheet(BuildContext context, WidgetRef ref, Shift shift) {
    final countedCtrl = TextEditingController();
    BottomSheetModal.show(
      context: context,
      title: 'Close shift',
      subtitle: 'Enter counted cash',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: countedCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Counted cash (UGX)',
              prefixIcon: Icon(Icons.money),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ElevatedButton(
            onPressed: () async {
              final counted = double.tryParse(countedCtrl.text.trim()) ?? 0;
              final db = ref.read(appDatabaseProvider);
              await db.closeShift(shiftId: shift.id, closingFloat: counted);
              await db.recordCashMovement(
                type: 'close',
                amount: counted,
                note: 'Close shift (${shift.id})',
                outletId: shift.outletId,
                staffId: shift.staffId,
              );
              unawaited(ref.read(syncServiceProvider).syncNow());
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Shift closed'),
                  backgroundColor: DesignTokens.brandAccent,
                ),
              );
            },
            child: const Text('Close shift'),
          ),
        ],
      ),
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
              'UGX ${movement.amount.toStringAsFixed(0)}',
              style: DesignTokens.textBodyBold.copyWith(color: isOut ? DesignTokens.error : DesignTokens.grayDark),
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
