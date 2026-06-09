import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/network/seller_api.dart';
import '../../core/theme/design_tokens.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class CrmNote {
  final String id;
  final String body;
  final String type;
  final bool isPinned;
  final DateTime? createdAt;
  final Map<String, dynamic>? meta;

  const CrmNote({
    required this.id,
    required this.body,
    required this.type,
    required this.isPinned,
    this.createdAt,
    this.meta,
  });

  factory CrmNote.fromJson(Map<String, dynamic> json) => CrmNote(
    id: json['id']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    type: json['type']?.toString() ?? 'note',
    isPinned: json['is_pinned'] == true,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : null,
  );

  CrmNote copyWith({bool? isPinned}) => CrmNote(
    id: id,
    body: body,
    type: type,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt,
    meta: meta,
  );
}

// ─── Note type config ─────────────────────────────────────────────────────────

const _noteTypes = [
  (value: 'note',     label: 'Note',      icon: Icons.notes_outlined,               color: Color(0xFF0F1D40)),
  (value: 'call',     label: 'Call',      icon: Icons.call_outlined,                color: Color(0xFF0EBE7E)),
  (value: 'visit',    label: 'Visit',     icon: Icons.store_outlined,               color: Color(0xFF4299E1)),
  (value: 'sale',     label: 'Sale',      icon: Icons.receipt_long_outlined,        color: Color(0xFF38A169)),
  (value: 'news',     label: 'News',      icon: Icons.campaign_outlined,            color: Color(0xFFF6AD55)),
  (value: 'reminder', label: 'Reminder',  icon: Icons.alarm_outlined,               color: Color(0xFFE53E3E)),
  (value: 'whatsapp', label: 'WhatsApp',  icon: Icons.chat_bubble_outline_rounded,  color: Color(0xFF25D366)),
];

