String? buildShopShareLink({
  required String? shopId,
  required String? shopName,
}) {
  final id = shopId?.trim();
  final name = shopName?.trim();
  if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
  final slug = name
      .toLowerCase()
      .replaceAll('/', ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  final memorableCode = slug.split('-').first;
  if (memorableCode.isEmpty) return null;
  return Uri.https('soko24.co', '/s/$memorableCode-$id').toString();
}
