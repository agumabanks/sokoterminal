import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../db/app_database.dart';

/// User role enum for RBAC
enum UserRole {
  cashier,
  manager,
}

/// Permission types that can be gated
enum Permission {
  refund,
  voidSale,
  priceOverride,
  viewReports,
  manageStaff,
  manageSettings,
  adjustInventory,
}

/// RBAC state holding current session info
class RbacState {
  const RbacState({
    this.currentStaff,
    this.role = UserRole.cashier,
    this.permissions = const {},
    this.isManagerSession = false,
  });
  
  final StaffData? currentStaff;
  final UserRole role;
  final Set<Permission> permissions;
  final bool isManagerSession;
  
  static const RbacState initial = RbacState();
  
  bool can(Permission permission) {
    // Manager can do everything
    if (role == UserRole.manager) return true;
    // Otherwise check specific permissions
    return permissions.contains(permission);
  }
  
  RbacState copyWith({
    StaffData? currentStaff,
    UserRole? role,
    Set<Permission>? permissions,
    bool? isManagerSession,
  }) => RbacState(
    currentStaff: currentStaff ?? this.currentStaff,
    role: role ?? this.role,
    permissions: permissions ?? this.permissions,
    isManagerSession: isManagerSession ?? this.isManagerSession,
  );
}

/// Staff data from local database
class StaffData {
  const StaffData({
    required this.id,
    required this.name,
    this.roleId,
    this.canRefund = false,
    this.canVoid = false,
    this.canPriceOverride = false,
  });
  
  final String id;
  final String name;
  final int? roleId;
  final bool canRefund;
  final bool canVoid;
  final bool canPriceOverride;
}

/// RBAC controller managing session state
class RbacController extends StateNotifier<RbacState> {
  RbacController(this._db) : super(RbacState.initial);
  
  final AppDatabase _db;
  
  /// Login with staff PIN
  Future<bool> loginWithPin(String pin) async {
    try {
      // Find staff by PIN
      final staff = await (_db.select(_db.staff)
        ..where((t) => t.pin.equals(pin))
        ..where((t) => t.active.equals(true))
        ..limit(1))
        .getSingleOrNull();
      
      if (staff == null) return false;
      
      // Get role permissions if roleId exists
      Role? role;
      if (staff.roleId != null) {
        role = await (_db.select(_db.roles)
          ..where((t) => t.id.equals(staff.roleId!)))
          .getSingleOrNull();
      }
      
      final permissions = <Permission>{};
      if (role?.canRefund == true) permissions.add(Permission.refund);
      if (role?.canVoid == true) permissions.add(Permission.voidSale);
      if (role?.canPriceOverride == true) permissions.add(Permission.priceOverride);
      
      // Determine user role (simple: name-based or roleId-based)
      final userRole = (role?.name.toLowerCase() == 'manager' || 
                        role?.canRefund == true && role?.canVoid == true && role?.canPriceOverride == true)
          ? UserRole.manager
          : UserRole.cashier;
      
      state = state.copyWith(
        currentStaff: StaffData(
          id: staff.id,
          name: staff.name,
          roleId: staff.roleId,
          canRefund: role?.canRefund ?? false,
          canVoid: role?.canVoid ?? false,
          canPriceOverride: role?.canPriceOverride ?? false,
        ),
        role: userRole,
        permissions: permissions,
        isManagerSession: userRole == UserRole.manager,
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Request manager PIN for elevated action
  Future<bool> requestManagerOverride(String pin) async {
    try {
      // Find manager by PIN
      final staff = await (_db.select(_db.staff)
        ..where((t) => t.pin.equals(pin))
        ..where((t) => t.active.equals(true))
        ..limit(1))
        .getSingleOrNull();
      
      if (staff == null) return false;
      
      // Check if this staff is a manager
      if (staff.roleId != null) {
        final role = await (_db.select(_db.roles)
          ..where((t) => t.id.equals(staff.roleId!)))
          .getSingleOrNull();
        
        // Must have all permissions to be manager
        if (role?.canRefund == true && role?.canVoid == true && role?.canPriceOverride == true) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Logout current session
  void logout() {
    state = RbacState.initial;
  }
  
  /// Check if session is active
  bool get isLoggedIn => state.currentStaff != null;
}

/// Provider for RBAC controller
final rbacProvider = StateNotifierProvider<RbacController, RbacState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RbacController(db);
});

/// Helper provider to check specific permission
final canRefundProvider = Provider<bool>((ref) {
  return ref.watch(rbacProvider.select((s) => s.can(Permission.refund)));
});

final canVoidProvider = Provider<bool>((ref) {
  return ref.watch(rbacProvider.select((s) => s.can(Permission.voidSale)));
});

final canPriceOverrideProvider = Provider<bool>((ref) {
  return ref.watch(rbacProvider.select((s) => s.can(Permission.priceOverride)));
});

final isManagerProvider = Provider<bool>((ref) {
  return ref.watch(rbacProvider.select((s) => s.role == UserRole.manager));
});
