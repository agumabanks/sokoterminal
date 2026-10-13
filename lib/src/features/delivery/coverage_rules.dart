String? coverageError(Map<String, dynamic>? rule) {
  if (rule == null || rule['mode'] == 'unrestricted') return null;
  bool coordinate(dynamic lat, dynamic lng) =>
      lat is num &&
      lng is num &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
  if (rule['mode'] == 'radius') {
    if (!coordinate(rule['center_lat'], rule['center_lng'])) {
      return 'Choose the centre of your selling area on the map.';
    }
    final radius = rule['radius_km'];
    if (radius is! num || !radius.isFinite || radius < 1 || radius > 100) {
      return 'Choose a distance between 1 and 100 km.';
    }
    return null;
  }
  if (rule['mode'] != 'polygon') return 'Choose a selling area.';
  final points = rule['polygon'];
  if (points is! List || points.length < 3 || points.length > 60) {
    return 'Draw between 3 and 60 corners on the map.';
  }
  for (final point in points) {
    if (point is! List ||
        point.length != 2 ||
        !coordinate(point[0], point[1])) {
      return 'Check the corners of your selling area.';
    }
  }
  num cross(List a, List b, List c) =>
      (b[1] - a[1]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[1] - a[1]);
  double area = 0;
  final unique = <String>{};
  for (var i = 0; i < points.length; i++) {
    if (!unique.add('${points[i][0]},${points[i][1]}')) {
      return 'Each corner must be in a different place.';
    }
    final next = points[(i + 1) % points.length];
    area += points[i][1] * next[0] - next[1] * points[i][0];
    for (var j = i + 2; j < points.length; j++) {
      if (i == 0 && j == points.length - 1) continue;
      final a = points[i] as List,
          b = next as List,
          c = points[j] as List,
          d = points[(j + 1) % points.length] as List;
      if (cross(a, b, c) * cross(a, b, d) <= 0 &&
          cross(c, d, a) * cross(c, d, b) <= 0 &&
          (a[1] <= b[1] ? b[1] : a[1]) >= (c[1] <= d[1] ? c[1] : d[1]) &&
          (c[1] <= d[1] ? d[1] : c[1]) >= (a[1] <= b[1] ? a[1] : b[1]) &&
          (a[0] <= b[0] ? b[0] : a[0]) >= (c[0] <= d[0] ? c[0] : d[0]) &&
          (c[0] <= d[0] ? d[0] : c[0]) >= (a[0] <= b[0] ? a[0] : b[0])) {
        return 'The boundary crosses itself. Undo a corner and draw around the outside.';
      }
    }
  }
  if (area.abs() < 1e-10) {
    return 'Draw a wider area with corners that form a boundary.';
  }
  return null;
}
