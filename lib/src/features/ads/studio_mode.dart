import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Primary studio workspaces — Canva-style entry points.
enum StudioMode {
  editPhotos,
  templates,
  graphics,
  creators,
  injector,
  campaigns,
}

extension StudioModeX on StudioMode {
  String get label => switch (this) {
        StudioMode.editPhotos => 'Edit Photos',
        StudioMode.templates => 'Templates',
        StudioMode.graphics => 'Graphics',
        StudioMode.creators => 'Creators',
        StudioMode.injector => 'Injector',
        StudioMode.campaigns => 'Campaigns',
      };

  String get subtitle => switch (this) {
        StudioMode.editPhotos => 'Collage, crop & background tools',
        StudioMode.templates => 'Business hub & ad templates',
        StudioMode.graphics => 'Logos, flyers, cards & invoices',
        StudioMode.creators => 'AI ads & marketplace',
        StudioMode.injector => 'Overlay brand on photo or video',
        StudioMode.campaigns => 'Marketing dashboard & campaigns',
      };

  IconData get icon => switch (this) {
        StudioMode.editPhotos => Icons.photo_library_outlined,
        StudioMode.templates => Icons.grid_view_rounded,
        StudioMode.graphics => Icons.layers_outlined,
        StudioMode.creators => Icons.auto_awesome_outlined,
        StudioMode.injector => Icons.auto_fix_high_rounded,
        StudioMode.campaigns => Icons.campaign_rounded,
      };

  Color get accent => switch (this) {
        StudioMode.editPhotos => DesignTokens.brandPrimary,
        StudioMode.templates => DesignTokens.brandAccent,
        StudioMode.graphics => const Color(0xFF27272A),
        StudioMode.creators => DesignTokens.brandPrimary,
        StudioMode.injector => const Color(0xFF52525B),
        StudioMode.campaigns => DesignTokens.brandPrimary,
      };
}