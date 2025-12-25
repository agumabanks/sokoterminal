import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/design_tokens.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    final categories = [
      _CategoryItem('Printing', Icons.print_outlined),
      _CategoryItem('Salon', Icons.content_cut_outlined),
      _CategoryItem('Repairs', Icons.build_outlined),
      _CategoryItem('Photography', Icons.camera_alt_outlined),
      _CategoryItem('Tailoring', Icons.checkroom_outlined),
      _CategoryItem('Food', Icons.restaurant_menu_outlined),
      _CategoryItem('Cleaning', Icons.cleaning_services_outlined),
      _CategoryItem('Transport', Icons.local_shipping_outlined),
      _CategoryItem('Other', Icons.miscellaneous_services_outlined),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: DesignTokens.spaceSm,
        mainAxisSpacing: DesignTokens.spaceSm,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final item = categories[index];
        final isSelected = selected == item.name;

        return GestureDetector(
          onTap: () {
            if (isSelected) {
              ref.read(selectedCategoryProvider.notifier).state = null;
            } else {
              ref.read(selectedCategoryProvider.notifier).state = item.name;
            }
          },
          child: AnimatedContainer(
            duration: DesignTokens.durationFast,
            decoration: BoxDecoration(
              color: isSelected ? DesignTokens.brandPrimary : DesignTokens.surfaceWhite,
              borderRadius: DesignTokens.borderRadiusMd,
              border: Border.all(
                color: isSelected ? DesignTokens.brandPrimary : DesignTokens.grayLight,
                width: 1,
              ),
              boxShadow: isSelected ? DesignTokens.shadowMd : DesignTokens.shadowSm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? Colors.white : DesignTokens.grayMedium,
                  size: 28,
                ),
                const SizedBox(height: DesignTokens.spaceSm),
                Text(
                  item.name,
                  style: DesignTokens.textSmall.copyWith(
                    color: isSelected ? Colors.white : DesignTokens.grayDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryItem {
  final String name;
  final IconData icon;

  _CategoryItem(this.name, this.icon);
}
