import '../../core/util/haptics.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import 'contacts_controller.dart';
import 'crm_contact_notes_widget.dart';
import 'keypad_screen.dart';

/// Contacts Screen — Premium, light, wow-grade.
/// Following Steve Jobs standard: invisible until useful.
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
    final controller = ref.watch(contactsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: _buildAppBar(state, controller),
      body: Column(
        children: [
          // Contextual permission preview / sync status
          _ContactsStatusArea(state: state, controller: controller),

          // Recent contacts section with header
          if (state.filteredContacts.isNotEmpty) _buildRecentSection(state),

          // Tabs
          Container(
            color: DesignTokens.surfaceWhite,
            child: TabBar(
              controller: _tabController,
              indicatorColor: DesignTokens.brandAccent,
              indicatorWeight: 3,
              labelColor: DesignTokens.brandAccent,
              unselectedLabelColor: DesignTokens.grayMedium,
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
                boxShadow: DesignTokens.shadowMd,
              ),
              child: FloatingActionButton(
                onPressed: () => _showAddContactSheet(context, controller),
                backgroundColor: DesignTokens.brandAccent,
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
        backgroundColor: DesignTokens.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: DesignTokens.grayDark),
          onPressed: () {
            setState(() => _showSearch = false);
            _searchController.clear();
            controller.clearSearch();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: DesignTokens.grayDark, fontSize: 18),
          cursorColor: DesignTokens.brandAccent,
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: DesignTokens.grayMedium),
            border: InputBorder.none,
          ),
          onChanged: controller.search,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: DesignTokens.grayDark),
              onPressed: () {
                _searchController.clear();
                controller.clearSearch();
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: DesignTokens.surface,
      elevation: 0,
      leadingWidth: 48,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(Icons.more_horiz, color: DesignTokens.grayMedium),
      ),
      title: Text(
        'Contacts',
        style: DesignTokens.textTitle,
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: DesignTokens.grayDark),
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
                color: DesignTokens.brandAccent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: DesignTokens.shadowSm,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection(ContactsState state) {
    final recentContacts = state.filteredContacts.take(5).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recent',
              style: DesignTokens.textBodyBold.copyWith(color: DesignTokens.grayDark),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
      return const Center(
        child: CircularProgressIndicator(color: DesignTokens.brandAccent),
      );
    }

    if (!state.permissionGranted && state.contacts.isEmpty) {
      return _EmptySearchState(
        icon: Icons.contacts_outlined,
        title: 'No contacts yet',
        subtitle: 'Sync your phone contacts or add your first customer.',
        ctaText: 'Sync My Contacts',
        onCta: () => controller.requestContactPermission(),
      );
    }

    if (state.filteredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: DesignTokens.grayMedium),
            const SizedBox(height: 16),
            Text(
              state.searchQuery.isNotEmpty
                  ? 'No results for "${state.searchQuery}"'
                  : 'No contacts yet',
              style: TextStyle(color: DesignTokens.grayMedium, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        Haptics.impact();
        await controller.refresh();
      },
      color: DesignTokens.brandAccent,
      backgroundColor: DesignTokens.surfaceWhite,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: state.filteredContacts.length,
        itemBuilder: (context, index) {
          final contact = state.filteredContacts[index];
          final canDelete =
              contact.isFromSoko &&
              contact.id.startsWith('soko_') &&
              !contact.isFromDevice;
          final tile = _ContactListTile(
            contact: contact,
            index: index,
            onTap: () => _showContactDetails(context, contact),
          );
          if (!canDelete) return tile;
          return Dismissible(
            key: Key(contact.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: DesignTokens.error,
                borderRadius: DesignTokens.borderRadiusMd,
              ),
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
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, ContactItem contact) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Contact',
          style: DesignTokens.textTitle,
        ),
        content: Text(
          'Remove ${contact.name} from your contacts?',
          style: DesignTokens.textBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: DesignTokens.grayMedium),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: DesignTokens.error)),
          ),
        ],
      ),
    );
  }

  void _showContactDetails(BuildContext context, ContactItem contact) {
    Haptics.selection();
    if ((contact.remoteCustomerId ?? '').trim().isNotEmpty) {
      _showCrmContactDetails(context, contact);
      return;
    }
    // For Soko CRM contacts without a remote ID, show local POS stats
    if (contact.isFromSoko && contact.id.startsWith('soko_')) {
      final localId = contact.id.substring(5);
      _showLocalStatsSheet(context, contact, localId);
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

  void _showLocalStatsSheet(BuildContext context, ContactItem contact, String localCustomerId) {
    final db = ref.read(appDatabaseProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: SafeArea(
          child: FutureBuilder(
            future: db.getLocalCustomerStats(localCustomerId),
            builder: (context, snapshot) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: DesignTokens.grayLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(child: _LargeAvatar(name: contact.name)),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        contact.name,
                        style: DesignTokens.textTitle.copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if ((contact.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          contact.phone!,
                          style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Data source label
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: DesignTokens.brandAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Local POS data',
                          style: DesignTokens.textSmallBold.copyWith(
                            color: DesignTokens.brandAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator(color: DesignTokens.brandAccent))
                    else if (snapshot.hasData)
                      Builder(builder: (ctx) {
                        final stats = snapshot.data!;
                        return _CrmSection(
                          title: 'Client summary · Local POS data',
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricCard(
                                label: 'Orders',
                                value: stats.totalOrders.toString(),
                              ),
                              _MetricCard(
                                label: 'Revenue',
                                value: 'UGX ${_formatCurrency(stats.totalRevenue)}',
                              ),
                              _MetricCard(
                                label: 'Average',
                                value: 'UGX ${_formatCurrency(stats.avgOrderValue)}',
                              ),
                              if (stats.lastPurchaseAt != null)
                                _MetricCard(
                                  label: 'Last purchase',
                                  value: _formatDateTime(stats.lastPurchaseAt),
                                ),
                            ],
                          ),
                        );
                      })
                    else ...[
                      Center(
                        child: Text(
                          'No local sales data yet.',
                          style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCrmContactDetails(BuildContext context, ContactItem contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surfaceCard,
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
      backgroundColor: DesignTokens.surfaceCard,
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
                  color: DesignTokens.grayLight,
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
                style: DesignTokens.textTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),

              // Phone/Email
              Text(
                contact.phone ?? contact.email ?? 'No contact info',
                style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
              ),

              // Source badges
              const SizedBox(height: 12),
              _SourceBadges(contact: contact),

              const SizedBox(height: 28),

              // Action buttons row
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (contact.phone != null) ...[
                    _ActionChip(
                      icon: Icons.call,
                      label: 'Call',
                      color: DesignTokens.brandAccent,
                      onTap: () {
                        Navigator.pop(context);
                        launchUrl(Uri.parse('tel:${contact.phone}'));
                      },
                    ),
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
                    _ActionChip(
                      icon: Icons.message,
                      label: 'SMS',
                      color: DesignTokens.info,
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DesignTokens.surfaceTint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: DesignTokens.grayLight.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Soko CRM',
                        style: DesignTokens.textBodyBold.copyWith(
                          color: DesignTokens.grayDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save this contact as a customer so you can attach sales, send receipts, and track history.',
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.grayMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                backgroundColor: DesignTokens.brandAccent,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.brandAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        label: const Text('Save as customer'),
                      ),
                      const SizedBox(height: 10),
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
                            const SnackBar(
                              content: Text('Linked to customer'),
                              backgroundColor: DesignTokens.brandAccent,
                            ),
                          );
                        },
                        icon: const Icon(Icons.link),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignTokens.grayDark,
                          side: BorderSide(color: DesignTokens.grayLight),
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
      backgroundColor: DesignTokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: customers.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: DesignTokens.grayLight),
          itemBuilder: (context, index) {
            final c = customers[index];
            return ListTile(
              title: Text(c.name, style: DesignTokens.textBodyBold),
              subtitle: Text(
                c.phone ?? c.email ?? '',
                style: DesignTokens.textSmall.copyWith(color: DesignTokens.grayMedium),
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
      backgroundColor: DesignTokens.surfaceCard,
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
                    color: DesignTokens.grayLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Contact',
                    style: DesignTokens.textTitle.copyWith(fontSize: 22),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: DesignTokens.grayMedium),
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
                  color: DesignTokens.surfaceTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DesignTokens.grayLight.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_outline, color: DesignTokens.grayMedium),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share with team',
                            style: DesignTokens.textBody.copyWith(
                              color: DesignTokens.grayDark,
                            ),
                          ),
                          Text(
                            'Visible to all staff members',
                            style: DesignTokens.textSmall.copyWith(
                              color: DesignTokens.grayMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: shareWithTeam,
                      onChanged: (v) => setModalState(() => shareWithTeam = v),
                      activeThumbColor: DesignTokens.brandAccent,
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
                          backgroundColor: DesignTokens.brandAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
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

/// Contextual permission / sync status area with animated transitions
class _ContactsStatusArea extends StatelessWidget {
  const _ContactsStatusArea({
    required this.state,
    required this.controller,
  });

  final ContactsState state;
  final ContactsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DesignTokens.durationFast,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildChild(context),
    );
  }

  Widget _buildChild(BuildContext context) {
    // Synced + permission granted
    if (state.permissionGranted && state.optedIn) {
      return Container(
        key: const ValueKey('synced'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Row(
          children: [
            const Spacer(),
            _SyncedPill(count: state.contacts.length),
          ],
        ),
      );
    }

    // Permanently denied
    if (state.isPermanentlyDenied) {
      return Container(
        key: const ValueKey('denied'),
        child: _ContactPreviewCard(
          icon: Icons.lock_outline,
          iconColor: DesignTokens.warning,
          title: 'Contacts access disabled',
          subtitle: 'Enable in Settings to sync your phone contacts.',
          ctaText: 'Open Settings',
          onCta: () async => openAppSettings(),
        ),
      );
    }

    // Permission granted but opted out
    if (state.permissionGranted && !state.optedIn) {
      return Container(
        key: const ValueKey('off'),
        child: _ContactPreviewCard(
          icon: Icons.cloud_off_outlined,
          iconColor: DesignTokens.grayMedium,
          title: 'Contact sync is off',
          subtitle: 'Turn on to see your phone contacts in Soko.',
          ctaText: 'Turn On',
          previewCount: state.deviceContactCount,
          onCta: () async => controller.setDeviceContactsOptIn(true),
        ),
      );
    }

    // Not granted -> teaser
    return Container(
      key: const ValueKey('teaser'),
      child: _ContactPreviewCard(
        icon: Icons.contacts_rounded,
        iconColor: DesignTokens.brandAccent,
        title: 'Never lose a customer',
        subtitle: state.deviceContactCount > 0
            ? 'You have ${state.deviceContactCount} contacts on this phone. Sync them to Soko and they\'ll appear on all your Soko terminals instantly.'
            : 'Sync your phone contacts so they\'re available on every Soko terminal — even after you switch devices.',
        ctaText: 'Allow Contacts Access',
        previewCount: state.deviceContactCount > 0 ? state.deviceContactCount : null,
        onCta: () async => controller.requestContactPermission(),
      ),
    );
  }
}

class _SyncedPill extends StatelessWidget {
  const _SyncedPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.brandAccentLight,
        borderRadius: DesignTokens.borderRadiusFull,
        border: Border.all(color: DesignTokens.brandAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: DesignTokens.brandAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count contacts · all devices',
            style: DesignTokens.textSmallBold.copyWith(
              color: DesignTokens.brandAccent,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPreviewCard extends StatelessWidget {
  const _ContactPreviewCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    this.previewCount,
    required this.onCta,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String ctaText;
  final int? previewCount;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceCard,
          borderRadius: DesignTokens.borderRadiusLg,
          boxShadow: DesignTokens.shadowSm,
          border: Border.all(
            color: DesignTokens.grayLight.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: DesignTokens.textBodyBold.copyWith(
                          color: DesignTokens.grayDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: DesignTokens.textSmall.copyWith(
                          color: DesignTokens.grayMedium,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (previewCount != null && previewCount! > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  ...List.generate(3, (i) {
                    return Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _avatarColors[i % _avatarColors.length]
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + i),
                          style: TextStyle(
                            color: _avatarColors[i % _avatarColors.length],
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+$previewCount more',
                      style: DesignTokens.textSmallBold.copyWith(
                        color: DesignTokens.grayDark,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.brandAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  ctaText,
                  style: DesignTokens.textBodyBold.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentContactAvatar extends StatelessWidget {
  const _RecentContactAvatar({required this.contact, required this.onTap});

  final ContactItem contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _getAvatarColor(contact.name);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DesignTokens.grayLight.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DesignTokens.textSmall.copyWith(
                color: DesignTokens.grayDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.contact,
    required this.index,
    required this.onTap,
  });

  final ContactItem contact;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(contact.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: DesignTokens.surfaceCard,
        borderRadius: DesignTokens.borderRadiusMd,
        elevation: 0,
        child: InkWell(
          borderRadius: DesignTokens.borderRadiusMd,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceCard,
              borderRadius: DesignTokens.borderRadiusMd,
              border: Border.all(
                color: DesignTokens.grayLight.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: DesignTokens.textBodyBold.copyWith(
                            color: DesignTokens.grayDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (contact.phone != null && contact.phone!.isNotEmpty)
                          Text(
                            contact.phone!,
                            style: DesignTokens.textSmall.copyWith(
                              color: DesignTokens.grayMedium,
                            ),
                          )
                        else if (contact.email != null &&
                            contact.email!.isNotEmpty)
                          Text(
                            contact.email!,
                            style: DesignTokens.textSmall.copyWith(
                              color: DesignTokens.grayMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: DesignTokens.grayLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaText,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaText;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: DesignTokens.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: DesignTokens.brandAccent),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTokens.textTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
            ),
            if (ctaText != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.brandAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    ctaText!,
                    style: DesignTokens.textBodyBold.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = _getAvatarColor(name);
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: DesignTokens.grayLight.withValues(alpha: 0.6),
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
    );
  }
}

class _SourceBadges extends StatelessWidget {
  const _SourceBadges({required this.contact});
  final ContactItem contact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        if (contact.isFromDevice)
          _Badge(
            label: 'Phone',
            color: DesignTokens.info,
          ),
        if (contact.isFromSoko)
          _Badge(
            label: 'Soko CRM',
            color: DesignTokens.brandAccent,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: DesignTokens.textSmallBold.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: DesignTokens.textSmallBold.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrmContactDetailSheet extends StatefulWidget {
  const _CrmContactDetailSheet({
    required this.contact,
    required this.detailsFuture,
  });

  final ContactItem contact;
  final Future<_CrmContactDetail> detailsFuture;

  @override
  State<_CrmContactDetailSheet> createState() => _CrmContactDetailSheetState();
}

class _CrmContactDetailSheetState extends State<_CrmContactDetailSheet> {
  _CrmContactDetail? _cached;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CrmContactDetail>(
      future: widget.detailsFuture,
      builder: (context, snapshot) {
        final detail = snapshot.data ?? _cached;
        if (detail != null) {
          _cached = detail;
        }
        if (snapshot.connectionState == ConnectionState.waiting && detail == null) {
          return const Center(
            child: CircularProgressIndicator(color: DesignTokens.brandAccent),
          );
        }
        if (detail == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: DesignTokens.grayMedium),
                const SizedBox(height: 12),
                Text(
                  'Could not load details',
                  style: DesignTokens.textTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later.',
                  style: DesignTokens.textBody.copyWith(color: DesignTokens.grayMedium),
                ),
              ],
            ),
          );
        }

        final primaryPhone = detail.contact.phones.isNotEmpty
            ? detail.contact.phones.first
            : widget.contact.phone;
        final primaryEmail = detail.contact.emails.isNotEmpty
            ? detail.contact.emails.first
            : widget.contact.email;

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
                    color: DesignTokens.grayLight,
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
                  style: DesignTokens.textTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              if ((primaryPhone ?? primaryEmail ?? '').isNotEmpty)
                Center(
                  child: Text(
                    primaryPhone ?? primaryEmail ?? '',
                    style: DesignTokens.textBody.copyWith(
                      color: DesignTokens.grayMedium,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Center(child: _SourceBadges(contact: widget.contact)),
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
                      color: DesignTokens.brandAccent,
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
                      color: DesignTokens.info,
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
                        style: DesignTokens.textBody.copyWith(
                          color: DesignTokens.grayMedium,
                        ),
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

              // ── Activity & Notes (live, interactive) ─────────────────────
              const SizedBox(height: 16),
              CrmContactNotesWidget(
                contactId: widget.contact.remoteCustomerId!,
                contactName: detail.contact.name.isNotEmpty
                    ? detail.contact.name
                    : widget.contact.name,
              ),

              const SizedBox(height: 24),
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
        color: DesignTokens.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: DesignTokens.grayLight.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DesignTokens.textBodyBold.copyWith(
              color: DesignTokens.grayDark,
              fontSize: 16,
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
        color: DesignTokens.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.grayLight.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTokens.textSmall.copyWith(
              color: DesignTokens.grayMedium,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: DesignTokens.textBodyBold.copyWith(
              color: DesignTokens.grayDark,
              fontSize: 15,
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
              style: DesignTokens.textSmall.copyWith(
                color: DesignTokens.grayMedium,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesignTokens.textBody.copyWith(
                color: DesignTokens.grayDark,
                fontSize: 14,
              ),
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
        color: DesignTokens.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.grayLight.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: DesignTokens.textBodyBold.copyWith(
                    color: DesignTokens.grayDark,
                  ),
                ),
              ),
              Text(
                'UGX ${_formatCurrency(order.grandTotal)}',
                style: DesignTokens.textBodyBold.copyWith(
                  color: DesignTokens.grayDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDateTime(order.createdAt),
            style: DesignTokens.textSmall.copyWith(
              color: DesignTokens.grayMedium,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(label: order.paymentStatus, color: DesignTokens.info),
              _StatusPill(label: order.deliveryStatus, color: DesignTokens.warning),
              _StatusPill(
                label: '${order.items.length} item(s)',
                color: DesignTokens.success,
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.name} • ${item.quantity} x UGX ${_formatCurrency(item.price)}',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                    fontSize: 13,
                  ),
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
              color: DesignTokens.brandAccent,
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
                  style: DesignTokens.textBodyBold.copyWith(
                    color: DesignTokens.grayDark,
                    fontSize: 14,
                  ),
                ),
                if ((event.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event.description!,
                      style: DesignTokens.textSmall.copyWith(
                        color: DesignTokens.grayMedium,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  _formatDateTime(event.date),
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.grayMedium,
                    fontSize: 12,
                  ),
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
      style: TextStyle(color: DesignTokens.grayDark, fontSize: 16),
      cursorColor: DesignTokens.brandAccent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: DesignTokens.grayMedium),
        prefixIcon: Icon(icon, color: DesignTokens.grayMedium),
        filled: true,
        fillColor: DesignTokens.surfaceTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DesignTokens.brandAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

Color _getAvatarColor(String name) {
  final colors = [
    DesignTokens.brandAccent,
    DesignTokens.info,
    DesignTokens.warning,
    DesignTokens.brandPrimary,
  ];
  return colors[name.length % colors.length];
}

const _avatarColors = [
  DesignTokens.brandAccent,
  DesignTokens.info,
  DesignTokens.warning,
];
