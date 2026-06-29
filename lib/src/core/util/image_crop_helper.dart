import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/design_tokens.dart';

/// Crops a product/service photo to a professional 800×800 square.
Future<File?> cropProductImage(File source) async {
  const brandPrimary = DesignTokens.brandPrimary;
  final cropped = await ImageCropper().cropImage(
    sourcePath: source.path,
    maxWidth: 800,
    maxHeight: 800,
    compressQuality: 88,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop Photo',
        toolbarColor: brandPrimary,
        toolbarWidgetColor: Colors.white,
        statusBarLight: true,
        activeControlsWidgetColor: DesignTokens.brandAccent,
        lockAspectRatio: true,
        initAspectRatio: CropAspectRatioPreset.square,
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: 'Crop Photo',
        doneButtonTitle: 'Done',
        cancelButtonTitle: 'Cancel',
        aspectRatioLockEnabled: true,
        minimumAspectRatio: 1.0,
        resetAspectRatioEnabled: false,
      ),
    ],
  );
  return cropped != null ? File(cropped.path) : null;
}
