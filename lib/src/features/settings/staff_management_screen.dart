import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import '../../core/auth/pos_session_controller.dart';
import '../../core/auth/pos_staff_prefs.dart';
import '../../core/db/app_database.dart';
import '../../core/network/seller_api.dart';
import '../../core/storage/secure_storage.dart';
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
    this.photoUploadId,
    this.photoUrl,
  });

  final int? photoUploadId;
  final String? photoUrl;
  final int id;
  final String name;
  final String role;
  final bool active;
  final DateTime? createdAt;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
    photoUploadId: int.tryParse('${json['photo_upload_id']}'),
    photoUrl: json['photo_url']?.toString(),
    id: (json['id'] as num?)?.toInt() ?? 0,
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
  }) => StaffState(
    loading: loading ?? this.loading,
    staff: staff ?? this.staff,
    error: error,
    initialized: initialized ?? this.initialized,
  );
}

final staffControllerProvider =
    StateNotifierProvider<StaffController, StaffState>((ref) {
      final api = ref.watch(sellerApiProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      final db = ref.watch(appDatabaseProvider);
      final storage = ref.watch(secureStorageProvider);
      return StaffController(api, prefs, db, storage)..load();
    });

class StaffController extends StateNotifier<StaffState> {
  StaffController(this._api, this._prefs, this._db, this._storage)
    : super(const StaffState());

  final SellerApi _api;
  final SharedPreferences _prefs;
  final AppDatabase _db;
  final SecureStorage _storage;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.fetchStaff();
      final data = res.data;
      final List<dynamic> list = (data is Map && data['data'] is List)
          ? data['data'] as List
          : [];
      final staff = list
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
      final initialized = staff.isNotEmpty;
      await _prefs.setBool(posStaffInitializedPrefKey, initialized);
      state = state.copyWith(
        loading: false,
        staff: staff,
        initialized: initialized,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> bootstrap({required String pin, String? name}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.bootstrapStaff({
        'pin': pin,
        if (name != null && name.isNotEmpty) 'name': name,
      });
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : null;
      final staffId = data?['id'] as int?;
      final staffName = data?['name']?.toString() ?? name ?? 'Owner';
      final staffRole = data?['role']?.toString() ?? 'manager';
      if (staffId != null) {
        await _db.upsertStaff(
          StaffCompanion.insert(
            id: drift.Value(staffId.toString()),
            name: staffName,
            pin: drift.Value(pin),
            active: const drift.Value(true),
            updatedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );
        await _storage.writePosStaffRole(staffId, staffRole);
      }
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
    int? photoUploadId,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.createStaff({
        if (photoUploadId != null) 'photo_upload_id': photoUploadId,
        'name': name,
        'role': role,
        'pin': pin,
      });
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : null;
      final staffId = data?['id'] as int?;
      if (staffId != null) {
        await _db.upsertStaff(
          StaffCompanion.insert(
            id: drift.Value(staffId.toString()),
            name: name,
            pin: drift.Value(pin),
            active: const drift.Value(true),
            updatedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );
        await _storage.writePosStaffRole(staffId, role);
      }
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    int id, {
    String? name,
    String? role,
    bool? active,
    String? pin,
    int? photoUploadId,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _api.updateStaff(id, {
        if (name != null) 'name': name,
        if (role != null) 'role': role,
        if (active != null) 'active': active,
        if (pin != null) 'pin': pin,
        if (photoUploadId != null) 'photo_upload_id': photoUploadId,
      });
      await _db.upsertStaff(
        StaffCompanion.insert(
          id: drift.Value(id.toString()),
          name: name ?? '',
          pin: pin == null ? const drift.Value.absent() : drift.Value(pin),
          active: active == null
              ? const drift.Value.absent()
              : drift.Value(active),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );
      if (role != null) {
        await _storage.writePosStaffRole(id, role);
      }
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
    final posSession = ref.watch(posSessionProvider);

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
      body: Column(
        children: [
          if (state.initialized)
            _PosSessionCard(
              session: posSession,
              onLogin: () => context.go('/pos-login?redirect=/home/more/staff'),
              onLogout: () async {
                await ref.read(posSessionProvider.notifier).end();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Signed out'),
                    backgroundColor: DesignTokens.brandAccent,
                  ),
                );
              },
            ),
          if (state.initialized)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: DesignTokens.brandAccentLight,
                borderRadius: DesignTokens.borderRadiusMd,
                child: ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: DesignTokens.brandAccent,
                  ),
                  title: Text(
                    '${state.staff.where((member) => member.active).length} active team members',
                    style: DesignTokens.textBodyBold,
                  ),
                  subtitle: const Text('Control what cashiers can see and use'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/home/more/staff-menu-access'),
                ),
              ),
            ),
          Expanded(child: _buildBody(context, state, controller)),
        ],
      ),
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
            Icon(
              Icons.people_outline,
              size: 64,
              color: DesignTokens.grayMedium,
            ),
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
        separatorBuilder: (_, __) =>
            const SizedBox(height: DesignTokens.spaceSm),
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
        child: _StaffForm(),
      );
      if (result != null) {
        final ok = await controller.create(
          name: result['name']?.toString() ?? '',
          role: result['role']?.toString() ?? 'cashier',
          pin: result['pin']?.toString() ?? '',
          photoUploadId: result['photo_upload_id'] as int?,
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
        child: _StaffForm(initial: member),
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
            photoUploadId: result['photo_upload_id'] as int?,
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

class _PosSessionCard extends StatelessWidget {
  const _PosSessionCard({
    required this.session,
    required this.onLogin,
    required this.onLogout,
  });

  final PosSessionState session;
  final VoidCallback onLogin;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final title = session.isActive
        ? '${session.staffName ?? 'Staff'} • ${(session.staffRole ?? '').toLowerCase()}'
        : 'Not signed in';
    final subtitle = session.isActive
        ? 'Signed in for sync and privileged actions.'
        : 'Sign in to sync sales and cash movements.';

    return Container(
      margin: DesignTokens.paddingScreen,
      padding: DesignTokens.paddingMd,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: DesignTokens.borderRadiusMd,
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POS Session', style: DesignTokens.textBodyBold),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(title, style: DesignTokens.textBody),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(subtitle, style: DesignTokens.textSmall),
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: session.loading ? null : onLogin,
                  icon: session.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          session.isActive ? Icons.switch_account : Icons.login,
                        ),
                  label: Text(session.isActive ? 'Switch staff' : 'Sign in'),
                ),
              ),
              if (session.isActive) ...[
                const SizedBox(width: DesignTokens.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: session.loading
                        ? null
                        : () => unawaited(onLogout()),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
          Icon(
            Icons.admin_panel_settings,
            size: 64,
            color: DesignTokens.brandPrimary,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          Text('Set Up Staff Access', style: DesignTokens.textTitle),
          const SizedBox(height: DesignTokens.spaceSm),
          Text(
            'Create your manager account to enable staff permissions.',
            style: DesignTokens.textBody.copyWith(
              color: DesignTokens.grayMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          AppInput(controller: _nameCtrl, label: 'Your Name (optional)'),
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
              : AppButton(label: 'Initialize', onPressed: _bootstrap),
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
          backgroundImage: member.photoUrl == null
              ? null
              : NetworkImage(member.photoUrl!),
          backgroundColor: member.role == 'manager'
              ? DesignTokens.brandPrimary
              : DesignTokens.brandAccent,
          child: member.photoUrl != null
              ? null
              : Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Text(member.name),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: member.role == 'manager'
                    ? DesignTokens.brandPrimary.withValues(alpha: 0.1)
                    : DesignTokens.brandAccent.withValues(alpha: 0.1),
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
                  color: DesignTokens.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Text(
                  'INACTIVE',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.error,
                  ),
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

class _StaffForm extends ConsumerStatefulWidget {
  const _StaffForm({this.initial});

  final StaffMember? initial;

  @override
  ConsumerState<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends ConsumerState<_StaffForm> {
  int? _photoUploadId;
  bool _uploadingPhoto = false;
  File? _photo;
  late final TextEditingController _nameCtrl;
  String _role = 'cashier';
  bool _active = true;
  String? _pin;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _photoUploadId = widget.initial?.photoUploadId;
    _role = widget.initial?.role ?? 'cashier';
    _active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final res = await ref
          .read(sellerApiProvider)
          .uploadSellerFile(File(image.path));
      final raw = res.data;
      final data = raw is Map && raw['data'] is Map
          ? raw['data'] as Map
          : raw as Map;
      final id = int.tryParse('${data['id'] ?? data['upload_id']}');
      if (id == null) throw StateError('Upload failed');
      if (mounted) {
        setState(() {
          _photoUploadId = id;
          _photo = File(image.path);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo upload failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: _photo == null ? null : FileImage(_photo!),
              child: _photo == null ? const Icon(Icons.person_outline) : null,
            ),
            title: const Text('Profile photo'),
            trailing: _uploadingPhoto
                ? const CircularProgressIndicator()
                : IconButton(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                  ),
          ),
          AppInput(controller: _nameCtrl, label: 'Full name'),
          const SizedBox(height: DesignTokens.spaceMd),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _role == 'manager'
                  ? 'Manager: manages stock, staff and approvals. Sign in using the shop login number and this staff member’s PIN.'
                  : 'Cashier: makes sales with the permissions you allow. Sign in using the shop login number and this staff member’s PIN.',
            ),
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
            label: Text(
              _pin == null ? 'Set PIN' : 'PIN: ${'•' * _pin!.length}',
            ),
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
                    if (_uploadingPhoto) return;
                    Navigator.pop(context, {
                      'name': _nameCtrl.text.trim(),
                      'role': _role,
                      if (_photoUploadId != null)
                        'photo_upload_id': _photoUploadId,
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
