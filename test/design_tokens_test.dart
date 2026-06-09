import 'package:flutter_test/flutter_test.dart';
import 'package:soko_seller_terminal/src/core/theme/design_tokens.dart';

void main() {
  test('spacing constants follow 8pt grid', () {
    expect(DesignTokens.spaceSm % 8, 0);
    expect(DesignTokens.spaceMd % 8, 0);
    expect(DesignTokens.spaceLg % 8, 0);
    expect(DesignTokens.spaceXl % 8, 0);
    expect(DesignTokens.spaceXxl % 8, 0);
  });

  test('gray trio maps to primary, secondary, tertiary text', () {
    expect(DesignTokens.textPrimary, DesignTokens.ink);
    expect(DesignTokens.textSecondary, DesignTokens.inkSubtle);
    expect(DesignTokens.textTertiary, DesignTokens.inkMuted);
    expect(DesignTokens.grayDark, DesignTokens.textSecondary);
    expect(DesignTokens.grayMedium, DesignTokens.textTertiary);
  });

  test('core spacing and radius tokens stay on the 8pt system', () {
    expect(DesignTokens.radiusMd, 14);
    expect(DesignTokens.radiusSm, 10);
    expect(DesignTokens.paddingMd.left, DesignTokens.spaceMd);
    expect(DesignTokens.paddingSm.left, DesignTokens.spaceSm);
  });
}