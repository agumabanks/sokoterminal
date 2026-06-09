import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../checkout/cart_controller.dart';
import '../checkout/checkout_screen.dart';

/// Job Timer — One-tap time tracking for service providers.
///
/// Design principles:
/// - One tap to start, one tap to stop.
/// - Duration auto-calculated from start/end epochs.
/// - Price auto-filled from service price.
/// - Costs are optional ( progressive disclosure ).
/// - Everything works offline and syncs later.
class JobTimerScreen extends ConsumerStatefulWidget {
  const JobTimerScreen({
    super.key,
    this.bookingId,
    this.serviceId,
    this.clientName,
    this.clientPhone,
  });

  final String? bookingId;
  final String? serviceId;
  final String? clientName;
  final String? clientPhone;

  @override
  ConsumerState<JobTimerScreen> createState() => _JobTimerScreenState();
}

class _JobTimerScreenState extends ConsumerState<JobTimerScreen> {
  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  ServiceJobSession? _activeSession;
  bool _loading = true;

  // Form state for when timer stops
  final _noteCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();
  final List<_CostLine> _costs = [];

  @override
  void initState() {
    super.initState();
    _resumeOrInit();
  }

  Future<void> _resumeOrInit() async {
    final db = ref.read(appDatabaseProvider);
    final active = await db.getActiveJobSession();
    if (active != null) {
      setState(() {
        _activeSession = active;
        _elapsedSeconds = DateTime.now().difference(active.startedAt).inSeconds;
        _startTick();
      });
    }
    setState(() => _loading = false);
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopTick() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  Future<void> _startJob() async {
    final db = ref.read(appDatabaseProvider);
    final service = widget.serviceId != null
        ? await db.getServiceById(widget.serviceId!)
        : null;

    final session = ServiceJobSession(
      id: const Uuid().v4(),
      serviceId: widget.serviceId ?? '',
      clientName: widget.clientName,
      clientPhone: widget.clientPhone,
      startedAt: DateTime.now(),
      endedAt: null,
      durationMinutes: null,
      description: null,
      materialsCost: 0,
      laborCharge: 0,
      finalCharge: service?.price ?? 0,
      photosJson: null,
      pipelineStage: 'in_progress',
      synced: false,
      createdAt: DateTime.now().toUtc(),
    );

    await db.upsertJobSession(session.toCompanion(true));
    setState(() {
      _activeSession = session;
      _elapsedSeconds = 0;
      _chargeCtrl.text = (service?.price ?? 0).toStringAsFixed(0);
    });
    _startTick();
  }

  Future<void> _stopJob() async {
    _stopTick();
    final db = ref.read(appDatabaseProvider);
    final endedAt = DateTime.now();
    final durationMin = _elapsedSeconds ~/ 60;

    final updated = _activeSession!.copyWith(
      endedAt: Value(endedAt),
      durationMinutes: Value(durationMin),
    );
    await db.upsertJobSession(updated.toCompanion(true));
    setState(() => _activeSession = updated);
  }

  Future<void> _saveAndCharge() async {
    if (_activeSession == null) return;

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);
    final charge = double.tryParse(_chargeCtrl.text.trim()) ?? 0;
    final totalCost = _costs.fold<double>(0, (s, c) => s + c.amount);

    final note = _noteCtrl.text.trim();
    final materialsJson = _costs.isNotEmpty
        ? jsonEncode(_costs.map((c) => {'item': c.name, 'cost': c.amount}).toList())
        : null;

    final saved = _activeSession!.copyWith(
      description: Value(note.isEmpty ? null : note),
      materialsCost: totalCost,
      finalCharge: charge,
      photosJson: Value(materialsJson),
      pipelineStage: 'awaiting_payment',
      synced: false,
    );

    await db.upsertJobSession(saved.toCompanion(true));

    // Push to backend
    await sync.enqueue('job_session_complete', {
      'local_id': saved.id,
      'service_id': saved.serviceId,
      'started_at': saved.startedAt.toUtc().toIso8601String(),
      'ended_at': saved.endedAt?.toUtc().toIso8601String(),
      'duration_minutes': saved.durationMinutes,
      'description': note,
      'materials': _costs.map((c) => {'item': c.name, 'cost': c.amount}).toList(),
      'final_charge': charge,
    });
    unawaited(sync.syncNow());

    if (!mounted) return;

    // Ask: charge now or save for later?
    final shouldCharge = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Job Complete'),
        content: Text(
          'Duration: ${_fmtDuration(saved.durationMinutes ?? 0)}\n'
          'Charge: UGX ${charge.toStringAsFixed(0)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Save Only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Charge Client'),
          ),
        ],
      ),
    );

    if (shouldCharge == true && mounted) {
      // Add to cart
      final service = await db.getServiceById(saved.serviceId);
      if (service != null) {
        ref.read(cartControllerProvider.notifier).addService(
          service: service,
          variantPrice: charge > 0 ? charge : null,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
        );
        return;
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _stopTick();
    _noteCtrl.dispose();
    _chargeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasActive = _activeSession != null && _activeSession!.endedAt == null;
    final isCompleted = _activeSession != null && _activeSession!.endedAt != null;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: const Text('Job Timer')),
      body: SafeArea(
        child: Padding(
          padding: DesignTokens.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timer display
              Container(
                padding: DesignTokens.paddingLg,
                decoration: BoxDecoration(
                  color: DesignTokens.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: DesignTokens.borderRadiusLg,
                ),
                child: Column(
                  children: [
                    Text(
                      _fmtDuration(_elapsedSeconds ~/ 60),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        color: hasActive ? DesignTokens.brandAccent : DesignTokens.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (_activeSession?.clientName != null)
                      Text(
                        _activeSession!.clientName!,
                        style: DesignTokens.textBody.copyWith(
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spaceLg),

              // Main action
              if (!hasActive && !isCompleted)
                ElevatedButton.icon(
                  onPressed: _startJob,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else if (hasActive)
                ElevatedButton.icon(
                  onPressed: _stopJob,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Timer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Charge amount (auto-filled)
                    TextField(
                      controller: _chargeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Charge Amount (UGX)',
                        prefixIcon: Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),

                    // Notes
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'What was done? (optional)',
                        prefixIcon: Icon(Icons.notes),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),

                    // Costs (collapsible)
                    _CostsSection(
                      costs: _costs,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: DesignTokens.spaceLg),

                    ElevatedButton.icon(
                      onPressed: _saveAndCharge,
                      icon: const Icon(Icons.save),
                      label: const Text('Save & Charge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.brandAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _CostLine {
  _CostLine({required this.name, required this.amount});
  String name;
  double amount;
}

class _CostsSection extends StatefulWidget {
  const _CostsSection({required this.costs, required this.onChanged});
  final List<_CostLine> costs;
  final VoidCallback onChanged;

  @override
  State<_CostsSection> createState() => _CostsSectionState();
}

class _CostsSectionState extends State<_CostsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: DesignTokens.borderRadiusMd,
          child: Padding(
            padding: DesignTokens.paddingMd,
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Costs / Materials (${widget.costs.length})',
                    style: DesignTokens.textBody,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: DesignTokens.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: DesignTokens.spaceSm),
          ...widget.costs.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Item name',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (v) {
                        c.name = v;
                        widget.onChanged();
                      },
                      controller: TextEditingController(text: c.name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cost',
                        prefixText: 'UGX ',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        c.amount = double.tryParse(v) ?? 0;
                        widget.onChanged();
                      },
                      controller: TextEditingController(text: c.amount.toStringAsFixed(0)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: DesignTokens.error),
                    onPressed: () {
                      widget.costs.removeAt(i);
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () {
              widget.costs.add(_CostLine(name: '', amount: 0));
              widget.onChanged();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Cost'),
          ),
        ],
      ],
    );
  }
}
