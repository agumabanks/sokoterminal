import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';

class ReceiptTemplateEditor extends ConsumerStatefulWidget {
  const ReceiptTemplateEditor({super.key, this.templateId});

  /// If provided, the editor loads and edits the existing template.
  final String? templateId;

  @override
  ConsumerState<ReceiptTemplateEditor> createState() => _ReceiptTemplateEditorState();
}

class _ReceiptTemplateEditorState extends ConsumerState<ReceiptTemplateEditor> {
  final _nameCtrl = TextEditingController(text: 'Custom Template');
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  bool _showLogo = true;
  bool _showQr = true;
  String _color = '0xFF000000';
  String _style = 'minimal';
  String? _existingId;

  // Sample data for preview
  final _sampleItems = [
    {'name': 'Printing (A4 Color)', 'qty': 50, 'price': 500},
    {'name': 'Spiral Binding', 'qty': 2, 'price': 5000},
  ];

  @override
  void initState() {
    super.initState();
    // Load existing template if editing, or set defaults for new template
    Future.microtask(() async {
      final db = ref.read(appDatabaseProvider);
      
      if (widget.templateId != null) {
        // Edit mode: load specific template
        final templates = await db.select(db.receiptTemplates).get();
        final existing = templates.where((t) => t.id == widget.templateId).firstOrNull;
        if (existing != null) {
          setState(() {
            _existingId = existing.id;
            _nameCtrl.text = existing.name;
            _style = existing.style;
            _headerCtrl.text = existing.headerText ?? '';
            _footerCtrl.text = existing.footerText ?? '';
            _showLogo = existing.showLogo;
            _showQr = existing.showQr;
            _color = existing.colorHex ?? '0xFF000000';
          });
        }
      } else {
        // Create mode: set defaults
        _headerCtrl.text = 'Thank you for your business!';
        _footerCtrl.text = 'Goods once sold are not returnable.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: const Text('Receipt Template')),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editor Pane
                Expanded(
                  flex: 4,
                  child: ListView(
                    padding: DesignTokens.paddingScreen,
                    children: [
                      // Template Name
                      Text('Template Name', style: DesignTokens.textBodyBold),
                      const SizedBox(height: DesignTokens.spaceSm),
                      AppInput(
                        controller: _nameCtrl,
                        label: 'Name',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DesignTokens.spaceLg),
                      
                      // Style Selection
                      Text('Style', style: DesignTokens.textBodyBold),
                      const SizedBox(height: DesignTokens.spaceSm),
                      Wrap(
                        spacing: 8,
                        children: ['minimal', 'modern', 'classic'].map((style) {
                          final isSelected = _style == style;
                          return ChoiceChip(
                            label: Text(style[0].toUpperCase() + style.substring(1)),
                            selected: isSelected,
                            selectedColor: DesignTokens.brandAccent.withValues(alpha: 0.2),
                            onSelected: (v) => setState(() => _style = style),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: DesignTokens.spaceLg),
                      
                      // Content Section
                      Text('Content', style: DesignTokens.textBodyBold),
                      const SizedBox(height: DesignTokens.spaceSm),
                      AppInput(
                        controller: _headerCtrl,
                        label: 'Header Message',
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DesignTokens.spaceMd),
                      AppInput(
                        controller: _footerCtrl,
                        label: 'Footer Message',
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: DesignTokens.spaceLg),
                      Text('Options', style: DesignTokens.textBodyBold),
                      SwitchListTile(
                        title: const Text('Show Logo'),
                        value: _showLogo,
                        onChanged: (v) => setState(() => _showLogo = v),
                      ),
                      SwitchListTile(
                        title: const Text('Show QR Code'),
                        value: _showQr,
                        onChanged: (v) => setState(() => _showQr = v),
                      ),
                    ],
                  ),
                ),

                // Preview Pane
                Expanded(
                  flex: 5,
                  child: Container(
                    margin: DesignTokens.paddingScreen,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: DesignTokens.grayLight),
                      boxShadow: DesignTokens.shadowSm,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_showLogo)
                             Container(
                               height: 60, width: 60, 
                               color: Colors.grey[300],
                               child: const Icon(Icons.store, size: 40),
                             ), // Placeholder
                          const SizedBox(height: 12),
                          Text('MY SHOP NAME', style: DesignTokens.textBodyBold),
                          Text('Kampala, Uganda', style: DesignTokens.textSmall),
                          const SizedBox(height: 16),
                          Text(_headerCtrl.text, textAlign: TextAlign.center, style: DesignTokens.textSmall.copyWith(fontStyle: FontStyle.italic)),
                          const Divider(),
                          ..._sampleItems.map((i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${i['qty']}x ${i['name']}'),
                                Text('${(i['qty'] as int) * (i['price'] as int)}'),
                              ],
                            ),
                          )),
                          const Divider(),
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Text('Total', style: DesignTokens.textBodyBold),
                               Text('35,000', style: DesignTokens.textBodyBold),
                             ],
                          ),
                          const SizedBox(height: 16),
                          Text(_footerCtrl.text, textAlign: TextAlign.center, style: DesignTokens.textSmall),
                          const SizedBox(height: 12),
                          if (_showQr)
                            Container(height: 60, width: 60, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
           Container(
            padding: DesignTokens.paddingScreen,
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              boxShadow: DesignTokens.shadowSm,
            ),
            child: SafeArea(
              child: AppButton(
                label: 'Save Template',
                onPressed: _saveTemplate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
     final db = ref.read(appDatabaseProvider);
     final sync = ref.read(syncServiceProvider);
     
     // Use existing ID if editing, otherwise create new
     final id = _existingId ?? const Uuid().v4();

     // Upsert template with all fields
     await db.upsertReceiptTemplate(
       ReceiptTemplatesCompanion(
         id: Value(id),
         name: Value(_nameCtrl.text.trim().isEmpty ? 'Custom Template' : _nameCtrl.text.trim()),
         style: Value(_style),
         headerText: Value(_headerCtrl.text),
         footerText: Value(_footerCtrl.text),
         showLogo: Value(_showLogo),
         showQr: Value(_showQr),
         colorHex: Value(_color),
         updatedAt: Value(DateTime.now().toUtc()),
         synced: const Value(true),
       ),
     );
     
     // Sync
     await sync.enqueue('receipt_template_update', {
       'local_id': id,
       'name': _nameCtrl.text,
       'style': _style,
       'header': _headerCtrl.text,
       'footer': _footerCtrl.text,
       'show_logo': _showLogo ? 1 : 0,
       'show_qr': _showQr ? 1 : 0,
       'color': _color,
     });
     unawaited(sync.syncNow());

     if(!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved')));
     Navigator.pop(context, true); // Return true to signal refresh needed
  }
}
