import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/util/image_crop_helper.dart';

Uint8List renderProductPhoto(Map<String, Object> options) {
  var photo = img.decodeImage(options['bytes'] as Uint8List);
  if (photo == null) throw const FormatException('Choose a JPG or PNG photo.');
  photo = img.bakeOrientation(photo);
  if (photo.width > 1600 || photo.height > 1600) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1600 : null,
      height: photo.height > photo.width ? 1600 : null,
    );
  }
  photo = img.copyRotate(photo, angle: (options['turns'] as int) * 90);
  switch (options['filter']) {
    case 'bright':
      photo = img.adjustColor(photo, brightness: 1.12, contrast: 1.04);
    case 'warm':
      photo = img.adjustColor(photo, saturation: 1.08, gamma: 0.95);
    case 'mono':
      photo = img.grayscale(photo);
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 88));
}

/// Non-destructive edits: saving creates a new file; the selected original is kept.
class ProductPhotoEditor extends StatefulWidget {
  const ProductPhotoEditor({required this.source, super.key});
  final File source;
  @override
  State<ProductPhotoEditor> createState() => _ProductPhotoEditorState();
}

class _ProductPhotoEditorState extends State<ProductPhotoEditor> {
  late File _base = widget.source;
  String _filter = 'original';
  int _turns = 0;
  bool _saving = false;
  late Future<Uint8List> _preview = _render();
  Future<Uint8List> _render() async => compute(renderProductPhoto, {
    'bytes': await _base.readAsBytes(),
    'turns': _turns,
    'filter': _filter,
  });
  void _refresh() => setState(() => _preview = _render());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit photo')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<Uint8List>(
              future: _preview,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'This photo could not be opened. Choose another.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return InteractiveViewer(
                  child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final cropped = await cropProductImage(_base);
                          if (cropped != null && mounted) {
                            _base = cropped;
                            _refresh();
                          }
                        },
                  icon: const Icon(Icons.crop),
                  label: const Text('Crop'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          _turns = (_turns + 1) % 4;
                          _refresh();
                        },
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Rotate'),
                ),
                for (final entry in const {
                  'original': 'Original',
                  'bright': 'Brighter',
                  'warm': 'Warm',
                  'mono': 'Black & white',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: _saving
                        ? null
                        : (_) {
                            _filter = entry.key;
                            _refresh();
                          },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          final data = await _preview;
                          final output = File(
                            '${widget.source.parent.path}/edited-${DateTime.now().microsecondsSinceEpoch}.jpg',
                          );
                          await output.writeAsBytes(data, flush: true);
                          if (context.mounted) Navigator.pop(context, output);
                        } catch (_) {
                          if (context.mounted) {
                            setState(() => _saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save this photo. Try again.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: Text(_saving ? 'Saving…' : 'Use this photo'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
