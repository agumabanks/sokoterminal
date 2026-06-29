import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ad_templates.dart';
import '../../core/theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Template Save Dialog
// Displayed from ad_editor_screen when user taps "Save as" in the top bar.
// Supports: save locally, share to community, list on marketplace.
// ---------------------------------------------------------------------------

class TemplateSaveDialog extends StatefulWidget {
  const TemplateSaveDialog({
    super.key,
    required this.template,
    required this.onSaveLocal,
    required this.onShareCommunity,
    required this.onPublishMarketplace,
  });

  final AdTemplate template;
  final void Function(String name) onSaveLocal;
  final void Function(String name) onShareCommunity;
  final void Function(String name, int price) onPublishMarketplace;

  @override
  State<TemplateSaveDialog> createState() => _TemplateSaveDialogState();
}

class _TemplateSaveDialogState extends State<TemplateSaveDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _nameCtrl;
  final _priceCtrl = TextEditingController(text: '5000');
  String _category = 'sale';

  static const _categories = [
    'sale', 'promo', 'new', 'event', 'grand', 'booking',
    'health', 'agri', 'delivery', 'story', 'catalog', 'other',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _nameCtrl = TextEditingController(text: widget.template.name);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignTokens.brandPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            _header(),
            _tabBar(),
            _tabViews(),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            const Icon(Icons.bookmark_add_rounded, color: DesignTokens.brandAccent, size: 22),
            const SizedBox(width: 10),
            const Text('Save Template',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );

  Widget _tabBar() => TabBar(
        controller: _tabs,
        labelColor: DesignTokens.brandAccent,
        unselectedLabelColor: Colors.white54,
        indicatorColor: DesignTokens.brandAccent,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'My Templates'),
          Tab(text: 'Community'),
          Tab(text: 'Marketplace'),
        ],
      );

  Widget _tabViews() => SizedBox(
        height: 340,
        child: TabBarView(
          controller: _tabs,
          children: [
            _LocalSaveTab(
              nameCtrl: _nameCtrl,
              category: _category,
              onCategoryChanged: (c) => setState(() => _category = c),
              onSave: () => widget.onSaveLocal(_nameCtrl.text.trim()),
              categories: _categories,
            ),
            _CommunityTab(
              nameCtrl: _nameCtrl,
              onShare: () =>
                  widget.onShareCommunity(_nameCtrl.text.trim()),
            ),
            _MarketplaceTab(
              nameCtrl: _nameCtrl,
              priceCtrl: _priceCtrl,
              category: _category,
              onCategoryChanged: (c) => setState(() => _category = c),
              onPublish: () {
                final price = int.tryParse(_priceCtrl.text) ?? 0;
                widget.onPublishMarketplace(_nameCtrl.text.trim(), price);
              },
              categories: _categories,
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Local save tab
// ---------------------------------------------------------------------------

class _LocalSaveTab extends StatelessWidget {
  const _LocalSaveTab({
    required this.nameCtrl,
    required this.category,
    required this.onCategoryChanged,
    required this.onSave,
    required this.categories,
  });

  final TextEditingController nameCtrl;
  final String category;
  final void Function(String) onCategoryChanged;
  final VoidCallback onSave;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel('Template name'),
          const SizedBox(height: 6),
          _TextField(ctrl: nameCtrl, hint: 'My Custom Template'),
          const SizedBox(height: 14),
          _FieldLabel('Category'),
          const SizedBox(height: 8),
          _CategoryChips(
              selected: category,
              categories: categories,
              onSelect: onCategoryChanged),
          const Spacer(),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
            ),
            child: const Text('Save to My Templates',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Community share tab
// ---------------------------------------------------------------------------

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({
    required this.nameCtrl,
    required this.onShare,
  });

  final TextEditingController nameCtrl;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.people_alt_rounded, color: DesignTokens.info, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Save to your cloud account and share with other Soko sellers. '
                    'Your design syncs across devices and can be remixed by the community.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Template name'),
          const SizedBox(height: 6),
          _TextField(ctrl: nameCtrl, hint: 'My Design Template'),
          const Spacer(),
          FilledButton(
            onPressed: onShare,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.info,
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
            ),
            child: const Text('Share to Community',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Synced to Soko cloud · reviewed before public listing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marketplace tab
// ---------------------------------------------------------------------------

class _MarketplaceTab extends StatelessWidget {
  const _MarketplaceTab({
    required this.nameCtrl,
    required this.priceCtrl,
    required this.category,
    required this.onCategoryChanged,
    required this.onPublish,
    required this.categories,
  });

  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final String category;
  final void Function(String) onCategoryChanged;
  final VoidCallback onPublish;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel('Template name'),
          const SizedBox(height: 6),
          _TextField(ctrl: nameCtrl, hint: 'Premium Design Template'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Price (UGX)'),
                    const SizedBox(height: 6),
                    _TextField(
                      ctrl: priceCtrl,
                      hint: '5000',
                      inputType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Category'),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: category,
                          dropdownColor: const Color(0xFF1A2340),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: categories.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c[0].toUpperCase() + c.substring(1)),
                          )).toList(),
                          onChanged: (v) => v != null ? onCategoryChanged(v) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignTokens.brandAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.monetization_on_outlined,
                    color: DesignTokens.brandAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You earn 80% of each sale. Soko keeps 20% as a platform fee.',
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onPublish,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.brandAccent,
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
            ),
            child: const Text('List on Marketplace',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.white54, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.ctrl,
    required this.hint,
    this.inputType,
    this.inputFormatters,
  });
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? inputType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      );
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.categories,
    required this.onSelect,
  });
  final String selected;
  final List<String> categories;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: categories.map((c) {
          final isSel = c == selected;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSel
                    ? DesignTokens.brandAccent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel
                      ? DesignTokens.brandAccent
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                c[0].toUpperCase() + c.substring(1),
                style: TextStyle(
                  color: isSel ? DesignTokens.brandAccent : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      );
}
