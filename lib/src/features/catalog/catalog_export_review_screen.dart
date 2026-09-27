import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';

enum CatalogExportKind { image, pdf }

/// Final proofing screen. The preview and the shared file are the same bytes,
/// so sellers can approve the real deliverable instead of a reconstruction.
class CatalogExportReviewScreen extends StatefulWidget {
  const CatalogExportReviewScreen.image({
    super.key,
    required this.file,
    required this.shareText,
    required this.title,
  }) : kind = CatalogExportKind.image,
       pdfBytes = null;

  const CatalogExportReviewScreen.pdf({
    super.key,
    required this.file,
    required this.pdfBytes,
    required this.shareText,
    required this.title,
  }) : kind = CatalogExportKind.pdf;

  final CatalogExportKind kind;
  final File file;
  final Uint8List? pdfBytes;
  final String shareText;
  final String title;

  @override
  State<CatalogExportReviewScreen> createState() =>
      _CatalogExportReviewScreenState();
}

class _CatalogExportReviewScreenState extends State<CatalogExportReviewScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      if (widget.kind == CatalogExportKind.pdf) {
        await Printing.sharePdf(
          bytes: widget.pdfBytes!,
          filename: widget.file.uri.pathSegments.last,
        );
      } else {
        await Share.shareXFiles([
          XFile(widget.file.path),
        ], text: widget.shareText);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open sharing. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.kind == CatalogExportKind.pdf;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Final proof',
              style: DesignTokens.textHeadline.copyWith(color: Colors.white),
            ),
            Text(
              'This is the exact file your customer will receive',
              style: DesignTokens.textCaption.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white.withValues(alpha: 0.06),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: DesignTokens.brandAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${isPdf ? 'PDF' : 'High-resolution image'} · ${widget.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  'PINCH TO INSPECT',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isPdf
                ? PdfPreview(
                    // Avoid native full-page buffers scaling with screen density.
                    dpi: 100,
                    build: (_) async => widget.pdfBytes!,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfFileName: widget.file.uri.pathSegments.last,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(
                        color: DesignTokens.brandAccent,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF151B2B),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(12),
                    child: InteractiveViewer(
                      minScale: 0.75,
                      maxScale: 5,
                      child: Image.file(
                        widget.file,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'The proof could not be rendered.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0B1020),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text(
                        'Edit',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share_rounded),
                      label: Text(_sharing ? 'Preparing…' : 'Approve & share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.brandAccent,
                        foregroundColor: const Color(0xFF07120F),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
