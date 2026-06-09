import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import 'ad_templates.dart';
import 'studio_recent_designs.dart';
import 'brand_kit_screen.dart';
import 'canvas_renderer.dart';
import 'canvas_background.dart';
import 'creative_library_panel.dart';
import 'illustration_renderer.dart';
import 'studio_entitlements.dart';
import 'studio_product_utils.dart';
import 'studio_share_sheet.dart';
import 'studio_media_picker.dart';
import 'studio_variable_context.dart';
import 'studio_variable_utils.dart';
import 'studio_watermark.dart';
import 'template_save_dialog.dart';

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------
const _kAccent  = Color(0xFF0EBE7E);
const _kSurface = Color(0xFF0F1D40);
const _kBg      = Color(0xFF080E1C);

// ---------------------------------------------------------------------------
// Editor state + notifier
// ---------------------------------------------------------------------------

class EditorState {
  const EditorState({
    required this.template,
    this.selectedId,
    this.undoStack = const [],
    this.redoStack = const [],
    this.showGrid = false,
    this.snapEnabled = true,
    this.multiSelected = const {},
  });

  final AdTemplate template;
  final String? selectedId;
  final List<AdTemplate> undoStack;
  final List<AdTemplate> redoStack;
  final bool showGrid;
  final bool snapEnabled;
  final Set<String> multiSelected;

  CanvasElement? get selected => selectedId == null
      ? null
      : template.elements.cast<CanvasElement?>().firstWhere(
          (e) => e?.id == selectedId, orElse: () => null);

  List<CanvasElement> get sortedElements =>
      [...template.elements]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  EditorState copyWith({
    AdTemplate? template,
    Object? selectedId = _kSentinel,
    List<AdTemplate>? undoStack,
    List<AdTemplate>? redoStack,
    bool? showGrid,
    bool? snapEnabled,
    Set<String>? multiSelected,
  }) =>
      EditorState(
        template: template ?? this.template,
        selectedId: selectedId == _kSentinel ? this.selectedId : selectedId as String?,
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
        showGrid: showGrid ?? this.showGrid,
        snapEnabled: snapEnabled ?? this.snapEnabled,
        multiSelected: multiSelected ?? this.multiSelected,
      );
}

const _kSentinel = Object();

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier(AdTemplate initial)
      : super(EditorState(
          template: initial,
          undoStack: [initial],
        ));

  void _commit(AdTemplate next) {
    final undo = [...state.undoStack, state.template];
    if (undo.length > 40) undo.removeAt(0);
    state = state.copyWith(template: next, undoStack: undo, redoStack: []);
  }

  AdTemplate _rebuildTemplate(List<CanvasElement> elements) => AdTemplate(
        id: state.template.id,
        name: state.template.name,
        category: state.template.category,
        canvasWidth: state.template.canvasWidth,
        canvasHeight: state.template.canvasHeight,
        background: state.template.background,
        elements: elements,
        previewColors: state.template.previewColors,
      );

  void undo() {
    if (state.undoStack.length <= 1) return;
    final redo = [...state.redoStack, state.template];
    final prev = state.undoStack.last;
    final undo = state.undoStack.sublist(0, state.undoStack.length - 1);
    state = EditorState(
      template: prev,
      undoStack: undo,
      redoStack: redo,
      showGrid: state.showGrid,
      snapEnabled: state.snapEnabled,
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) return;
    final next = state.redoStack.last;
    final undo = [...state.undoStack, state.template];
    final redo = state.redoStack.sublist(0, state.redoStack.length - 1);
    state = EditorState(template: next, undoStack: undo, redoStack: redo);
  }

  void select(String? id) =>
      state = state.copyWith(selectedId: id ?? _kSentinel, multiSelected: {});

  void updateElement(CanvasElement el) {
    final elements = [
      for (final e in state.template.elements) if (e.id == el.id) el else e,
    ];
    _commit(_rebuildTemplate(elements));
  }

  void addElement(CanvasElement el) {
    // Auto assign zIndex above current max
    final maxZ = state.template.elements.isEmpty
        ? 0
        : state.template.elements.map((e) => e.zIndex).reduce(math.max);
    final withZ = el.copyWith(zIndex: maxZ + 1);
    _commit(_rebuildTemplate([...state.template.elements, withZ]));
    state = state.copyWith(selectedId: el.id);
  }

  void deleteElement(String id) {
    _commit(_rebuildTemplate(
        state.template.elements.where((e) => e.id != id).toList()));
    state = state.copyWith(selectedId: _kSentinel);
  }

  void deleteSelected() {
    if (state.selectedId != null) deleteElement(state.selectedId!);
  }

  void duplicateSelected() {
    final el = state.selected;
    if (el == null) return;
    final id = 'el_${DateTime.now().millisecondsSinceEpoch}';
    final copy = el.copyWith(x: el.x + 30, y: el.y + 30, zIndex: el.zIndex + 1)
        ..id; // triggers rebuild
    addElement(CanvasElement(
      id: id, type: el.type, text: el.text, src: el.src,
      x: el.x + 30, y: el.y + 30,
      width: el.width, height: el.height,
      fontSize: el.fontSize, fontWeight: el.fontWeight, fontFamily: el.fontFamily,
      fill: el.fill, align: el.align, cornerRadius: el.cornerRadius,
      opacity: el.opacity, textDecoration: el.textDecoration,
      rotation: el.rotation, zIndex: el.zIndex + 1,
      letterSpacing: el.letterSpacing, lineHeight: el.lineHeight,
      shadowColor: el.shadowColor, shadowDx: el.shadowDx,
      shadowDy: el.shadowDy, shadowBlur: el.shadowBlur,
      strokeColor: el.strokeColor, strokeWidth: el.strokeWidth,
    ));
  }

  void bringForward() {
    final el = state.selected;
    if (el == null) return;
    updateElement(el.copyWith(zIndex: el.zIndex + 1));
  }

  void sendBackward() {
    final el = state.selected;
    if (el == null) return;
    updateElement(el.copyWith(zIndex: math.max(0, el.zIndex - 1)));
  }

  void bringToFront() {
    final el = state.selected;
    if (el == null) return;
    final maxZ = state.template.elements.map((e) => e.zIndex).reduce(math.max);
    updateElement(el.copyWith(zIndex: maxZ + 1));
  }

  void sendToBack() {
    final el = state.selected;
    if (el == null) return;
    final minZ = state.template.elements.map((e) => e.zIndex).reduce(math.min);
    updateElement(el.copyWith(zIndex: minZ - 1));
  }

  void toggleLock() {
    final el = state.selected;
    if (el == null) return;
    updateElement(el.copyWith(isLocked: !el.isLocked));
  }

  void setBackground(String hex) {
    _commit(_rebuildTemplate(state.template.elements));
    _commit(AdTemplate(
      id: state.template.id, name: state.template.name,
      category: state.template.category,
      canvasWidth: state.template.canvasWidth, canvasHeight: state.template.canvasHeight,
      background: hex, elements: state.template.elements,
      previewColors: state.template.previewColors,
    ));
  }

  void applyMagicLayout(String background, List<CanvasElement> elements) {
    final maxZ = state.template.elements.isEmpty
        ? 0
        : state.template.elements.map((e) => e.zIndex).reduce(math.max);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final stamped = [
      for (var i = 0; i < elements.length; i++)
        stampCanvasElement(
          elements[i],
          newId: '${elements[i].id}_${ts}_$i',
          preservePosition: true,
        ).copyWith(zIndex: maxZ + i + 1),
    ];
    _commit(AdTemplate(
      id: state.template.id,
      name: state.template.name,
      category: state.template.category,
      canvasWidth: state.template.canvasWidth,
      canvasHeight: state.template.canvasHeight,
      background: background,
      elements: [...state.template.elements, ...stamped],
      previewColors: state.template.previewColors,
    ));
  }

  void alignSelected(AlignMode mode, {CanvasElement? relTo}) {
    final el = state.selected;
    if (el == null) return;
    final cw = state.template.canvasWidth;
    final ch = state.template.canvasHeight;
    final ref = relTo;
    double? nx, ny;
    switch (mode) {
      case AlignMode.left:   nx = ref?.x ?? 0;
      case AlignMode.centerH: nx = (ref != null ? ref.x + ref.width / 2 : cw / 2) - el.width / 2;
      case AlignMode.right:  nx = (ref != null ? ref.x + ref.width : cw) - el.width;
      case AlignMode.top:    ny = ref?.y ?? 0;
      case AlignMode.centerV: ny = (ref != null ? ref.y + ref.height / 2 : ch / 2) - el.height / 2;
      case AlignMode.bottom: ny = (ref != null ? ref.y + ref.height : ch) - el.height;
    }
    updateElement(el.copyWith(x: nx ?? el.x, y: ny ?? el.y));
  }

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);
  void toggleSnap() => state = state.copyWith(snapEnabled: !state.snapEnabled);

  void renameTemplate(String name) {
    _commit(AdTemplate(
      id: state.template.id, name: name, category: state.template.category,
      canvasWidth: state.template.canvasWidth, canvasHeight: state.template.canvasHeight,
      background: state.template.background, elements: state.template.elements,
      previewColors: state.template.previewColors,
    ));
  }
}

