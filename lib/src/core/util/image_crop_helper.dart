import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Crops a product/service photo to a professional 800×800 square.
Future<File?> cropProductImage(File source) async {
  const brandPrimary = Color(0xFF0F1D40);
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
        statusBarColor: brandPrimary,
        activeControlsWidgetColor: const Color(0xFF0EBE7E),
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
