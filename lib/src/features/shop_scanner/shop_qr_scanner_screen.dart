import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/util/haptics.dart';

class ShopQrTarget {
  const ShopQrTarget({required this.lookup, required this.url});

  final String lookup;
  final Uri url;
}

ShopQrTarget? parseSokoShopQr(String rawValue) {
  final raw = rawValue.trim();
  if (raw.isEmpty) return null;

  if (raw.toUpperCase().startsWith('SOKO:SHOP:')) {
    final code = raw.substring('SOKO:SHOP:'.length).trim();
    if (code.isEmpty || int.tryParse(code) != null) return null;
    return ShopQrTarget(lookup: code, url: Uri.https('soko24.co', '/s/$code'));
  }

  final embeddedUrl = RegExp(
    r'https?://(?:www\.)?soko24\.co/[^\s]+',
    caseSensitive: false,
  ).firstMatch(raw)?.group(0);
  final candidate =
      embeddedUrl ??
      (raw.toLowerCase().startsWith('soko24.co/') ? 'https://$raw' : raw);
  final uri = Uri.tryParse(candidate);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final isSokoHost = host == 'soko24.co' || host == 'www.soko24.co';
  final isSokoScheme = uri.scheme.toLowerCase() == 'soko24';
  if (!isSokoHost && !isSokoScheme) return null;

  final segments = <String>[
    if (isSokoScheme && uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((segment) => segment.isNotEmpty),
  ];
  if (segments.length < 2) return null;
  final route = segments.first.toLowerCase();
  final lookup = segments[1].trim();
  if (lookup.isEmpty || (route == 's' && int.tryParse(lookup) != null)) {
    return null;
  }
  if (route != 's' && route != 'shop') return null;

  return ShopQrTarget(
    lookup: lookup,
    url: Uri.https('soko24.co', '/$route/$lookup'),
  );
}

class ShopQrScannerScreen extends StatefulWidget {
  const ShopQrScannerScreen({super.key});

  @override
  State<ShopQrScannerScreen> createState() => _ShopQrScannerScreenState();
}

class _ShopQrScannerScreenState extends State<ShopQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scanner;
  late final AnimationController _scanAnimation;
  bool _processing = false;
  bool _found = false;
  String _status = 'Point at a Soko shop QR code';

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      autoZoom: true,
    );
    _scanAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnimation.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _handleValue(String value) async {
    if (_processing) return;
    final target = parseSokoShopQr(value);
    if (target == null) {
      await _showNotShopCode();
      return;
    }

    setState(() {
      _processing = true;
      _found = true;
      _status = 'Shop found · Opening storefront';
    });
    await _scanner.stop();
    Haptics.success();
    await Future<void>.delayed(const Duration(milliseconds: 480));
    final opened = await launchUrl(
      target.url,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _processing = false;
      _found = false;
      _status = 'Could not open that shop. Try again.';
    });
    await _scanner.start();
  }

  Future<void> _showNotShopCode() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _status = 'That is not a Soko shop QR';
    });
    Haptics.warning();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted || _found) return;
    setState(() {
      _processing = false;
      _status = 'Point at a Soko shop QR code';
    });
  }

  Future<void> _scanPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final capture = await _scanner.analyzeImage(image.path);
    final value = capture == null || capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (value == null) {
      await _showNotShopCode();
      return;
    }
    await _handleValue(value);
  }

  Future<void> _pasteLink() async {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (value == null) {
      await _showNotShopCode();
      return;
    }
    await _handleValue(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) {
              if (capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value != null) unawaited(_handleValue(value));
            },
            errorBuilder: (context, error) => const _CameraUnavailable(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .72),
                  Colors.transparent,
                  Colors.black.withValues(alpha: .84),
                ],
                stops: const [0, .48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ScannerTopBar(scanner: _scanner),
                const Spacer(),
                _ScannerFrame(animation: _scanAnimation, found: _found),
                const Spacer(),
                _StatusPill(status: _status, found: _found),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GlassAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Scan photo',
                      onTap: _scanPhoto,
                    ),
                    const SizedBox(width: 14),
                    _GlassAction(
                      icon: Icons.content_paste_rounded,
                      label: 'Paste link',
                      onTap: _pasteLink,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerTopBar extends StatelessWidget {
  const _ScannerTopBar({required this.scanner});

  final MobileScannerController scanner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.close_rounded,
            onTap: Navigator.of(context).pop,
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Scan Soko',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Open any storefront instantly',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _RoundButton(
            icon: Icons.flashlight_on_rounded,
            onTap: scanner.toggleTorch,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({required this.animation, required this.found});

  final Animation<double> animation;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final accent = found ? DesignTokens.success : DesignTokens.brandAccent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 272,
      height: 272,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .28), blurRadius: 32),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(31),
        child: Stack(
          children: [
            CustomPaint(
              painter: _CornerPainter(color: found ? accent : Colors.white),
              size: const Size.square(272),
            ),
            if (!found)
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Positioned(
                  top: 24 + animation.value * 222,
                  left: 24,
                  right: 24,
                  child: child!,
                ),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, accent, Colors.transparent],
                    ),
                    boxShadow: [BoxShadow(color: accent, blurRadius: 12)],
                  ),
                ),
              ),
            if (found)
              Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 72,
                  color: accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const i = 16.0;
    const l = 38.0;
    final path = Path()
      ..moveTo(i, i + l)
      ..lineTo(i, i)
      ..lineTo(i + l, i)
      ..moveTo(size.width - i - l, i)
      ..lineTo(size.width - i, i)
      ..lineTo(size.width - i, i + l)
      ..moveTo(size.width - i, size.height - i - l)
      ..lineTo(size.width - i, size.height - i)
      ..lineTo(size.width - i - l, size.height - i)
      ..moveTo(i + l, size.height - i)
      ..lineTo(i, size.height - i)
      ..lineTo(i, size.height - i - l);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.found});

  final String status;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: found
            ? DesignTokens.success.withValues(alpha: .92)
            : Colors.black.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Camera access is unavailable. Enable Camera in Settings, or scan a saved QR photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
      ),
    );
  }
}