enum AlignMode { left, centerH, right, top, centerV, bottom }

final editorProvider =
    StateNotifierProvider.family<EditorNotifier, EditorState, AdTemplate>(
  (ref, tpl) => EditorNotifier(tpl),
);

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
  final _canvasKey   = GlobalKey();
  final _transformCtrl = TransformationController();
  final _imagePicker = ImagePicker();

  late final _editorProv = editorProvider(widget.template);

  String? _activePanel; // text|image|background|elements|fonts|effects|align|layers
  bool _busy = false;
  bool _isExporting = false; // hides handles/guides during PNG capture

  // Canvas display dimensions
  double _displayScale = 1.0;
  Offset _canvasOrigin = Offset.zero;

  // For snap guide drawing
  List<Offset> _snapLinesH = [];
  List<Offset> _snapLinesV = [];

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

  // Convert screen tap position → canvas coordinates
  Offset _screenToCanvas(Offset screen) {
    final matrix = _transformCtrl.value;
    final inv = Matrix4.inverted(matrix);
    final local = MatrixUtils.transformPoint(inv, screen) - _canvasOrigin;
    return Offset(local.dx / _displayScale, local.dy / _displayScale);
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(_editorProv);
    final notifier = ref.read(_editorProv.notifier);
    final kit     = ref.watch(brandKitProvider);
    final varCtx  = StudioVariableContext(
      kit: kit,
      product: widget.product,
      productLink: widget.productLink ?? '',
    );
    final sel     = state.selected;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    _displayScale = (screenW) / state.template.canvasWidth;
    final canvasW = state.template.canvasWidth * _displayScale;
    final canvasH = state.template.canvasHeight * _displayScale;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            _TopBar(
              template: state.template,
              canUndo: state.undoStack.length > 1,
              canRedo: state.redoStack.isNotEmpty,
              showGrid: state.showGrid,
              snapEnabled: state.snapEnabled,
              isBusy: _busy,
              onUndo: notifier.undo,
              onRedo: notifier.redo,
              onToggleGrid: notifier.toggleGrid,
              onToggleSnap: notifier.toggleSnap,
              onSave: () => widget.onSave(state.template),
              onShare: () => _share(state, kit),
              onSaveAs: () => _saveAs(state),
            ),

            // ── Canvas area ───────────────────────────────────────────────
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
                      child: RepaintBoundary(
                        key: _canvasKey,
                        child: SizedBox(
                          width: canvasW,
                          height: canvasH,
                          child: _EditorCanvas(
                            state: state,
                            scale: _displayScale,
                            isExporting: _isExporting,
                            variableContext: varCtx,
                            onElementTap: (id) {
                              if (state.template.elements
                                  .firstWhere((e) => e.id == id).isLocked) return;
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
                    );
                  }),

                  // ── Floating element toolbar (above selected element) ───
                  if (sel != null)
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
                          child: _FloatingToolbar(
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

                  // ── Alignment toolbar (shows when element selected) ─────
                  if (sel != null)
                    Positioned(
                      bottom: 0,
                      left: 0, right: 0,
                      child: _AlignmentBar(
                        onAlign: (mode) => notifier.alignSelected(mode),
                      ),
                    ),
                ],
              ),
            ),

            // ── Quick bottom tool bar ─────────────────────────────────────
            _BottomToolbar(
              activePanel: _activePanel,
              hasSelection: sel != null,
              onTool: (panel) {
                setState(() => _activePanel = _activePanel == panel ? null : panel);
                if (panel != 'text' && panel != 'fonts' && panel != 'image') {
                  notifier.select(null);
                }
              },
            ),

            // ── Panel slides up from bottom ───────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _buildPanel(state, notifier, kit, varCtx),
            ),
          ],
        ),
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
        return _TextPanel(
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
      case 'image':
        return _ImagePanel(
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
        return _BackgroundPanel(
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
        return _FontPanel(
          selectedFont: sel?.fontFamily ?? kit.font,
          onSelect: (font) {
            if (sel != null) notifier.updateElement(sel.copyWith(fontFamily: font));
          },
        );
      case 'effects':
        return _EffectsPanel(
          element: sel,
          onUpdate: sel != null ? notifier.updateElement : null,
        );
      case 'layers':
        return _LayersPanel(
          elements: state.sortedElements,
          selectedId: state.selectedId,
          onSelect: notifier.select,
          onReorder: (oldZ, newZ) {
            // Swap zIndexes
            final elems = state.template.elements.toList();
            final fromEl = elems.firstWhere((e) => e.zIndex == oldZ);
            notifier.updateElement(fromEl.copyWith(zIndex: newZ));
          },
          onToggleLock: (id) {
            final el = state.template.elements.firstWhere((e) => e.id == id);
            notifier.updateElement(el.copyWith(isLocked: !el.isLocked));
          },
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
    final xf = await _imagePicker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery);
    if (xf == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: xf.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: _kSurface,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _kAccent,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    final src = 'file://${cropped?.path ?? xf.path}';
    await _applyImageSrc(notifier, state, src);
  }

  Future<void> _removeBg(EditorNotifier notifier, CanvasElement el) async {
    final src = el.src;
    if (src == null || src.isEmpty) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(sellerApiProvider);
      String imageUrl;

      if (src.startsWith('http')) {
        imageUrl = src;
      } else {
        final path = src.startsWith('file://') ? src.substring(7) : src;
        final file = File(path);
        if (!file.existsSync()) {
          throw StateError('Image file not found');
        }
        final uploadRes = await api.uploadSellerFile(file);
        if (uploadRes.data is! Map<String, dynamic>) {
          throw StateError('Invalid upload response');
        }
        final data = uploadRes.data as Map<String, dynamic>;
        if (data['result'] != true) {
          throw StateError(data['message']?.toString() ?? 'Upload failed');
        }
        imageUrl = data['url']?.toString() ?? '';
        if (imageUrl.isEmpty) throw StateError('Upload missing URL');
      }

      final bgRes = await api.studioRemoveBackground(imageUrl: imageUrl);
      if (bgRes.data is! Map<String, dynamic>) {
        throw StateError('Invalid remove-bg response');
      }
      final body = bgRes.data as Map<String, dynamic>;
      if (body['success'] != true) {
        throw StateError(body['message']?.toString() ?? 'Background removal failed');
      }
      final resultUrl = body['result_url']?.toString();
      if (resultUrl == null || resultUrl.isEmpty) {
        throw StateError('No result URL returned');
      }
      notifier.updateElement(el.copyWith(src: resultUrl));
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Background removed'),
            backgroundColor: _kAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Remove background failed: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(EditorState state, BrandKit kit) async {
    setState(() => _busy = true);
    try {
      setState(() => _isExporting = true);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !mounted) return;

      var bytes = data.buffer.asUint8List();
      final entitlements = await ref.read(studioEntitlementsProvider.future);
      if (entitlements.needsSokoWatermark) {
        bytes = await applySokoWatermark(bytes);
      }

      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'soko-ad-${state.template.id}.png'));
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) setState(() => _isExporting = false);
      if (!mounted) return;
      await ref.read(recentDesignsProvider.notifier).add(state.template);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudioShareSheet(
          adFile: file,
          template: state.template,
          kit: kit,
          initialProduct: widget.product,
          showWatermarkBadge: entitlements.needsSokoWatermark,
        ),
      ));
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
          } catch (_) {}
          Navigator.pop(context);
          await Share.share(
            'Check out my Soko Studio template "${named.name}" — '
            'made on Soko24 Seller Terminal. #SokoStudio',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Template saved & shared to community queue'),
              ),
            );
          }
        },
        onPublishMarketplace: (name, price) async {
          final tpl = state.template;
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
          } catch (_) {}
          Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Template queued for marketplace (UGX $price)')),
            );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor canvas with element rendering + handles
