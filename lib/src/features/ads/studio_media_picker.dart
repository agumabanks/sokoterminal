import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/media/offline_media_cache.dart';
import '../../widgets/offline_cached_image.dart';
import '../checkout/checkout_screen.dart';
import 'brand_kit_screen.dart';

/// A picked image from device gallery, catalog, Soko uploads, or brand kit.
class StudioMediaPick {
  const StudioMediaPick({
    required this.src,
    required this.label,
    required this.source,
    this.uploadId,
  });

  /// Network URL or `file://` local path for canvas elements.
  final String src;
  final String label;
  final StudioMediaSourceKind source;
  final int? uploadId;
}

enum StudioMediaSourceKind {
  gallery,
  camera,
  product,
  service,
  sokoUpload,
  brandLogo,
}

const _accent = Color(0xFF0EBE7E);
const _surface = Color(0xFF0F1D40);

/// Production media picker: gallery, camera, catalog, Soko uploads, brand logo.
Future<StudioMediaPick?> showStudioMediaPicker(
  BuildContext context, {
  required WidgetRef ref,
  bool allowCamera = true,
  String title = 'Choose image',
}) {
  return showModalBottomSheet<StudioMediaPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _StudioMediaPickerSheet(
      ref: ref,
      allowCamera: allowCamera,
      title: title,
    ),
  );
}

class _StudioMediaPickerSheet extends ConsumerStatefulWidget {
  const _StudioMediaPickerSheet({
    required this.ref,
    required this.allowCamera,
    required this.title,
  });

  final WidgetRef ref;
  final bool allowCamera;
  final String title;

  @override
  ConsumerState<_StudioMediaPickerSheet> createState() =>
      _StudioMediaPickerSheetState();
}

