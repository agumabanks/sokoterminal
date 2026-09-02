import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Google Play photo and video permissions policy', () {
    test(
      'restricted storage permissions are removed from merged manifests',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        const restrictedPermissions = <String>[
          'android.permission.READ_EXTERNAL_STORAGE',
          'android.permission.READ_MEDIA_IMAGES',
          'android.permission.READ_MEDIA_VIDEO',
          'android.permission.MANAGE_EXTERNAL_STORAGE',
        ];

        for (final permission in restrictedPermissions) {
          final declarations = RegExp(
            '<uses-permission[^>]*android:name="$permission"[^>]*/>',
            dotAll: true,
          ).allMatches(manifest);
          for (final declaration in declarations) {
            expect(
              declaration.group(0),
              contains('tools:node="remove"'),
              reason:
                  '$permission must never be packaged in the release bundle',
            );
          }
        }
      },
    );

    test('app code never requests broad photo or storage access', () {
      final dartSources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final source in dartSources) {
        final contents = source.readAsStringSync();
        expect(
          contents,
          isNot(contains('Permission.photos')),
          reason: source.path,
        );
        expect(
          contents,
          isNot(contains('Permission.videos')),
          reason: source.path,
        );
        expect(
          contents,
          isNot(contains('Permission.storage')),
          reason: source.path,
        );
        expect(
          contents,
          isNot(contains("package:photo_manager")),
          reason: source.path,
        );
      }
    });

    test('Android Photo Picker is explicitly enabled', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('useAndroidPhotoPicker = true'));
    });
  });
}