// ---------------------------------------------------------------------------

enum ResizeAnchor { topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left }

class _EditorCanvas extends StatefulWidget {
  const _EditorCanvas({
    required this.state,
    required this.scale,
    required this.isExporting,
    required this.variableContext,
    required this.onElementTap,
    required this.onCanvasTap,
    required this.onElementMoved,
    required this.onElementResized,
    required this.onElementRotated,
  });

  final EditorState state;
  final double scale;
  final bool isExporting;
  final StudioVariableContext variableContext;
  final ValueChanged<String> onElementTap;
  final VoidCallback onCanvasTap;
  final void Function(String id, double dx, double dy) onElementMoved;
  final void Function(String id, double dw, double dh, ResizeAnchor anchor) onElementResized;
  final void Function(String id, double angle) onElementRotated;

  @override
  State<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<_EditorCanvas> {
  Offset? _dragStart;
  Offset? _resizeStart;
  ResizeAnchor? _activeAnchor;
  Offset? _rotateStart;
  Offset? _rotateCenter;
  double? _rotateStartAngle;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scale = widget.scale;
    final tpl   = state.template;
    final cw    = tpl.canvasWidth * scale;
    final ch    = tpl.canvasHeight * scale;

    return GestureDetector(
      onTap: widget.onCanvasTap,
      child: Container(
        width: cw, height: ch,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Positioned.fill(
              child: buildCanvasBackground(background: tpl.background),
            ),

            // Grid
            if (state.showGrid)
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter(scale)),
              ),

            // Elements sorted by zIndex
            ...state.sortedElements.map((el) {
              final isSelected = !widget.isExporting && el.id == state.selectedId;
              return _ElementWidget(
                key: ValueKey(el.id),
                el: el,
                scale: scale,
                isSelected: isSelected,
                variableContext: widget.variableContext,
                onTap: () => widget.onElementTap(el.id),
                onMoveStart: (pos) => _dragStart = pos,
                onMoveUpdate: (pos) {
                  if (_dragStart != null) {
                    final d = pos - _dragStart!;
                    _dragStart = pos;
                    widget.onElementMoved(el.id, d.dx, d.dy);
                  }
                },
                onResizeStart: (pos, anchor) {
                  _resizeStart = pos;
                  _activeAnchor = anchor;
                },
                onResizeUpdate: (pos) {
                  if (_resizeStart != null && _activeAnchor != null) {
                    final d = pos - _resizeStart!;
                    _resizeStart = pos;
                    widget.onElementResized(el.id, d.dx, d.dy, _activeAnchor!);
                  }
                },
                onRotateStart: (pos, center) {
                  _rotateCenter = center;
                  _rotateStart = pos;
                  _rotateStartAngle = el.rotation;
                },
                onRotateUpdate: (pos) {
                  if (_rotateCenter != null && _rotateStart != null) {
                    final startA = (_rotateStart! - _rotateCenter!).direction;
                    final currA  = (pos - _rotateCenter!).direction;
                    final angle  = (_rotateStartAngle ?? 0) + currA - startA;
                    widget.onElementRotated(el.id, angle);
                  }
                },
              );
            }),

            // Snap guide lines (suppressed during export)
            if (state.snapEnabled && !widget.isExporting)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SnapGuidePainter(
                      tpl: tpl, selected: state.selected, scale: scale)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Element widget with handles
// ---------------------------------------------------------------------------

const _kHandleSize = 18.0;

class _ElementWidget extends StatelessWidget {
  const _ElementWidget({
    super.key,
    required this.el,
    required this.scale,
    required this.isSelected,
    required this.variableContext,
    required this.onTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onRotateStart,
    required this.onRotateUpdate,
  });

  final CanvasElement el;
  final double scale;
  final bool isSelected;
  final StudioVariableContext variableContext;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMoveStart;
  final ValueChanged<Offset> onMoveUpdate;
  final void Function(Offset, ResizeAnchor) onResizeStart;
  final ValueChanged<Offset> onResizeUpdate;
  final void Function(Offset pos, Offset center) onRotateStart;
  final ValueChanged<Offset> onRotateUpdate;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final x = el.x * s, y = el.y * s;
    final w = el.width * s, h = el.type == 'text' ? null : el.height * s;
    final cx = x + (w) / 2, cy = y + ((h ?? 40.0)) / 2;

    Widget content = _buildContent(s);

    // Apply flip
    if (el.flipX || el.flipY) {
      content = Transform.scale(
        scaleX: el.flipX ? -1 : 1,
        scaleY: el.flipY ? -1 : 1,
        child: content,
      );
    }

    // Apply rotation
    Widget rotated = el.rotation != 0
        ? Transform.rotate(angle: el.rotation, child: content)
        : content;

    // Apply opacity
    Widget opaque = Opacity(opacity: el.opacity.clamp(0.0, 1.0), child: rotated);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Main element ─────────────────────────────────────────────────
        Positioned(
          left: x, top: y,
          width: w,
          height: h,
          child: GestureDetector(
            onTap: onTap,
            onPanStart: (d) => onMoveStart(d.globalPosition),
            onPanUpdate: (d) => onMoveUpdate(d.globalPosition),
            child: opaque,
          ),
        ),

        // ── Selection overlay ─────────────────────────────────────────────
        if (isSelected) ...[
          Positioned(
            left: x - 2, top: y - 2,
            width: (w) + 4,
            height: (h ?? 40.0) + 4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: _kAccent, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Rotation handle (above element center) ─────────────────────
          Positioned(
            left: cx - _kHandleSize / 2,
            top:  y - 36,
            child: GestureDetector(
              onPanStart: (d) => onRotateStart(d.globalPosition, Offset(cx, cy)),
              onPanUpdate: (d) => onRotateUpdate(d.globalPosition),
              child: Container(
                width: _kHandleSize, height: _kHandleSize,
                decoration: const BoxDecoration(
                  color: _kAccent, shape: BoxShape.circle),
                child: const Icon(Icons.rotate_right_rounded,
                    color: Colors.white, size: 12),
              ),
            ),
          ),

          // ── Resize handles (8 points) ──────────────────────────────────
          ..._buildResizeHandles(x, y, w, h ?? 40.0),
        ],
      ],
    );
  }

