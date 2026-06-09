import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';

class ServiceCategoryOption {
  const ServiceCategoryOption({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
    this.slug,
  });

  final int id;
  final String name;
  final int? parentId;
  final String? parentName;
  final String? slug;

  String get displayLabel =>
      parentName != null && parentName!.isNotEmpty ? '$parentName › $name' : name;
}

final serviceCategoriesProvider =
    FutureProvider.autoDispose<List<ServiceCategoryOption>>((ref) async {
  final api = ref.read(sellerApiProvider);
  final res = await api.fetchServiceCategories();
  final body = res.data;
  if (body is! Map) return const [];

  final data = body['data'];
  if (data is! List) return const [];

  return data
      .whereType<Map>()
      .expand((parent) {
        final parentId = int.tryParse(parent['id']?.toString() ?? '');
        final parentName = parent['name']?.toString() ?? '';
        if (parentId == null) return const <ServiceCategoryOption>[];

        final children = parent['children'];
        if (children is List && children.isNotEmpty) {
          return children.whereType<Map>().map((child) {
            final childId = int.tryParse(child['id']?.toString() ?? '');
            if (childId == null) return null;
            return ServiceCategoryOption(
              id: childId,
              name: child['name']?.toString() ?? 'Category',
              parentId: parentId,
              parentName: parentName,
              slug: child['slug']?.toString(),
            );
          }).whereType<ServiceCategoryOption>();
        }

        return [
          ServiceCategoryOption(
            id: parentId,
            name: parentName.isNotEmpty ? parentName : 'Category',
            slug: parent['slug']?.toString(),
          ),
        ];
      })
      .toList()
    ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
});