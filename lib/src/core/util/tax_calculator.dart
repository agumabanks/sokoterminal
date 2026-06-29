/// Tax calculation helpers.
class TaxCalculator {
  /// Calculate tax amount for a given [subtotal] and [ratePercent].
  ///
  /// When [inclusive] is true, the tax is extracted from the subtotal.
  /// When false, the tax is added on top of the subtotal.
  static double taxAmount(double subtotal, double ratePercent,
      {bool inclusive = false}) {
    if (subtotal <= 0 || ratePercent <= 0) return 0;
    if (inclusive) {
      // tax-included: tax = subtotal - (subtotal / (1 + rate/100))
      return (subtotal - (subtotal / (1 + ratePercent / 100)))
          .roundToDouble();
    }
    // tax-exclusive: tax = subtotal * rate/100
    return (subtotal * (ratePercent / 100)).roundToDouble();
  }

  /// Net amount before tax when price is tax-inclusive.
  static double netAmount(double grossSubtotal, double ratePercent) {
    if (grossSubtotal <= 0 || ratePercent <= 0) return grossSubtotal;
    return (grossSubtotal / (1 + ratePercent / 100)).roundToDouble();
  }

  /// Gross total when price is tax-exclusive.
  static double grossTotal(double netSubtotal, double ratePercent) {
    if (netSubtotal <= 0 || ratePercent <= 0) return netSubtotal;
    return (netSubtotal * (1 + ratePercent / 100)).roundToDouble();
  }
}
