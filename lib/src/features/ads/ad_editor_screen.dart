import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/theme/design_tokens.dart';
import 'ad_templates.dart';
import 'brand_kit_screen.dart';
import 'creative_library_panel.dart';
import 'studio_entitlements.dart';
import 'studio_media_picker.dart';
import 'studio_providers.dart';
import 'studio_recent_designs.dart';
import 'studio_share_sheet.dart';
import 'studio_variable_context.dart';
import 'studio_watermark.dart';
import 'studio_watermark_settings.dart';
import 'template_save_dialog.dart';
import 'editor/editor_alignment_bar.dart';
import 'editor/editor_bottom_toolbar.dart';
import 'editor/editor_canvas.dart';
import 'editor/editor_floating_toolbar.dart';
import 'editor/editor_shared_widgets.dart';
import 'editor/editor_state.dart';
import 'editor/editor_top_bar.dart';
import 'editor/panels/background_panel.dart';
import 'studio_onboarding_prefs.dart';
import 'editor/panels/effects_panel.dart';
import 'editor/panels/font_panel.dart';
import 'editor/panels/image_panel.dart';
import 'editor/panels/layers_panel.dart';
import 'editor/panels/photo_tools_panel.dart';
import 'editor/panels/text_panel.dart';
import 'remove_background.dart';

// ---------------------------------------------------------------------------
// Ad Editor Screen
// ---------------------------------------------------------------------------

class AdEditorScreen extends ConsumerStatefulWidget {
  const AdEditorScreen({
    super.key,
    required this.template,
    required this.onSave,
    this.product,
    this.productLink,
    this.initialPanel,
  });

  final AdTemplate template;
  final ValueChanged<AdTemplate> onSave;
  final Item? product;
  final String? productLink;
  /// `text` | `image` | `background` | `elements` | `fonts` | `effects` | `layers`
  final String? initialPanel;

  @override
  ConsumerState<AdEditorScreen> createState() => _AdEditorScreenState();
}