class _StudioMediaPickerSheetState
    extends ConsumerState<_StudioMediaPickerSheet> {
  int _tab = 0;
  final _picker = ImagePicker();
  bool _loadingUploads = false;
  List<_UploadRow> _uploads = [];
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _loadUploads();
  }

  Future<void> _loadUploads() async {
    setState(() {
      _loadingUploads = true;
      _uploadError = null;
    });
    try {
      final res = await ref.read(sellerApiProvider).fetchSellerFiles(
            type: 'image',
            sort: 'newest',
          );
      final body = res.data;
      final rows = <_UploadRow>[];
      if (body is Map && body['data'] is List) {
        for (final item in body['data'] as List) {
          if (item is! Map) continue;
          final url = item['url']?.toString();
          if (url == null || url.isEmpty) continue;
          rows.add(_UploadRow(
            id: (item['id'] as num?)?.toInt() ?? 0,
            name: item['file_original_name']?.toString() ?? 'Upload',
            url: url,
          ));
        }
      }
      if (mounted) {
        setState(() {
          _uploads = rows;
          _loadingUploads = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = e.toString();
          _loadingUploads = false;
        });
      }
    }
  }

  Future<void> _pickDevice(ImageSource source) async {
    final xf = await _picker.pickImage(source: source, maxWidth: 4096);
    if (xf == null || !mounted) return;
    Navigator.pop(
      context,
      StudioMediaPick(
        src: 'file://${xf.path}',
        label: source == ImageSource.camera ? 'Camera' : 'Gallery',
        source: source == ImageSource.camera
            ? StudioMediaSourceKind.camera
            : StudioMediaSourceKind.gallery,
      ),
    );
  }

  void _pickUrl({
    required String url,
    required String label,
    required StudioMediaSourceKind kind,
    int? uploadId,
  }) {
    Navigator.pop(
      context,
      StudioMediaPick(
        src: url,
        label: label,
        source: kind,
        uploadId: uploadId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final kit = ref.watch(brandKitProvider);
    final items = ref.watch(itemsStreamProvider).valueOrNull ?? [];
    final services = ref.watch(servicesStreamProvider).valueOrNull ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.allowCamera)
                  IconButton(
                    onPressed: () => _pickDevice(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: _accent, size: 22),
                    tooltip: 'Camera',
                  ),
                IconButton(
                  onPressed: () => _pickDevice(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined,
                      color: _accent, size: 22),
                  tooltip: 'Gallery',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _TabChip(
                  label: 'Catalog',
                  icon: Icons.inventory_2_outlined,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _TabChip(
                  label: 'Soko Uploads',
                  icon: Icons.cloud_outlined,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                _TabChip(
                  label: 'Brand',
                  icon: Icons.badge_outlined,
                  selected: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (_tab) {
              0 => _CatalogGrid(
                  scrollCtrl: scrollCtrl,
                  items: items,
                  services: services,
                  onPick: _pickUrl,
                ),
              1 => _UploadsGrid(
                  scrollCtrl: scrollCtrl,
                  loading: _loadingUploads,
                  error: _uploadError,
                  uploads: _uploads,
                  onRetry: _loadUploads,
                  onPick: _pickUrl,
                ),
              _ => _BrandPanel(
                  scrollCtrl: scrollCtrl,
                  kit: kit,
                  onPick: _pickUrl,
                ),
            },
          ),
          SizedBox(height: bottom + 8),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : Colors.white54),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({
    required this.scrollCtrl,
    required this.items,
    required this.services,
    required this.onPick,
  });

  final ScrollController scrollCtrl;
  final List<Item> items;
  final List<Service> services;
  final void Function({
    required String url,
    required String label,
    required StudioMediaSourceKind kind,
  }) onPick;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && services.isEmpty) {
      return const Center(
        child: Text('No products or services in catalog',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (items.isNotEmpty) ...[
          const _SectionLabel('Products'),
          _MediaGrid(
            children: items.map((item) {
              final url = item.imageUrl ?? item.thumbnailUrl;
              return _MediaTile(
                label: item.name,
                imageUrl: url,
                onTap: () async {
                  if (url == null || url.isEmpty) return;
                  final file =
                      await OfflineMediaCache.instance.resolve(url);
                  final src = file != null
                      ? 'file://${file.path}'
                      : url;
                  onPick(
                    url: src,
                    label: item.name,
                    kind: StudioMediaSourceKind.product,
                  );
                },
              );
            }).toList(),
          ),
        ],
        if (services.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel('Services'),
          _MediaGrid(
            children: services.map((svc) {
              return _MediaTile(
                label: svc.title,
                imageUrl: svc.imageUrl,
                onTap: () async {
                  final url = svc.imageUrl;
                  if (url == null || url.isEmpty) return;
                  final file =
                      await OfflineMediaCache.instance.resolve(url);
                  final src = file != null
                      ? 'file://${file.path}'
                      : url;
                  onPick(
                    url: src,
                    label: svc.title,
                    kind: StudioMediaSourceKind.service,
                  );
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _UploadsGrid extends StatelessWidget {
  const _UploadsGrid({
    required this.scrollCtrl,
    required this.loading,
    required this.error,
    required this.uploads,
    required this.onRetry,
    required this.onPick,
  });

  final ScrollController scrollCtrl;
  final bool loading;
  final String? error;
  final List<_UploadRow> uploads;
  final VoidCallback onRetry;
  final void Function({
    required String url,
    required String label,
    required StudioMediaSourceKind kind,
    int? uploadId,
  }) onPick;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(_accent),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load uploads',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (uploads.isEmpty) {
      return const Center(
        child: Text('No Soko uploads yet — use Gallery or upload from catalog',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const _SectionLabel('Your Soko uploads'),
        _MediaGrid(
          children: uploads.map((u) {
            return _MediaTile(
              label: u.name,
              imageUrl: u.url,
              onTap: () => onPick(
                url: u.url,
                label: u.name,
                kind: StudioMediaSourceKind.sokoUpload,
                uploadId: u.id,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.scrollCtrl,
    required this.kit,
    required this.onPick,
  });

  final ScrollController scrollCtrl;
  final BrandKit kit;
  final void Function({
    required String url,
    required String label,
    required StudioMediaSourceKind kind,
  }) onPick;

  @override
  Widget build(BuildContext context) {
    final logoUrl = kit.logoNetworkUrl;
    final logoLocal = kit.logoLocalPath;

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionLabel('Brand kit logo'),
        if (logoUrl?.isNotEmpty == true || logoLocal?.isNotEmpty == true)
          _MediaTile(
            label: kit.businessName.isNotEmpty
                ? kit.businessName
                : 'Brand logo',
            imageUrl: logoUrl,
            localPath: logoLocal,
            onTap: () {
              if (logoUrl?.isNotEmpty == true) {
                onPick(
                  url: logoUrl!,
                  label: 'Brand logo',
                  kind: StudioMediaSourceKind.brandLogo,
                );
              } else if (logoLocal?.isNotEmpty == true) {
                onPick(
                  url: 'file://$logoLocal',
                  label: 'Brand logo',
                  kind: StudioMediaSourceKind.brandLogo,
                );
              }
            },
          )
        else
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Add a logo in Brand Kit first, or pick from Gallery / Catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.82,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.localPath,
  });

  final String label;
  final String? imageUrl;
  final String? localPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: imageUrl?.isNotEmpty == true
                  ? OfflineCachedImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : localPath?.isNotEmpty == true
                      ? Image.file(
                          File(localPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white10,
      child: const Icon(Icons.image_outlined, color: Colors.white24),
    );
  }
}

class _UploadRow {
  const _UploadRow({
    required this.id,
    required this.name,
    required this.url,
  });

  final int id;
  final String name;
  final String url;
}