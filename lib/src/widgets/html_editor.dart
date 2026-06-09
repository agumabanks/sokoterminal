import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme/design_tokens.dart';
import '../core/util/formatters.dart';
import '../core/util/service_html_utils.dart';
import 'service_description_article.dart';

enum HtmlEditorMode { rich, plain }

const _kHtmlEditorChannel = 'HtmlEditorChannel';

/// A lightweight WYSIWYG HTML editor powered by WebView.
///
/// Plain mode uses a native [TextField]. Rich mode uses a scrollable WebView
/// with a native Flutter formatting toolbar (more reliable on POS hardware).
class HtmlEditor extends StatefulWidget {
  const HtmlEditor({
    super.key,
    this.initialHtml,
    this.placeholder = 'Write something…',
    this.label,
    this.helperText,
    this.minHeight = 220,
    this.allowExpand = true,
    this.showCharCount = true,
    this.initialMode = HtmlEditorMode.plain,
    this.richOpensFullscreen = true,
    this.onChanged,
    this.onFocus,
  });

  final String? initialHtml;
  final String placeholder;
  final String? label;
  final String? helperText;
  final double minHeight;
  final bool allowExpand;
  final bool showCharCount;
  final HtmlEditorMode initialMode;
  /// When true, tapping Rich opens the fullscreen editor instead of embedding
  /// a WebView inside a parent scroll view (recommended on POS / narrow screens).
  final bool richOpensFullscreen;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFocus;

  @override
  State<HtmlEditor> createState() => HtmlEditorState();
}

