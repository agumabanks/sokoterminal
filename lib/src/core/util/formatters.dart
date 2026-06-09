import 'package:intl/intl.dart';

/// Formats a POS receipt number as `000-XXX` (e.g., `000-001`).
String formatPosReceiptNumber(int? number) {
  if (number == null || number <= 0) return '000-001';
  final numStr = number.toString().padLeft(3, '0');
  return '000-$numStr';
}

extension PriceExtensions on num {
  /// Formats a number to UGX with comma separators.
  /// Example: 1000 -> UGX 1,000
  String toUgx() {
    final format = NumberFormat.currency(
      symbol: 'UGX ',
      decimalDigits: 0,
      locale: 'en_US',
    );
    return format.format(this);
  }

  /// Formats a number as a simple comma-separated value.
  /// Example: 1000 -> 1,000
  String formatCommas() {
    final format = NumberFormat('#,###', 'en_US');
    return format.format(this);
  }
}

extension DateExtensions on DateTime {
  /// Returns a human-readable label for dates (e.g., "Just now", "2h ago", "Dec 24").
  String toRelativeLabel() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM dd').format(this);
  }
}

/// Strips HTML tags from a string and decodes common HTML entities.
/// Returns clean plain text.
String stripHtml(String? html) {
  if (html == null || html.isEmpty) return '';

  // Remove HTML tags
  var result = html.replaceAll(RegExp(r'<[^>]*>'), '');

  // Decode common HTML entities
  result = result
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&bull;', '•');

  // Normalize whitespace
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

  return result;
}

extension StringHtmlExtensions on String {
  /// Strips HTML tags and returns plain text
  String get plainText => stripHtml(this);
}

/// Converts multi-line plain text into simple HTML paragraphs.
String plainTextToHtml(String text) {
  final lines = text.split('\n').map((line) => line.trim()).toList();
  if (lines.every((line) => line.isEmpty)) return '';

  final buffer = StringBuffer();
  final paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    final body = paragraph.join(' ').trim();
    if (body.isNotEmpty) {
      buffer.write('<p>$body</p>');
    }
    paragraph.clear();
  }

  for (final line in lines) {
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }
    paragraph.add(line);
  }
  flushParagraph();
  return buffer.toString();
}

/// Converts stored HTML into editable plain text with paragraph breaks.
String htmlToEditablePlain(String? html) {
  if (html == null || html.isEmpty) return '';

  var result = html
      .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n---\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</(ul|ol)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<(ul|ol)[^>]*>', caseSensitive: false), '');

  result = stripHtml(result);
  return result.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
