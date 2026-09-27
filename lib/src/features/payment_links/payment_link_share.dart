import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// The QR contains the same HTTPS checkout URL as the caption, so a camera scan
/// opens the hosted payment page without requiring the Terminal app.
Future<Uint8List> paymentLinkQrCard(Map<String, dynamic> link) async {
  final url = link['url']?.toString() ?? '';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException(
      'This payment link has no valid secure web address.',
    );
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  void label(
    String value,
    double y,
    double size, {
    FontWeight weight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 620);
    painter.paint(canvas, Offset((720 - painter.width) / 2, y));
  }

  label('SCAN TO PAY', 30, 32, weight: FontWeight.bold);
  label(link['title']?.toString() ?? 'Soko24 payment', 80, 24);
  // A generous white quiet zone surrounds the QR on every side.
  canvas.save();
  canvas.translate(100, 155);
  QrPainter(
    data: url,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  ).paint(canvas, const Size(520, 520));
  canvas.restore();
  label(
    '${link['currency'] ?? 'UGX'} ${link['amount'] ?? ''}',
    710,
    34,
    weight: FontWeight.bold,
  );
  final pricing = link['pricing'];
  if (pricing is Map && pricing['service_fee'] != null) {
    label(
      'Mobile money charges (${pricing['service_fee_percent']}%): ${link['currency'] ?? 'UGX'} ${pricing['service_fee']}',
      770,
      20,
    );
  }
  label('Scan with your camera or open the link to pay', 810, 20);
  label('Soko24 • Secure web checkout', 850, 20);
  final picture = recorder.endRecording();
  final image = await picture.toImage(720, 900);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) throw StateError('Could not prepare the payment QR image.');
  return data.buffer.asUint8List();
}

Future<void> sharePaymentLink(
  BuildContext context,
  Map<String, dynamic> link,
) async {
  try {
    final bytes = await paymentLinkQrCard(link);
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'soko-scan-to-pay.png',
        ),
      ],
      fileNameOverrides: ['soko-scan-to-pay.png'],
      text:
          'Pay ${link['currency'] ?? 'UGX'} ${link['amount']} for ${link['title'] ?? 'your order'}.\n'
          'Scan the QR code or open this link to pay in your browser:\n${link['url']}',
      subject: 'Scan to pay • Soko24',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not share the QR code. Please try again or copy the link.',
          ),
        ),
      );
    }
  }
}
