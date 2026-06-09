import '../../core/db/app_database.dart';
import 'brand_kit_screen.dart';
import 'studio_product_utils.dart';
import 'studio_variable_utils.dart';

/// Live shop/product values for resolving {{TOKENS}} on canvas and export.
class StudioVariableContext {
  const StudioVariableContext({
    required this.kit,
    this.product,
    this.productLink = '',
  });

  final BrandKit kit;
  final Item? product;
  final String productLink;

  static const empty = StudioVariableContext(
    kit: BrandKit(),
    product: null,
    productLink: '',
  );

  String resolve(String? raw) => resolveStudioVariables(
        raw,
        kit: kit,
        product: product,
        productLink: productLink,
      );

  StudioVariableContext copyWith({
    BrandKit? kit,
    Item? product,
    String? productLink,
  }) =>
      StudioVariableContext(
        kit: kit ?? this.kit,
        product: product ?? this.product,
        productLink: productLink ?? this.productLink,
      );
}