class HtmlEditorState extends State<HtmlEditor> {
  late final WebViewController _controller;
  late final TextEditingController _plainCtrl;
  late HtmlEditorMode _mode;
  String _html = '';
  bool _ready = false;
  bool _focused = false;
  bool _hasRichFormatting = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _html = normalizeServiceDescriptionHtml(widget.initialHtml);
    _hasRichFormatting = serviceHtmlHasMarkup(_html);
    _plainCtrl = TextEditingController(text: htmlToEditablePlain(_html));
    _plainCtrl.addListener(_onPlainChanged);
    _controller = _createWebController();
  }

  WebViewController _createWebController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(DesignTokens.canvas)
      ..addJavaScriptChannel(
        _kHtmlEditorChannel,
        onMessageReceived: (msg) {
          final payload = msg.message;
          if (payload == '__focus__') {
            if (mounted) setState(() => _focused = true);
            widget.onFocus?.call();
            return;
          }
          if (payload == '__blur__') {
            if (mounted) setState(() => _focused = false);
            return;
          }
          _html = payload;
          _hasRichFormatting = serviceHtmlHasMarkup(_html);
          widget.onChanged?.call(_html);
          if (mounted) setState(() {});
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _ready = true;
            if (_html.isNotEmpty) {
              await _setHtml(_html);
            }
            if (mounted) setState(() {});
          },
        ),
      )
      ..loadHtmlString(
        _buildEditorHtml(
          minHeight: widget.minHeight,
          placeholder: widget.placeholder,
        ),
      );
  }

  @override
  void dispose() {
    _plainCtrl
      ..removeListener(_onPlainChanged)
      ..dispose();
    super.dispose();
  }

  void _onPlainChanged() {
    _html = plainTextToHtml(_plainCtrl.text);
    widget.onChanged?.call(_html);
    setState(() {});
  }

  Future<void> _setHtml(String html) async {
    final encoded = jsonEncode(html);
    await _controller.runJavaScript('setHtml($encoded);');
  }

  Future<void> _execCommand(String cmd, {String? value}) async {
    if (!_ready) return;
    final cmdEnc = jsonEncode(cmd);
    if (value != null) {
      final valEnc = jsonEncode(value);
      await _controller.runJavaScript('execCmd($cmdEnc, $valEnc);');
      return;
    }
    await _controller.runJavaScript('execCmd($cmdEnc);');
  }

  Future<String?> getHtml() async {
    if (_mode == HtmlEditorMode.plain) {
      return prepareServiceDescriptionForSave(plainTextToHtml(_plainCtrl.text));
    }
    if (!_ready) return prepareServiceDescriptionForSave(_html);
    final result = await _controller.runJavaScriptReturningResult(
      'document.getElementById("editor").innerHTML',
    );
    String raw;
    if (result is String) {
      try {
        raw = jsonDecode(result) as String;
      } catch (_) {
        raw = result;
      }
    } else {
      raw = result.toString();
    }
    return prepareServiceDescriptionForSave(raw);
  }

  Future<void> _switchMode(HtmlEditorMode next) async {
    if (next == _mode) return;

    if (next == HtmlEditorMode.rich && widget.richOpensFullscreen) {
      await _openFullscreen(forceRich: true);
      return;
    }

    if (next == HtmlEditorMode.plain) {
      final latest = await getHtml();
      _html = latest?.trim() ?? _html;
      _plainCtrl.text = htmlToEditablePlain(_html);
      widget.onChanged?.call(_html);
    } else {
      _html = plainTextToHtml(_plainCtrl.text);
      widget.onChanged?.call(_html);
      if (_ready) {
        await _setHtml(_html);
      }
    }
    if (mounted) setState(() => _mode = next);
  }

  Future<void> _openFullscreen({bool forceRich = false}) async {
    widget.onFocus?.call();
    final latestPlain = plainTextToHtml(_plainCtrl.text);
    final seedHtml = normalizeServiceDescriptionHtml(
      _mode == HtmlEditorMode.plain ? latestPlain : _html,
    );
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _HtmlEditorFullscreenPage(
          initialHtml: seedHtml,
          placeholder: widget.placeholder,
          initialMode: forceRich ? HtmlEditorMode.rich : _mode,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _html = normalizeServiceDescriptionHtml(result);
    _hasRichFormatting = serviceHtmlHasMarkup(_html);
    _plainCtrl.text = htmlToEditablePlain(_html);
    widget.onChanged?.call(_html);
    if (_mode == HtmlEditorMode.rich && _ready) {
      await _setHtml(_html);
    }
    setState(() {});
  }

  int get _charCount => (_mode == HtmlEditorMode.plain
          ? _plainCtrl.text
          : _html.plainText)
      .trim()
      .length;

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused ? DesignTokens.brandAccent : DesignTokens.hairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.label != null)
              Expanded(
                child: Text(widget.label!, style: DesignTokens.textSmallBold),
              )
            else
              const Spacer(),
            _ModeChip(
              label: 'Plain',
              selected: _mode == HtmlEditorMode.plain,
              onTap: () => _switchMode(HtmlEditorMode.plain),
            ),
            const SizedBox(width: 6),
            _ModeChip(
              label: 'Rich',
              selected: _mode == HtmlEditorMode.rich,
              onTap: () => _switchMode(HtmlEditorMode.rich),
            ),
            if (widget.allowExpand) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Expand editor',
                visualDensity: VisualDensity.compact,
                onPressed: _openFullscreen,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                color: DesignTokens.inkMuted,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: DesignTokens.durationFast,
          curve: DesignTokens.curveStandard,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceRaised,
            borderRadius: DesignTokens.borderRadiusMd,
            border: Border.all(color: borderColor, width: _focused ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: _mode == HtmlEditorMode.plain
              ? _buildPlainField()
              : _buildInlineRichEditor(),
        ),
        if (_hasRichFormatting && _mode == HtmlEditorMode.plain) ...[
          const SizedBox(height: 8),
          _RichFormattingBanner(onEdit: () => _openFullscreen(forceRich: true)),
        ],
        if (widget.helperText != null || widget.showCharCount) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (widget.helperText != null)
                Expanded(
                  child: Text(
                    widget.helperText!,
                    style: DesignTokens.textCaption,
                  ),
                ),
              if (widget.showCharCount)
                Text(
                  '$_charCount characters',
                  style: DesignTokens.textCaption,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPlainField() {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextField(
        controller: _plainCtrl,
        maxLines: 8,
        minLines: 6,
        style: DesignTokens.textBody.copyWith(color: DesignTokens.ink),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: DesignTokens.textBody.copyWith(
            color: DesignTokens.inkDisabled,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onTap: widget.onFocus,
      ),
    );
  }

  Widget _buildInlineRichEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RichToolbar(onCommand: _execCommand),
        SizedBox(
          height: widget.minHeight,
          child: WebViewWidget(
            controller: _controller,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
          ),
        ),
      ],
    );
  }
}

