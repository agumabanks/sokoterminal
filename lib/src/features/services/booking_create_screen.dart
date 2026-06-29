import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../contacts/contacts_controller.dart';
import 'availability_controller.dart';
import 'service_bookings_controller.dart';

/// Walk-in Booking Creation — with time-slot picker and conflict detection.
class BookingCreateScreen extends ConsumerStatefulWidget {
  const BookingCreateScreen({
    super.key,
    this.preselectedServiceId,
    this.preselectedDate,
  });
  final String? preselectedServiceId;
  final DateTime? preselectedDate;

  @override
  ConsumerState<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends ConsumerState<BookingCreateScreen> {
  String? _selectedServiceId;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  int _durationMinutes = 60;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot; // "HH:MM"
  String _meetingType = 'in_person';
  bool _saving = false;
  bool _loadingSlots = false;
  List<String> _availableSlots = [];
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.preselectedServiceId;
    if (widget.preselectedDate != null) {
      _selectedDate = widget.preselectedDate!;
    }
    _autoFillFromService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
  }

  Future<void> _autoFillFromService() async {
    if (_selectedServiceId == null) return;
    final db = ref.read(appDatabaseProvider);
    final service = await db.getServiceById(_selectedServiceId!);
    if (service == null) return;
    setState(() {
      _priceCtrl.text = service.price.toStringAsFixed(0);
      _durationMinutes = service.durationMinutes ?? 60;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
        _availableSlots = [];
      });
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    if (_selectedServiceId == null) return;
    final service = await ref.read(appDatabaseProvider).getServiceById(_selectedServiceId!);
    if (service == null) return;

    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    try {
      final api = ref.read(sellerApiProvider);
      final res = await api.fetchAvailableSlots(
        offeringId: service.remoteId ?? 0,
        date: dateStr,
        timezone: DateTime.now().timeZoneName,
      );
      final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final slotsData = data['data'] is Map ? data['data'] as Map<String, dynamic> : <String, dynamic>{};
      final slots = List<String>.from(slotsData['slots'] ?? []);
      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
      });
    } catch (e) {
      // Offline fallback: generate locally
      final bookingsState = ref.read(serviceBookingsControllerProvider);
      final controller = ref.read(availabilityControllerProvider.notifier);
      final slots = controller.generateSlotsForDate(
        dateStr: dateStr,
        durationMinutes: _durationMinutes,
        existingBookings: bookingsState.bookings,
      );
      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
        if (slots.isEmpty) {
          _slotsError = 'No slots available. Check your working hours or try another date.';
        }
      });
    }
  }

  bool get _hasConflict {
    if (_selectedSlot == null || _selectedServiceId == null) return false;
    final start = _bookingStart;
    final end = _bookingEnd;
    if (start == null || end == null) return false;

    final bookingsState = ref.read(serviceBookingsControllerProvider);
    for (final b in bookingsState.bookings) {
      final bStartStr = b['scheduled_start']?.toString();
      final bEndStr = b['scheduled_end']?.toString();
      if (bStartStr == null || bEndStr == null) continue;
      final bStart = DateTime.tryParse(bStartStr);
      final bEnd = DateTime.tryParse(bEndStr);
      if (bStart == null || bEnd == null) continue;

      if (start.isBefore(bEnd) && end.isAfter(bStart)) {
        return true;
      }
    }
    return false;
  }

  DateTime? get _bookingStart {
    if (_selectedSlot == null) return null;
    final parts = _selectedSlot!.split(':');
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime? get _bookingEnd {
    final start = _bookingStart;
    if (start == null) return null;
    return start.add(Duration(minutes: _durationMinutes));
  }

  Future<void> _pickFromContacts() async {
    final contactsState = ref.read(contactsControllerProvider);
    final contacts = contactsState.contacts;

    final picked = await showModalBottomSheet<ContactItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactPickerSheet(contacts: contacts),
    );

    if (picked != null) {
      setState(() {
        _nameCtrl.text = picked.name;
        if ((picked.phone ?? '').trim().isNotEmpty) {
          _phoneCtrl.text = picked.phone!.trim();
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty || _selectedServiceId == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill client name and price')),
      );
      return;
    }
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    final sync = ref.read(syncServiceProvider);

    final start = _bookingStart!;
    final end = _bookingEnd!;
    final service = await db.getServiceById(_selectedServiceId!);

    final locationJson = _locationCtrl.text.trim().isNotEmpty
        ? {'address': _locationCtrl.text.trim()}
        : null;

    try {
      await sync.enqueue('booking_create', {
        'offering_id': service?.remoteId,
        'client_name': name,
        'client_phone': _phoneCtrl.text.trim(),
        'scheduled_start': start.toUtc().toIso8601String(),
        'scheduled_end': end.toUtc().toIso8601String(),
        'price': price,
        'notes': _notesCtrl.text.trim(),
        'timezone': DateTime.now().timeZoneName,
        'meeting_type': _meetingType,
        if (locationJson != null) 'location': locationJson,
      });
      unawaited(sync.syncNow());
    } catch (e) {
      debugPrint('[BookingCreate] Sync enqueue failed: $e');
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking created'),
        backgroundColor: DesignTokens.brandAccent,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: const Text('New Booking')),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          // Service selector
          StreamBuilder<List<Service>>(
            stream: db.watchServices(),
            builder: (context, snap) {
              final services = snap.data ?? [];
              return DropdownButtonFormField<String?>(
                initialValue: _selectedServiceId,
                decoration: const InputDecoration(
                  labelText: 'Service',
                  prefixIcon: Icon(Icons.room_service_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select a service')),
                  ...services.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.title),
                  )),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedServiceId = v;
                    _selectedSlot = null;
                    _availableSlots = [];
                  });
                  _autoFillFromService();
                  _loadSlots();
                },
              );
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Client name + pick from contacts
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _pickFromContacts,
                  icon: const Icon(Icons.contacts_outlined, size: 18),
                  label: const Text('Pick'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.brandAccent,
                    side: BorderSide(
                      color: DesignTokens.brandAccent.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: DesignTokens.borderRadiusMd,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Client phone
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Date picker
          InkWell(
            onTap: _pickDate,
            borderRadius: DesignTokens.borderRadiusMd,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Time slots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Slots', style: DesignTokens.textSmallBold),
              if (_loadingSlots)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          if (_slotsError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_slotsError!, style: const TextStyle(color: DesignTokens.warning, fontSize: 13)),
            ),
          if (_availableSlots.isEmpty && !_loadingSlots)
            const Text(
              'No slots for this date. Pick another date or check working hours.',
              style: TextStyle(color: DesignTokens.grayMedium, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSlots.map((slot) {
                final selected = _selectedSlot == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSlot = slot),
                  selectedColor: DesignTokens.brandAccent,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : DesignTokens.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Conflict warning
          if (_hasConflict)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: DesignTokens.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: DesignTokens.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This slot overlaps with an existing booking',
                      style: TextStyle(color: DesignTokens.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Duration chips
          Text('Duration', style: DesignTokens.textSmallBold),
          const SizedBox(height: DesignTokens.spaceXs),
          Wrap(
            spacing: 8,
            children: [30, 60, 90, 120, 180, 240].map((min) {
              final selected = _durationMinutes == min;
              return ChoiceChip(
                label: Text('${min ~/ 60}h${min % 60 > 0 ? ' ${min % 60}m' : ''}'),
                selected: selected,
                onSelected: (_) {
                  setState(() => _durationMinutes = min);
                  _loadSlots();
                },
                selectedColor: DesignTokens.brandAccent.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? DesignTokens.brandAccent : DesignTokens.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Meeting type
          DropdownButtonFormField<String>(
            initialValue: _meetingType,
            decoration: const InputDecoration(
              labelText: 'Meeting Type',
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'in_person', child: Text('In Person')),
              DropdownMenuItem(value: 'virtual', child: Text('Virtual')),
              DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _meetingType = v);
            },
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Location / Link
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location or Meeting Link (optional)',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Price
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (UGX)',
              prefixIcon: Icon(Icons.money),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),

          // Notes for client
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes for client (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
              hintText: 'e.g. bring ID, park at back entrance…',
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),

          ElevatedButton.icon(
            onPressed: (_saving || _hasConflict) ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Create Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact Picker Sheet ─────────────────────────────────────────────────────
class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet({required this.contacts});
  final List<ContactItem> contacts;

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<ContactItem> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.contacts
          : widget.contacts.where((c) {
              return c.name.toLowerCase().contains(q) ||
                  (c.phone?.toLowerCase().contains(q) ?? false);
            }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.grayLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Pick a Contact', style: DesignTokens.textTitle),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: DesignTokens.grayMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search contacts…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: DesignTokens.canvasParchment,
                  border: OutlineInputBorder(
                    borderRadius: DesignTokens.borderRadiusMd,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts found',
                        style: DesignTokens.textCaption,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: DesignTokens.hairline),
                      itemBuilder: (context, index) {
                        final c = _filtered[index];
                        final initial = c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: DesignTokens.brandAccent.withValues(alpha: 0.12),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: DesignTokens.brandAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(c.name, style: DesignTokens.textBodyBold),
                          subtitle: (c.phone ?? '').isNotEmpty
                              ? Text(c.phone!, style: DesignTokens.textCaption)
                              : null,
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
