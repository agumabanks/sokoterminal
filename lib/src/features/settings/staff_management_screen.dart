import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/bottom_sheet_modal.dart';
import '../../widgets/error_page.dart';
import '../../widgets/pin_prompt_sheet.dart';

/// Staff member DTO
class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    this.createdAt,
  });

  final int id;
  final String name;
  final String role;
  final bool active;
  final DateTime? createdAt;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        role: json['role']?.toString() ?? 'cashier',
        active: json['active'] == true || json['active'] == 1,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

/// State for staff management
class StaffState {
  const StaffState({
    this.loading = false,
    this.staff = const [],
    this.error,
    this.initialized = false,
  });

  final bool loading;
  final List<StaffMember> staff;
  final String? error;
  final bool initialized;

  StaffState copyWith({
    bool? loading,
    List<StaffMember>? staff,
    String? error,
    bool? initialized,
  }) =>
      StaffState(
        loading: loading ?? this.loading,
        staff: staff ?? this.staff,
        error: error,
        initialized: initialized ?? this.initialized,
      );
}

final staffControllerProvider =
    StateNotifierProvider<StaffController, StaffState>((ref) {
  final api = ref.watch(sellerApiProvider);
  return StaffController(api)..load();
});

class StaffController extends StateNotifier<StaffState> {
  StaffController(this._api) : super(const StaffState());

  final SellerApi _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.fetchStaff();
      final data = res.data;
      final List<dynamic> list =
          (data is Map && data['data'] != null) ? data['data'] as List : [];
      final staff = list
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        loading: false,
        staff: staff,
        initialized: staff.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> bootstrap({required String pin, String? name}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _api.bootstrapStaff({
        'pin': pin,
        if (name != null && name.isNotEmpty) 'name': name,
      });
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> create({
    required String name,
    required String role,
    required String pin,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _api.createStaff({
        'name': name,
        'role': role,
        'pin': pin,
      });
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> update(int id, {String? name, String? role, bool? active, String? pin}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _api.updateStaff(id, {
        if (name != null) 'name': name,
        if (role != null) 'role': role,
        if (active != null) 'active': active,
        if (pin != null) 'pin': pin,
      });
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> delete(int id) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _api.deleteStaff(id);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }
}

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffControllerProvider);
    final controller = ref.read(staffControllerProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Staff & Roles'),
        actions: [
          if (state.initialized)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddStaff(context, controller),
            ),
        ],
      ),
      body: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    StaffState state,
    StaffController controller,
  ) {
    if (state.loading && state.staff.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.staff.isEmpty) {
      return ErrorPage(
        title: 'Failed to Load Staff',
        message: state.error,
        onRetry: controller.load,
      );
    }

    if (!state.initialized) {
      return _BootstrapView(controller: controller);
    }

    if (state.staff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: DesignTokens.grayMedium),
            const SizedBox(height: DesignTokens.spaceMd),
            Text('No staff members', style: DesignTokens.textBody),
            const SizedBox(height: DesignTokens.spaceLg),
            AppButton(
              label: 'Add Staff',
              onPressed: () => _showAddStaff(context, controller),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: DesignTokens.paddingScreen,
        itemCount: state.staff.length,
        separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spaceSm),
        itemBuilder: (context, index) {
          final member = state.staff[index];
          return _StaffCard(
            member: member,
            onTap: () => _showEditStaff(context, controller, member),
          );
        },
      ),
    );
  }

  void _showAddStaff(BuildContext context, StaffController controller) {
    unawaited(() async {
      final result = await BottomSheetModal.show<Map<String, dynamic>>(
        context: context,
        title: 'Add Staff Member',
        builder: (ctx) => _StaffForm(),
      );
      if (result != null) {
        final ok = await controller.create(
          name: result['name'] as String,
          role: result['role'] as String,
          pin: result['pin'] as String,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? 'Staff added' : 'Failed to add staff'),
              backgroundColor: ok ? DesignTokens.success : DesignTokens.error,
            ),
          );
        }
      }
    }());
  }

  void _showEditStaff(
    BuildContext context,
    StaffController controller,
    StaffMember member,
  ) {
    unawaited(() async {
      final result = await BottomSheetModal.show<Map<String, dynamic>>(
        context: context,
        title: 'Edit Staff',
        builder: (ctx) => _StaffForm(initial: member),
      );
      if (result != null) {
        if (result['delete'] == true) {
          final ok = await controller.delete(member.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'Staff deleted' : 'Failed to delete'),
                backgroundColor: ok ? DesignTokens.success : DesignTokens.error,
              ),
            );
          }
        } else {
          final ok = await controller.update(
            member.id,
            name: result['name'] as String?,
            role: result['role'] as String?,
            active: result['active'] as bool?,
            pin: result['pin'] as String?,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'Staff updated' : 'Failed to update'),
                backgroundColor: ok ? DesignTokens.success : DesignTokens.error,
              ),
            );
          }
        }
      }
    }());
  }
}