class _AdEditorScreenState extends ConsumerState<AdEditorScreen>
    with SingleTickerProviderStateMixin {
  final _canvasKey = GlobalKey();
  final _transformCtrl = TransformationController();
  final _imagePicker = ImagePicker();

  late final _editorProv = editorProvider(widget.template);

  String? _activePanel; // text|image|background|elements|fonts|effects|layers
  bool _busy = false;
  bool _isExporting = false; // hides handles/guides during PNG capture
  bool _hintDismissed = false;

  // Canvas display dimensions
  double _displayScale = 1.0;
  Offset _canvasOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _activePanel = widget.initialPanel;
    _transformCtrl.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransform);
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onTransform() => setState(() {});

  // Compute element's bounding rect in screen coordinates
  Rect _elementToScreen(CanvasElement el) {
    final matrix = _transformCtrl.value;
    // Canvas logical → display pixel
    final tl = Offset(el.x * _displayScale, el.y * _displayScale);
    final br = Offset((el.x + el.width) * _displayScale, (el.y + el.height) * _displayScale);
    // Apply InteractiveViewer transform (pan+zoom)
    final stl = MatrixUtils.transformPoint(matrix, tl + _canvasOrigin);
    final sbr = MatrixUtils.transformPoint(matrix, br + _canvasOrigin);
    return Rect.fromPoints(stl, sbr);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_editorProv);
    final notifier = ref.read(_editorProv.notifier);
    final kit = ref.watch(brandKitProvider);
    final varCtx = StudioVariableContext(
      kit: kit,
      product: widget.product,
      productLink: widget.productLink ?? '',
    );
    final sel = state.selected;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    _displayScale = (screenW) / state.template.canvasWidth;
    final canvasW = state.template.canvasWidth * _displayScale;
    final canvasH = state.template.canvasHeight * _displayScale;
    final hasSeenEditorHint = ref.watch(hasSeenStudioEditorHintProvider);
    final showHint = !hasSeenEditorHint && !_hintDismissed;
    final watermarkSettings = ref.watch(watermarkSettingsProvider);
    final showWatermarkPreview = ref.watch(watermarkPreviewProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top bar
                TopBar(
              template: state.template,
              activeSize: state.activeSize,
              canUndo: state.undoStack.length > 1,
              canRedo: state.redoStack.isNotEmpty,
              showGrid: state.showGrid,
              snapEnabled: state.snapEnabled,
              isBusy: _busy,
              onUndo: notifier.undo,
              onRedo: notifier.redo,
              onToggleGrid: notifier.toggleGrid,
              onToggleSnap: notifier.toggleSnap,
              onSave: () => _saveAndClose(state),
              onShare: () => _share(state, kit),
              onSaveAs: () => _saveAs(state),
              onResize: notifier.resizeToSize,
            ),

            // Canvas area
            Expanded(
              child: Stack(
                children: [
                  // Pinch-zoom-pan canvas
                  LayoutBuilder(builder: (ctx, constraints) {
                    // Store canvas origin for coordinate transform
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final rb = ctx.findRenderObject() as RenderBox?;
                      if (rb != null) {
                        _canvasOrigin = rb.localToGlobal(Offset.zero);
                      }
                    });

                    return InteractiveViewer(
                      transformationController: _transformCtrl,
                      minScale: 0.3,
                      maxScale: 8.0,
                      constrained: false,
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: _canvasKey,
                            child: SizedBox(
                              width: canvasW,
                              height: canvasH,
                              child: EditorCanvas(
                                state: state,
                                scale: _displayScale,
                                isExporting: _isExporting,
                                variableContext: varCtx,
                                onElementTap: (id) {
                                  if (state.template.elements
                                      .firstWhere((e) => e.id == id).isLocked) {
                                    return;
                                  }
                                  notifier.select(id);
                                  setState(() => _activePanel = null);
                                },
                                onCanvasTap: () {
                                  notifier.select(null);
                                  setState(() => _activePanel = null);
                                },
                                onElementMoved: (id, dx, dy) {
                                  final el = state.template.elements
                                      .firstWhere((e) => e.id == id);
                                  if (el.isLocked) return;
                                  var nx = el.x + dx / _displayScale;
                                  var ny = el.y + dy / _displayScale;
                                  // Snap to canvas edges and center
                                  if (state.snapEnabled) {
                                    final cw = state.template.canvasWidth;
                                    final ch = state.template.canvasHeight;
                                    const thresh = 12.0;
                                    if ((nx).abs() < thresh) nx = 0;
                                    if ((nx + el.width - cw).abs() < thresh) nx = cw - el.width;
                                    if ((nx + el.width / 2 - cw / 2).abs() < thresh) nx = cw / 2 - el.width / 2;
                                    if ((ny).abs() < thresh) ny = 0;
                                    if ((ny + el.height - ch).abs() < thresh) ny = ch - el.height;
                                    if ((ny + el.height / 2 - ch / 2).abs() < thresh) ny = ch / 2 - el.height / 2;
                                  }
                                  notifier.updateElement(el.copyWith(x: nx, y: ny));
                                },
                                onElementResized: (id, dw, dh, anchor) {
                                  final el = state.template.elements
                                      .firstWhere((e) => e.id == id);
                                  if (el.isLocked) return;
                                  _applyResize(notifier, el, dw, dh, anchor);
                                },
                                onElementRotated: (id, angle) {
                                  final el = state.template.elements
                                      .firstWhere((e) => e.id == id);
                                  notifier.updateElement(el.copyWith(rotation: angle));
                                },
                              ),
                            ),
                          ),
                          if (showWatermarkPreview && watermarkSettings.enabled)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Padding(
                                  padding: EdgeInsets.all(canvasW * 0.04),
                                  child: Align(
                                    alignment: switch (watermarkSettings.position) {
                                      WatermarkPosition.topLeft => Alignment.topLeft,
                                      WatermarkPosition.topRight => Alignment.topRight,
                                      WatermarkPosition.bottomLeft => Alignment.bottomLeft,
                                      WatermarkPosition.bottomRight => Alignment.bottomRight,
                                      WatermarkPosition.center => Alignment.center,
                                    },
                                    child: SizedBox(
                                      width: canvasW * watermarkSettings.scale,
                                      height: canvasW * watermarkSettings.scale,
                                      child: Opacity(
                                        opacity: watermarkSettings.opacity,
                                        child: _buildWatermarkPreviewImage(
                                          watermarkAssetPath(
                                            settings: watermarkSettings,
                                            brandKit: kit,
                                          ),
                                          canvasW * watermarkSettings.scale,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Floating element toolbar (above selected element)
                  if (sel != null && sel.isVisible)
                    AnimatedBuilder(
                      animation: _transformCtrl,
                      builder: (_, __) {
                        final rect = _elementToScreen(sel);
                        const tbH = 40.0;
                        final top = (rect.top - tbH - 6).clamp(
                            MediaQuery.of(context).padding.top + 44.0,
                            screenH - tbH);
                        return Positioned(
                          left: rect.left.clamp(0, screenW - 240),
                          top: top,
                          child: FloatingToolbar(
                            element: sel,
                            onDelete: notifier.deleteSelected,
                            onDuplicate: notifier.duplicateSelected,
                            onBringForward: notifier.bringForward,
                            onSendBackward: notifier.sendBackward,
                            onLock: notifier.toggleLock,
                            onEditText: sel.type == 'text'
                                ? () => setState(() => _activePanel = 'text')
                                : null,
                            onEditFont: sel.type == 'text'
                                ? () => setState(() => _activePanel = 'fonts')
                                : null,
                            onEditImage: sel.type == 'image'
                                ? () => setState(() => _activePanel = 'image')
                                : null,
                          ),
                        );
                      },
                    ),

                  // Alignment toolbar (shows when element selected)
                  if (sel != null && sel.isVisible)
                    Positioned(
                      bottom: 0,
                      left: 0, right: 0,
                      child: AlignmentBar(
                        onAlign: notifier.alignSelected,
                      ),
                    ),
                ],
              ),
            ),

            // Quick bottom tool bar
            BottomToolbar(
              activePanel: _activePanel,
              hasSelection: sel != null,
              onTool: (panel) {
                setState(() => _activePanel = _activePanel == panel ? null : panel);
                if (panel != 'text' && panel != 'fonts' && panel != 'image') {
                  notifier.select(null);
                }
              },
            ),

            // Panel slides up from bottom
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _buildPanel(state, notifier, kit, varCtx),
            ),
          ],
        ),
      ),
      AnimatedOpacity(
        opacity: showHint ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        onEnd: () {
          if (_hintDismissed) {
            ref.read(hasSeenStudioEditorHintProvider.notifier).markSeen();
          }
        },
        child: showHint
            ? _EditorFirstRunHint(
                onDismiss: () => setState(() => _hintDismissed = true),
              )
            : const SizedBox.shrink(),
      ),
    ],
  ),
);
  }

  Widget _buildPanel(
    EditorState state,
    EditorNotifier notifier,
    BrandKit kit,
    StudioVariableContext varCtx,
  ) {
    final sel = state.selected;
    switch (_activePanel) {
      case 'text':
        return TextPanel(
          element: sel,
          kit: kit,
          product: widget.product,
          productLink: varCtx.productLink,
          brandColors: brandPaletteColors(
            primary: kit.primaryColor,
            secondary: kit.secondaryColor,
            accent: kit.accentColor,
          ),
          onUpdate: notifier.updateElement,
          onAddText: () {
            final tpl = state.template;
            final id = 'text_${DateTime.now().millisecondsSinceEpoch}';
            notifier.addElement(CanvasElement(
              id: id, type: 'text',
              text: 'Your Text',
              x: tpl.canvasWidth * 0.1,
              y: tpl.canvasHeight * 0.4,
              width: tpl.canvasWidth * 0.8,
              fontSize: 52,
              fontFamily: kit.headingFont,
              fontWeight: 'bold',
              fill: '#ffffff',
              align: 'center',
            ));
          },
        );
      case 'photo':
        return PhotoToolsPanel(
          element: sel,
          onCrop: sel?.src?.isNotEmpty == true
              ? () => _cropSelected(notifier, sel!)
              : null,
          onRotateLeft: sel?.src?.isNotEmpty == true
              ? () => _rotateSelected(notifier, sel!, counterClockwise: true)
              : null,
          onRotateRight: sel?.src?.isNotEmpty == true
              ? () => _rotateSelected(notifier, sel!, counterClockwise: false)
              : null,
          onFlipH: sel != null ? () => notifier.updateElement(sel.copyWith(flipX: !sel.flipX)) : null,
          onFlipV: sel != null ? () => notifier.updateElement(sel.copyWith(flipY: !sel.flipY)) : null,
          onRemoveBg: sel?.src?.isNotEmpty == true
              ? () => _removeBg(notifier, sel!)
              : null,
          onAddText: () => _addTextElement(notifier, state),
          onAddSticker: () => _addStickerElement(notifier, state),
          onOpenFilters: () => setState(() => _activePanel = 'image'),
          onOpenAdjust: () => _showAdjustNotice(),
        );
      case 'image':
        return ImagePanel(
          element: sel,
          onPickGallery: () => _pickImage(notifier, state, camera: false),
          onPickCamera: () => _pickImage(notifier, state, camera: true),
          onPickCatalog: () => _pickStudioMedia(notifier, state),
          onRemoveBg: sel?.src?.isNotEmpty == true
              ? () => _removeBg(notifier, sel!)
              : null,
          onUpdate: sel != null ? notifier.updateElement : null,
        );
      case 'background':
        return BackgroundPanel(
          current: state.template.background,
          brandColors: brandPaletteColors(
            primary: kit.primaryColor,
            secondary: kit.secondaryColor,
            accent: kit.accentColor,
          ),
          onSolid: notifier.setBackground,
          onGradient: (preset) => notifier.setBackground('gradient:${preset.id}'),
        );
      case 'elements':
        return CreativeLibraryPanel(
          canvasWidth: state.template.canvasWidth,
          canvasHeight: state.template.canvasHeight,
          currentBackground: state.template.background,
          product: widget.product,
          onInsert: (el) {
            final id = '${el.id}_${DateTime.now().millisecondsSinceEpoch}';
            notifier.addElement(stampCanvasElement(
              el,
              newId: id,
              canvasWidth: state.template.canvasWidth,
              canvasHeight: state.template.canvasHeight,
            ));
            setState(() => _activePanel = null);
          },
          onInsertGroup: (elements, background) {
            notifier.applyMagicLayout(background, elements);
            setState(() => _activePanel = null);
          },
          onApplyBackground: notifier.setBackground,
        );
      case 'fonts':
        return FontPanel(
          selectedFont: sel?.fontFamily ?? kit.font,
          element: sel,
          onSelect: (font) {
            if (sel != null) notifier.updateElement(sel.copyWith(fontFamily: font));
          },
        );
      case 'effects':
        return EffectsPanel(
          element: sel,
          onUpdate: sel != null ? notifier.updateElement : null,
          onAlign: sel != null ? notifier.alignSelected : null,
        );
      case 'layers':
        return LayersPanel(
          elements: state.sortedElements,
          selectedId: state.selectedId,
          onSelect: notifier.select,
          onReorder: (oldZ, newZ) {
            final diff = newZ - oldZ;
            notifier.moveLayer(
              state.template.elements.firstWhere((e) => e.zIndex == oldZ).id,
              diff > 0,
            );
          },
          onToggleLock: (id) {
            final el = state.template.elements.firstWhere((e) => e.id == id);
            notifier.updateElement(el.copyWith(isLocked: !el.isLocked));
          },
          onToggleVisibility: notifier.toggleVisibility,
          onDelete: notifier.deleteElement,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _applyResize(EditorNotifier notifier, CanvasElement el,
      double dw, double dh, ResizeAnchor anchor) {
    final ds = _displayScale;
    double x = el.x, y = el.y;
    double w = el.width + dw / ds;
    double h = el.height + dh / ds;

    // Adjust position for left/top anchors
    if (anchor == ResizeAnchor.topLeft || anchor == ResizeAnchor.left ||
        anchor == ResizeAnchor.bottomLeft) {
      x = el.x - dw / ds;
      w = el.width + dw / ds;
    }
    if (anchor == ResizeAnchor.topLeft || anchor == ResizeAnchor.top ||
        anchor == ResizeAnchor.topRight) {
      y = el.y - dh / ds;
      h = el.height + dh / ds;
    }
    notifier.updateElement(el.copyWith(
      x: math.max(0, x),
      y: math.max(0, y),
      width: math.max(20, w),
      height: math.max(20, h),
    ));
  }

  Future<void> _applyImageSrc(
    EditorNotifier notifier,
    EditorState state,
    String src,
  ) async {
    final sel = state.selected;
    if (sel?.type == 'image') {
      notifier.updateElement(sel!.copyWith(src: src));
    } else {
      final tpl = state.template;
      final w = tpl.canvasWidth * 0.7;
      notifier.addElement(CanvasElement(
        id: 'img_${DateTime.now().millisecondsSinceEpoch}',
        type: 'image',
        src: src,
        x: tpl.canvasWidth * 0.15,
        y: tpl.canvasHeight * 0.2,
        width: w,
        height: w,
        cornerRadius: 16,
      ));
    }
  }

  Future<void> _pickStudioMedia(
    EditorNotifier notifier,
    EditorState state,
  ) async {
    final pick = await showStudioMediaPicker(
      context,
      ref: ref,
      title: 'Insert image',
    );
    if (pick == null || !mounted) return;
    await _applyImageSrc(notifier, state, pick.src);
  }

  Future<void> _pickImage(EditorNotifier notifier, EditorState state,
      {required bool camera}) async {
    try {
      final xf = await _imagePicker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery);
      if (xf == null || !mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: xf.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: kSurface,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: kAccent,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Image'),
        ],
      );

      final src = 'file://${cropped?.path ?? xf.path}';
      await _applyImageSrc(notifier, state, src);
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_pick_image'));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image pick failed: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }
  }

  Future<void> _cropSelected(EditorNotifier notifier, CanvasElement el) async {
    final src = el.src;
    if (src == null || src.isEmpty) return;
    final path = src.startsWith('file://') ? src.substring(7) : src;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: kSurface,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: kAccent,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Image'),
        ],
      );
      if (cropped == null || !mounted) return;
      notifier.updateElement(el.copyWith(src: 'file://${cropped.path}'));
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_crop'));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: $e'), backgroundColor: DesignTokens.error),
        );
      }
    }
  }

  Future<void> _rotateSelected(
    EditorNotifier notifier,
    CanvasElement el, {
    required bool counterClockwise,
  }) async {
    final src = el.src;
    if (src == null || src.isEmpty) return;
    try {
      setState(() => _busy = true);
      final path = src.startsWith('file://') ? src.substring(7) : src;
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      decoded = counterClockwise
          ? img.copyRotate(decoded, angle: -90)
          : img.copyRotate(decoded, angle: 90);
      final dir = await getTemporaryDirectory();
      final dest = p.join(
        dir.path,
        'soko-rotate-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(dest).writeAsBytes(img.encodePng(decoded));
      notifier.updateElement(el.copyWith(src: 'file://$dest'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rotated 90°')),
        );
      }
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_rotate'));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotate failed: $e'), backgroundColor: DesignTokens.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addTextElement(EditorNotifier notifier, EditorState state) {
    final tpl = state.template;
    final id = 'text_${DateTime.now().millisecondsSinceEpoch}';
    notifier.addElement(CanvasElement(
      id: id,
      type: 'text',
      text: 'Your Text',
      x: tpl.canvasWidth * 0.1,
      y: tpl.canvasHeight * 0.4,
      width: tpl.canvasWidth * 0.8,
      fontSize: 52,
      fontWeight: 'bold',
      fill: '#ffffff',
      align: 'center',
    ));
  }

  void _addStickerElement(EditorNotifier notifier, EditorState state) {
    final tpl = state.template;
    final id = 'sticker_${DateTime.now().millisecondsSinceEpoch}';
    notifier.addElement(CanvasElement(
      id: id,
      type: 'sticker',
      text: '★',
      x: tpl.canvasWidth * 0.4,
      y: tpl.canvasHeight * 0.4,
      width: tpl.canvasWidth * 0.2,
      fontSize: 120,
      fill: '#facc15',
      align: 'center',
    ));
  }

  void _showAdjustNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adjust tool selected — brightness, contrast & saturation scaffold ready.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeBg(EditorNotifier notifier, CanvasElement el) async {
    final src = el.src;
    if (src == null || src.isEmpty) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await removeImageBackground(
      api: ref.read(sellerApiProvider),
      src: src,
    );
    if (mounted) {
      if (result.success && result.resultUrl != null) {
        notifier.updateElement(el.copyWith(src: result.resultUrl));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Background removed'),
            backgroundColor: kAccent,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Background removal failed'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
      setState(() => _busy = false);
    }
  }

  Future<void> _saveAndClose(EditorState state) async {
    unawaited(ref.read(studioCampaignAnalyticsProvider.notifier).recordEdit());
    widget.onSave(state.template);
  }

  Future<void> _share(EditorState state, BrandKit kit) async {
    setState(() => _busy = true);
    try {
      setState(() => _isExporting = true);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Canvas not ready for export');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Failed to encode PNG');
      }

      var bytes = data.buffer.asUint8List();
      final entitlements = await ref.read(studioEntitlementsProvider.future);
      final watermarkSettings = ref.read(watermarkSettingsProvider);
      if (entitlements.needsSokoWatermark) {
        bytes = await applySokoWatermark(
          bytes,
          settings: watermarkSettings,
          brandKit: kit,
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'soko-ad-${state.template.id}.png'));
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) setState(() => _isExporting = false);
      if (!mounted) return;
      await ref.read(recentDesignsProvider.notifier).add(state.template);
      unawaited(ref.read(studioCampaignAnalyticsProvider.notifier).recordExport());
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.event('studio_export', props: {
          'template_id': state.template.id,
          'template_name': state.template.name,
          'has_watermark': entitlements.needsSokoWatermark,
        }));
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudioShareSheet(
          adFile: file,
          template: state.template,
          kit: kit,
          initialProduct: widget.product,
          showWatermarkBadge: entitlements.needsSokoWatermark,
          activeSize: state.activeSize,
        ),
      ));
    } catch (e, st) {
      final telemetry = Telemetry.instance;
      if (telemetry != null) {
        unawaited(telemetry.recordError(e, st, hint: 'studio_export'));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _saveAs(EditorState state) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplateSaveDialog(
        template: state.template,
        onSaveLocal: (name) {
          final tpl = state.template;
          final namedTpl = AdTemplate(
            id: tpl.id,
            name: name.trim().isEmpty ? tpl.name : name.trim(),
            category: tpl.category,
            canvasWidth: tpl.canvasWidth,
            canvasHeight: tpl.canvasHeight,
            background: tpl.background,
            elements: tpl.elements,
            previewColors: tpl.previewColors,
          );
          Navigator.pop(context);  // close the dialog first
          widget.onSave(namedTpl); // then save + close editor
        },
        onShareCommunity: (name) async {
          final tpl = state.template;
          final named = AdTemplate(
            id: tpl.id,
            name: name.trim().isEmpty ? tpl.name : name.trim(),
            category: tpl.category,
            canvasWidth: tpl.canvasWidth,
            canvasHeight: tpl.canvasHeight,
            background: tpl.background,
            elements: tpl.elements,
            previewColors: tpl.previewColors,
          );
          var communityOk = true;
          try {
            await ref.read(sellerApiProvider).saveStudioTemplate({
              'id': named.id,
              'name': named.name,
              'category': named.category,
              'canvasWidth': named.canvasWidth,
              'canvasHeight': named.canvasHeight,
              'background': named.background,
              'elements': named.elements.map((e) => e.toJson()).toList(),
              'shared_to_community': true,
            });
          } catch (e, st) {
            communityOk = false;
            final telemetry = Telemetry.instance;
            if (telemetry != null) {
              unawaited(telemetry.recordError(e, st, hint: 'studio_share_community'));
            }
          }
          if (mounted) Navigator.pop(context);
          await Share.share(
            'Check out my Soko Studio template "${named.name}" — '
            'made on Soko24 Seller Terminal. #SokoStudio',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(communityOk
                    ? 'Template saved & shared to community queue'
                    : 'Shared locally — community upload failed (offline?)'),
              ),
            );
          }
        },
        onPublishMarketplace: (name, price) async {
          final tpl = state.template;
          var publishOk = true;
          try {
            await ref.read(sellerApiProvider).saveStudioTemplate({
              'id': tpl.id,
              'name': name.trim().isEmpty ? tpl.name : name.trim(),
              'category': tpl.category,
              'canvasWidth': tpl.canvasWidth,
              'canvasHeight': tpl.canvasHeight,
              'background': tpl.background,
              'elements': tpl.elements.map((e) => e.toJson()).toList(),
              'marketplace_price_ugx': price,
            });
          } catch (e, st) {
            publishOk = false;
            final telemetry = Telemetry.instance;
            if (telemetry != null) {
              unawaited(telemetry.recordError(e, st, hint: 'studio_publish_marketplace'));
            }
          }
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(publishOk
                    ? 'Template queued for marketplace (UGX $price)'
                    : 'Saved locally — marketplace upload failed (offline?)'),
              ),
            );
          }
        },
      ),
    );
  }
}

Widget _buildWatermarkPreviewImage(String source, double width) {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return Image.network(source, width: width, fit: BoxFit.contain);
  }
  if (source.startsWith('assets/')) {
    return Image.asset(source, width: width, fit: BoxFit.contain);
  }
  return Image.file(File(source), width: width, fit: BoxFit.contain);
}

class _EditorFirstRunHint extends StatelessWidget {
  const _EditorFirstRunHint({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignTokens.brandPrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAccent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: kAccent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Get started',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _HintRow(icon: Icons.touch_app_outlined, text: 'Tap an element to select it.'),
                const _HintRow(icon: Icons.open_with_rounded, text: 'Drag to move, use handles to resize.'),
                const _HintRow(icon: Icons.pinch_rounded, text: 'Pinch or spread to zoom the canvas.'),
                const _HintRow(icon: Icons.dashboard_rounded, text: 'Use the bottom toolbar to add content.'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
