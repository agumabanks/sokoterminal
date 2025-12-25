import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/util/phone_normalizer.dart';

class ContactItem {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isFromDevice;
  final bool isFromSoko;
  final DateTime? lastInteraction;

  ContactItem({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.isFromDevice = false,
    this.isFromSoko = false,
    this.lastInteraction,
  });

  ContactItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    bool? isFromDevice,
    bool? isFromSoko,
    DateTime? lastInteraction,
  }) {
    return ContactItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      isFromDevice: isFromDevice ?? this.isFromDevice,
      isFromSoko: isFromSoko ?? this.isFromSoko,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }
}

class ContactsState {
  final bool loading;
  final List<ContactItem> contacts;
  final List<ContactItem> filteredContacts;
  final String? error;
  final bool permissionGranted;
  final String searchQuery;

  ContactsState({
    this.loading = false,
    this.contacts = const [],
    this.filteredContacts = const [],
    this.error,
    this.permissionGranted = false,
    this.searchQuery = '',
  });

  ContactsState copyWith({
    bool? loading,
    List<ContactItem>? contacts,
    List<ContactItem>? filteredContacts,
    String? error,
    bool? permissionGranted,
    String? searchQuery,
  }) {
    return ContactsState(
      loading: loading ?? this.loading,
      contacts: contacts ?? this.contacts,
      filteredContacts: filteredContacts ?? this.filteredContacts,
      error: error,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, ContactsState>((ref) {
  final api = ref.watch(sellerApiProvider);
  final db = ref.watch(appDatabaseProvider);
  final sync = ref.watch(syncServiceProvider);
  return ContactsController(api, db, sync)..init();
});

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController(this._api, this._db, this._syncService)
      : super(ContactsState());

  final SellerApi _api;
  final AppDatabase _db;
  final SyncService _syncService;

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final status = await Permission.contacts.request();
      final hasPermission = status.isGranted;
      
      List<ContactItem> items = [];

      // 1. Fetch from Device if permitted
      if (hasPermission) {
        final deviceContacts = await FlutterContacts.getContacts(withProperties: true);
        items.addAll(deviceContacts.map((c) => ContactItem(
          id: c.id,
          name: c.displayName,
          phone: c.phones.isNotEmpty ? c.phones.first.number : null,
          email: c.emails.isNotEmpty ? c.emails.first.address : null,
          isFromDevice: true,
        )));
        try {
          // Sync device contacts to backend in background
          await _syncService.syncDeviceContacts(force: true, contacts: deviceContacts);
        } catch (_) {
          // Sync failures should not block local contact display.
        }
      }

      // 2. Fetch from Soko DB (Local Cache of Seller Customers)
      final sokoCustomers = await _db.select(_db.customers).get();
      items.addAll(sokoCustomers.map((c) => ContactItem(
        id: 'soko_${c.id}',
        name: c.name,
        phone: c.phone,
        email: c.email,
        isFromSoko: true,
      )));

      final merged = <String, ContactItem>{};
      for (final item in items) {
        final key = _contactKey(item);
        final existing = merged[key];
        if (existing == null) {
          merged[key] = item;
        } else {
          merged[key] = _mergeContacts(existing, item);
        }
      }

      final uniqueItems = merged.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      state = state.copyWith(
        loading: false, 
        contacts: uniqueItems, 
        filteredContacts: _applySearch(uniqueItems, state.searchQuery),
        permissionGranted: hasPermission
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Search contacts by name, phone, or email
  void search(String query) {
    final trimmed = query.trim().toLowerCase();
    state = state.copyWith(
      searchQuery: trimmed,
      filteredContacts: _applySearch(state.contacts, trimmed),
    );
  }

  List<ContactItem> _applySearch(List<ContactItem> contacts, String query) {
    if (query.isEmpty) return contacts;
    return contacts.where((c) {
      return c.name.toLowerCase().contains(query) ||
          (c.phone?.toLowerCase().contains(query) ?? false) ||
          (c.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      filteredContacts: state.contacts,
    );
  }

  /// Create a new contact - saves locally first, then syncs IMMEDIATELY to backend
  Future<bool> createContact({
    required String name,
    String? phone,
    String? email,
    String? notes,
    bool shareWithTeam = false,
  }) async {
    try {

      // Smart formatting: Ensure phone has +256 prefix if it's a UG number
      if (phone != null && phone.isNotEmpty) {
        final normalized = normalizeUgPhone(phone);
        if (normalized.isNotEmpty && normalized.startsWith('256')) {
           phone = '+$normalized';
        }
      }

      final contactId = const Uuid().v4();
      final now = DateTime.now().toUtc();
      
      // 1. Save to local database first (offline-first, prevents data loss)
      await _db.upsertCustomer(
        CustomersCompanion.insert(
          id: drift.Value(contactId),
          name: name,
          phone: drift.Value(phone),
          email: drift.Value(email),
          synced: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );

      // 2. Try IMMEDIATE sync to backend (prioritize cloud backup)
      bool syncedToCloud = false;
      try {
        final response = await _api.pushCustomer({
          'display_name': name,
          'phones': phone != null ? [phone] : [],
          'emails': email != null ? [email] : [],
          'notes': notes,
          'shared_with_business': shareWithTeam,
          'source': 'pos_terminal',
        }, idempotencyKey: contactId);
        
        // If API call succeeded, mark as synced
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _db.upsertCustomer(
            CustomersCompanion.insert(
              id: drift.Value(contactId),
              name: name,
              phone: drift.Value(phone),
              email: drift.Value(email),
              synced: const drift.Value(true),
              updatedAt: drift.Value(now),
            ),
          );
          syncedToCloud = true;
          print('[Contacts] ✅ Contact "$name" synced to cloud immediately');
        }
      } catch (e) {
        // API call failed - enqueue for later sync (offline mode)
        print('[Contacts] ⚠️ Immediate sync failed, enqueueing for later: $e');
        await _syncService.enqueue('customer_push', {
          'idempotency_key': contactId,
          'customer_id': contactId,
          'display_name': name,
          'phones': phone != null ? [phone] : [],
          'emails': email != null ? [email] : [],
          'notes': notes,
          'shared_with_business': shareWithTeam,
          'source': 'pos_terminal',
        });
      }

      // 3. Refresh local state
      await refresh();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create contact: $e');
      return false;
    }
  }

  /// Delete a contact - removes locally and syncs deletion to backend
  Future<bool> deleteContact(String id) async {
    try {
      // Extract the actual ID from soko_ prefix
      final actualId = id.startsWith('soko_') ? id.substring(5) : id;
      
      // Remove from local database
      await (_db.delete(_db.customers)
        ..where((c) => c.id.equals(actualId)))
        .go();
      
      // Try to delete from backend if online
      try {
        await _api.deleteCustomer(actualId);
      } catch (_) {
        // Backend delete failed, but local delete succeeded
        // Could enqueue a delete operation for later
      }
      
      // Remove from local state immediately
      final updated = state.contacts.where((c) => c.id != id).toList();
      state = state.copyWith(
        contacts: updated,
        filteredContacts: _applySearch(updated, state.searchQuery),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete contact: $e');
      return false;
    }
  }

  String? _normalizePhone(String? phone) {
    if (phone == null) return null;
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  String? _normalizeEmail(String? email) {
    if (email == null) return null;
    final trimmed = email.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _contactKey(ContactItem item) {
    final phone = _normalizePhone(item.phone);
    if (phone != null && phone.isNotEmpty) {
      return 'p:$phone';
    }
    final email = _normalizeEmail(item.email);
    if (email != null && email.isNotEmpty) {
      return 'e:$email';
    }
    return 'i:${item.id}';
  }

  ContactItem _mergeContacts(ContactItem a, ContactItem b) {
    final name = a.name.isNotEmpty ? a.name : b.name;
    final phone = a.phone ?? b.phone;
    final email = a.email ?? b.email;
    return ContactItem(
      id: a.id,
      name: name,
      phone: phone,
      email: email,
      isFromDevice: a.isFromDevice || b.isFromDevice,
      isFromSoko: a.isFromSoko || b.isFromSoko,
    );
  }

  Future<void> addContact(String name, String phone) async {
    await createContact(name: name, phone: phone);
  }
}