class _BootstrapView extends StatefulWidget {
  const _BootstrapView({required this.controller});

  final StaffController controller;

  @override
  State<_BootstrapView> createState() => _BootstrapViewState();
}

class _BootstrapViewState extends State<_BootstrapView> {
  final _nameCtrl = TextEditingController();
  String _pin = '';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN must be at least 4 digits'),
          backgroundColor: DesignTokens.error,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await widget.controller.bootstrap(
      pin: _pin,
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
    );
    if (mounted) {
      setState(() => _loading = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to initialize staff'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DesignTokens.paddingScreen,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 64, color: DesignTokens.brandPrimary),
          const SizedBox(height: DesignTokens.spaceLg),
          Text('Set Up Staff Access', style: DesignTokens.textTitle),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Create your manager account to enable staff permissions.',
            style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          AppInput(
            controller: _nameCtrl,
            label: 'Your Name (optional)',
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          OutlinedButton.icon(
            icon: const Icon(Icons.pin),
            label: Text(_pin.isEmpty ? 'Set PIN' : 'PIN: ${'•' * _pin.length}'),
            onPressed: () async {
              final pin = await PinPromptSheet.show(
                context: context,
                title: 'Set Manager PIN',
                pinLabel: 'PIN (4-8 digits)',
                actionLabel: 'Save',
              );
              if (pin != null) {
                setState(() => _pin = pin);
              }
            },
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          _loading
              ? const CircularProgressIndicator()
              : AppButton(
                  label: 'Initialize',
                  onPressed: _bootstrap,
                ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, this.onTap});

  final StaffMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.role == 'manager'
              ? DesignTokens.brandPrimary
              : DesignTokens.brandAccent,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member.name),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: member.role == 'manager'
                    ? DesignTokens.brandPrimary.withOpacity(0.1)
                    : DesignTokens.brandAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Text(
                member.role.toUpperCase(),
                style: DesignTokens.textSmall.copyWith(
                  color: member.role == 'manager'
                      ? DesignTokens.brandPrimary
                      : DesignTokens.brandAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!member.active) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DesignTokens.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Text(
                  'INACTIVE',
                  style: DesignTokens.textSmall.copyWith(color: DesignTokens.error),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StaffForm extends StatefulWidget {
  const _StaffForm({this.initial});

  final StaffMember? initial;

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  late final TextEditingController _nameCtrl;
  String _role = 'cashier';
  bool _active = true;
  String? _pin;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _role = widget.initial?.role ?? 'cashier';
    _active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(
            controller: _nameCtrl,
            label: 'Name',
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
          if (isEdit) ...[
            const SizedBox(height: DesignTokens.spaceMd),
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: DesignTokens.spaceMd),
          OutlinedButton.icon(
            icon: const Icon(Icons.pin),
            label: Text(_pin == null ? 'Set PIN' : 'PIN: ${'•' * _pin!.length}'),
            onPressed: () async {
              final pin = await PinPromptSheet.show(
                context: context,
                title: isEdit ? 'Change PIN' : 'Set PIN',
                pinLabel: 'PIN (4-8 digits)',
                actionLabel: 'Save',
              );
              if (pin != null) {
                setState(() => _pin = pin);
              }
            },
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Row(
            children: [
              if (isEdit)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.error,
                    ),
                    onPressed: () => Navigator.pop(context, {'delete': true}),
                    child: const Text('Delete'),
                  ),
                ),
              if (isEdit) const SizedBox(width: DesignTokens.spaceMd),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: isEdit ? 'Save' : 'Add',
                  onPressed: () {
                    if (_nameCtrl.text.trim().isEmpty) return;
                    if (!isEdit && (_pin == null || _pin!.length < 4)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('PIN required'),
                          backgroundColor: DesignTokens.error,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'name': _nameCtrl.text.trim(),
                      'role': _role,
                      'active': _active,
                      if (_pin != null) 'pin': _pin,
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
