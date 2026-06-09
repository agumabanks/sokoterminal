import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/service_publish_utils.dart';
import '../../core/util/haptics.dart';
import '../../widgets/offline_cached_image.dart';
import '../../widgets/sync_status_chip.dart';

enum ServicesViewMode { grid, list }

enum ServicesFilter { all, online, pending, draft }

List<Service> filterServices(
  List<Service> services, {
  required String searchQuery,
  required ServicesFilter filter,
}) {
  final query = searchQuery.trim().toLowerCase();
  return services.where((service) {
    if (query.isNotEmpty) {
      final haystack =
          '${service.title} ${service.summary ?? ''} ${service.category ?? ''}'
              .toLowerCase();
      if (!haystack.contains(query)) return false;
    }
    switch (filter) {
      case ServicesFilter.online:
        return service.publishedOnline && !isServicePendingModeration(service);
      case ServicesFilter.pending:
        return isServicePendingModeration(service);
      case ServicesFilter.draft:
        return !service.publishedOnline && !isServicePendingModeration(service);
      case ServicesFilter.all:
        return true;
    }
  }).toList();
}

class ServiceArtwork extends StatelessWidget {
  const ServiceArtwork({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final String title;
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: OfflineCachedImage(
            imageUrl: raw,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: _fallback(),
            errorWidget: _fallback(),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(raw),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DesignTokens.canvasCloud,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.room_service_outlined,
        color: DesignTokens.inkMuted,
        size: width * 0.42,
      ),
    );
  }
}

class ServiceGridTile extends StatelessWidget {
  const ServiceGridTile({
    super.key,
    required this.service,
    required this.onTap,
  });

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surfaceRaised,
      borderRadius: DesignTokens.borderRadiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          onTap();
        },
        borderRadius: DesignTokens.borderRadiusMd,
        splashFactory: NoSplash.splashFactory,
        highlightColor: DesignTokens.surfaceGrouped,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.08,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ServiceArtwork(
                    title: service.title,
                    imageUrl: service.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _ServiceStatusPill(
                      publishedOnline: service.publishedOnline,
                      moderationStatus: service.moderationStatus,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: DesignTokens.textBodyBold.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (serviceListSubtitle(service) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      serviceListSubtitle(service)!,
                      style: DesignTokens.textCaption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    pricingPackagesLabel(service.pricingPackages) ??
                        service.price.toUgx(),
                    style: DesignTokens.textMono.copyWith(fontSize: 13),
                  ),
                  if (service.durationMinutes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${service.durationMinutes} min',
                      style: DesignTokens.textCaption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceLineTile extends StatefulWidget {
  const ServiceLineTile({
    super.key,
    required this.service,
    required this.onTap,
    this.onTogglePublish,
  });

  final Service service;
  final VoidCallback onTap;
  final ValueChanged<bool>? onTogglePublish;

  @override
  State<ServiceLineTile> createState() => _ServiceLineTileState();
}

class _ServiceLineTileState extends State<ServiceLineTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final subtitle = _subtitleFor(service);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: DesignTokens.durationFast,
      curve: DesignTokens.curveStandard,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceRaised,
          borderRadius: DesignTokens.borderRadiusMd,
          border: Border.all(color: DesignTokens.hairline),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Haptics.selection();
              widget.onTap();
            },
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: DesignTokens.borderRadiusMd,
            splashFactory: NoSplash.splashFactory,
            highlightColor: DesignTokens.surfaceGrouped,
            child: Padding(
              padding: DesignTokens.paddingMd,
              child: Row(
                children: [
                  ServiceArtwork(
                    title: service.title,
                    imageUrl: service.imageUrl,
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: DesignTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                service.title,
                                style: DesignTokens.textBody.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: DesignTokens.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SyncStatusChip(
                              isSynced: service.synced,
                              localId: service.id,
                            ),
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: DesignTokens.spaceXxs),
                          Text(
                            subtitle,
                            style: DesignTokens.textSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: DesignTokens.spaceXxs),
                        Row(
                          children: [
                            Text(
                              service.price.toUgx(),
                              style: DesignTokens.textMono.copyWith(fontSize: 14),
                            ),
                            const SizedBox(width: DesignTokens.spaceSm),
                            _ServiceStatusPill(
                              publishedOnline: service.publishedOnline,
                              moderationStatus: service.moderationStatus,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.onTogglePublish != null) ...[
                    const SizedBox(width: DesignTokens.spaceSm),
                    _ServiceLiveToggle(
                      value: service.publishedOnline,
                      onChanged: widget.onTogglePublish!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _subtitleFor(Service service) => serviceListSubtitle(service);
}

class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({
    super.key,
    required this.publishedOnline,
    this.moderationStatus,
  });

  final bool publishedOnline;
  final String? moderationStatus;

  @override
  Widget build(BuildContext context) {
    return _ServiceStatusPill(
      publishedOnline: publishedOnline,
      moderationStatus: moderationStatus,
    );
  }
}

class _ServiceStatusPill extends StatelessWidget {
  const _ServiceStatusPill({
    required this.publishedOnline,
    this.moderationStatus,
    this.compact = false,
  });

  final bool publishedOnline;
  final String? moderationStatus;
  final bool compact;

  String get _label {
    if (moderationStatus == 'pending') return 'Pending';
    return publishedOnline ? 'Live' : 'Draft';
  }

  Color get _color {
    if (moderationStatus == 'pending') return DesignTokens.warning;
    return publishedOnline ? DesignTokens.success : DesignTokens.inkMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
      ),
      child: Text(
        _label,
        style: DesignTokens.textCaption.copyWith(
          color: _color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}

class _ServiceLiveToggle extends StatelessWidget {
  const _ServiceLiveToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        width: 72,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: value ? DesignTokens.brandAccent : DesignTokens.grayLight,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: DesignTokens.durationFast,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live',
                    style: DesignTokens.textSmallBold.copyWith(
                      color: value ? Colors.white : Colors.transparent,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Draft',
                    style: DesignTokens.textSmallBold.copyWith(
                      color: !value ? DesignTokens.grayDark : Colors.transparent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}