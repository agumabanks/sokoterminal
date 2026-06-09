import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import 'ad_templates.dart';
import 'canvas_renderer.dart';

final _fmt = NumberFormat('#,###');

// Available font families
const _availableFonts = <String>[
  'Default',
  'Serif',
  'Monospace',
  'Cursive',
];

// Map display name to Flutter fontFamily
String? _fontFamilyForName(String name) {
  switch (name) {
    case 'Serif':
      return 'serif';
    case 'Monospace':
      return 'monospace';
    case 'Cursive':
      return 'cursive';
    default:
      return null;
  }
}

String _fontDisplayName(String? family) {
  if (family == null) return 'Default';
  switch (family) {
    case 'serif':
      return 'Serif';
    case 'monospace':
      return 'Monospace';
    case 'cursive':
      return 'Cursive';
    default:
      return 'Default';
  }
}

enum _EditorTool { none, text, font, fontSize, color, image }

class AdDetailScreen extends StatefulWidget {
  const AdDetailScreen({
    super.key,
    required this.template,
    required this.item,
    this.adCopy,
  });

  final AdTemplate template;
  final Item item;
  final Map<String, dynamic>? adCopy;

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final GlobalKey _renderKey = GlobalKey();
  late AdTemplate _current;
  int _sizeIndex = 0;
  bool _exporting = false;
  String? _selectedElementId;
  _EditorTool _activeTool = _EditorTool.none;

  @override
  void initState() {
    super.initState();
    _current = _applyProduct(widget.template);
    for (var i = 0; i < adSizes.length; i++) {
      if (adSizes[i].width == _current.canvasWidth &&
          adSizes[i].height == _current.canvasHeight) {
        _sizeIndex = i;
        break;
      }
    }
  }

  AdTemplate _applyProduct(AdTemplate tpl) {
    return tpl.applyProduct(
      productName: widget.item.name,
      priceFormatted: 'UGX ${_fmt.format(widget.item.price.round())}',
      imageUrl: widget.item.imageUrl ?? widget.item.thumbnailUrl,
    );
  }

  void _switchTemplate(AdTemplate tpl) {
    setState(() {
      _current = _applyProduct(tpl);
      _selectedElementId = null;
      _activeTool = _EditorTool.none;
    });
  }

  CanvasElement? get _selectedElement {
    if (_selectedElementId == null) return null;
    return _current.elements
        .where((e) => e.id == _selectedElementId)
        .firstOrNull;
  }

  // ── Element mutations ────────────────────────────────────

  void _updateElement(String id, CanvasElement Function(CanvasElement) transform) {
    setState(() {
      _current = AdTemplate(
        id: _current.id,
        name: _current.name,
        category: _current.category,
        canvasWidth: _current.canvasWidth,
        canvasHeight: _current.canvasHeight,
        background: _current.background,
        elements: _current.elements.map((e) => e.id == id ? transform(e) : e).toList(),
      );
    });
  }

  void _moveElement(String id, double dx, double dy) {
    _updateElement(id, (e) => e.copyWith(x: e.x + dx, y: e.y + dy));
  }

  void _resizeElement(String id, double dw, double dh) {
    _updateElement(id, (e) {
      final newW = (e.width + dw).clamp(40.0, _current.canvasWidth).toDouble();
      final newH = (e.height + dh).clamp(40.0, _current.canvasHeight).toDouble();
      return e.copyWith(width: newW, height: newH);
    });
  }

  // ── Text editing ──────────────────────────────────────────