({IconData icon, Color color, String label}) _typeConfig(String type) {
  for (final t in _noteTypes) {
    if (t.value == type) return (icon: t.icon, color: t.color, label: t.label);
  }
  return (icon: Icons.notes_outlined, color: DesignTokens.inkMuted, label: 'Note');
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _crmNotesProvider = StateNotifierProvider.family
    .autoDispose<_CrmNotesNotifier, AsyncValue<List<CrmNote>>, String>((ref, contactId) {
  final api = ref.watch(sellerApiProvider);
  return _CrmNotesNotifier(api, contactId)..load();
});

class _CrmNotesNotifier extends StateNotifier<AsyncValue<List<CrmNote>>> {
  _CrmNotesNotifier(this._api, this._contactId) : super(const AsyncLoading());

  final SellerApi _api;
  final String _contactId;

  Future<void> load() async {
    try {
      final res = await _api.fetchContactNotes(_contactId);
      final body = res.data;
      final rawList = (body is Map && body['data'] is List) ? body['data'] as List : const [];
      final notes = rawList
          .whereType<Map>()
          .map((e) => CrmNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) state = AsyncData(notes);
    } catch (e) {
      if (mounted) state = AsyncError(e, StackTrace.current);
    }
  }

  Future<CrmNote?> addNote({
    required String body,
    required String type,
    bool isPinned = false,
  }) async {
    final clientId = const Uuid().v4();
    try {
      final res = await _api.createContactNote(
        _contactId,
        body: body,
        type: type,
        isPinned: isPinned,
        clientNoteId: clientId,
      );
      final data = (res.data is Map && res.data['data'] is Map)
          ? Map<String, dynamic>.from(res.data['data'] as Map)
          : null;
      if (data == null) return null;
      final note = CrmNote.fromJson(data);
      if (mounted) {
        final current = state.valueOrNull ?? [];
        state = AsyncData([note, ...current]);
      }
      return note;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _api.deleteContactNote(_contactId, noteId);
      if (mounted) {
        final current = state.valueOrNull ?? [];
        state = AsyncData(current.where((n) => n.id != noteId).toList());
      }
    } catch (_) {}
  }

  Future<void> togglePin(String noteId) async {
    try {
      await _api.toggleContactNotePin(_contactId, noteId);
      if (mounted) {
        final current = state.valueOrNull ?? [];
        state = AsyncData(
          current.map((n) => n.id == noteId ? n.copyWith(isPinned: !n.isPinned) : n).toList()
            ..sort((a, b) {
              if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
              return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
            }),
        );
      }
    } catch (_) {}
  }
}

// ─── Main widget ──────────────────────────────────────────────────────────────

/// Embeddable CRM notes section for the contact detail sheet.
/// Shows notes list + "Add" button that opens the note creation sheet.
class CrmContactNotesWidget extends ConsumerWidget {
  const CrmContactNotesWidget({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  final String contactId;
  final String contactName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(_crmNotesProvider(contactId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activity & Notes',
              style: DesignTokens.textBodyBold.copyWith(
                color: DesignTokens.ink,
                fontSize: 16,
              ),
            ),
            GestureDetector(
              onTap: () => _showAddNote(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: DesignTokens.brandAccent,
                  borderRadius: DesignTokens.borderRadiusFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: DesignTokens.textCaption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Notes list ─────────────────────────────────────────────────────
        notesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => _EmptyNotes(
            label: 'Could not load notes',
            onAdd: () => _showAddNote(context, ref),
          ),
          data: (notes) => notes.isEmpty
              ? _EmptyNotes(onAdd: () => _showAddNote(context, ref))
              : Column(
                  children: notes.map((note) => _NoteCard(
                    note: note,
                    onDelete: () => ref.read(_crmNotesProvider(contactId).notifier).deleteNote(note.id),
                    onTogglePin: () => ref.read(_crmNotesProvider(contactId).notifier).togglePin(note.id),
                  )).toList(),
                ),
        ),
      ],
    );
  }

  void _showAddNote(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddNoteSheet(
        contactId: contactId,
        contactName: contactName,
        onSaved: (note) {
          ref.read(_crmNotesProvider(contactId).notifier).load();
        },
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({this.label, required this.onAdd});
  final String? label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: DesignTokens.canvasCloud,
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(color: DesignTokens.hairline),
        ),
        child: Column(
          children: [
            const Icon(Icons.sticky_note_2_outlined, size: 32, color: DesignTokens.inkMuted),
            const SizedBox(height: 10),
            Text(
              label ?? 'No notes yet',
              style: DesignTokens.textSmall.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to add a call log, visit note, or news',
              style: DesignTokens.textCaption.copyWith(color: DesignTokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Note card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onDelete,
    required this.onTogglePin,
  });

  final CrmNote note;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig(note.type);
    final timeLabel = _formatTime(note.createdAt);

    return Dismissible(
      key: Key('note_${note.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: DesignTokens.error.withValues(alpha: 0.1),
          borderRadius: DesignTokens.borderRadiusMd,
        ),
        child: const Icon(Icons.delete_outline, color: DesignTokens.error, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: note.isPinned
              ? DesignTokens.brandAccentDim
              : DesignTokens.canvas,
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(
            color: note.isPinned
                ? DesignTokens.brandAccent.withValues(alpha: 0.25)
                : DesignTokens.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cfg.icon, size: 15, color: cfg.color),
                ),
                const SizedBox(width: 8),
                Text(
                  cfg.label,
                  style: DesignTokens.textCaption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cfg.color,
                  ),
                ),
                const Spacer(),
                if (note.isPinned)
                  const Icon(Icons.push_pin_rounded, size: 14, color: DesignTokens.brandAccent),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onTogglePin,
                  child: Icon(
                    note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 16,
                    color: note.isPinned ? DesignTokens.brandAccent : DesignTokens.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              note.body,
              style: DesignTokens.textBody.copyWith(color: DesignTokens.ink, height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              timeLabel,
              style: DesignTokens.textCaption.copyWith(color: DesignTokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${local.day} ${months[local.month - 1]}';
  }
}

// ─── Add note bottom sheet ────────────────────────────────────────────────────

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({
    required this.contactId,
    required this.contactName,
    required this.onSaved,
  });

  final String contactId;
  final String contactName;
  final void Function(CrmNote note) onSaved;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _bodyCtrl = TextEditingController();
  String _selectedType = 'note';
  bool _saving = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignTokens.canvas,
        borderRadius: DesignTokens.borderRadiusBottomSheet,
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.hairline,
                borderRadius: DesignTokens.borderRadiusFull,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Activity', style: DesignTokens.textTitle),
                    Text(
                      widget.contactName,
                      style: DesignTokens.textSmall.copyWith(color: DesignTokens.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: DesignTokens.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type selector — horizontal scroll pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _noteTypes.map((t) {
                final selected = _selectedType == t.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? t.color : DesignTokens.canvasCloud,
                      borderRadius: DesignTokens.borderRadiusFull,
                      border: Border.all(
                        color: selected ? t.color : DesignTokens.hairline,
                        width: selected ? 0 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 15, color: selected ? Colors.white : t.color),
                        const SizedBox(width: 6),
                        Text(
                          t.label,
                          style: DesignTokens.textCaption.copyWith(
                            color: selected ? Colors.white : DesignTokens.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Body field
          TextField(
            controller: _bodyCtrl,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            style: DesignTokens.textBody.copyWith(color: DesignTokens.ink),
            decoration: InputDecoration(
              hintText: _placeholder(_selectedType),
              hintStyle: DesignTokens.textBody.copyWith(color: DesignTokens.inkDisabled),
              filled: true,
              fillColor: DesignTokens.canvasCloud,
              border: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMd,
                borderSide: const BorderSide(color: DesignTokens.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMd,
                borderSide: const BorderSide(color: DesignTokens.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: DesignTokens.borderRadiusMd,
                borderSide: const BorderSide(color: DesignTokens.brandAccent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),

          // Save
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              minimumSize: const Size(double.infinity, 50),
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _placeholder(String type) {
    return switch (type) {
      'call'     => 'Describe the call — what was discussed, next steps…',
      'visit'    => 'Who visited, what was shared or sold…',
      'sale'     => 'Items sold, amount, payment method…',
      'news'     => 'Any news or update about this contact…',
      'reminder' => 'What to follow up on and when…',
      'whatsapp' => 'Summary of the WhatsApp conversation…',
      _          => 'Write your note here…',
    };
  }

  Future<void> _save() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first'), behavior: SnackBarBehavior.floating, shape: StadiumBorder()),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final note = await ref.read(_crmNotesProvider(widget.contactId).notifier).addNote(
        body: body,
        type: _selectedType,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (note != null) {
        widget.onSaved(note);
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_typeConfig(_selectedType).label} saved'),
            backgroundColor: DesignTokens.ink,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
