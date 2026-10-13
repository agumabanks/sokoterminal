import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

String coverageSummary(Map<String, dynamic>? value, {bool product = false}) {
  if (value == null) {
    return product ? 'Use my shop’s selling area' : 'Anyone can buy';
  }
  if (value['mode'] == 'radius') {
    return 'Within ${value['radius_km']} km of the selected location';
  }
  if (value['mode'] == 'polygon') {
    return 'Only inside the area drawn on the map';
  }
  return 'Anyone can buy';
}

/// The map and JSON are shared by shop defaults and per-product overrides.
class SellingCoverageCard extends StatefulWidget {
  const SellingCoverageCard({
    required this.value,
    required this.onChanged,
    this.product = false,
    this.shopValue,
    this.origin,
    super.key,
  });
  final Map<String, dynamic>? value, shopValue;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final bool product;
  final LatLng? origin;
  @override
  State<SellingCoverageCard> createState() => _SellingCoverageCardState();
}

class _SellingCoverageCardState extends State<SellingCoverageCard> {
  bool _expanded = false;
  String get _mode =>
      widget.value?['mode']?.toString() ??
      (widget.product ? 'inherit' : 'unrestricted');
  LatLng? get _center =>
      widget.value?['center_lat'] is num && widget.value?['center_lng'] is num
      ? LatLng(
          (widget.value!['center_lat'] as num).toDouble(),
          (widget.value!['center_lng'] as num).toDouble(),
        )
      : widget.origin;
  List<LatLng> get _points => (widget.value?['polygon'] as List? ?? [])
      .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();
  void _change(Map<String, dynamic> v) =>
      widget.onChanged({...?widget.value, ...v});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Who can buy online?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Done' : 'Change'),
              ),
            ],
          ),
          Text(
            coverageSummary(
              widget.value ?? widget.shopValue,
              product: widget.product && widget.shopValue == null,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Selling area'),
              items: [
                if (widget.product)
                  const DropdownMenuItem(
                    value: 'inherit',
                    child: Text('Same as my shop'),
                  ),
                const DropdownMenuItem(
                  value: 'unrestricted',
                  child: Text('Anyone'),
                ),
                const DropdownMenuItem(
                  value: 'radius',
                  child: Text('Near a location'),
                ),
                const DropdownMenuItem(
                  value: 'polygon',
                  child: Text('Draw an area'),
                ),
              ],
              onChanged: (mode) {
                if (mode == null) return;
                if (mode == 'inherit') {
                  widget.onChanged(null);
                  return;
                }
                widget.onChanged({
                  'mode': mode,
                  if (_center != null) 'center_lat': _center!.latitude,
                  if (_center != null) 'center_lng': _center!.longitude,
                  'radius_km': widget.value?['radius_km'] ?? 5,
                  'polygon': widget.value?['polygon'] ?? [],
                });
              },
            ),
            if (_mode == 'radius' || _mode == 'polygon') ...[
              const SizedBox(height: 16),
              Text(
                _mode == 'radius'
                    ? 'Tap the map to choose the centre.'
                    : 'Tap at least 3 corners around your area. Connect the last corner to the first.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter:
                          _center ??
                          (_points.isEmpty
                              ? const LatLng(0.3476, 32.5825)
                              : _points.first),
                      initialZoom: 12,
                      onTap: (_, point) {
                        if (_mode == 'radius') {
                          _change({
                            'center_lat': point.latitude,
                            'center_lng': point.longitude,
                          });
                        } else if (_points.length < 60) {
                          _change({
                            'polygon': [
                              ..._points.map((p) => [p.latitude, p.longitude]),
                              [point.latitude, point.longitude],
                            ],
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.soko24.soko_seller_terminal',
                      ),
                      if (_mode == 'radius' && _center != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _center!,
                              radius:
                                  ((widget.value?['radius_km'] as num?)
                                          ?.toDouble() ??
                                      5) *
                                  1000,
                              useRadiusInMeter: true,
                              color: Colors.green.withValues(alpha: .15),
                              borderColor: Colors.green,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      if (_points.length >= 3 && _mode == 'polygon')
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _points,
                              color: Colors.green.withValues(alpha: .15),
                              borderColor: Colors.green,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (final p
                              in _mode == 'radius'
                                  ? [if (_center != null) _center!]
                                  : _points)
                            Marker(
                              point: p,
                              width: 32,
                              height: 32,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                      const SimpleAttributionWidget(
                        source: Text('OpenStreetMap contributors'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_mode == 'radius') ...[
                const SizedBox(height: 8),
                Text('Within ${widget.value?['radius_km'] ?? 5} km'),
                Slider(
                  min: 1,
                  max: 100,
                  divisions: 99,
                  value: ((widget.value?['radius_km'] as num?)?.toDouble() ?? 5)
                      .clamp(1, 100)
                      .toDouble(),
                  label: '${widget.value?['radius_km'] ?? 5} km',
                  onChanged: (v) => _change({'radius_km': v.round()}),
                ),
                if (_center == null)
                  const Text('Choose the centre before saving.'),
              ] else
                Row(
                  children: [
                    Text('${_points.length} corners'),
                    const Spacer(),
                    TextButton(
                      onPressed: _points.isEmpty
                          ? null
                          : () => _change({
                              'polygon': _points
                                  .take(_points.length - 1)
                                  .map((p) => [p.latitude, p.longitude])
                                  .toList(),
                            }),
                      child: const Text('Undo corner'),
                    ),
                    TextButton(
                      onPressed: () => _change({'polygon': []}),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              const Text(
                'Maps need internet. Saved boundaries work when you reconnect; checkout checks the buyer’s location.',
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
