import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ad_templates.dart';

// ---------------------------------------------------------------------------
// Sentinel used for null-aware copyWith
// ---------------------------------------------------------------------------
const kSentinel = Object();

// ---------------------------------------------------------------------------
// Editor state + notifier
// ---------------------------------------------------------------------------

class EditorState {
  const EditorState({
    required this.template,
    this.selectedId,
    this.activeSize,
    this.undoStack = const [],
    this.redoStack = const [],
    this.showGrid = false,
    this.snapEnabled = true,
    this.multiSelected = const {},
  });

  final AdTemplate template;
  final String? selectedId;
  final AdSize? activeSize;
  final List<(AdTemplate, AdSize?)> undoStack;
  final List<(AdTemplate, AdSize?)> redoStack;
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
    Object? selectedId = kSentinel,
    Object? activeSize = kSentinel,
    List<(AdTemplate, AdSize?)>? undoStack,
    List<(AdTemplate, AdSize?)>? redoStack,
    bool? showGrid,
    bool? snapEnabled,
    Set<String>? multiSelected,
  }) =>
      EditorState(
        template: template ?? this.template,
        selectedId: selectedId == kSentinel ? this.selectedId : selectedId as String?,
        activeSize: activeSize == kSentinel ? this.activeSize : activeSize as AdSize?,
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
        showGrid: showGrid ?? this.showGrid,
        snapEnabled: snapEnabled ?? this.snapEnabled,
        multiSelected: multiSelected ?? this.multiSelected,
      );
}

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier(AdTemplate initial)
      : super(EditorState(
          template: initial,
          activeSize: findAdSizeFor(initial.canvasWidth, initial.canvasHeight),
          undoStack: [(initial, findAdSizeFor(initial.canvasWidth, initial.canvasHeight))],
        ));

  void _commit(AdTemplate next, {Object? activeSize = kSentinel}) {
    final undo = [...state.undoStack, (state.template, state.activeSize)];
    if (undo.length > 40) undo.removeAt(0);
    state = state.copyWith(
      template: next,
      undoStack: undo,
      redoStack: [],
      activeSize: activeSize,
    );
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
        tags: state.template.tags,
        industry: state.template.industry,
        season: state.template.season,
        complexity: state.template.complexity,
        suggestedCaption: state.template.suggestedCaption,
        marketingGoal: state.template.marketingGoal,
      );

  void undo() {
    if (state.undoStack.length <= 1) return;
    final redo = [...state.redoStack, (state.template, state.activeSize)];
    final prev = state.undoStack.last;
    final undo = state.undoStack.sublist(0, state.undoStack.length - 1);
    state = EditorState(
      template: prev.$1,
      activeSize: prev.$2,
      undoStack: undo,
      redoStack: redo,
      showGrid: state.showGrid,
      snapEnabled: state.snapEnabled,
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) return;
    final next = state.redoStack.last;
    final undo = [...state.undoStack, (state.template, state.activeSize)];
    final redo = state.redoStack.sublist(0, state.redoStack.length - 1);
    state = EditorState(
      template: next.$1,
      activeSize: next.$2,
      undoStack: undo,
      redoStack: redo,
      showGrid: state.showGrid,
      snapEnabled: state.snapEnabled,
    );
  }

  void select(String? id) =>
      state = state.copyWith(selectedId: id ?? kSentinel, multiSelected: {});

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
    state = state.copyWith(selectedId: kSentinel);
  }

  void deleteSelected() {
    if (state.selectedId != null) deleteElement(state.selectedId!);
  }

  void duplicateSelected() {
    final el = state.selected;
    if (el == null) return;
    final id = 'el_${DateTime.now().millisecondsSinceEpoch}';
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

  void toggleVisibility(String id) {
    final el = state.template.elements.firstWhere((e) => e.id == id);
    updateElement(el.copyWith(isVisible: !el.isVisible));
  }

  void moveLayer(String id, bool up) {
    final sorted = state.sortedElements;
    final idx = sorted.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final swapIdx = up ? idx + 1 : idx - 1;
    if (swapIdx < 0 || swapIdx >= sorted.length) return;

    final current = sorted[idx];
    final neighbor = sorted[swapIdx];
    // Swap zIndex values
    updateElement(current.copyWith(zIndex: neighbor.zIndex));
    updateElement(neighbor.copyWith(zIndex: current.zIndex));
  }

  void setBackground(String hex) {
    _commit(_rebuildTemplate(state.template.elements));
    _commit(AdTemplate(
      id: state.template.id, name: state.template.name,
      category: state.template.category,
      canvasWidth: state.template.canvasWidth, canvasHeight: state.template.canvasHeight,
      background: hex, elements: state.template.elements,
      previewColors: state.template.previewColors,
      tags: state.template.tags,
      industry: state.template.industry,
      season: state.template.season,
      complexity: state.template.complexity,
      suggestedCaption: state.template.suggestedCaption,
      marketingGoal: state.template.marketingGoal,
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
      tags: state.template.tags,
      industry: state.template.industry,
      season: state.template.season,
      complexity: state.template.complexity,
      suggestedCaption: state.template.suggestedCaption,
      marketingGoal: state.template.marketingGoal,
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
      tags: state.template.tags,
      industry: state.template.industry,
      season: state.template.season,
      complexity: state.template.complexity,
      suggestedCaption: state.template.suggestedCaption,
      marketingGoal: state.template.marketingGoal,
    ));
  }

  /// Resizes the canvas to [size] and uniformly scales every element so the
  /// design fits. Font sizes are clamped to a minimum of 14 after scaling.
  /// Elements that fall outside the new canvas remain in the model.
  void resizeToSize(AdSize size) {
    final tpl = state.template;
    if (tpl.canvasWidth == size.width && tpl.canvasHeight == size.height) return;
    final scaled = scaleTemplateToSize(tpl, size);
    _commit(scaled, activeSize: size);
  }
}

enum AlignMode { left, centerH, right, top, centerV, bottom }

final editorProvider =
    StateNotifierProvider.family<EditorNotifier, EditorState, AdTemplate>(
  (ref, tpl) => EditorNotifier(tpl),
);
