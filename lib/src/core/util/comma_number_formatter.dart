import 'package:flutter/services.dart';

/// Formats numeric input with comma separators (e.g. 50000 -> 50,000).
///
/// Use this for UGX amount and quantity fields. The raw value (digits only)
/// is available via [unformat].
class CommaNumberFormatter extends TextInputFormatter {
  const CommaNumberFormatter();

  /// Strip commas and return digits-only string.
  static String unformat(String text) => text.replaceAll(',', '');

  /// Format a digits-only string with commas.
  static String format(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Strip all non-digits from the new text
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // If nothing left, return empty
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Prevent leading zeros (except single zero)
    String cleanDigits = digits;
    if (digits.length > 1 && digits.startsWith('0')) {
      cleanDigits = digits.replaceFirst(RegExp(r'^0+'), '');
      if (cleanDigits.isEmpty) cleanDigits = '0';
    }

    final formatted = format(cleanDigits);

    // Calculate new cursor position
    // Count how many digits are before the old cursor
    final oldTextBeforeCursor =
        oldValue.text.substring(0, oldValue.selection.baseOffset);
    final digitsBeforeCursor =
        oldTextBeforeCursor.replaceAll(RegExp(r'[^0-9]'), '').length;

    // In the formatted text, find position where that many digits have appeared
    int digitCount = 0;
    int newCursor = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitCount++;
      }
      newCursor = i + 1;
      if (digitCount >= digitsBeforeCursor) {
        break;
      }
    }

    // Handle case where user is typing at the end
    if (newValue.selection.baseOffset >= oldValue.text.length &&
        newValue.text.length > oldValue.text.length) {
      newCursor = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
