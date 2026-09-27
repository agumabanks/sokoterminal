import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';

class SellerQuickAction {
  const SellerQuickAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.managerOnly = false,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool managerOnly;
}

const sellerQuickActions = <SellerQuickAction>[
  SellerQuickAction(
    id: 'marketing',
    label: 'Marketing',
    subtitle: 'Stickers, video, content',
    icon: Icons.auto_awesome_outlined,
    color: DesignTokens.brandAccent,
  ),
  SellerQuickAction(
    id: 'scan-shop',
    label: 'Scan a shop',
    subtitle: 'Open a Soko storefront',
    icon: Icons.qr_code_scanner_rounded,
    color: DesignTokens.brandAccent,
  ),
  SellerQuickAction(
    id: 'product',
    label: 'New product',
    subtitle: 'Add an item to sell',
    icon: Icons.inventory_2_outlined,
    color: DesignTokens.brandPrimary,
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'service',
    label: 'New service',
    subtitle: 'Publish a bookable service',
    icon: Icons.room_service_outlined,
    color: DesignTokens.info,
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'stock',
    label: 'Receive stock',
    subtitle: 'Record incoming inventory',
    icon: Icons.move_to_inbox_outlined,
    color: DesignTokens.success,
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'expense',
    label: 'Expense',
    subtitle: 'Log money spent',
    icon: Icons.payments_outlined,
    color: DesignTokens.error,
  ),
  SellerQuickAction(
    id: 'ad',
    label: 'Create an ad',
    subtitle: 'Open Soko Studio',
    icon: Icons.auto_awesome_outlined,
    color: DesignTokens.brandAccent,
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'sms',
    label: 'Send SMS',
    subtitle: 'Reach customers quickly',
    icon: Icons.sms_outlined,
    color: Color(0xFF7C3AED),
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'catalog',
    label: 'Share catalog',
    subtitle: 'Build a digital catalog',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF0891B2),
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'customer',
    label: 'Customer',
    subtitle: 'Open contacts and CRM',
    icon: Icons.person_add_alt_1_outlined,
    color: Color(0xFF2563EB),
  ),
  SellerQuickAction(
    id: 'quotation',
    label: 'Quotation',
    subtitle: 'Prepare a customer quote',
    icon: Icons.request_quote_outlined,
    color: Color(0xFFB45309),
  ),
  SellerQuickAction(
    id: 'coupon',
    label: 'Coupon',
    subtitle: 'Create a promotion',
    icon: Icons.confirmation_number_outlined,
    color: DesignTokens.warning,
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'wallet',
    label: 'Sanaa Wallet',
    subtitle: 'Balance, credits, and plans',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF059669),
    managerOnly: true,
  ),
  SellerQuickAction(
    id: 'order',
    label: 'Orders',
    subtitle: 'Review customer orders',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF4F46E5),
  ),
];

class SmartActionLauncher {
  const SmartActionLauncher({
    required this.isManager,
    required this.onSelected,
  });

  final bool isManager;
  final ValueChanged<String> onSelected;

  static const _favoritesKey = 'seller_quick_action_favorites_v1';
  static const _usePrefix = 'seller_quick_action_use_';
  static const _defaultFavorites = <String>[
    'scan-shop',
    'product',
    'service',
    'stock',
    'expense',
    'ad',
  ];

  Future<void> show(BuildContext context, WidgetRef ref) async {
    Haptics.impact();
    final prefs = ref.read(sharedPreferencesProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _QuickActionSheet(prefs: prefs, isManager: isManager),
    );
    if (selected == null || !context.mounted) return;
    await prefs.setInt(
      '$_usePrefix$selected',
      (prefs.getInt('$_usePrefix$selected') ?? 0) + 1,
    );
    Haptics.selection();
    onSelected(selected);
  }

  static List<String> favorites(SharedPreferences prefs) {
    final saved = prefs.getStringList(_favoritesKey);
    return saved == null || saved.isEmpty ? _defaultFavorites : saved;
  }

