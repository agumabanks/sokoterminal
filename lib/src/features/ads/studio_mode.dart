import 'package:flutter/material.dart';

/// Primary studio workspaces — Canva-style entry points.
enum StudioMode {
  editPhotos,
  templates,
  graphics,
  creators,
  injector,
}

extension StudioModeX on StudioMode {
  String get label => switch (this) {
        StudioMode.editPhotos => 'Edit Photos',
        StudioMode.templates => 'Templates',
        StudioMode.graphics => 'Graphics',
        StudioMode.creators => 'Creators',
        StudioMode.injector => 'Injector',
      };

  String get subtitle => switch (this) {
        StudioMode.editPhotos => 'Collage, crop & background tools',
        StudioMode.templates => 'Business hub & ad templates',
        StudioMode.graphics => 'Logos, flyers, cards & invoices',
        StudioMode.creators => 'AI ads & marketplace',
        StudioMode.injector => 'Overlay brand on photo or video',
      };

  IconData get icon => switch (this) {
        StudioMode.editPhotos => Icons.photo_library_outlined,
        StudioMode.templates => Icons.grid_view_rounded,
        StudioMode.graphics => Icons.layers_outlined,
        StudioMode.creators => Icons.auto_awesome_outlined,
        StudioMode.injector => Icons.auto_fix_high_rounded,
      };

  Color get accent => switch (this) {
        StudioMode.editPhotos => const Color(0xFF3b82f6),
        StudioMode.templates => const Color(0xFF0EBE7E),
        StudioMode.graphics => const Color(0xFFa855f7),
        StudioMode.creators => const Color(0xFFf59e0b),
        StudioMode.injector => const Color(0xFF22d3ee),
      };
}