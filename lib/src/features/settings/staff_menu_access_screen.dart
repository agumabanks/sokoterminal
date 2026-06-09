import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/pos_session_controller.dart';
import '../../core/settings/staff_menu_visibility.dart';
import '../../core/theme/design_tokens.dart';

class StaffMenuFeature {
  const StaffMenuFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section,
  });

  final String id;
  final String title;
  final String subtitle;
  final String section;
}

const staffMenuFeatures = <StaffMenuFeature>[
  StaffMenuFeature(
    id: 'dashboard',
    title: 'Dashboard',
    subtitle: 'Daily KPIs and sales snapshot',
    section: 'Today',
  ),
  StaffMenuFeature(
    id: 'customers',
    title: 'Customers',
    subtitle: 'Contacts and regular buyers',
    section: 'Today',
  ),
  StaffMenuFeature(
    id: 'orders',
    title: 'Orders',
    subtitle: 'Marketplace and pickup orders',
    section: 'Today',
  ),
  StaffMenuFeature(
    id: 'products',
    title: 'Products',
    subtitle: 'Catalog and pricing',
    section: 'Catalog',
  ),
  StaffMenuFeature(
    id: 'services',
    title: 'Services',
    subtitle: 'Service menu and bookings',
    section: 'Catalog',
  ),
  StaffMenuFeature(
    id: 'quotations',
    title: 'Quotations',
    subtitle: 'Prepare and share quotes',
    section: 'Catalog',
  ),
  StaffMenuFeature(
    id: 'shifts',
    title: 'Shifts & Cash',
    subtitle: 'Shift opening, closing, and cash tracking',
    section: 'Operations',
  ),
  StaffMenuFeature(
    id: 'refunds',
    title: 'Refunds',
    subtitle: 'Return handling and disputes',
    section: 'Operations',
  ),
  StaffMenuFeature(
    id: 'profile',
    title: 'Profile',
    subtitle: 'Personal and business identity surface',
    section: 'Account',
  ),
];

class StaffMenuAccessScreen extends ConsumerWidget {
  const StaffMenuAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posSession = ref.watch(posSessionProvider);
    final state = ref.watch(staffMenuAccessProvider);
    final controller = ref.read(staffMenuAccessProvider.notifier);
    final groups = <String, List<StaffMenuFeature>>{};
    for (final feature in staffMenuFeatures) {
      groups.putIfAbsent(feature.section, () => []).add(feature);
    }

    if (!posSession.isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Menu Access')),
        body: Center(
          child: Padding(
            padding: DesignTokens.paddingScreen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 56,
                  color: DesignTokens.grayMedium,
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                Text(
                  'Manager access required',
                  style: DesignTokens.textTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                Text(
                  'Only managers can change what staff see in the More tab.',
                  style: DesignTokens.textBodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text('Staff Menu Access'),
        actions: [
          TextButton(
            onPressed: controller.resetDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: DesignTokens.paddingScreen,
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.spaceLg),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusLg,
              boxShadow: DesignTokens.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control what staff can see in More',
                  style: DesignTokens.textTitleMedium,
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                Text(
                  'Managers still see the full terminal. These switches only shape the staff-facing menu, so the interface stays focused and harder to misuse.',
                  style: DesignTokens.textBodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: DesignTokens.spaceXs,
                bottom: DesignTokens.spaceSm,
              ),
              child: Text(
                entry.key.toUpperCase(),
                style: DesignTokens.textSmallBold.copyWith(letterSpacing: 0.5),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: DesignTokens.spaceLg),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceWhite,
                borderRadius: DesignTokens.borderRadiusLg,
                boxShadow: DesignTokens.shadowSm,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < entry.value.length; i++) ...[
                    SwitchListTile.adaptive(
                      title: Text(entry.value[i].title),
                      subtitle: Text(
                        entry.value[i].subtitle,
                        style: DesignTokens.textSmall,
                      ),
                      value:
                          !state.loaded || state.isVisible(entry.value[i].id),
                      onChanged: (value) =>
                          controller.toggleFeature(entry.value[i].id, value),
                    ),
                    if (i != entry.value.length - 1)
                      Divider(
                        height: 1,
                        color: DesignTokens.grayLight.withValues(alpha: 0.6),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
