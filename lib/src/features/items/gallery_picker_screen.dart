import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/image_crop_helper.dart';

/// Full-screen grid picker for device photos with multi-select.
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  bool _loading = true;
  bool _permissionDenied = false;
  final List<AssetEntity> _assets = [];
  final Set<AssetEntity> _selected = {};
  final Map<String, Uint8List?> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Android 13+ uses Permission.photos; older Android versions fall back
    // to Permission.storage because Permission.photos does not exist there.
    PermissionStatus status = await Permission.photos.request();
    if (Platform.isAndroid && (status.isDenied || status.isRestricted)) {
      status = await Permission.storage.request();
    }
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final assets = await albums.first.getAssetListPaged(page: 0, size: 200);
    setState(() {
      _assets.addAll(assets);
      _loading = false;
    });

    // Load thumbnails in background
    for (final a in assets) {
      final thumb = await a.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
        quality: 80,
      );
      if (mounted) {
        setState(() => _thumbs[a.id] = thumb);
      }
    }
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else {
        _selected.add(asset);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);

    final files = <File>[];
    for (final asset in _selected) {
      final file = await asset.file;
      if (file != null) {
        final cropped = await cropProductImage(file);
        if (cropped != null) files.add(cropped);
      }
    }

    if (mounted) {
      Navigator.pop(context, files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _selected.isEmpty
              ? 'Select Photos'
              : '${_selected.length} selected',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _assets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Photo access denied',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    if (_assets.isEmpty) {
      return const Center(
        child: Text(
          'No photos found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final isSelected = _selected.contains(asset);
        final thumb = _thumbs[asset.id];

        return GestureDetector(
          onTap: () => _toggleSelection(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              thumb != null
                  ? Image.memory(thumb, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade900),

              // Selection overlay
              if (isSelected)
                Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),

              // Check indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesignTokens.brandPrimary
                        : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? DesignTokens.brandPrimary
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