  List<Widget> _buildResizeHandles(double x, double y, double w, double h) {
    final points = <(Offset, ResizeAnchor)>[
      (Offset(x, y), ResizeAnchor.topLeft),
      (Offset(x + w / 2, y), ResizeAnchor.top),
      (Offset(x + w, y), ResizeAnchor.topRight),
      (Offset(x + w, y + h / 2), ResizeAnchor.right),
      (Offset(x + w, y + h), ResizeAnchor.bottomRight),
      (Offset(x + w / 2, y + h), ResizeAnchor.bottom),
      (Offset(x, y + h), ResizeAnchor.bottomLeft),
      (Offset(x, y + h / 2), ResizeAnchor.left),
    ];
    return points.map((p) {
      final pos = p.$1;
      final anchor = p.$2;
      return Positioned(
        left: pos.dx - _kHandleSize / 2,
        top:  pos.dy - _kHandleSize / 2,
        child: GestureDetector(
          onPanStart: (d) => onResizeStart(d.globalPosition, anchor),
          onPanUpdate: (d) => onResizeUpdate(d.globalPosition),
          child: Container(
            width: _kHandleSize, height: _kHandleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _kAccent, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildContent(double s) {
    switch (el.type) {
      case 'text':
      case 'sticker':
        return _buildText(s);
      case 'image':
        return _buildImage(s);
      case 'figure':
        return _buildFigure(s);
      case 'icon':
        return _buildIcon(s);
      case 'illustration':
        return _buildIllustration(s);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIcon(double s) {
    if (el.iconCodePoint == null) return _buildFigure(s);
    return Icon(
      IconData(
        el.iconCodePoint!,
        fontFamily: el.iconFontFamily,
        fontPackage: el.iconFontPackage,
      ),
      size: math.min(el.width, el.height) * s * 0.72,
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
    );
  }

  Widget _buildIllustration(double s) {
    final color = el.fill != null ? parseHexColor(el.fill!) : Colors.white;
    return IllustrationRenderer(
      assetId: el.assetId ?? 'burst_rays',
      color: color,
      width: el.width * s,
      height: el.height * s,
    );
  }

  Widget _buildText(double s) {
    FontWeight w = FontWeight.w400;
    if (el.fontWeight == 'bold' || el.fontWeight == '700') w = FontWeight.bold;
    if (el.fontWeight == '600') w = FontWeight.w600;
    if (el.fontWeight == '800') w = FontWeight.w800;
    if (el.fontWeight == '900') w = FontWeight.w900;

    TextAlign align = TextAlign.left;
    if (el.align == 'center') align = TextAlign.center;
    if (el.align == 'right')  align = TextAlign.right;

    final color = el.fill != null ? parseHexColor(el.fill!) : Colors.black;

    List<Shadow>? shadows;
    if (el.hasShadow) {
      shadows = [
        Shadow(
          color: parseHexColor(el.shadowColor!).withValues(alpha: 0.6),
          offset: Offset(el.shadowDx, el.shadowDy),
          blurRadius: el.shadowBlur,
        ),
      ];
    }

    TextStyle style = TextStyle(
      fontSize: (el.fontSize ?? 24) * s,
      fontWeight: w,
      color: color,
      letterSpacing: el.letterSpacing,
      height: el.lineHeight,
      shadows: shadows,
      decoration: el.textDecoration == 'underline'
          ? TextDecoration.underline
          : el.textDecoration == 'line-through'
              ? TextDecoration.lineThrough
              : TextDecoration.none,
    );

    if (el.fontFamily != null && studioFonts.containsKey(el.fontFamily)) {
      try {
        style = GoogleFonts.getFont(studioFonts[el.fontFamily!]!,
            textStyle: style);
      } catch (_) {}
    }

    final displayText = variableContext.resolve(el.text ?? el.placeholder);

    Widget text = Text(
      displayText,
      style: style,
      textAlign: align,
      softWrap: true,
    );

    if (el.hasStroke) {
      text = Stack(children: [
        Text(
          displayText,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (el.strokeWidth ?? 1) * s
              ..color = parseHexColor(el.strokeColor!),
          ),
          textAlign: align,
        ),
        text,
      ]);
    }

    return SizedBox(
      width: el.width * s,
      child: text,
    );
  }

  Widget _buildImage(double s) {
    final src = el.src ?? '';
    Widget img;

    if (src.startsWith('file://')) {
      img = Image.file(File(src.substring(7)),
          fit: BoxFit.cover, width: el.width * s, height: el.height * s);
    } else if (src.startsWith('http')) {
      img = Image.network(src,
          fit: BoxFit.cover, width: el.width * s, height: el.height * s,
          errorBuilder: (_, __, ___) => _placeholder(s));
    } else {
      img = _placeholder(s);
    }

    if ((el.cornerRadius ?? 0) > 0) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(el.cornerRadius! * s),
        child: img,
      );
    }
    return img;
  }

  Widget _placeholder(double s) => Container(
        width: el.width * s, height: el.height * s,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: el.cornerRadius != null
              ? BorderRadius.circular(el.cornerRadius! * s)
              : null,
        ),
        child: const Icon(Icons.image_outlined, color: Colors.white24, size: 32),
      );

  Widget _buildFigure(double s) {
    return Container(
      width: el.width * s, height: el.height * s,
      decoration: BoxDecoration(
        color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
        borderRadius: el.cornerRadius != null
            ? BorderRadius.circular(el.cornerRadius! * s)
            : null,
        border: el.hasStroke
            ? Border.all(
                color: parseHexColor(el.strokeColor!),
                width: (el.strokeWidth ?? 1) * s)
            : null,
        boxShadow: el.hasShadow
            ? [
                BoxShadow(
                  color: parseHexColor(el.shadowColor!).withValues(alpha: 0.4),
                  offset: Offset(el.shadowDx, el.shadowDy),
                  blurRadius: el.shadowBlur,
                ),
              ]
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Snap guide painter
// ---------------------------------------------------------------------------

class _SnapGuidePainter extends CustomPainter {
  const _SnapGuidePainter({required this.tpl, required this.selected, required this.scale});
  final AdTemplate tpl;
  final CanvasElement? selected;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (selected == null) return;
    final el = selected!;
    final s = scale;
    final paint = Paint()
      ..color = const Color(0xFF00BFFF).withValues(alpha: 0.7)
      ..strokeWidth = 0.8;

    const thresh = 12.0;
    final cw = tpl.canvasWidth;
    final ch = tpl.canvasHeight;

    // Center guides
    if ((el.x + el.width / 2 - cw / 2).abs() < thresh) {
      canvas.drawLine(Offset(cw * s / 2, 0), Offset(cw * s / 2, ch * s), paint);
    }
    if ((el.y + el.height / 2 - ch / 2).abs() < thresh) {
      canvas.drawLine(Offset(0, ch * s / 2), Offset(cw * s, ch * s / 2), paint);
    }
    // Edge guides
    if (el.x.abs() < thresh) {
      canvas.drawLine(Offset(0, 0), Offset(0, ch * s), paint);
    }
    if ((el.x + el.width - cw).abs() < thresh) {
      canvas.drawLine(Offset(cw * s, 0), Offset(cw * s, ch * s), paint);
    }
    if (el.y.abs() < thresh) {
      canvas.drawLine(Offset(0, 0), Offset(cw * s, 0), paint);
    }
    if ((el.y + el.height - ch).abs() < thresh) {
      canvas.drawLine(Offset(0, ch * s), Offset(cw * s, ch * s), paint);
    }
  }

  @override
  bool shouldRepaint(_SnapGuidePainter old) =>
      old.selected?.id != selected?.id || old.selected?.x != selected?.x;
}

// Grid painter
class _GridPainter extends CustomPainter {
  const _GridPainter(this.scale);
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0.5;
    const step = 108.0;
    for (double x = 0; x <= size.width; x += step * scale / 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step * scale / 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---------------------------------------------------------------------------
// Floating element toolbar (above selected element)
// ---------------------------------------------------------------------------

class _FloatingToolbar extends StatelessWidget {
  const _FloatingToolbar({
    required this.element,
    required this.onDelete,
    required this.onDuplicate,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onLock,
    this.onEditText,
    this.onEditFont,
    this.onEditImage,
  });

  final CanvasElement element;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final VoidCallback onLock;
  final VoidCallback? onEditText;
  final VoidCallback? onEditFont;
  final VoidCallback? onEditImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2540),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEditText != null) _FTBtn(Icons.edit_rounded, 'Edit', onEditText!),
            if (onEditFont != null) _FTBtn(Icons.font_download_rounded, 'Font', onEditFont!),
            if (onEditImage != null) _FTBtn(Icons.image_rounded, 'Image', onEditImage!),
            _FTBtn(Icons.content_copy_rounded, 'Copy', onDuplicate),
            _FTBtn(Icons.flip_to_front_rounded, '↑', onBringForward),
            _FTBtn(Icons.flip_to_back_rounded, '↓', onSendBackward),
            _FTBtn(
              element.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              element.isLocked ? 'Unlock' : 'Lock',
              onLock,
              color: element.isLocked ? Colors.amber : null,
            ),
            _FTBtn(Icons.delete_rounded, 'Del', onDelete, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }
}

class _FTBtn extends StatelessWidget {
  const _FTBtn(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 16),
            Text(label, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alignment bar
// ---------------------------------------------------------------------------

class _AlignmentBar extends StatelessWidget {
  const _AlignmentBar({required this.onAlign});
  final ValueChanged<AlignMode> onAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: const Color(0xFF0A1220),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ABtn(Icons.align_horizontal_left_rounded,   'Left',    () => onAlign(AlignMode.left)),
          _ABtn(Icons.align_horizontal_center_rounded, 'Center',  () => onAlign(AlignMode.centerH)),
          _ABtn(Icons.align_horizontal_right_rounded,  'Right',   () => onAlign(AlignMode.right)),
          Container(width: 1, height: 20, color: Colors.white12),
          _ABtn(Icons.align_vertical_top_rounded,      'Top',     () => onAlign(AlignMode.top)),
          _ABtn(Icons.align_vertical_center_rounded,   'Middle',  () => onAlign(AlignMode.centerV)),
          _ABtn(Icons.align_vertical_bottom_rounded,   'Bottom',  () => onAlign(AlignMode.bottom)),
        ],
      ),
    );
  }
}

class _ABtn extends StatelessWidget {
  const _ABtn(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(icon, color: Colors.white54, size: 18),
        ),
      );
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.template,
    required this.canUndo,
    required this.canRedo,
    required this.showGrid,
    required this.snapEnabled,
    required this.isBusy,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleGrid,
    required this.onToggleSnap,
    required this.onSave,
    required this.onShare,
    required this.onSaveAs,
  });

  final AdTemplate template;
  final bool canUndo, canRedo, showGrid, snapEnabled, isBusy;
  final VoidCallback onUndo, onRedo, onToggleGrid, onToggleSnap, onSave, onShare, onSaveAs;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: _kSurface,
      padding: EdgeInsets.fromLTRB(4, topPad + 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              template.name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Undo / Redo
          IconButton(
            icon: Icon(Icons.undo_rounded,
                color: canUndo ? Colors.white70 : Colors.white24, size: 20),
            onPressed: canUndo ? onUndo : null,
          ),
          IconButton(
            icon: Icon(Icons.redo_rounded,
                color: canRedo ? Colors.white70 : Colors.white24, size: 20),
            onPressed: canRedo ? onRedo : null,
          ),
          // Grid toggle
          IconButton(
            icon: Icon(
              Icons.grid_on_rounded,
              color: showGrid ? _kAccent : Colors.white38, size: 20),
            onPressed: onToggleGrid,
          ),
          // Snap toggle
          IconButton(
            icon: Icon(
              Icons.straighten_rounded,
              color: snapEnabled ? _kAccent : Colors.white38, size: 20),
            onPressed: onToggleSnap,
            tooltip: 'Snap to guides',
          ),
          // Save as
          IconButton(
            icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white70, size: 20),
            onPressed: onSaveAs,
            tooltip: 'Save as template',
          ),
          // Share
          if (isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_kAccent)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white70, size: 20),
              onPressed: onShare,
            ),
          // Save (green pill)
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _kAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom toolbar
// ---------------------------------------------------------------------------

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.activePanel,
    required this.hasSelection,
    required this.onTool,
  });

  final String? activePanel;
  final bool hasSelection;
  final ValueChanged<String> onTool;

  static final _tools = [
    ('text',       Icons.title_rounded,          'Text'),
    ('image',      Icons.image_rounded,           'Image'),
    ('elements',   Icons.auto_awesome_rounded,    'Creatives'),
    ('background', Icons.layers_rounded,          'Background'),
    ('fonts',      Icons.font_download_outlined,  'Fonts'),
    ('effects',    Icons.auto_fix_high_rounded,   'Effects'),
    ('layers',     Icons.layers_outlined,         'Layers'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      color: _kSurface,
      padding: EdgeInsets.fromLTRB(0, 4, 0, bottomPad + 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _tools.map((t) {
            final active = activePanel == t.$1;
            return GestureDetector(
              onTap: () => onTool(t.$1),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? _kAccent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? _kAccent : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$2,
                        size: 20,
                        color: active ? _kAccent : Colors.white38),
                    const SizedBox(height: 2),
                    Text(t.$3,
                        style: TextStyle(
                          color: active ? _kAccent : Colors.white38,
                          fontSize: 9,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text panel
// ---------------------------------------------------------------------------

class _TextPanel extends StatefulWidget {
  const _TextPanel({
    required this.element,
    required this.kit,
    required this.product,
    required this.productLink,
    required this.brandColors,
    required this.onUpdate,
    required this.onAddText,
  });
  final CanvasElement? element;
  final BrandKit kit;
  final Item? product;
  final String productLink;
  final List<Color> brandColors;
  final ValueChanged<CanvasElement> onUpdate;
  final VoidCallback onAddText;

  @override
  State<_TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<_TextPanel>
    with SingleTickerProviderStateMixin {
  late TextEditingController _ctrl;
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _ctrl = TextEditingController(text: widget.element?.text ?? '');
  }

  @override
  void didUpdateWidget(_TextPanel old) {
    super.didUpdateWidget(old);
    if (old.element?.id != widget.element?.id) {
      _ctrl.text = widget.element?.text ?? '';
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final el = widget.element;
    return _PanelWrap(
      height: 340,
      child: el == null || el.type != 'text'
          ? _PanelAction(
              icon: Icons.add_circle_rounded,
              label: 'Add Text',
              color: _kAccent,
              onTap: widget.onAddText,
            )
          : Column(
              children: [
                // Live preview strip
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    resolveStudioVariables(
                      _ctrl.text,
                      kit: widget.kit,
                      product: widget.product,
                      productLink: widget.productLink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: el.align == 'center'
                        ? TextAlign.center
                        : el.align == 'right'
                            ? TextAlign.right
                            : TextAlign.left,
                    style: _previewStyle(el),
                  ),
                ),
                TabBar(
                  controller: _tc,
                  labelColor: _kAccent,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: _kAccent,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(fontSize: 11),
                  tabs: const [Tab(text: 'Content'), Tab(text: 'Style')],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tc,
                    children: [
                      // ── Content tab ─────────────────────────────────────
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tap variables from your shop & product',
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            _DarkField(
                              ctrl: _ctrl,
                              hint: 'Type your text…',
                              maxLines: 4,
                              onChanged: (v) => widget.onUpdate(el.copyWith(text: v)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: studioVariableChips.map((chip) {
                                return GestureDetector(
                                  onTap: () {
                                    final t = _ctrl.text + chip.token;
                                    _ctrl.text = t;
                                    widget.onUpdate(el.copyWith(text: t));
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _kAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: _kAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      chip.label,
                                      style: const TextStyle(
                                        color: _kAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      // ── Style tab ────────────────────────────────────────
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Font size
                            Row(children: [
                              const Text('Size', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Slider(
                                  value: (el.fontSize ?? 24).clamp(8, 200),
                                  min: 8, max: 200,
                                  activeColor: _kAccent, inactiveColor: Colors.white12,
                                  onChanged: (v) => widget.onUpdate(el.copyWith(fontSize: v)),
                                ),
                              ),
                              Text('${(el.fontSize ?? 24).toInt()}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),

                            // Letter spacing
                            Row(children: [
                              const Text('Spacing', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Slider(
                                  value: (el.letterSpacing ?? 0).clamp(-5, 20),
                                  min: -5, max: 20,
                                  activeColor: _kAccent, inactiveColor: Colors.white12,
                                  onChanged: (v) => widget.onUpdate(el.copyWith(letterSpacing: v)),
                                ),
                              ),
                              Text('${(el.letterSpacing ?? 0).toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),

                            // Line height
                            Row(children: [
                              const Text('Line H.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Expanded(
                                child: Slider(
                                  value: (el.lineHeight ?? 1.2).clamp(0.8, 3.0),
                                  min: 0.8, max: 3.0,
                                  activeColor: _kAccent, inactiveColor: Colors.white12,
                                  onChanged: (v) => widget.onUpdate(el.copyWith(lineHeight: v)),
                                ),
                              ),
                              Text('${(el.lineHeight ?? 1.2).toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),

                            // Alignment + bold + italic row
                            Row(children: [
                              for (final a in [
                                ('left',   Icons.format_align_left_rounded),
                                ('center', Icons.format_align_center_rounded),
                                ('right',  Icons.format_align_right_rounded),
                              ])
                                _ToggleBtn(
                                  icon: a.$2,
                                  active: el.align == a.$1,
                                  onTap: () => widget.onUpdate(el.copyWith(align: a.$1)),
                                ),
                              const Spacer(),
                              _ToggleBtn(
                                label: 'B',
                                bold: true,
                                active: el.fontWeight == 'bold' || el.fontWeight == '700',
                                onTap: () => widget.onUpdate(el.copyWith(
                                    fontWeight: el.fontWeight == 'bold' ? '400' : 'bold')),
                              ),
                              _ToggleBtn(
                                label: 'U',
                                underline: true,
                                active: el.textDecoration == 'underline',
                                onTap: () => widget.onUpdate(CanvasElement(
                                  id: el.id, type: el.type, text: el.text,
                                  x: el.x, y: el.y, width: el.width, height: el.height,
                                  fontSize: el.fontSize, fontWeight: el.fontWeight,
                                  fontFamily: el.fontFamily, fill: el.fill, align: el.align,
                                  opacity: el.opacity, rotation: el.rotation, zIndex: el.zIndex,
                                  letterSpacing: el.letterSpacing, lineHeight: el.lineHeight,
                                  shadowColor: el.shadowColor, strokeColor: el.strokeColor,
                                  strokeWidth: el.strokeWidth,
                                  textDecoration: el.textDecoration == 'underline'
                                      ? null
                                      : 'underline',
                                )),
                              ),
                            ]),

                            // Color row
                            const SizedBox(height: 8),
                            if (widget.brandColors.isNotEmpty) ...[
                              const Text('Brand colors',
                                  style: TextStyle(color: Colors.white38, fontSize: 10)),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: widget.brandColors.map((c) {
                                    final hex = colorToHex(c);
                                    final isSel = el.fill == hex;
                                    return GestureDetector(
                                      onTap: () =>
                                          widget.onUpdate(el.copyWith(fill: hex)),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSel ? _kAccent : Colors.white24,
                                            width: isSel ? 2.5 : 1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: colorPalette.take(25).map((c) {
                                  final hex = colorToHex(c);
                                  final isSel = el.fill == hex;
                                  return GestureDetector(
                                    onTap: () => widget.onUpdate(el.copyWith(fill: hex)),
                                    child: Container(
                                      width: 28, height: 28,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: c, shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSel ? _kAccent : Colors.white12,
                                          width: isSel ? 2.5 : 1,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  TextStyle _previewStyle(CanvasElement el) {
    var style = TextStyle(
      fontSize: (el.fontSize ?? 24).clamp(14, 28),
      fontWeight: el.fontWeight == 'bold' ? FontWeight.bold : FontWeight.w500,
      color: el.fill != null ? parseHexColor(el.fill!) : Colors.white,
      height: el.lineHeight ?? 1.2,
    );
    if (el.fontFamily != null && studioFonts.containsKey(el.fontFamily)) {
      try {
        style = GoogleFonts.getFont(studioFonts[el.fontFamily!]!, textStyle: style);
      } catch (_) {}
    }
    return style;
  }
}

// ---------------------------------------------------------------------------
// Image panel
// ---------------------------------------------------------------------------

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.element,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onPickCatalog,
    required this.onRemoveBg,
    required this.onUpdate,
  });

  final CanvasElement? element;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onPickCatalog;
  final VoidCallback? onRemoveBg;
  final ValueChanged<CanvasElement>? onUpdate;

  @override
  Widget build(BuildContext context) {
    final el = element;
    return _PanelWrap(
      height: el?.type == 'image' ? 220 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PanelAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: onPickGallery),
              _PanelAction(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: onPickCamera),
              _PanelAction(
                icon: Icons.folder_special_rounded,
                label: 'Catalog & Uploads',
                color: const Color(0xFF3b82f6),
                onTap: onPickCatalog,
              ),
              if (onRemoveBg != null)
                _PanelAction(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Remove BG',
                  color: const Color(0xFF6366f1),
                  onTap: onRemoveBg!,
                ),
              if (el != null && el.type == 'image' && onUpdate != null) ...[
                _PanelAction(
                  icon: Icons.flip_rounded,
                  label: 'Flip H',
                  onTap: () => onUpdate!(el.copyWith(flipX: !el.flipX)),
                ),
                _PanelAction(
                  icon: Icons.flip_rounded,
                  label: 'Flip V',
                  onTap: () => onUpdate!(el.copyWith(flipY: !el.flipY)),
                ),
                _PanelAction(
                  icon: Icons.refresh_rounded,
                  label: 'Replace',
                  onTap: onPickGallery,
                ),
              ],
            ],
          ),
          if (el != null && el.type == 'image' && onUpdate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Opacity',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: el.opacity.clamp(0.1, 1.0),
                    min: 0.1,
                    max: 1.0,
                    activeColor: _kAccent,
                    onChanged: (v) => onUpdate!(el.copyWith(opacity: v)),
                  ),
                ),
                Text('${(el.opacity * 100).round()}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            Row(
              children: [
                const Text('Corners',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: (el.cornerRadius ?? 0).clamp(0, 80),
                    min: 0,
                    max: 80,
                    activeColor: _kAccent,
                    onChanged: (v) => onUpdate!(el.copyWith(cornerRadius: v)),
                  ),
                ),
                Text('${(el.cornerRadius ?? 0).round()}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background panel
// ---------------------------------------------------------------------------

class _BackgroundPanel extends StatefulWidget {
  const _BackgroundPanel({
    required this.current,
    required this.brandColors,
    required this.onSolid,
    required this.onGradient,
  });
  final String current;
  final List<Color> brandColors;
  final ValueChanged<String> onSolid;
  final void Function(({String id, String label, List<Color> colors})) onGradient;

  @override
  State<_BackgroundPanel> createState() => _BackgroundPanelState();
}

class _BackgroundPanelState extends State<_BackgroundPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelWrap(
      height: 180,
      child: Column(
        children: [
          TabBar(
            controller: _tc,
            labelColor: _kAccent,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _kAccent,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 11),
            tabs: const [
              Tab(text: 'Solid'),
              Tab(text: 'Gradient'),
              Tab(text: 'Magic'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      ...widget.brandColors.map((c) {
                        final hex = colorToHex(c);
                        return GestureDetector(
                          onTap: () => widget.onSolid(hex),
                          child: Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.current == hex
                                    ? _kAccent
                                    : Colors.white24,
                                width: widget.current == hex ? 2.5 : 1.5,
                              ),
                            ),
                            child: widget.current == hex
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }),
                      ...colorPalette.map((c) {
                        final hex = colorToHex(c);
                        return GestureDetector(
                          onTap: () => widget.onSolid(hex),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.current == hex
                                    ? _kAccent
                                    : Colors.white12,
                                width: widget.current == hex ? 2.5 : 1,
                              ),
                            ),
                            child: widget.current == hex
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: gradientPresets.map((g) {
                      final isSel = widget.current == 'gradient:${g.id}';
                      return GestureDetector(
                        onTap: () => widget.onGradient(g),
                        child: Container(
                          width: 64, height: 64,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: g.colors,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? _kAccent : Colors.transparent, width: 2),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(g.label,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      ...patternBackgroundIds.map((id) {
                        final bg = 'pattern:$id';
                        final isSel = widget.current == bg;
                        return GestureDetector(
                          onTap: () => widget.onSolid(bg),
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0f172a),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? _kAccent : Colors.white12,
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: buildCanvasBackground(background: bg),
                            ),
                          ),
                        );
                      }),
                      ...meshBackgroundPresets.map((m) {
                        final bg = 'gradient:${m.id}';
                        final isSel = widget.current == bg;
                        return GestureDetector(
                          onTap: () => widget.onGradient((
                            id: m.id,
                            label: m.label,
                            colors: m.colors,
                          )),
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: m.begin,
                                end: m.end,
                                colors: m.colors,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? _kAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  m.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(blurRadius: 4, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Font panel
// ---------------------------------------------------------------------------

class _FontPanel extends StatelessWidget {
  const _FontPanel({required this.selectedFont, required this.onSelect});
  final String selectedFont;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _PanelWrap(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: studioFonts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final name = studioFonts.keys.elementAt(i);
          final pkgName = studioFonts.values.elementAt(i);
          final desc = fontDescriptors[name];
          final isSel = selectedFont == name;

          TextStyle style;
          try {
            style = GoogleFonts.getFont(pkgName,
                fontSize: 20, fontWeight: FontWeight.w700,
                color: isSel ? _kAccent : Colors.white);
          } catch (_) {
            style = TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: isSel ? _kAccent : Colors.white);
          }

          return GestureDetector(
            onTap: () => onSelect(name),
            child: Container(
              width: 88,
              decoration: BoxDecoration(
                color: isSel ? _kAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? _kAccent : Colors.white10),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(desc?.sample ?? 'Aa', style: style),
                  const SizedBox(height: 3),
                  Text(name,
                      style: TextStyle(color: isSel ? _kAccent : Colors.white38,
                          fontSize: 8, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  if (desc != null)
                    Text(desc.vibe,
                        style: const TextStyle(color: Colors.white24, fontSize: 7),
                        textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Effects panel (shadow, stroke, opacity)
// ---------------------------------------------------------------------------

class _EffectsPanel extends StatelessWidget {
  const _EffectsPanel({required this.element, required this.onUpdate});
  final CanvasElement? element;
  final ValueChanged<CanvasElement>? onUpdate;

  @override
  Widget build(BuildContext context) {
    final el = element;
    if (el == null || onUpdate == null) {
      return _PanelWrap(
        child: const Center(
          child: Text('Select an element to apply effects',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      );
    }

    return _PanelWrap(
      height: 220,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opacity
            Row(children: [
              const Text('Opacity', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: el.opacity.clamp(0.0, 1.0),
                  min: 0.0, max: 1.0,
                  activeColor: _kAccent, inactiveColor: Colors.white12,
                  onChanged: (v) => onUpdate!(el.copyWith(opacity: v)),
                ),
              ),
              Text('${(el.opacity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),

            // Rotation (degrees)
            Row(children: [
              const Text('Rotation', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: (el.rotation * 180 / math.pi).clamp(-180, 180),
                  min: -180, max: 180,
                  activeColor: _kAccent, inactiveColor: Colors.white12,
                  onChanged: (v) => onUpdate!(el.copyWith(rotation: v * math.pi / 180)),
                ),
              ),
              Text('${(el.rotation * 180 / math.pi).toStringAsFixed(0)}°',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),

            // Shadow toggle
            Row(children: [
              const Text('Shadow', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const Spacer(),
              Switch(
                value: el.hasShadow,
                activeColor: _kAccent,
                onChanged: (v) => onUpdate!(el.copyWith(
                  shadowColor: v ? '#000000' : null,
                )),
              ),
            ]),
            if (el.hasShadow)
              Row(children: [
                const Text('Blur', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: el.shadowBlur.clamp(0, 40),
                    min: 0, max: 40,
                    activeColor: _kAccent, inactiveColor: Colors.white12,
                    onChanged: (v) => onUpdate!(el.copyWith(shadowBlur: v)),
                  ),
                ),
              ]),

            // Stroke
            Row(children: [
              const Text('Stroke', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const Spacer(),
              Switch(
                value: el.hasStroke,
                activeColor: _kAccent,
                onChanged: (v) => onUpdate!(el.copyWith(
                  strokeColor: v ? '#ffffff' : null,
                  strokeWidth: v ? 2.0 : null,
                )),
              ),
            ]),
            if (el.hasStroke)
              Row(children: [
                const Text('Width', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: (el.strokeWidth ?? 2).clamp(0.5, 20),
                    min: 0.5, max: 20,
                    activeColor: _kAccent, inactiveColor: Colors.white12,
                    onChanged: (v) => onUpdate!(el.copyWith(strokeWidth: v)),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layers panel
// ---------------------------------------------------------------------------

class _LayersPanel extends StatelessWidget {
  const _LayersPanel({
    required this.elements,
    required this.selectedId,
    required this.onSelect,
    required this.onReorder,
    required this.onToggleLock,
    required this.onDelete,
  });

  final List<CanvasElement> elements;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final void Function(int oldZ, int newZ) onReorder;
  final ValueChanged<String> onToggleLock;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final sorted = [...elements].reversed.toList(); // Top layer first
    return _PanelWrap(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: sorted.length,
        itemBuilder: (_, i) {
          final el = sorted[i];
          final isSel = el.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(el.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: isSel ? _kAccent.withValues(alpha: 0.12) : Colors.transparent,
              child: Row(
                children: [
                  Icon(
                    el.type == 'text' ? Icons.title_rounded
                        : el.type == 'image' ? Icons.image_rounded
                        : Icons.rectangle_rounded,
                    color: isSel ? _kAccent : Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      el.text ?? el.type,
                      style: TextStyle(
                        color: isSel ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onToggleLock(el.id),
                    child: Icon(
                      el.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: el.isLocked ? Colors.amber : Colors.white24,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onDelete(el.id),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 16),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PanelWrap extends StatelessWidget {
  const _PanelWrap({required this.child, this.height});
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1525),
      constraints: BoxConstraints(maxHeight: height ?? 160),
      child: child,
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    this.icon,
    this.label,
    required this.active,
    required this.onTap,
    this.bold = false,
    this.underline = false,
  });
  final IconData? icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;
  final bool bold;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: active ? _kAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _kAccent : Colors.transparent),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: active ? _kAccent : Colors.white38, size: 18)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: active ? _kAccent : Colors.white38,
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
                    decoration: underline ? TextDecoration.underline : TextDecoration.none,
                    decorationColor: active ? _kAccent : Colors.white38,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.ctrl,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kAccent)),
        ),
      );
}
