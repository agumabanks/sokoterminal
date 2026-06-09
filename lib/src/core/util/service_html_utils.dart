import 'dart:convert';

/// Normalizes and sanitizes service description HTML so web (Summernote)
/// content, copy-paste, and terminal editor output stay consistent.

final _tagPattern = RegExp(r'<[^>]+>', caseSensitive: false);
final _scriptPattern = RegExp(
  r'<script[\s\S]*?</script>',
  caseSensitive: false,
);
final _styleBlockPattern = RegExp(
  r'<style[\s\S]*?</style>',
  caseSensitive: false,
);
final _commentPattern = RegExp(r'<!--[\s\S]*?-->');
final _dangerousHrefPattern = RegExp(
  r'''href\s*=\s*["']?\s*javascript:''',
  caseSensitive: false,
);

/// Decode a JSON string array column from Drift (gallery URLs, etc.).
List<String> decodeJsonStringList(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is List) {
      return decoded
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return const [];
}

/// Returns true when the string contains meaningful HTML markup.
bool serviceHtmlHasMarkup(String? html) {
  final raw = html?.trim() ?? '';
  if (raw.isEmpty) return false;
  return _tagPattern.hasMatch(raw);
}

/// Prepare HTML from web backend / DB for editing or display.
String normalizeServiceDescriptionHtml(String? html) {
  var result = (html ?? '').trim();
  if (result.isEmpty) return '';

  result = result
      .replaceAll(_commentPattern, '')
      .replaceAll(_scriptPattern, '')
      .replaceAll(_styleBlockPattern, '');

  // Summernote / Word paste artifacts
  result = result
      .replaceAll(RegExp(r'<!\[if[\s\S]*?<!\[endif\]>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<o:p>\s*</o:p>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?o:[^>]+>', caseSensitive: false), '')
      .replaceAll(RegExp(r'class="Mso[^"]*"', caseSensitive: false), '')
      .replaceAll(RegExp(r'xmlns="[^"]*"', caseSensitive: false), '');

  // Downgrade oversized headings from web CMS
  result = result.replaceAllMapped(
    RegExp(r'<h1(\s[^>]*)?>', caseSensitive: false),
    (_) => '<h2>',
  );
  result = result.replaceAll(RegExp(r'</h1>', caseSensitive: false), '</h2>');

  // Remove font tags but keep inner content
  result = result.replaceAll(RegExp(r'<font[^>]*>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'</font>', caseSensitive: false), '');

  // Strip spans/divs wrappers that only carry presentation styles
  final spanPattern = RegExp(r'<span[^>]*>([\s\S]*?)</span>', caseSensitive: false);
  final divPattern = RegExp(r'<div[^>]*>([\s\S]*?)</div>', caseSensitive: false);
  for (var i = 0; i < 4; i++) {
    if (!spanPattern.hasMatch(result)) break;
    result = result.replaceAllMapped(spanPattern, (m) => m.group(1) ?? '');
  }
  if (divPattern.hasMatch(result)) {
    result = result.replaceAllMapped(
      divPattern,
      (m) => '<p>${m.group(1) ?? ''}</p>',
    );
  }

  // Remove inline presentation attributes that cause "giant text" in WebView
  result = _stripAttributes(
    result,
    attributes: const [
      'style',
      'class',
      'id',
      'size',
      'face',
      'color',
      'width',
      'height',
      'align',
      'valign',
      'bgcolor',
      'data-[^=]+',
    ],
  );

  // Remove dangerous links
  result = result.replaceAll(_dangerousHrefPattern, 'href="#"');

  // Normalize line breaks
  result = result
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '<br>')
      .replaceAll(RegExp(r'\r\n'), '\n');

  // Collapse empty paragraphs
  result = result.replaceAll(
    RegExp(r'<p>\s*(?:&nbsp;|\u00a0|\s)*</p>', caseSensitive: false),
    '',
  );

  // Ensure block content is wrapped — bare text nodes become paragraphs
  if (!_tagPattern.hasMatch(result)) {
    return plainLinesToServiceHtml(result);
  }

  return result.trim();
}

/// Sanitize clipboard HTML before inserting into the rich editor.
String sanitizePastedServiceHtml(String html) {
  var result = normalizeServiceDescriptionHtml(html);

  // Paste often brings nested tables from Word — flatten simple single-cell rows
  result = result.replaceAll(
    RegExp(r'<table[^>]*>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(RegExp(r'</table>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'<tbody[^>]*>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'</tbody>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'<tr[^>]*>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'</tr>', caseSensitive: false), '<br>');
  result = result.replaceAll(RegExp(r'<td[^>]*>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'</td>', caseSensitive: false), ' ');

  return result.trim();
}

/// Clean editor output before saving to DB / API.
String prepareServiceDescriptionForSave(String? html) {
  final normalized = normalizeServiceDescriptionHtml(html);
  if (normalized.isEmpty) return '';
  return normalized;
}

/// Multi-line plain text → simple HTML paragraphs (POS plain mode).
String plainLinesToServiceHtml(String text) {
  final lines = text.split('\n').map((l) => l.trim()).toList();
  if (lines.every((l) => l.isEmpty)) return '';

  final buffer = StringBuffer();
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    final body = paragraph.join(' ').trim();
    if (body.isNotEmpty) buffer.write('<p>$body</p>');
    paragraph.clear();
  }

  for (final line in lines) {
    if (line.isEmpty) {
      flush();
      continue;
    }
    if (line.startsWith('• ') || line.startsWith('- ')) {
      flush();
      buffer.write('<p>${_escapeHtml(line)}</p>');
      continue;
    }
    if (line == '---') {
      flush();
      buffer.write('<hr>');
      continue;
    }
    paragraph.add(_escapeHtml(line));
  }
  flush();
  return buffer.toString();
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _stripAttributes(String html, {required List<String> attributes}) {
  var result = html;
  for (final attr in attributes) {
    result = result.replaceAll(
      RegExp('$attr\\s*=\\s*"[^"]*"', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp("$attr\\s*=\\s*'[^']*'", caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp('$attr\\s*=\\s*[^\\s>]+', caseSensitive: false),
      '',
    );
  }
  return result;
}

/// Shared CSS injected into the WebView rich editor (matches [HtmlContent] blog).
String serviceDescriptionEditorCss() {
  return '''
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body {
    margin: 0; padding: 0; height: 100%;
    background: #FFFFFF; color: #111111; overflow: hidden;
    font-family: -apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  #editor-wrap {
    height: 100%; overflow-y: auto;
    -webkit-overflow-scrolling: touch; overscroll-behavior: contain;
  }
  #editor {
    outline: none; word-wrap: break-word;
    padding: 14px 16px 28px;
    font-size: 15px; line-height: 1.65; color: #111111;
  }
  #editor * {
    font-family: inherit !important;
    line-height: inherit !important;
    max-width: 100%;
  }
  #editor :not(h2):not(h3):not(h4) {
    font-size: inherit !important;
    color: inherit !important;
  }
  #editor:empty:before {
    content: attr(data-placeholder);
    color: #AEAEB2; pointer-events: none;
  }
  #editor p { margin: 0 0 12px; }
  #editor h2 {
    font-size: 20px !important; font-weight: 700 !important;
    margin: 20px 0 8px; letter-spacing: -0.3px; color: #111 !important;
  }
  #editor h3 {
    font-size: 17px !important; font-weight: 600 !important;
    margin: 16px 0 6px; letter-spacing: -0.2px; color: #111 !important;
  }
  #editor h4 {
    font-size: 15px !important; font-weight: 600 !important;
    margin: 12px 0 4px; color: #3C3C43 !important;
  }
  #editor ul, #editor ol { padding-left: 22px; margin: 8px 0 14px; }
  #editor li { margin: 6px 0; }
  #editor strong, #editor b { font-weight: 700 !important; }
  #editor em, #editor i { font-style: italic !important; }
  #editor u { text-decoration: underline !important; }
  #editor a { color: #0EBE7E !important; text-decoration: underline; }
  #editor blockquote {
    margin: 12px 0; padding: 10px 14px;
    border-left: 3px solid #0EBE7E; background: #F5F5F7;
    color: #3C3C43 !important;
  }
  #editor hr {
    border: none; border-top: 1px solid #E5E5EA; margin: 18px 0;
  }
  ''';
}