  void _editTextInline() {
    final el = _selectedElement;
    if (el == null || el.type != 'text') return;
    final controller = TextEditingController(text: el.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Text', style: DesignTokens.textBodyBold),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Enter text...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _updateElement(el.id, (e) => e.copyWith(text: controller.text));
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.brandAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Font picker ───────────────────────────────────────────

  void _showFontPicker() {
    final el = _selectedElement;
    if (el == null || el.type != 'text') return;
    setState(() => _activeTool = _EditorTool.font);
  }

  void _applyFont(String fontName) {
    final el = _selectedElement;
    if (el == null) return;
    _updateElement(el.id, (e) => CanvasElement(
      id: e.id, type: e.type, text: e.text, src: e.src,
      x: e.x, y: e.y, width: e.width, height: e.height,
      fontSize: e.fontSize, fontWeight: e.fontWeight,
      fontFamily: _fontFamilyForName(fontName),
      fill: e.fill, align: e.align, cornerRadius: e.cornerRadius,
      opacity: e.opacity, textDecoration: e.textDecoration,
      placeholder: e.placeholder,
    ));
  }

  // ── Font size ─────────────────────────────────────────────

  void _changeFontSize(double delta) {
    final el = _selectedElement;
    if (el == null) return;
    final newSize = ((el.fontSize ?? 24) + delta).clamp(8.0, 200.0);
    _updateElement(el.id, (e) => e.copyWith(fontSize: newSize));
  }

  // ── Color picker ──────────────────────────────────────────

  void _showColorPicker() {
    setState(() => _activeTool = _EditorTool.color);
  }

  void _applyColor(String hex) {
    final el = _selectedElement;
    if (el == null) return;
    _updateElement(el.id, (e) => e.copyWith(fill: hex));
  }

  // ── Image replace ─────────────────────────────────────────

  Future<void> _replaceImage() async {
    final el = _selectedElement;
    if (el == null || el.type != 'image') return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
      if (file == null) return;
      _updateElement(el.id, (e) => e.copyWith(src: file.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  // ── Image coverage (resize) ───────────────────────────────

  void _adjustImageCoverage(double factor) {
    final el = _selectedElement;
    if (el == null || el.type != 'image') return;
    final dw = el.width * (factor - 1);
    final dh = el.height * (factor - 1);
    final newW = (el.width + dw).clamp(100.0, _current.canvasWidth).toDouble();
    final newH = (el.height + dh).clamp(100.0, _current.canvasHeight).toDouble();
    final cx = el.x + el.width / 2;
    final cy = el.y + el.height / 2;
    _updateElement(el.id, (e) => e.copyWith(
      width: newW, height: newH,
      x: cx - newW / 2, y: cy - newH / 2,
    ));
  }

  // ── Export ────────────────────────────────────────────────

  Future<File> _export({bool jpg = false}) async {
    // Deselect before export
    setState(() {
      _selectedElementId = null;
      _activeTool = _EditorTool.none;
    });
    await Future.delayed(const Duration(milliseconds: 100));

    final boundary = _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('Render not ready');

    final pixelRatio = _current.canvasWidth / boundary.size.width;
    final image = await boundary.toImage(pixelRatio: pixelRatio.clamp(1.0, 4.0));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Export failed');

    Uint8List bytes = data.buffer.asUint8List();
    String ext = 'png';

    if (jpg) {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
        ext = 'jpg';
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'generated_ads'));
    if (!outDir.existsSync()) await outDir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final size = '${_current.canvasWidth.round()}x${_current.canvasHeight.round()}';
    final file = File(p.join(outDir.path, 'soko-ad-$size-$stamp.$ext'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _shareAd() async {
    setState(() => _exporting = true);
    try {
      final file = await _export();
      final adCopy = widget.adCopy;
      final text = adCopy != null
          ? [adCopy['headline'], adCopy['body'], adCopy['cta']]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join('\n\n')
          : '${widget.item.name}\nUGX ${_fmt.format(widget.item.price.round())}\n\nsoko24.co';
      await Share.shareXFiles([XFile(file.path)], text: text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _downloadAd({bool jpg = false}) async {
    setState(() => _exporting = true);
    try {
      final file = await _export(jpg: jpg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved: ${p.basename(file.path)}'),
        action: SnackBarAction(label: 'Share', onPressed: () => Share.shareXFiles([XFile(file.path)])),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sel = _selectedElement;
    final isTextSelected = sel != null && sel.type == 'text';
    final isImageSelected = sel != null && sel.type == 'image';

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text(_current.name, style: DesignTokens.textTitle.copyWith(fontSize: 17)),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.undo, size: 20),
              tooltip: 'Reset template',
              onPressed: () => setState(() {
                _current = _applyProduct(widget.template);
                _selectedElementId = null;
                _activeTool = _EditorTool.none;
              }),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              onSelected: (v) {
                if (v == 'png') _downloadAd();
                if (v == 'jpg') _downloadAd(jpg: true);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'png', child: Text('Save as PNG')),
                const PopupMenuItem(value: 'jpg', child: Text('Save as JPG')),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Size switcher ──────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: adSizes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = adSizes[i];
                final active = i == _sizeIndex;
                return ChoiceChip(
                  label: Text(s.label, style: TextStyle(fontSize: 11,
                      color: active ? Colors.white : DesignTokens.grayDark)),
                  avatar: Icon(s.icon, size: 14,
                      color: active ? Colors.white : DesignTokens.grayMedium),
                  selected: active,
                  selectedColor: DesignTokens.brandPrimary,
                  onSelected: (_) => _switchSize(i),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // ── Canvas ─────────────────────────────────────────
          Expanded(
            child: ClipRect(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RepaintBoundary(
                    key: _renderKey,
                    child: InteractiveCanvas(
                    template: _current,
                    selectedElementId: _selectedElementId,
                    onElementSelected: (id) {
                      setState(() {
                        _selectedElementId = id;
                        _activeTool = _EditorTool.none;
                      });
                    },
                    onElementMoved: _moveElement,
                    onElementResized: _resizeElement,
                  ),
                ),
              ),
            ),
          ),
          ),

          const SizedBox(height: 4),

          // ── Context toolbar / tool panel ────────────────────
          if (sel != null)
            Listener(
              behavior: HitTestBehavior.opaque,
              child: _buildContextToolbar(sel, isTextSelected, isImageSelected),
            ),

          // ── Expanded tool panel ────────────────────────────
          if (_activeTool != _EditorTool.none)
            Listener(
              behavior: HitTestBehavior.opaque,
              child: _buildToolPanel(),
            ),

          // ── Template picker (when nothing selected) ────────
          if (sel == null)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: builtInTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final tpl = builtInTemplates[i];
                  final active = tpl.id == _current.id;
                  final colors = tpl.previewColors ?? [Colors.grey, Colors.white];
                  return GestureDetector(
                    onTap: () => _switchTemplate(tpl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? DesignTokens.brandAccent : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tpl.name.split(' ').first,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _isLight(colors.first) ? DesignTokens.grayDark : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 6),

          // ── Action bar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exporting ? null : _shareAd,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exporting ? null : _shareAd,
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Context-sensitive bottom toolbar (Canva-style) ────────

  Widget _buildContextToolbar(CanvasElement el, bool isText, bool isImage) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: DesignTokens.shadowMd,
      ),
      child: Row(
        children: [
          if (isText) ...[
            _ToolbarButton(
              icon: Icons.edit,
              label: 'Edit',
              active: _activeTool == _EditorTool.text,
              onTap: _editTextInline,
            ),
            _ToolbarButton(
              icon: Icons.font_download_outlined,
              label: 'Font',
              active: _activeTool == _EditorTool.font,
              onTap: _showFontPicker,
            ),
            _ToolbarButton(
              icon: Icons.format_size,
              label: 'Size',
              active: _activeTool == _EditorTool.fontSize,
              onTap: () => setState(() => _activeTool = _activeTool == _EditorTool.fontSize ? _EditorTool.none : _EditorTool.fontSize),
            ),
            _ToolbarButton(
              icon: Icons.palette_outlined,
              label: 'Color',
              active: _activeTool == _EditorTool.color,
              onTap: _showColorPicker,
            ),
            _ToolbarButton(
              icon: Icons.format_bold,
              label: el.fontWeight == 'bold' ? 'Unbold' : 'Bold',
              onTap: () => _updateElement(el.id, (e) => CanvasElement(
                id: e.id, type: e.type, text: e.text, src: e.src,
                x: e.x, y: e.y, width: e.width, height: e.height,
                fontSize: e.fontSize,
                fontWeight: e.fontWeight == 'bold' ? null : 'bold',
                fontFamily: e.fontFamily,
                fill: e.fill, align: e.align, cornerRadius: e.cornerRadius,
                opacity: e.opacity, textDecoration: e.textDecoration,
              )),
            ),
          ],
          if (isImage) ...[
            _ToolbarButton(
              icon: Icons.swap_horiz,
              label: 'Replace',
              onTap: _replaceImage,
            ),
            _ToolbarButton(
              icon: Icons.zoom_out_map,
              label: 'Bigger',
              onTap: () => _adjustImageCoverage(1.15),
            ),
            _ToolbarButton(
              icon: Icons.zoom_in_map,
              label: 'Smaller',
              onTap: () => _adjustImageCoverage(0.85),
            ),
            _ToolbarButton(
              icon: Icons.palette_outlined,
              label: 'Color',
              active: _activeTool == _EditorTool.color,
              onTap: _showColorPicker,
            ),
          ],
          if (!isText && !isImage) ...[
            _ToolbarButton(
              icon: Icons.palette_outlined,
              label: 'Color',
              active: _activeTool == _EditorTool.color,
              onTap: _showColorPicker,
            ),
          ],
          const Spacer(),
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: DesignTokens.error,
            onTap: () {
              setState(() {
                _current = AdTemplate(
                  id: _current.id, name: _current.name,
                  category: _current.category,
                  canvasWidth: _current.canvasWidth,
                  canvasHeight: _current.canvasHeight,
                  background: _current.background,
                  elements: _current.elements.where((e) => e.id != el.id).toList(),
                );
                _selectedElementId = null;
                _activeTool = _EditorTool.none;
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Expandable tool panels ─────────────────────────────────

  Widget _buildToolPanel() {
    switch (_activeTool) {
      case _EditorTool.font:
        return _buildFontPanel();
      case _EditorTool.fontSize:
        return _buildFontSizePanel();
      case _EditorTool.color:
        return _buildColorPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFontPanel() {
    final currentFont = _fontDisplayName(_selectedElement?.fontFamily);
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _availableFonts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final font = _availableFonts[i];
          final active = font == currentFont;
          return GestureDetector(
            onTap: () => _applyFont(font),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: active ? DesignTokens.brandPrimary : DesignTokens.surfaceWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? DesignTokens.brandPrimary : DesignTokens.grayLight),
              ),
              child: Center(
                child: Text(font, style: TextStyle(
                  fontSize: 14,
                  fontFamily: _fontFamilyForName(font),
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : DesignTokens.grayDark,
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFontSizePanel() {
    final current = _selectedElement?.fontSize ?? 24;
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 24),
            onPressed: () => _changeFontSize(-2),
          ),
          Expanded(
            child: Slider(
              value: current.clamp(8.0, 120.0),
              min: 8,
              max: 120,
              divisions: 56,
              label: '${current.round()}',
              activeColor: DesignTokens.brandPrimary,
              onChanged: (v) {
                final el = _selectedElement;
                if (el == null) return;
                _updateElement(el.id, (e) => e.copyWith(fontSize: v));
              },
            ),
          ),
          Text('${current.round()}', style: DesignTokens.textBodyBold),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            onPressed: () => _changeFontSize(2),
          ),
        ],
      ),
    );
  }

  static const _colorPalette = [
    '#ffffff', '#000000', '#f44336', '#e91e63', '#9c27b0', '#673ab7',
    '#3f51b5', '#2196f3', '#03a9f4', '#00bcd4', '#009688', '#4caf50',
    '#8bc34a', '#cddc39', '#ffeb3b', '#ffc107', '#ff9800', '#ff5722',
    '#795548', '#607d8b', '#c9a96e', '#dc2626', '#f97316', '#1e293b',
    '#7c3aed', '#e11d48', '#075e54', '#25d366', '#1e40af', '#6366f1',
  ];

  Widget _buildColorPanel() {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _colorPalette.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final hex = _colorPalette[i];
          final color = parseHexColor(hex);
          final active = _selectedElement?.fill == hex;
          return GestureDetector(
            onTap: () => _applyColor(hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? DesignTokens.brandAccent : Colors.grey.shade300,
                  width: active ? 3 : 1,
                ),
                boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)] : null,
              ),
              child: active
                  ? Icon(Icons.check, size: 16,
                      color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                  : null,
            ),
          );
        },
      ),
    );
  }

  void _switchSize(int i) {
    setState(() {
      _sizeIndex = i;
      _selectedElementId = null;
      _activeTool = _EditorTool.none;
    });
    final targetSize = adSizes[i];
    final match = builtInTemplates.where(
      (t) => t.category == _current.category &&
          t.canvasWidth == targetSize.width &&
          t.canvasHeight == targetSize.height,
    );
    if (match.isNotEmpty) {
      _switchTemplate(match.first);
    } else {
      final scaleX = targetSize.width / _current.canvasWidth;
      final scaleY = targetSize.height / _current.canvasHeight;
      final scaled = _current.elements.map((e) => CanvasElement(
        id: e.id, type: e.type, text: e.text, src: e.src,
        x: e.x * scaleX, y: e.y * scaleY,
        width: e.width * scaleX,
        height: e.height * scaleY,
        fontSize: e.fontSize != null ? e.fontSize! * scaleX : null,
        fontWeight: e.fontWeight, fontFamily: e.fontFamily,
        fill: e.fill, align: e.align, cornerRadius: e.cornerRadius,
        opacity: e.opacity, textDecoration: e.textDecoration,
      )).toList();
      setState(() {
        _current = AdTemplate(
          id: _current.id, name: _current.name,
          category: _current.category,
          canvasWidth: targetSize.width,
          canvasHeight: targetSize.height,
          background: _current.background,
          elements: scaled,
        );
      });
    }
  }

  bool _isLight(Color c) => c.computeLuminance() > 0.5;
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? DesignTokens.brandPrimary : DesignTokens.grayDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c)),
          ],
        ),
      ),
    );
  }
}