  static List<SellerQuickAction> rankedFavorites(
    SharedPreferences prefs, {
    required bool isManager,
  }) {
    final favoriteIds = favorites(prefs);
    final actions = favoriteIds
        .map(
          (id) => sellerQuickActions
              .where(
                (action) =>
                    action.id == id && (isManager || !action.managerOnly),
              )
              .firstOrNull,
        )
        .whereType<SellerQuickAction>()
        .toList();
    actions.sort((a, b) {
      final bUses = prefs.getInt('$_usePrefix${b.id}') ?? 0;
      final aUses = prefs.getInt('$_usePrefix${a.id}') ?? 0;
      if (aUses == bUses) {
        return favoriteIds.indexOf(a.id).compareTo(favoriteIds.indexOf(b.id));
      }
      return bUses.compareTo(aUses);
    });
    return actions;
  }
}

class _QuickActionSheet extends StatefulWidget {
  const _QuickActionSheet({required this.prefs, required this.isManager});

  final SharedPreferences prefs;
  final bool isManager;

  @override
  State<_QuickActionSheet> createState() => _QuickActionSheetState();
}

class _QuickActionSheetState extends State<_QuickActionSheet> {
  late List<String> _favoriteIds;
  bool _isCustomizing = false;

  List<SellerQuickAction> get _available => sellerQuickActions
      .where((action) => widget.isManager || !action.managerOnly)
      .toList();

  @override
  void initState() {
    super.initState();
    _favoriteIds = SmartActionLauncher.favorites(
      widget.prefs,
    ).where((id) => _available.any((action) => action.id == id)).toList();
  }

  List<SellerQuickAction> get _smartFavorites {
    return SmartActionLauncher.rankedFavorites(
      widget.prefs,
      isManager: widget.isManager,
    ).where((action) => _favoriteIds.contains(action.id)).toList();
  }

  Future<void> _customize() async {
    setState(() => _isCustomizing = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = _smartFavorites;
    if (_isCustomizing) {
      return Material(
        color: DesignTokens.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: _CustomizeActionsSheet(
          available: _available,
          selectedIds: _favoriteIds,
          onBack: () => setState(() => _isCustomizing = false),
          onSave: (next) async {
            await widget.prefs.setStringList(
              SmartActionLauncher._favoritesKey,
              next,
            );
            if (!mounted) return;
            setState(() {
              _favoriteIds = next;
              _isCustomizing = false;
            });
          },
        ),
      );
    }
    return Material(
      color: DesignTokens.surfaceWhite,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .52,
        maxChildSize: .94,
        builder: (context, controller) => CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DesignTokens.hairline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What would you like to do?',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your most-used actions move to the front.',
                                style: DesignTokens.textSmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _customize,
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('Customize'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (favorites.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionLabel(label: 'YOUR SHORTCUTS'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ActionCard(
                      action: favorites[index],
                      onTap: () =>
                          Navigator.of(context).pop(favorites[index].id),
                    ),
                    childCount: favorites.length,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: _SectionLabel(label: 'ALL TOOLS')),
            SliverList.separated(
              itemCount: _available.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) {
                final action = _available[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 3,
                  ),
                  leading: _ActionIcon(action: action, size: 42),
                  title: Text(
                    action.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(action.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(action.id),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _CustomizeActionsSheet extends StatefulWidget {
  const _CustomizeActionsSheet({
    required this.available,
    required this.selectedIds,
    required this.onBack,
    required this.onSave,
  });

  final List<SellerQuickAction> available;
  final List<String> selectedIds;
  final VoidCallback onBack;
  final ValueChanged<List<String>> onSave;

  @override
  State<_CustomizeActionsSheet> createState() => _CustomizeActionsSheetState();
}

class _CustomizeActionsSheetState extends State<_CustomizeActionsSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = [...widget.selectedIds];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Choose your daily shortcuts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pick up to 8. You can change these any time.',
                style: DesignTokens.textSmall,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.available.map((action) {
                    final selected = _selected.contains(action.id);
                    return CheckboxListTile(
                      value: selected,
                      secondary: _ActionIcon(action: action, size: 38),
                      title: Text(action.label),
                      subtitle: Text(action.subtitle),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (value) {
                        if (value == true && _selected.length >= 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Choose up to 8 shortcuts'),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          if (value == true) {
                            _selected.add(action.id);
                          } else {
                            _selected.remove(action.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => widget.onSave(_selected),
                  child: const Text('Save shortcuts'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});

  final SellerQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: .08),
      borderRadius: DesignTokens.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignTokens.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionIcon(action: action, size: 40),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action, required this.size});

  final SellerQuickAction action;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: action.color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(action.icon, color: action.color, size: size * .52),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        label,
        style: DesignTokens.textCaption.copyWith(
          color: DesignTokens.textTertiary,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}