class _RichFormattingBanner extends StatelessWidget {
  const _RichFormattingBanner({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.brandAccentSubtle,
      borderRadius: DesignTokens.borderRadiusMd,
      child: InkWell(
        onTap: onEdit,
        borderRadius: DesignTokens.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.format_paint_outlined,
                  size: 18, color: DesignTokens.brandAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This description has rich formatting',
                  style: DesignTokens.textSmall.copyWith(
                    color: DesignTokens.brandAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Edit',
                style: DesignTokens.textSmallBold.copyWith(
                  color: DesignTokens.brandAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RichToolbar extends StatelessWidget {
  const _RichToolbar({required this.onCommand});

  final Future<void> Function(String cmd, {String? value}) onCommand;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DesignTokens.canvasCloud,
        border: Border(bottom: BorderSide(color: DesignTokens.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            _ToolbarBtn(
              icon: Icons.format_bold,
              label: 'Bold',
              onPressed: () => onCommand('bold'),
            ),
            _ToolbarBtn(
              icon: Icons.format_italic,
              label: 'Italic',
              onPressed: () => onCommand('italic'),
            ),
            _ToolbarBtn(
              icon: Icons.format_underlined,
              label: 'Underline',
              onPressed: () => onCommand('underline'),
            ),
            _ToolbarBtn(
              icon: Icons.title,
              label: 'H2',
              onPressed: () => onCommand('formatBlock', value: '<h2>'),
            ),
            _ToolbarBtn(
              icon: Icons.text_fields,
              label: 'H3',
              onPressed: () => onCommand('formatBlock', value: '<h3>'),
            ),
            _ToolbarBtn(
              icon: Icons.format_list_bulleted,
              label: 'List',
              onPressed: () => onCommand('insertUnorderedList'),
            ),
            _ToolbarBtn(
              icon: Icons.format_list_numbered,
              label: '1.',
              onPressed: () => onCommand('insertOrderedList'),
            ),
            _ToolbarBtn(
              icon: Icons.horizontal_rule,
              label: 'Line',
              onPressed: () => onCommand('insertHorizontalRule'),
            ),
            _ToolbarBtn(
              icon: Icons.subject,
              label: 'Para',
              onPressed: () => onCommand('formatBlock', value: '<p>'),
            ),
            _ToolbarBtn(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: () => onCommand('undo'),
            ),
            _ToolbarBtn(
              icon: Icons.redo,
              label: 'Redo',
              onPressed: () => onCommand('redo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: DesignTokens.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: DesignTokens.ink),
                const SizedBox(width: 4),
                Text(label, style: DesignTokens.textCaption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? DesignTokens.brandAccentDim : Colors.transparent,
          borderRadius: DesignTokens.borderRadiusFull,
          border: Border.all(
            color: selected ? DesignTokens.brandAccent : DesignTokens.hairline,
          ),
        ),
        child: Text(
          label,
          style: DesignTokens.textCaption.copyWith(
            color: selected ? DesignTokens.brandAccent : DesignTokens.inkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HtmlEditorFullscreenPage extends StatefulWidget {
  const _HtmlEditorFullscreenPage({
    required this.initialHtml,
    required this.placeholder,
    required this.initialMode,
  });

  final String initialHtml;
  final String placeholder;
  final HtmlEditorMode initialMode;

  @override
  State<_HtmlEditorFullscreenPage> createState() =>
      _HtmlEditorFullscreenPageState();
}

class _HtmlEditorFullscreenPageState extends State<_HtmlEditorFullscreenPage> {
  final _editorKey = GlobalKey<HtmlEditorState>();
  String _draft = '';
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _draft = normalizeServiceDescriptionHtml(widget.initialHtml);
    _tabIndex = widget.initialMode == HtmlEditorMode.rich ? 0 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final editorHeight = MediaQuery.sizeOf(context).height * 0.52;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceGrouped,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: DesignTokens.surfaceRaised,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Service Description', style: DesignTokens.textTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final html = await _editorKey.currentState?.getHtml();
              if (!context.mounted) return;
              Navigator.pop(
                context,
                prepareServiceDescriptionForSave(html ?? _draft),
              );
            },
            child: Text(
              'Done',
              style: DesignTokens.textBodyBold.copyWith(
                color: DesignTokens.brandAccent,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Edit'), icon: Icon(Icons.edit_note)),
                ButtonSegment(value: 1, label: Text('Preview'), icon: Icon(Icons.visibility_outlined)),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (value) {
                setState(() => _tabIndex = value.first);
              },
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        child: _tabIndex == 0
            ? HtmlEditor(
                key: _editorKey,
                initialHtml: _draft,
                initialMode: widget.initialMode == HtmlEditorMode.rich
                    ? HtmlEditorMode.rich
                    : HtmlEditorMode.plain,
                placeholder: widget.placeholder,
                label: 'Write like an Upwork listing',
                helperText:
                    'Paste from web or docs — formatting is cleaned automatically. Use headings and lists.',
                minHeight: editorHeight,
                allowExpand: false,
                richOpensFullscreen: false,
                onChanged: (html) => _draft = html,
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DesignTokens.surfaceRaised,
                    borderRadius: DesignTokens.borderRadiusLg,
                    border: Border.all(color: DesignTokens.hairline),
                  ),
                  child: ServiceDescriptionArticle(
                    title: 'How buyers will see this',
                    html: _draft,
                  ),
                ),
              ),
      ),
    );
  }
}

String _buildEditorHtml({
  required double minHeight,
  required String placeholder,
}) {
  final minHeightPx = minHeight.round();
  final placeholderAttr = jsonEncode(placeholder);
  final editorCss = serviceDescriptionEditorCss();

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
$editorCss
  #editor { min-height: ${minHeightPx}px; }
</style>
</head>
<body>
<div id="editor-wrap">
  <div id="editor" contenteditable="true" data-placeholder=$placeholderAttr></div>
</div>
<script>
  const editor = document.getElementById('editor');
  const channel = window.$_kHtmlEditorChannel;

  function send() {
    if (channel) channel.postMessage(editor.innerHTML);
  }

  function setHtml(html) {
    editor.innerHTML = html || '';
    send();
  }

  function execCmd(cmd, value) {
    if (cmd === 'formatBlock' && value) {
      document.execCommand('formatBlock', false, value);
    } else {
      document.execCommand(cmd, false, value || null);
    }
    editor.focus();
    send();
  }

  function sanitizePasteHtml(raw) {
    if (!raw) return '';
    let html = raw;
    html = html.replace(/<script[\\s\\S]*?<\\/script>/gi, '');
    html = html.replace(/<style[\\s\\S]*?<\\/style>/gi, '');
    html = html.replace(/<!--[\\s\\S]*?-->/g, '');
    html = html.replace(/<\\?xml[\\s\\S]*?>/gi, '');
    html = html.replace(/<\\/?o:[^>]+>/gi, '');
    html = html.replace(/<font[^>]*>/gi, '').replace(/<\\/font>/gi, '');
    html = html.replace(/ style="[^"]*"/gi, '').replace(/ style='[^']*'/gi, '');
    html = html.replace(/ class="[^"]*"/gi, '').replace(/ class='[^']*'/gi, '');
    html = html.replace(/ size="[^"]*"/gi, '');
    html = html.replace(/<h1/gi, '<h2').replace(/<\\/h1>/gi, '<\\/h2>');
    html = html.replace(/<span[^>]*>/gi, '').replace(/<\\/span>/gi, '');
    return html.trim();
  }

  editor.addEventListener('paste', function(e) {
    e.preventDefault();
    const html = e.clipboardData.getData('text/html');
    const text = e.clipboardData.getData('text/plain');
    if (html && html.trim()) {
      document.execCommand('insertHTML', false, sanitizePasteHtml(html));
    } else if (text) {
      const lines = text.split('\\n');
      const chunks = lines.map(function(line) {
        const trimmed = line.trim();
        if (!trimmed) return '<br>';
        if (trimmed.startsWith('• ') || trimmed.startsWith('- ')) {
          return '<p>' + trimmed + '</p>';
        }
        return '<p>' + trimmed + '</p>';
      });
      document.execCommand('insertHTML', false, chunks.join(''));
    }
    send();
  });

  editor.addEventListener('input', send);
  editor.addEventListener('focus', () => {
    if (channel) channel.postMessage('__focus__');
  });
  editor.addEventListener('blur', () => {
    if (channel) channel.postMessage('__blur__');
  });
</script>
</body>
</html>
''';
}