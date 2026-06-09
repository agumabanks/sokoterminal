import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../core/theme/design_tokens.dart';
import '../core/util/service_html_utils.dart';

/// Blog / Upwork-style renderer for service descriptions.
class ServiceDescriptionArticle extends StatelessWidget {
  const ServiceDescriptionArticle({
    super.key,
    required this.html,
    this.title,
    this.compact = false,
  });

  final String? html;
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeServiceDescriptionHtml(html);
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    final baseSize = compact ? 14.0 : 15.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: DesignTokens.textBodyBold),
          const SizedBox(height: 10),
        ],
        Html(
          data: normalized,
          style: _articleStyles(baseSize),
        ),
      ],
    );
  }

  static Map<String, Style> _articleStyles(double baseSize) {
    return {
      'body': Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(baseSize),
        lineHeight: const LineHeight(1.65),
        color: DesignTokens.ink,
      ),
      'p': Style(
        margin: Margins.only(bottom: 12),
        fontSize: FontSize(baseSize),
        lineHeight: const LineHeight(1.65),
      ),
      'h2': Style(
        fontSize: FontSize(baseSize + 5),
        fontWeight: FontWeight.w700,
        margin: Margins.only(top: 20, bottom: 8),
        letterSpacing: -0.3,
        color: DesignTokens.ink,
      ),
      'h3': Style(
        fontSize: FontSize(baseSize + 2),
        fontWeight: FontWeight.w600,
        margin: Margins.only(top: 16, bottom: 6),
        letterSpacing: -0.2,
        color: DesignTokens.ink,
      ),
      'h4': Style(
        fontSize: FontSize(baseSize),
        fontWeight: FontWeight.w600,
        margin: Margins.only(top: 12, bottom: 4),
        color: DesignTokens.inkSubtle,
      ),
      'ul': Style(
        margin: Margins.only(bottom: 14),
        padding: HtmlPaddings.only(left: 22),
      ),
      'ol': Style(
        margin: Margins.only(bottom: 14),
        padding: HtmlPaddings.only(left: 22),
      ),
      'li': Style(
        margin: Margins.only(bottom: 6),
        fontSize: FontSize(baseSize),
        lineHeight: const LineHeight(1.6),
      ),
      'strong': Style(fontWeight: FontWeight.w700),
      'b': Style(fontWeight: FontWeight.w700),
      'em': Style(fontStyle: FontStyle.italic),
      'i': Style(fontStyle: FontStyle.italic),
      'u': Style(textDecoration: TextDecoration.underline),
      'a': Style(
        color: DesignTokens.brandAccent,
        textDecoration: TextDecoration.underline,
      ),
      'blockquote': Style(
        margin: Margins.symmetric(vertical: 12),
        padding: HtmlPaddings.only(left: 14, top: 10, bottom: 10, right: 10),
        backgroundColor: DesignTokens.canvasCloud,
        border: const Border(left: BorderSide(color: DesignTokens.brandAccent, width: 3)),
        color: DesignTokens.inkSubtle,
      ),
      'hr': Style(
        margin: Margins.symmetric(vertical: 18),
        border: const Border(top: BorderSide(color: DesignTokens.hairline)),
      ),
    };
  }
}