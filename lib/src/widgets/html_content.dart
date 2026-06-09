import 'package:flutter/material.dart';

import 'service_description_article.dart';
import '../core/util/service_html_utils.dart';

/// Renders HTML content inline — delegates to [ServiceDescriptionArticle]
/// for consistent blog-style typography across the app.
class HtmlContent extends StatelessWidget {
  const HtmlContent({
    super.key,
    required this.html,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.style,
    this.compact = false,
  });

  final String? html;
  final int? maxLines;
  final TextOverflow overflow;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final raw = html?.trim() ?? '';
    if (raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasHtml = serviceHtmlHasMarkup(raw);
    if (!hasHtml) {
      return Text(
        raw,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }

    if (maxLines != null) {
      // Truncated preview — show plain text excerpt
      final plain = raw.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
      return Text(
        plain,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }

    return ServiceDescriptionArticle(html: raw, compact: compact);
  }
}