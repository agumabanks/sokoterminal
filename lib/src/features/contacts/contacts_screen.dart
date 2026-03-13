import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/sync/sync_service.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import 'contacts_controller.dart';
import 'keypad_screen.dart';

final deviceContactsOptInProvider = FutureProvider<bool>((ref) async {
  return ref.watch(syncServiceProvider).isDeviceContactsOptedIn();
});

/// WhatsApp-inspired Contacts Screen — Premium, dark, minimal.
/// Following Steve Jobs standard: Maximum impact, minimum complexity.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  // WhatsApp colors
  static const _bgBlack = Color(0xFF000000);
  static const _bgDark = Color(0xFF0B141A);
  static const _headerBg = Color(0xFF1F2C34);
  static const _whatsappGreen = Color(0xFF00A884);
  static const _cardBg = Color(0xFF111B21);
  static const _missedRed = Color(0xFFEF5350);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsControllerProvider);
    final controller = ref.read(contactsControllerProvider.notifier);
    final optInAsync = ref.watch(deviceContactsOptInProvider);

    return Scaffold(
      backgroundColor: _bgBlack,
      appBar: _buildAppBar(state, controller),
      body: Column(
        children: [
          // Quick action buttons row
          _buildQuickActions(),

          // Contacts sync toggle (privacy-safe)
          optInAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (enabled) => _SyncBanner(
              enabled: enabled,
              onChanged: (next) async {
                await ref
                    .read(syncServiceProvider)
                    .setDeviceContactsOptIn(next);
                ref.invalidate(deviceContactsOptInProvider);
                final telemetry = Telemetry.instance;
                if (telemetry != null) {
                  unawaited(
                    telemetry.event(
                      'contacts_opt_in_changed',
                      props: {'enabled': next},
                    ),
                  );
                }
                // Refresh immediately to import + (if enabled) sync.
                await controller.refresh();
              },
            ),
          ),

          // Recent contacts section with header
          if (state.filteredContacts.isNotEmpty) _buildRecentSection(state),

          // Tabs
          Container(
            color: _bgDark,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _whatsappGreen,
              indicatorWeight: 3,
              labelColor: _whatsappGreen,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Contacts'),
                Tab(text: 'Keypad'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContactsList(state, controller),
                const KeypadScreen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _whatsappGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => _showAddContactSheet(context, controller),
                backgroundColor: _whatsappGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_add, color: Colors.white),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
    ContactsState state,
    ContactsController controller,
  ) {
    if (_showSearch) {
      return AppBar(
        backgroundColor: _headerBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _showSearch = false);
            _searchController.clear();
            controller.clearSearch();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: _whatsappGreen,
          decoration: const InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
          ),
          onChanged: controller.search,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                controller.clearSearch();
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: _bgBlack,
      elevation: 0,
      leadingWidth: 48,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(Icons.more_horiz, color: Colors.grey.shade400),
      ),
      title: const Text(
        'Contacts',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => setState(() => _showSearch = true),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _showAddContactSheet(
              context,
              ref.read(contactsControllerProvider.notifier),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _whatsappGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      color: _bgBlack,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _QuickActionButton(
            icon: Icons.phone_outlined,
            label: 'Call',
            onTap: () => _tabController.animateTo(1),
          ),
          const SizedBox(width: 20),
          _QuickActionButton(
            icon: Icons.calendar_today_outlined,
            label: 'Schedule',
            onTap: () {},
          ),
          const SizedBox(width: 20),
          _QuickActionButton(
            icon: Icons.grid_view_rounded,
            label: 'Keypad',
            onTap: () => _tabController.animateTo(1),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection(ContactsState state) {
    final recentContacts = state.filteredContacts.take(5).toList();

    return Container(
      color: _bgBlack,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent contacts horizontal scroll
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentContacts.length,
              itemBuilder: (context, index) {
                final contact = recentContacts[index];
                return _RecentContactAvatar(
                  contact: contact,
                  onTap: () => _showContactDetails(context, contact),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList(
    ContactsState state,
    ContactsController controller,
  ) {
    if (state.loading && state.contacts.isEmpty) {
      return Container(
        color: _bgBlack,
        child: const Center(
          child: CircularProgressIndicator(color: _whatsappGreen),
        ),
      );
    }

    if (!state.permissionGranted && state.contacts.isEmpty) {
      return Container(
        color: _bgBlack,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.contacts_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Contacts Permission',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Allow access to sync your contacts',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (state.isPermanentlyDenied) {
                      openAppSettings();
                    } else {
                      controller.refresh();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _whatsappGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    state.isPermanentlyDenied
                        ? 'Open Settings'
                        : 'Grant Access',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.filteredContacts.isEmpty) {
      return Container(
        color: _bgBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text(
                state.searchQuery.isNotEmpty
                    ? 'No results for "${state.searchQuery}"'
                    : 'No contacts yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: _bgBlack,
      child: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await controller.refresh();
        },
        color: _whatsappGreen,
        backgroundColor: _cardBg,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: state.filteredContacts.length,
          itemBuilder: (context, index) {
            final contact = state.filteredContacts[index];
            final canDelete =
                contact.isFromSoko &&
                contact.id.startsWith('soko_') &&
                !contact.isFromDevice;
            final tile = _ContactListTile(
              contact: contact,
              onTap: () => _showContactDetails(context, contact),
            );
            if (!canDelete) return tile;
            return Dismissible(
              key: Key(contact.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: _missedRed,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              confirmDismiss: (direction) => _confirmDelete(context, contact),
              onDismissed: (direction) => controller.deleteContact(contact.id),
              child: tile,
            );
          },
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, ContactItem contact) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Contact',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove ${contact.name} from your contacts?',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _missedRed)),
          ),
        ],
      ),
    );
  }

  void _showContactDetails(BuildContext context, ContactItem contact) {
    HapticFeedback.selectionClick();
    if ((contact.remoteCustomerId ?? '').trim().isNotEmpty) {
      _showCrmContactDetails(context, contact);
      return;
    }
    _showQuickContactDetails(context, contact);
  }

  Future<_CrmContactDetail> _fetchCrmContactDetail(String remoteCustomerId) async {
    final response = await ref
        .read(sellerApiProvider)
        .fetchSellerCustomerDetails(remoteCustomerId);
    final body = response.data is Map<String, dynamic>
        ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
        : const <String, dynamic>{};
    final data = body['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    return _CrmContactDetail.fromJson(data);
  }

  void _showCrmContactDetails(BuildContext context, ContactItem contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: SafeArea(
          child: _CrmContactDetailSheet(
            contact: contact,
            detailsFuture: _fetchCrmContactDetail(contact.remoteCustomerId!),
          ),
        ),
      ),
    );
  }

  void _showQuickContactDetails(BuildContext context, ContactItem contact) {
    final controller = ref.read(contactsControllerProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Avatar
              _LargeAvatar(name: contact.name),
              const SizedBox(height: 16),

              // Name
              Text(
                contact.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Phone/Email
              Text(
                contact.phone ?? contact.email ?? 'No contact info',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),

              // Source badges
              const SizedBox(height: 12),
              _SourceBadges(contact: contact),

              const SizedBox(height: 28),

              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (contact.phone != null) ...[
                    _ActionChip(
                      icon: Icons.call,
                      label: 'Call',
                      color: _whatsappGreen,
                      onTap: () {
                        Navigator.pop(context);
                        launchUrl(Uri.parse('tel:${contact.phone}'));
                      },
                    ),
                    const SizedBox(width: 12),
                    _ActionChip(
                      icon: Icons.chat_bubble,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        Navigator.pop(context);
                        launchUrl(
                          Uri.parse(
                            'https://wa.me/${contact.phone?.replaceAll(RegExp(r"\D"), "")}',
                          ),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _ActionChip(
                      icon: Icons.message,
                      label: 'SMS',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        launchUrl(Uri.parse('sms:${contact.phone}'));
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              if (contact.isFromDevice && !contact.isFromSoko) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2C34),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Soko CRM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save this contact as a customer so you can attach sales, send receipts, and track history.',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          final id = await controller
                              .createCustomerFromDeviceContact(contact);
                          if (!context.mounted) return;
                          if (id != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved to Soko CRM'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _whatsappGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        label: const Text('Save as customer'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickExistingCustomer(context);
                          if (picked == null) return;
                          await controller.linkDeviceContact(
                            deviceId: contact.id,
                            customerId: picked.id,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Linked to customer')),
                          );
                        },
                        icon: const Icon(Icons.link),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                        label: const Text('Link to existing customer'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<Customer?> _pickExistingCustomer(BuildContext context) async {
    final db = ref.read(appDatabaseProvider);
    final customers = await db.select(db.customers).get();
    customers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    if (!context.mounted) return null;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers found to link')),
      );
      return null;
    }

    return showModalBottomSheet<Customer?>(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: customers.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, index) {
            final c = customers[index];
            return ListTile(
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                c.phone ?? c.email ?? '',
                style: TextStyle(color: Colors.grey.shade400),
              ),
              onTap: () => Navigator.of(context).pop(c),
            );
          },
        ),
      ),
    );
  }

  void _showAddContactSheet(
    BuildContext context,
    ContactsController controller,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    bool shareWithTeam = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade500),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name field
              _PremiumTextField(
                controller: nameController,
                label: 'Name',
                icon: Icons.person_outline,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Phone field
              _PremiumTextField(
                controller: phoneController,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Email field
              _PremiumTextField(
                controller: emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Share with team toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _headerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_outline, color: Colors.grey.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share with team',
                            style: TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Visible to all staff members',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: shareWithTeam,
                      onChanged: (v) => setModalState(() => shareWithTeam = v),
                      activeThumbColor: _whatsappGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Name is required')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    final success = await controller.createContact(
                      name: name,
                      phone: phoneController.text.trim().isEmpty
                          ? null
                          : phoneController.text.trim(),
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                      shareWithTeam: shareWithTeam,
                    );

                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name added'),
                          backgroundColor: _whatsappGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _whatsappGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B141A),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111B21),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.sync, color: Color(0xFF00A884)),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync device contacts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Imports contacts locally for matching + WhatsApp, then syncs to Soko CRM during normal sync.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: Color(0xFF00A884),
              activeTrackColor: Color(0xFF00A884),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button (Call, Schedule, Keypad)
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2C34),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF00A884).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF00A884), size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent contact circular avatar with name
class _RecentContactAvatar extends StatelessWidget {
  const _RecentContactAvatar({required this.contact, required this.onTap});

  final ContactItem contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _getAvatarColor(contact.name),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getAvatarColor(contact.name).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              contact.name.split(' ').first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF00BCD4),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
    ];
    return colors[name.hashCode % colors.length];
  }
}

