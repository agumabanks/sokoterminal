import 'dart:io';

import 'package:flutter/material.dart';

import '../core/media/offline_media_cache.dart';

class OfflineCachedImage extends StatefulWidget {
  const OfflineCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<OfflineCachedImage> createState() => _OfflineCachedImageState();
}

class _OfflineCachedImageState extends State<OfflineCachedImage> {
  late Future<File?> _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = OfflineMediaCache.instance.resolve(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant OfflineCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fileFuture = OfflineMediaCache.instance.resolve(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.imageUrl.trim();
    if (raw.isEmpty) return _fallback();

    final uri = Uri.tryParse(raw);
    final scheme = (uri?.scheme ?? '').toLowerCase();
    final isNetwork = scheme == 'http' || scheme == 'https';

    if (!isNetwork) {
      final path = scheme == 'file' ? uri!.toFilePath() : raw;
      final file = File(path);
      if (!file.existsSync()) return _fallback();
      return Image.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return FutureBuilder<File?>(
      future: _fileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return Image.file(
            file,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => _fallback(),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return _loading();
        }

        return Image.network(
          raw,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _loading();
          },
        );
      },
    );
  }

  Widget _loading() {
    return widget.placeholder ??
        const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
  }

  Widget _fallback() => widget.errorWidget ?? widget.placeholder ?? const SizedBox();
}