/// Contact list tile with WhatsApp styling
class _ContactListTile extends StatelessWidget {
  const _ContactListTile({required this.contact, required this.onTap});

  final ContactItem contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getAvatarColor(contact.name),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        contact.isFromSoko
                            ? Icons.cloud_done
                            : Icons.phone_android,
                        size: 14,
                        color: contact.isFromSoko
                            ? const Color(0xFF00A884)
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          contact.phone ?? 'No phone',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Info button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade700, width: 1),
              ),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF00BCD4),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
    ];
    return colors[name.hashCode % colors.length];
  }
}

/// Large avatar for contact detail sheet
class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _getAvatarColor(name),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getAvatarColor(name).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 36,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF00BCD4),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
    ];
    return colors[name.hashCode % colors.length];
  }
}

/// Source badges (Soko, Device)
class _SourceBadges extends StatelessWidget {
  const _SourceBadges({required this.contact});

  final ContactItem contact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (contact.isFromSoko)
          _Badge(
            icon: Icons.cloud_done,
            label: 'Soko',
            color: const Color(0xFF00A884),
          ),
        if (contact.isFromDevice)
          _Badge(
            icon: Icons.phone_android,
            label: 'Device',
            color: Colors.blue,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Action chip button for contact detail
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmContactDetailSheet extends StatelessWidget {
  const _CrmContactDetailSheet({
    required this.contact,
    required this.detailsFuture,
  });

  final ContactItem contact;
  final Future<_CrmContactDetail> detailsFuture;

  static const _sectionBg = Color(0xFF1F2C34);
  static const _accent = Color(0xFF00A884);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CrmContactDetail>(
      future: detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _accent),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                _LargeAvatar(name: contact.name),
                const SizedBox(height: 16),
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load CRM history right now.',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
          );
        }

        final detail = snapshot.data!;
        final primaryPhone = detail.contact.phones.isNotEmpty
            ? detail.contact.phones.first
            : contact.phone;
        final primaryEmail = detail.contact.emails.isNotEmpty
            ? detail.contact.emails.first
            : contact.email;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: _LargeAvatar(name: detail.contact.name)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  detail.contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              if ((primaryPhone ?? primaryEmail ?? '').isNotEmpty)
                Center(
                  child: Text(
                    primaryPhone ?? primaryEmail ?? '',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 12),
              Center(child: _SourceBadges(contact: contact)),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if ((primaryPhone ?? '').isNotEmpty)
                    _ActionChip(
                      icon: Icons.call,
                      label: 'Call',
                      color: _accent,
                      onTap: () => launchUrl(Uri.parse('tel:$primaryPhone')),
                    ),
                  if ((primaryPhone ?? '').isNotEmpty)
                    _ActionChip(
                      icon: Icons.chat_bubble,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://wa.me/${primaryPhone!.replaceAll(RegExp(r"\D"), "")}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  if ((primaryPhone ?? '').isNotEmpty)
                    _ActionChip(
                      icon: Icons.message,
                      label: 'SMS',
                      color: Colors.blue,
                      onTap: () => launchUrl(Uri.parse('sms:$primaryPhone')),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _CrmSection(
                title: 'Client summary',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      label: 'Orders',
                      value: detail.summary.totalOrders.toString(),
                    ),
                    _MetricCard(
                      label: 'Revenue',
                      value: 'UGX ${_formatCurrency(detail.summary.totalRevenue)}',
                    ),
                    _MetricCard(
                      label: 'Average',
                      value:
                          'UGX ${_formatCurrency(detail.summary.avgOrderValue)}',
                    ),
                    _MetricCard(
                      label: 'Outstanding',
                      value:
                          'UGX ${_formatCurrency(detail.summary.outstandingBalance)}',
                    ),
                    _MetricCard(
                      label: 'Segment',
                      value: detail.summary.segment,
                    ),
                    _MetricCard(
                      label: 'Loyalty',
                      value: detail.summary.loyaltyLevel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CrmSection(
                title: 'Profile',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileLine(
                      label: 'Role',
                      value: detail.contact.roleCategory ?? 'Customer',
                    ),
                    if ((detail.contact.businessType ?? '').isNotEmpty)
                      _ProfileLine(
                        label: 'Business',
                        value: detail.contact.businessType!,
                      ),
                    if ((detail.contact.location ?? '').isNotEmpty)
                      _ProfileLine(
                        label: 'Location',
                        value: detail.contact.location!,
                      ),
                    if (detail.summary.lastPurchaseAt != null)
                      _ProfileLine(
                        label: 'Last purchase',
                        value: _formatDateTime(detail.summary.lastPurchaseAt!),
                      ),
                    if (detail.summary.purchaseFrequencyDays != null)
                      _ProfileLine(
                        label: 'Purchase frequency',
                        value: '${detail.summary.purchaseFrequencyDays} days',
                      ),
                    _ProfileLine(
                      label: 'Churn risk',
                      value: detail.summary.churnRisk,
                    ),
                    if ((detail.contact.notes ?? '').isNotEmpty)
                      _ProfileLine(
                        label: 'Notes',
                        value: detail.contact.notes!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CrmSection(
                title: 'Orders',
                child: detail.orders.isEmpty
                    ? Text(
                        'No seller orders linked to this contact yet.',
                        style: TextStyle(color: Colors.grey.shade400),
                      )
                    : Column(
                        children: detail.orders
                            .map((order) => _OrderCard(order: order))
                            .toList(),
                      ),
              ),
              if (detail.timeline.isNotEmpty) ...[
                const SizedBox(height: 16),
                _CrmSection(
                  title: 'Timeline',
                  child: Column(
                    children: detail.timeline
                        .take(8)
                        .map((event) => _TimelineRow(event: event))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CrmSection extends StatelessWidget {
  const _CrmSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _CrmContactDetailSheet._sectionBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final _CrmOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'UGX ${_formatCurrency(order.grandTotal)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(order.createdAt),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(label: order.paymentStatus, color: Colors.blue),
              _StatusPill(label: order.deliveryStatus, color: Colors.orange),
              _StatusPill(label: '${order.items.length} item(s)', color: Colors.green),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.name} • ${item.quantity} x UGX ${_formatCurrency(item.price)}',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final _CrmTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((event.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event.description!,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  _formatDateTime(event.date),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrmContactDetail {
  const _CrmContactDetail({
    required this.contact,
    required this.summary,
    required this.orders,
    required this.timeline,
  });

  factory _CrmContactDetail.fromJson(Map<String, dynamic> json) {
    final contactJson = json['contact'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['contact'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final summaryJson = json['summary'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['summary'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final ordersJson = json['orders'] is List ? json['orders'] as List : const [];
    final timelineJson = json['timeline'] is List
        ? json['timeline'] as List
        : const [];

    return _CrmContactDetail(
      contact: _CrmContactProfile.fromJson(contactJson),
      summary: _CrmContactSummary.fromJson(summaryJson),
      orders: ordersJson
          .whereType<Map>()
          .map((e) => _CrmOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      timeline: timelineJson
          .whereType<Map>()
          .map((e) => _CrmTimelineEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  final _CrmContactProfile contact;
  final _CrmContactSummary summary;
  final List<_CrmOrder> orders;
  final List<_CrmTimelineEvent> timeline;
}

class _CrmContactProfile {
  const _CrmContactProfile({
    required this.name,
    required this.phones,
    required this.emails,
    this.roleCategory,
    this.notes,
    this.location,
    this.businessType,
  });

  factory _CrmContactProfile.fromJson(Map<String, dynamic> json) {
    return _CrmContactProfile(
      name: json['display_name']?.toString() ?? '',
      phones: _stringList(json['phones']),
      emails: _stringList(json['emails']),
      roleCategory: json['role_category']?.toString(),
      notes: json['notes']?.toString(),
      location: json['location']?.toString(),
      businessType: json['business_type']?.toString(),
    );
  }

  final String name;
  final List<String> phones;
  final List<String> emails;
  final String? roleCategory;
  final String? notes;
  final String? location;
  final String? businessType;
}

class _CrmContactSummary {
  const _CrmContactSummary({
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgOrderValue,
    required this.outstandingBalance,
    required this.segment,
    required this.loyaltyLevel,
    required this.churnRisk,
    this.lastPurchaseAt,
    this.purchaseFrequencyDays,
  });

  factory _CrmContactSummary.fromJson(Map<String, dynamic> json) {
    return _CrmContactSummary(
      totalOrders: _asInt(json['total_orders']),
      totalRevenue: _asDouble(json['total_revenue']),
      avgOrderValue: _asDouble(json['avg_order_value']),
      outstandingBalance: _asDouble(json['outstanding_balance']),
      segment: json['segment']?.toString() ?? 'New',
      loyaltyLevel: json['loyalty_level']?.toString() ?? 'Standard',
      churnRisk: json['churn_risk']?.toString() ?? 'Low',
      lastPurchaseAt: DateTime.tryParse(json['last_purchase_at']?.toString() ?? ''),
      purchaseFrequencyDays: json['purchase_frequency_days'] == null
          ? null
          : _asDouble(json['purchase_frequency_days']),
    );
  }

  final int totalOrders;
  final double totalRevenue;
  final double avgOrderValue;
  final double outstandingBalance;
  final String segment;
  final String loyaltyLevel;
  final String churnRisk;
  final DateTime? lastPurchaseAt;
  final double? purchaseFrequencyDays;
}

class _CrmOrder {
  const _CrmOrder({
    required this.code,
    required this.grandTotal,
    required this.paymentStatus,
    required this.deliveryStatus,
    required this.createdAt,
    required this.items,
  });

  factory _CrmOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] is List ? json['items'] as List : const [];
    return _CrmOrder(
      code: json['code']?.toString() ?? '#',
      grandTotal: _asDouble(json['grand_total']),
      paymentStatus: json['payment_status']?.toString() ?? 'unknown',
      deliveryStatus: json['delivery_status']?.toString() ?? 'unknown',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      items: itemsJson
          .whereType<Map>()
          .map((e) => _CrmOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  final String code;
  final double grandTotal;
  final String paymentStatus;
  final String deliveryStatus;
  final DateTime? createdAt;
  final List<_CrmOrderItem> items;
}

class _CrmOrderItem {
  const _CrmOrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory _CrmOrderItem.fromJson(Map<String, dynamic> json) {
    return _CrmOrderItem(
      name: json['name']?.toString() ?? 'Item',
      quantity: _asDouble(json['quantity']),
      price: _asDouble(json['price']),
    );
  }

  final String name;
  final double quantity;
  final double price;
}

class _CrmTimelineEvent {
  const _CrmTimelineEvent({
    required this.title,
    this.description,
    this.date,
  });

  factory _CrmTimelineEvent.fromJson(Map<String, dynamic> json) {
    return _CrmTimelineEvent(
      title: json['title']?.toString() ?? 'Activity',
      description: json['description']?.toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
    );
  }

  final String title;
  final String? description;
  final DateTime? date;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatCurrency(double value) {
  final rounded = value.round();
  final digits = rounded.toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString().split('').reversed.join();
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Unknown';
  final local = value.toLocal();
  final month = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][local.month - 1];
  final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} $month ${local.year}, $hour:$minute $suffix';
}

/// Premium text field for add contact sheet
class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: const Color(0xFF00A884),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true,
        fillColor: const Color(0xFF1F2C34),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
